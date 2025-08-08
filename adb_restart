#!/bin/bash
#
# v1.0.0
#
if [[ "$1" == "?"  || "$1" == "h" ]]
then
    echo "
    Documentation
	Redémarre adb

	Syntaxe: $0  -to <param>
        t: Affiche les commandes executées
        o: Optien
        
        <param> Paramètre
	"
   exit 1
fi

if [[ $1 == "-"*"t"* ]]
then
    set -x #echo on
fi

killall adb
adb start-server
flutter devices

exit 0
