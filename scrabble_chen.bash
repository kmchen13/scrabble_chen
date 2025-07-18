#!/bin/bash

# Détecte les 2 premiers devices connectés
devices=($(adb devices | awk 'NR>1 && $2=="device" {print $1}'))

if [ ${#devices[@]} -lt 2 ]; then
  echo "❌ Moins de 2 appareils détectés. Branche-les puis réessaie."
  flutter devices
  exit 1
fi

# Option -c pour compiler
if [[ $1 == "-"*"c"* ]]; then
  flutter build apk --debug
  APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

  if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK introuvable à $APK_PATH"
    exit 1
  fi

  echo "📲 Installation sur les appareils..."

  for device in "${devices[@]:0:2}"; do
    echo "➡️ Installation sur $device"
    adb -s "$device" install -r "$APK_PATH"
  done
fi

echo "✅ Lancement des apps et affichage des logs..."

# Positionnements souhaités (X Y) pour chaque fenêtre
positions=("0 0" "0 700") # Modifier ici pour adapter à ta résolution

for i in "${!devices[@]}"; do
  device="${devices[$i]}"
  read X Y <<< "${positions[$i]}"

  # Lancer Konsole avec les logs dans une nouvelle instance
  konsole --hold -e bash -c "
    echo '📲 Lancement de l’app sur $device...';
    adb -s \"$device\" shell am start -n com.example.scrabble_chen/.MainActivity;
    echo '📟 Logs pour $device (appuyez sur Ctrl+C pour quitter)';
    adb -s \"$device\" logcat | grep -E 'flutter|dart';
  " &
  
  pid=$!
  sleep 1  # Attendre l'ouverture de la fenêtre

  # Rechercher la fenêtre Konsole et la déplacer
  win_id=$(xdotool search --pid $pid | tail -1)
  if [ -n "$win_id" ]; then
    xdotool windowmove "$win_id" "$X" "$Y"
  else
    echo "⚠️ Impossible de trouver la fenêtre Konsole pour $device"
  fi
done

