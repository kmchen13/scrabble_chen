#!/bin/bash

# Stopper les apps sur les devices
devices=($(adb devices | grep -w "device" | cut -f1))
for device in "${devices[@]:0:2}"; do
  echo "🛑 Arrêt de l’app sur $device..."
  adb -s "$device" shell am force-stop com.example.scrabble_chen
done

# Fermer les Konsole ouvertes par le script
if [ -f .konsole_pids.txt ]; then
  while read pid; do
    echo "🗑️ Fermeture Konsole PID $pid..."
    kill "$pid" 2>/dev/null || true
  done < .konsole_pids.txt
  rm .konsole_pids.txt
else
  echo "⚠️ Aucun PID enregistré — rien à fermer."
fi

echo "✅ Nettoyage terminé."

