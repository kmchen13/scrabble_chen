#!/bin/bash

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="com.example.scrabblechen.app" # remplace avec ton vrai nom de package

# Lister les appareils
devices=($(adb devices | grep -w "device" | cut -f1))

if [ ${#devices[@]} -eq 0 ]; then
  echo "❌ Aucun appareil connecté."
  exit 1
elif [ ${#devices[@]} -gt 1 ]; then
  echo "📱 Plusieurs appareils détectés :"
  for i in "${!devices[@]}"; do
    echo "[$i] ${devices[$i]}"
  done
  read -p "Sélectionnez un appareil (index) : " index
  DEVICE_ID=${devices[$index]}
else
  DEVICE_ID=${devices[0]}
fi

echo "📦 Installation sur $DEVICE_ID ..."
adb -s $DEVICE_ID install -r "$APK_PATH"

echo "🚀 Lancement de l'application $PACKAGE_NAME ..."
adb -s $DEVICE_ID shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1

echo "✅ Terminé."

