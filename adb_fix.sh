#!/bin/bash
# fix_adb.sh - corrige "failed to create inotify fd: Too many open files"

echo "�� Augmentation des limites inotify et file descriptors..."

# Appliquer immédiatement
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512
sudo sysctl -w fs.file-max=2097152

# Écrire dans sysctl.conf pour rendre permanent
sudo bash -c 'cat >> /etc/sysctl.conf <<EOF
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
fs.file-max=2097152
EOF'

echo "✅ Limites augmentées."

# Tuer tous les processus adb
echo "🛑 Arrêt des processus adb..."
pkill -9 adb

# Redémarrer adb
echo "🚀 Redémarrage d adb..."
adb start-server

echo "🎉 adb corrigé et relancé."

