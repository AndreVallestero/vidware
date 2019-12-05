#!/bin/bash

# TODO:
#	- Make script compatible with posix compilant shell (/bin/sh)
#	- Have a top level script download common dependencies among all scripts then auto detect the
#		hardware then run device specific scripts
#	- Use a file name resolver to resolve binaries and their corresponding packages so the script
#		can be distribution agnostic (test with Debian/Ubuntu and Arch/Manjaro) 
#	- Prefer multithreaded decompression tools like pigz, pbzip2, zstd. Use --threads=0 for xz
#		and zstd to enable multithreading. Use make -j($nproc).

# dependencies: libass waf lame
# only clean up when finished so if build is intterupted, progress is saved
#

# file structure
#
# vidware-x.sh
#	vidware
#		downloads
#		build
#		packages

# Define variables
THREADS=$(nproc)
EXTRA_CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a72.cortex-a53 -mcpu=cortex-a72.cortex-a53"

# Install dependencies
sudo pacman --noconfirm --needed -S findutils wget tar waf libass

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
./configure --prefix=/usr --enable-shared --disable-opencl --extra-cflags=$EXTRA_CFLAGS
make -j$THREADS
#sudo ldconfig


