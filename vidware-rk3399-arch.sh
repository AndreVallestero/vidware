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

echo "Installing dependnecies from the AUR"
git clone https://aur.archlinux.org/rockchip-mpp.git
cd rockchip-mpp
makepkg --noconfirm --needed -ACsif
cd ..

echo "Downloading package tarballs to custom compile"
echo "https://ffmpeg.org/releases/ffmpeg-4.2.tar.bz2 \
https://github.com/mpv-player/mpv/archive/v0.30.0.tar.gz \
https://download.videolan.org/x264/snapshots/x264-snapshot-20191204-2245-stable.tar.bz2" \
| xargs -n1 -P$THREADS wget -q -N

echo "Extracting and removing tarballs"
ls *.gz | xargs -n1 -P$THREADS tar --skip-old-files -xzf
ls *.bz2 | xargs -n1 -P$THREADS tar --skip-old-files -jxf
rm *.tar*

echo "Building x264"
cd x264*
./configure --prefix=/usr --enable-shared --enable-lto --enable-strip \
	--extra-cflags="-march=armv8-a+crc+crypto -mtune=cortex-a72.cortex-a53 -mcpu=cortex-a72.cortex-a53 -Ofast -pipe -fno-plt -fvisibility=hidden -flto -Wl,-lfto -s" \
	--extra-ldflags="-Wl,--hash-style=both -Wl,-znow -Wl,--as-needed -Wl,--sort-common -Wl,--relax -Wl,--enable-new-dtags -Wl,-flto -Wl,-s"
make -j$THREADS
sudo make install
sudo ldconfig

echo "Building ffmpeg"
cd ../ffmpeg*
./configure --prefix=/usr --enable-gpl --enable-version3 --enable-nonfree --enable-static --enable-gmp \
	--enable-gnutls --enable-libass --enable-libbluray --enable-libcdio --enable-libfdk-aac \
	--enable-libfreetype --enable-libmp3lame --enable-libtheora --enable-libvorbis --enable-libx264 \
	--enable-libxcb --enable-opencl --enable-libdrm --enable-rkmpp --enable-lto \
	--enable-hardcoded-tables --disable-debug \
	--extra-cflags="-march=armv8-a+crc+crypto -mtune=cortex-a72.cortex-a53 -mcpu=cortex-a72.cortex-a53 -Ofast -pipe -fno-plt -fvisibility=hidden -flto -Wl,-lfto -s" \
	--extra-ldflags="-Wl,--hash-style=both -Wl,-znow -Wl,--as-needed -Wl,--sort-common -Wl,--relax -Wl,--enable-new-dtags -Wl,-flto -Wl,-s"
make -j$THREADS
sudo make install
sudo ldconfig

echo "Building mpv"
cd ../mpv*
waf configure --prefix=/usr --enable-egl-drm --enable-cdda --enable-dvdnav --enable-libbluray \
	--disable-debug-build 
	
waf build -j$THREADS
sudo waf install
sudo ldconfig

echo "Configuring mpv"
mkdir -p ~/.config/mpv
echo 'vo=gpu
gpu-context=drm
hwdec=rkmpp
demuxer-max-bytes=41943040
demuxer-max-back-bytes=41943040
drm-draw-plane=1
drm-drmprime-video-plane=0

ytdl-format=bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best
alsa-buffer-time=800000' > ~/.config/mpv/mpv.conf

echo "Installation complete, downloading demo"
cd ../
youtube-dl -f "bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best" \
	-o demo.mp4 https://www.youtube.com/watch?v=LXb3EKWsInQ

echo "Playing demo"
mpv $(ls | grep demo)
