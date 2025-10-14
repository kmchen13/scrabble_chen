#!/bin/bash
bin/version_update.bash
set -e

# Nom du package (adapter si besoin)
PACKAGE="com.scrabble_P2P"

# Nom de l'activité principale
ACTIVITY="$PACKAGE/.MainActivity"

# Dossier du projet
cd "$(dirname "$0")"

# Trouver les 2 premiers devices
devices=($(adb devices | grep -w "device" | cut -f1))

if [ ${#devices[@]} -lt 2 ]; then
  echo "❌ Moins de 2 appareils détectés. Branche-les puis réessaie."
  flutter devices
  exit 1
fi

# Nettoyer éventuels PID précédents
rm -f .konsole_pids.txt

# Option -c → compilation unique
if [[ "$1" == *"-c"* ]]; then
  echo "🔨 Compilation APK en mode debug..."
  flutter build apk --debug
fi

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ APK introuvable à $APK_PATH"
  exit 1
fi

# Installation APK sur les 2 devices
for device in "${devices[@]:0:2}"; do
  echo "📲 Installation sur $device..."
  adb -s "$device" install -r "$APK_PATH"
done

# Positions des fenêtres (modifier selon écran)
positions=("0 0" "0 700")

# Lancement Konsole avec logs
for i in "${!devices[@]}"; do
  device="${devices[$i]}"
  read X Y <<< "${positions[$i]}"

  konsole --hold -e bash -c "
    echo '🚀 Lancement sur $device...';
    adb -s \"$device\" shell am start -n $ACTIVITY;
    echo '📟 Logs pour $device (Ctrl+C pour quitter)';
    adb -s \"$device\" logcat | grep -E 'flutter|dart';
  " &
  
  pid=$!
  echo $pid >> .konsole_pids.txt
  sleep 1

  win_id=$(xdotool search --pid $pid | tail -1)
  if [ -n "$win_id" ]; then
    xdotool windowmove "$win_id" "$X" "$Y"
  fi
done

# Debug sur le 1er device (facultatif)
debug_device="${devices[0]}"
konsole --hold -e bash -c "
  echo '🧩 Debug sur $debug_device...';
  flutter attach -d $debug_device
" &
echo $! >> .konsole_pids.txt

echo "✅ Lancement terminé. Pour nettoyer, exécute : ./cleanup_scrabble_chen.bash"

