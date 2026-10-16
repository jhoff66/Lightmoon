#!/bin/bash
# Instala a versão mais recente do Moonlight em /Applications.
# Baixar pelo terminal evita o bloqueio que o macOS aplica a apps não notarizados vindos do navegador.
set -euo pipefail

URL="https://github.com/jhoff66/Moonlight/releases/latest/download/Moonlight.dmg"
TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

echo "Baixando o Moonlight..."
curl -fsSL "$URL" -o "$TMP/Moonlight.dmg"
mkdir -p "$MOUNT"
hdiutil attach "$TMP/Moonlight.dmg" -nobrowse -quiet -mountpoint "$MOUNT"

pkill -x Moonlight 2>/dev/null || true
# O app se chamava Lightmoon: remove a versão antiga.
pkill -x Lightmoon 2>/dev/null || true
rm -rf /Applications/Moonlight.app /Applications/Lightmoon.app
cp -R "$MOUNT/Moonlight.app" /Applications/
xattr -cr /Applications/Moonlight.app

open /Applications/Moonlight.app
echo "Pronto: o Moonlight está na barra de menus."
