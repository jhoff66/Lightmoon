#!/bin/bash
# Instala a versão mais recente do Lightmoon em /Applications.
# Baixar pelo terminal evita o bloqueio que o macOS aplica a apps não notarizados vindos do navegador.
set -euo pipefail

URL="https://github.com/jhoff66/Lightmoon/releases/latest/download/Lightmoon.dmg"
TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

echo "Baixando o Lightmoon..."
curl -fsSL "$URL" -o "$TMP/Lightmoon.dmg"
mkdir -p "$MOUNT"
hdiutil attach "$TMP/Lightmoon.dmg" -nobrowse -quiet -mountpoint "$MOUNT"

pkill -x Lightmoon 2>/dev/null || true
rm -rf /Applications/Lightmoon.app
cp -R "$MOUNT/Lightmoon.app" /Applications/
xattr -cr /Applications/Lightmoon.app

open /Applications/Lightmoon.app
echo "Pronto: o Lightmoon está na barra de menus."
