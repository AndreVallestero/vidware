#!/bin/bash

# Hardware acceleration info:
# 	- Decoder API:
#		- Internal: 		VAAPI / VDPAU
#		- Standalone: 		RockChip MPP / V4L2
#		- Hardware output:	RockChip MPP / VAAPI / VDPAU
#	- Encoder API:
#		- Standalone:		VAAPI / V4L2
#		- Hardware input:	VAAPI
#	- Other:
#		- Filtering:		VAAPI / OpenCL
#		- Hardware context:	RockChip MPP / VAAPI / DVPAU / OpenCL 
#
# TODO:
#	- Make script compatible with posix compilant shell (/bin/sh)
#	- Have a top level script download common dependencies among all scripts then auto detect the
#		hardware then run device specific scripts
#	- Use a file name resolver to resolve binaries and their corresponding packages so the script
#		can be distribution agnostic (test with Debian/Ubuntu and Arch/Manjaro) 
#	- Prefer multithreaded decompression tools like pigz, pbzip2, zstd. Use --threads=0 for xz
#		and zstd to enable multithreading. Use make -j($nproc).
#	- Only clean up when finished so if build is intterupted, progress is saved

echo "Preparing build enviornment"
THREADS=$(nproc)
mkdir -p vidware-build
cd vidware-build

echo "Installing dependencies"
sudo pacman --noconfirm --needed -S findutils wget tar make sdl2 automake libva luajit-git mesa-git libtool \
	libvdpau libxcb texinfo fontconfig fribidi python-docutils libbluray libjpeg-turbo libtheora \
	libvorbis gnutls xdotool libcdio libcdio-paranoia libdvdread libdvdnav waf libass youtube-dl \
	libfdk-aac libclc opencl-headers ocl-icd rockchip-tools cmake libdrm

echo "Downloading package tarballs to custom compile"
echo "https://ffmpeg.org/releases/ffmpeg-4.2.tar.bz2" \
	| xargs -n1 -P$THREADS wget -q -N

echo "Downloading latest git repos to custom compile"
git clone https://github.com/rockchip-linux/mpp.git

echo "Extracting and removing tarballs"
ls *.gz | xargs -n1 -P$THREADS tar --skip-old-files -xzf
ls *.bz2 | xargs -n1 -P$THREADS tar --skip-old-files -jxf
rm *.tar*

echo "Building mpp"
cd mpp*/build
sed -i 's/${SYSPROC} STREQUAL "armv8-a"/${SYSPROC} STREQUAL "armv8-a" OR ${SYSPROC} STREQUAL "aarch64"/g' ../CMakeLists.txt
cmake -DHAVE_DRM:BOOL='ON' -DRKPLATFORM:BOOL='ON' -DCMAKE_INSTALL_PREFIX:PATH='/usr' ..
make -j$THREADS
sudo make install
sudo ldconfig

echo "Building ffmpeg"
cd ../../ffmpeg*
./configure --prefix=/usr --enable-rkmpp --enable-nonfree --enable-opengl --enable-libdrm --enable-version3 --enable-shared --disable-static --enable-openssl
make -j$THREADS
sudo make install
sudo ldconfig
