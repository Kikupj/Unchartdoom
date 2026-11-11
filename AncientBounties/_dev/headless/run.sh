#!/bin/bash
# usage: run.sh <timeout> args...   (headless, line-buffered log on stdout)
R=$HOME/uz/squashfs-root
export LD_LIBRARY_PATH=$R/usr/lib
T=$1; shift
cd $R/usr/share/games/uzdoom
timeout $T xvfb-run -a -s "-screen 0 1024x576x24" stdbuf -oL -eL $R/usr/bin/uzdoom -iwad $HOME/mnt/Unchartdoom/freedoom-0.13.0/freedoom2.wad -nosound "$@" 2>&1 | grep -v -E '^\s*$|[:#+|]{3}|^ {3,}|^ALSA|^XIO|after [0-9]+ requests'
