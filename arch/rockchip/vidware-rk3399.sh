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

mkdir -p vidware/{downloads,build,packages}

echo "https://ffmpeg.org/releases/ffmpeg-4.0.2.tar.bz2 \
https://github.com/mpv-player/mpv/archive/v0.29.0.tar.gz \
https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz \
https://download.videolan.org/x264/snapshots/x264-snapshot-20180831-2245-stable.tar.bz2" | xargs -n 1 -P 8 wget -q


mkdir Vidware_Downloads
mkdir Vidware_Build
mkdir Vidware_Packages
sudo mkdir -p /usr/share/doc/lame
cd /home/pi/Vidware_Downloads

wget -q --show-progress --no-use-server-timestamps https://ffmpeg.org/releases/ffmpeg-4.0.2.tar.bz2
wget -q --show-progress --no-use-server-timestamps https://github.com/mpv-player/mpv/archive/v0.29.0.tar.gz
wget -q --show-progress --no-use-server-timestamps https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz
wget -q --show-progress --no-use-server-timestamps https://download.videolan.org/x264/snapshots/x264-snapshot-20180831-2245-stable.tar.bz2

cp *.gz /home/pi/Vidware_Build
cp *.bz2 /home/pi/Vidware_Build
cd /home/pi/Vidware_Build
ls *.gz | xargs -n1 tar xzf
ls *.bz2 | xargs -n1 tar jxf
rm *.gz
rm *.bz2
mv ffmpeg* ffmpeg
mv mpv* mpv
mv x264* x264
mv fdk* aac
mv lame* mp3
mv libass* libass
cp /home/pi/Vidware_Downloads/waf /home/pi/Vidware_Build/mpv
sudo apt-get install -y automake checkinstall libsdl2-dev libva-dev libluajit-5.1-dev libgles2-mesa-dev libtool libvdpau-dev libxcb-shm0-dev texinfo libfontconfig1-dev libfribidi-dev python-docutils libbluray-dev libjpeg-dev libtheora-dev libvorbis-dev libgnutls28-dev linux-headers-rpi2 libomxil-bellagio-dev xdotool libcdio-cdda-dev libcdio-paranoia-dev libdvdread-dev libdvdnav-dev libbluray-dev
cd /home/pi/Vidware_Build/x264
./configure --prefix=/usr --enable-shared --disable-opencl --extra-cflags="-march=armv8-a+crc -mfpu=neon-fp-armv8 -mtune=cortex-a53"
make -j4
sudo checkinstall -y --pkgname x264 --pkgversion 0.155 make install
sudo ldconfig
cd /home/pi/Vidware_Build/aac
./autogen.sh
./configure --prefix=/usr --enable-shared
make -j4
sudo checkinstall -y --pkgname fdk-aac --pkgversion 0.1.6 make install
sudo ldconfig
cd /home/pi/Vidware_Build/mp3
./configure --prefix=/usr --enable-shared
make -j4
sudo checkinstall -y --pkgname mp3lame --pkgversion 3.100 make install
sudo ldconfig
cd /home/pi/Vidware_Build/libass
./configure --prefix=/usr --enable-shared
make -j4
sudo checkinstall -y --pkgname libass --pkgversion 0.14.0 make install
sudo ldconfig
cd /home/pi/Vidware_Build/ffmpeg
./configure \
--prefix=/usr \
--enable-gpl \
--enable-nonfree \
--enable-static \
--enable-libtheora \
--enable-libvorbis \
--enable-omx \
--enable-omx-rpi \
--enable-mmal \
--enable-libxcb \
--enable-libfreetype \
--enable-libass \
--enable-gnutls \
--disable-opencl \
--enable-libcdio \
--enable-libbluray \
--extra-cflags="-march=armv8-a+crc -mfpu=neon-fp-armv8 -mtune=cortex-a53" \
--enable-libx264 \
--enable-libfdk-aac \
--enable-libmp3lame
make -j4
sudo checkinstall -y --pkgname ffmpeg --pkgversion 4.0.2 make install
sudo ldconfig
cd /home/pi/Vidware_Build/mpv
sed -i_BACKUP '767s|GLESv2|brcmGLESv2|g' /home/pi/Vidware_Build/mpv/wscript
sed -i_BACKUP '939,951d' /home/pi/Vidware_Build/mpv/audio/out/ao_alsa.c
sed -i '939i\
\
\
static int get_space(struct ao *ao)\
{\
int err;\
struct priv *p = ao->priv;\
\
snd_pcm_state_t state = snd_pcm_state(p->alsa);\
snd_pcm_sframes_t space = state == SND_PCM_STATE_SETUP || state == SND_PCM_STATE_PAUSED\
? p->buffersize : snd_pcm_avail(p->alsa);\
if (space < 0) {\
if (space == -EPIPE) { // EOF\
err = snd_pcm_prepare(p->alsa);\
CHECK_ALSA_ERROR("pcm recover error");\
return p->buffersize;\
}\
\
MP_ERR(ao, "Error received from snd_pcm_avail (%ld, %s)!\\n",\
space, snd_strerror(space));\
\
// request a reload of the AO if device is not present,\
// then error out.\
\
' /home/pi/Vidware_Build/mpv/audio/out/ao_alsa.c
sed -i_BACKUP '143s|built on|built by the RPi_Mike script on|g' /home/pi/Vidware_Build/mpv/player/main.c
export LIBRARY_PATH=/opt/vc/lib
export PKG_CONFIG_PATH=/opt/vc/lib/pkgconfig
export CPATH=/opt/vc/include
./waf configure --prefix=/usr --enable-rpi --enable-cdda --enable-dvdread --enable-dvdnav --enable-libbluray
./waf build -j4
sudo checkinstall -y --pkgname mpv --pkgversion 0.29.0 ./waf install
sudo ldconfig
mkdir -p /home/pi/.config/mpv
echo "--fullscreen
rpi-background=yes
screenshot-format=png
ytdl-format=bestvideo[height<=?1080][fps<=?30][vcodec!=?vp9]+bestaudio/best
--alsa-buffer-time=800000" > /home/pi/.config/mpv/mpv.conf
cp /home/pi/.config/mimeapps.list /home/pi/.config/mimeapps.list_BACKUP &> /dev/null
echo "[Added Associations]
video/mp4=mpv.desktop;
video/webm=mpv.desktop;
video/x-matroska=mpv.desktop;
video/mp2t=mpv.desktop;
video/quicktime=mpv.desktop;
video/x-msvideo=mpv.desktop;
video/x-ms-wmv=mpv.desktop;
video/mpeg=mpv.desktop;
audio/x-wav=mpv.desktop;
audio/mpeg=mpv.desktop;
audio/mp4=mpv.desktop;
audio/flac=mpv.desktop;
text/plain=leafpad.desktop;

[Default Applications]
video/mp4=mpv.desktop
video/webm=mpv.desktop
video/x-matroska=mpv.desktop
video/mp2t=mpv.desktop
video/quicktime=mpv.desktop
video/x-msvideo=mpv.desktop
video/x-ms-wmv=mpv.desktop
video/mpeg=mpv.desktop
audio/x-wav=mpv.desktop
audio/mpeg=mpv.desktop
audio/mp4=mpv.desktop
audio/flac=mpv.desktop
text/plain=leafpad.desktop

[Removed Associations]" > /home/pi/.config/mimeapps.list
echo "[Desktop Entry]
Type=Application
Name=MPV
Exec=lxterminal -t mpv_control -e bash -c \"sleep 0.25; xdotool search --name mpv_control windowactivate; mpv %f\"
NoDisplay=true
Icon=mpv" > /home/pi/.local/share/applications/mpv.desktop
sudo cp /etc/apt/preferences /etc/apt/preferences_BACKUP &> /dev/null
echo "Package: ffmpeg
Pin: version 4.0.2-1
Pin-Priority: 1001

Package: mpv
Pin: version 0.29.0-1
Pin-Priority: 1001

Package: x264
Pin: version 0.155-1
Pin-Priority: 1001

Package: fdk-aac
Pin: version 0.1.6-1
Pin-Priority: 1001

Package: mp3lame
Pin: version 3.100-1
Pin-Priority: 1001

Package: libass
Pin: version 0.14.0-1
Pin-Priority: 1001" | sudo cp /dev/stdin /etc/apt/preferences
sudo chmod 644 /etc/apt/preferences
find /home/pi/Vidware_Build -name '*.deb' -exec mv -t /home/pi/Vidware_Packages {} +
sudo pip install --upgrade youtube_dl
cd /home/pi
youtube-dl -f 137+140 --no-mtime -o Neutron_Stars_Colliding_1080p.mp4 https://www.youtube.com/watch?v=x_Akn8fUBeQ
mpv -version
mpv --loop=9 Neutron_Stars_Colliding_1080p.mp4