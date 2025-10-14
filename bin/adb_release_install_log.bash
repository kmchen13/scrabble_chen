#!/bin/bash
#
bin/version_update.bash
CONSTANTS_FILE="/data/flutter/scrabble_chen/lib/constants.dart"
PARAM="const String version"
VERSION=$(bin/version_last.bash)
if [ -z "$VERSION" ]; then
    echo "Erreur : Impossible de trouver la VALUE dans le fichier $CONSTANTS_FILE."
    exit 1
fi
echo "cOMPILATION Version $VERSION"

NEW_NAME="scrabble_P2P-v$VERSION.apk"
APK_DIR="build/app/outputs/flutter-apk"
APK_NAME="app-release.apk"
    
if [[( "$1" == "?" )  || ( "$1" == "h" ) ]]
then
    echo "
    installe la release $NEW_NAME sur le 1er device adb trouvé
    et lance le log adb filtré sur "flutter".
    
    La compilation crée un fichier app-release.apk par défaut. Ce script
    fait une copie nommée $NEW_NAME.

	Syntaxe:" $0 " <-tc> <string>
        t: Affiche les commandes executées
        c: compiler avant d'installer
        
        <string> flutter par défaut. Filtrage par la string si précise"

   exit 1
fi

set -e


if [[ $1 == "-"*'t'* ]]
then
    set -x #echo on
fi

if [[ $1 == "-"*"c"* ]]
then
    echo "1. Compilation APK release..."
    flutter build apk --release --target-platform android-arm,android-arm64

    echo "2. Copie et renommage de l'apk..."
    cp "$APK_DIR/$APK_NAME" "$APK_DIR/$NEW_NAME"
fi


echo "3. Installation sur le device..."
adb install -r "$APK_DIR/$NEW_NAME"

echo "4. Lancement de logcat filtré sur 'localNet' (CTRL+C pour arrêter)..."
adb logcat | grep flutter
