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


# Define variables
THREADS=$(nproc)
EXTRA_CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a72.cortex-a53 -mcpu=cortex-a72.cortex-a53 \
	-Ofast -pipe -fno-plt -fvisibility=hidden -flto -s"

# Install dependencies
sudo pacman --noconfirm --needed -S findutils wget tar make waf libass youtube-dl

echo "Preparing build enviornment"
mkdir -p vidware/{downloads,build,packages}

echo "Downloading packages to custom compile"
cd vidware/downloads
echo "https://ffmpeg.org/releases/ffmpeg-4.0.2.tar.bz2 \
https://github.com/mpv-player/mpv/archive/v0.29.0.tar.gz \
https://download.videolan.org/x264/snapshots/x264-snapshot-20180831-2245-stable.tar.bz2" \
| xargs -n1 -P$THREADS wget -q -nc

echo "Extracting packages and moving to build directory"
ls *.gz | xargs -n1 -P$THREADS tar xzf
ls *.bz2 | xargs -n1 -P$THREADS tar jxf
shopt -s extglob
mv !(*.tar*) ../build
cd ../build
mv *ffmpeg* ffmpeg
mv *mpv* mpv
mv *x264* x264

echo "Building x264"
cd x264
./configure --prefix=/usr --enable-shared --enable-opencl --extra-cflags=$EXTRA_CFLAGS
make -j$THREADS
sudo make install
sudo ldconfig

echo "Building ffmpeg"
cd ../ffmpeg
./configure --prefix=/usr --enable-gpl --enable-nonfree --enable-static --enable-libtheora \
	--enable-libvorbis --enable-omx --enable-omx-rpi --enable-mmal --enable-libxcb \
	--enable-libfreetype --enable-libass --enable-gnutls --enable-opencl --enable-libcdio \
	--enable-libbluray \
	--extra-cflags="-march=armv8-a+crc -mfpu=neon-fp-armv8 -mtune=cortex-a53" \ 
	--enable-libx264 --enable-libfdk-aac --enable-libmp3lame   

echo "Building mpv"
cd ../mpv
./waf configure --prefix=/usr --enable-cdda --enable-dvdread --enable-dvdnav --enable-libbluray
./waf build -j$THREADS
sudo ./waf install
sudo ldconfig

echo "Configuring mpv"
if [-f ~/.config/mpv/mpv.conf]; then
	"ytdl-format=bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best
--alsa-buffer-time=800000" > ~/.config/mpv/mpv.conf
fi

echo "Installation complete"
mpv -version

echo "Downloading demo"
cd ../../downloads
youtube-dl -f bestvideo[height<=?1080][width<=?1920][fps<=?30][vcodec!=?vp9]+bestaudio/best \
	-o demo.mp4 https://youtu.be/LXb3EKWsInq

echo "Playing demo"
youtube-dl demo.mp4
