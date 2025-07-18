#!/bin/bash

# Compile une fois
echo "🛠 Compilation APK debug..."
flutter build apk --debug || { echo "❌ Compilation échouée"; exit 1; }
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ APK introuvable: $APK_PATH"
  exit 1
fi

# Récupère la liste des devices connectés
devices=($(adb devices | grep -w 'device' | cut -f1))

if [ "${#devices[@]}" -lt 2 ]; then
  echo "❌ Moins de 2 devices connectés, connecte-les puis relance."
  exit 1
fi

echo "📱 Devices détectés: ${devices[0]} ${devices[1]}"

# Installe l'APK sur les 2 devices
for device in "${devices[@]:0:2}"; do
  echo "📥 Installation sur $device"
  adb -s "$device" install -r "$APK_PATH"
done

# Lance l'app sur les 2 devices
for device in "${devices[@]:0:2}"; do
  echo "🚀 Lancement de l'app sur $device"
  adb -s "$device" shell am start -n com.example.scrabble_chen/.MainActivity
done

# Ouvre un terminal Konsole pour flutter attach sur le 1er device (debug actif)
konsole --hold -e bash -c "
  echo '🔌 Attachement debug Flutter sur ${devices[0]}...';
  flutter attach -d ${devices[0]};
  echo '✋ Flutter attach terminé ou interrompu.';
  read -p 'Appuyez sur entrée pour fermer ce terminal...'
" &

# Ouvre 2 terminaux Konsole avec logcat filtré sur flutter|dart, positionnés
positions=("0 0" "0 700")
for i in 0 1; do
  device=${devices[$i]}
  read X Y <<< "${positions[$i]}"
  konsole --hold -e bash -c "
    echo '📟 Logs Flutter/Dart pour $device (Ctrl+C pour quitter)';
    adb -s $device logcat | grep -E 'flutter|dart'
  " &
  pid=$!
  sleep 1
  win_id=$(xdotool search --pid $pid | tail -1)
  if [ -n "$win_id" ]; then
    xdotool windowmove "$win_id" "$X" "$Y"
  fi
done

echo "✅ Tout est prêt. Debug attach en cours sur ${devices[0]}."

