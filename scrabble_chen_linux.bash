#!/bin/bash
#
# v1.0.0
#
./version_update.bash

if [[ $# -eq 0 || "$1" == "?" || "$1" == "h" ]]; then
    echo "
    Lance dans un émulateur linux avec un nom de joueur

	Syntaxe:" $0 " -to <nom_joueur>
        t: Affiche les commandes executées
        o: Optien
        
        <nom_joueur> Nom d'un joueur. Si lancé pour la première fois, faudra déterminer les paramètres 
        "

   exit 1
fi

if [[ $1 == "-"*'t'* ]]; then
    set -x #echo on
fi

if [[ $1 == "-"* ]]
then
    NOM="$2"
else
    NOM="$1"
fi

flutter run -d linux --dart-define=USER_NAME="$NOM"

echo 'Terminé'
exit 0


