#/bin/sh
adb -s $1 logcat -v time > $1.log
