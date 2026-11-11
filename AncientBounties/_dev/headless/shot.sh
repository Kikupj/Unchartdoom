#!/bin/bash
# usage: shot.sh <seconds> <out.png> args...   -- runs game, grabs X root after N seconds, then kills
R=$HOME/uz/squashfs-root
export LD_LIBRARY_PATH=$R/usr/lib
SECS=$1; OUT=$2; shift; shift
D=:$((90 + RANDOM % 50))
Xvfb $D -screen 0 1024x576x24 >/dev/null 2>&1 &
XP=$!
sleep 1
cd $R/usr/share/games/uzdoom
DISPLAY=$D $R/usr/bin/uzdoom -iwad $HOME/mnt/Unchartdoom/freedoom-0.13.0/freedoom2.wad -nosound -width 1024 -height 576 +vid_fullscreen 0 +wipetype 0 "$@" > $HOME/uz/log.txt 2>&1 &
GP=$!
sleep $SECS
DISPLAY=$D import -window root $OUT
kill $GP 2>/dev/null; sleep 0.5; kill -9 $GP 2>/dev/null; kill $XP 2>/dev/null
