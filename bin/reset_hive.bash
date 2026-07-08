 
#!/bin/bash
echo "🧹 Nettoyage des fichiers générés..."
rm -f lib/models/game_state.g.dart
rm -f lib/models/*.g.dart
rm -rf .dart_tool
rm -rf build

echo "📦 Régénération des fichiers Hive..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "✅ Terminé !"
