#!/bin/bash
# rebuild (no import) and check script load; prints errors/warnings
cd $HOME/work/ab && python3 tools/build.py --modding $HOME/work/modding --no-import --no-zip "$@" > /tmp/build.log 2>&1 || { tail -20 /tmp/build.log; exit 1; }
$HOME/uz/run.sh ${CHK_T:-40} -file $HOME/work/ab/build -norun > $HOME/uz/log.txt
grep -n -iE 'error|warning|could not|unknown|fail|not found|unexpected|line [0-9]+' $HOME/uz/log.txt | grep -v 'Tried to define' | head -${CHK_N:-40}
tail -2 $HOME/uz/log.txt | cut -c1-200
