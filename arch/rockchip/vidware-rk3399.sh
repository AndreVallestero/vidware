#!/bin/bash

# TODO:
#	- Make script compatible with posix compilant shell (/bin/sh)
#	- Have a top level script download common dependencies among all scripts then auto detect the
#		hardware then run device specific scripts
#	- Use a file name resolver to resolve binaries and their corresponding packages so the script
#		can be distribution agnostic (test with Debian/Ubuntu and Arch/Manjaro) 
#	- Prefer multithreaded decompression tools like pigz, pbzip2, zstd. Use --threads=0 for xz
#		and zstd to enable multithreading. Use make -j($nproc).
#	- Only clean up when finished so if build is intterupted, progress is saved

echo "Installing dependencies"
sudo pacman --noconfirm --needed -S findutils wget tar make sdl2 automake libva luajit-git mesa libtool \
	libvdpau libxcb texinfo fontconfig fribidi python-docutils libbluray libjpeg-turbo libtheora \
	libvorbis gnutls xdotool libcdio libcdio-paranoia libdvdread libdvdnav waf libass youtube-dl \
	libfdk-aac libclc opencl-headers ocl-icd rockchip-tools cmake libdrm

echo "Preparing build enviornment"
THREADS=$(nproc)
mkdir -p vidware/{downloads,build}

echo "Downloading packages to custom compile"
cd vidware/downloads
echo "https://ffmpeg.org/releases/ffmpeg-4.2.tar.bz2 \
https://github.com/mpv-player/mpv/archive/v0.30.0.tar.gz \
https://download.videolan.org/x264/snapshots/x264-snapshot-20191204-2245-stable.tar.bz2" \
| xargs -n1 -P$THREADS wget -q -nc

echo "Extracting packages and moving to build directory"
ls *.gz | xargs -n1 -P$THREADS tar --skip-old-files -xzf
ls *.bz2 | xargs -n1 -P$THREADS tar --skip-old-files -jxf
shopt -s extglob
mv -n !(*.tar*) ../build
cd ../build

echo "Cloning git packages to custom compile"
git clone https://github.com/rockchip-linux/mpp.git

echo "Building mpp"
cd mpp*/build 
cmake -DCMAKE_INSTALL_PREFIX:PATH='/usr' -DCMAKE_BUILD_TYPE:STRING='Release' -DRKPLATFORM:BOOL='ON' \
	-DHAVE_DRM:BOOL='ON' -IEP_TEST:BOOL='OFF' -MPI_DEC_MT_TEST:BOOL='OFF' -MPI_DEC_MULTI_TEST:BOOL='OFF' \
	-MPI_DEC_TEST:BOOL='OFF' -MPI_ENC_MULTI_TEST:BOOL='OFF' -MPI_ENC_TEST:BOOL='OFF'
	-MPI_RC2_TEST:BOOL='OFF' -MPI_RC_TEST:BOOL='OFF' -MPI_TEST:BOOL='OFF' -MPP_BUFFER_TEST:BOOL='OFF' 
	-MPP_ENV_TEST:BOOL='OFF' -MPP_INFO_TEST:BOOL='OFF' -MPP_LOG_TEST:BOOL='OFF' \
	-MPP_MEM_TEST:BOOL='OFF' -MPP_PACKET_TEST:BOOL='OFF' -MPP_PLATFORM_TEST:BOOL='OFF' \
	-MPP_RUNTIME_TEST:BOOL='OFF' -MPP_TASK_TEST:BOOL='OFF' -MPP_THREAD_TEST:BOOL='OFF' \
	-MPP_TIME_TEST:BOOL='OFF' -RGA_TEST:BOOL='OFF' -VPU_API_TEST:BOOL='OFF' ..
cmake build .
make
sudo make install
sudo ldconfig

echo "Building x264"
cd ../../x264*
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
	--enable-libxcb --enable-opencl --enable-libdrm --enable-omx --enable-rkmpp --enable-lto \
	--enable-hardcoded-tables --disable-debug \
	--extra-cflags="-march=armv8-a+crc+crypto -mtune=cortex-a72.cortex-a53 -mcpu=cortex-a72.cortex-a53 -Ofast -pipe -fno-plt -fvisibility=hidden -flto -Wl,-lfto -s" \
	--extra-ldflags="-Wl,--hash-style=both -Wl,-znow -Wl,--as-needed -Wl,--sort-common -Wl,--relax -Wl,--enable-new-dtags -Wl,-flto -Wl,-s"
make -j$THREADS
sudo make install
sudo ldconfig

echo "Building mpv"
cd ../mpv*
waf configure --prefix=/usr --enable-cdda --enable-dvdnav --enable-libbluray --enable-lgpl \
	--disable-debug-build --enable-drm --enable-drmprime
waf build -j$THREADS
sudo waf install
sudo ldconfig

echo "Configuring mpv"
if [ -f ~/.config/mpv/mpv.conf ]; then
	"ytdl-format=bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best
--alsa-buffer-time=800000" > ~/.config/mpv/mpv.conf
fi

echo "Installation complete"
mpv -version

echo "Downloading demo"
cd ../../downloads
if [ ! -f demo.* ]; then
	youtube-dl -f "bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best" \
		-o demo.mp4 https://www.youtube.com/watch?v=LXb3EKWsInQ
fi

echo "Playing demo"
mpv $(ls | grep demo)
