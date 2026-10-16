#!/bin/zsh
# Compila o Moonlight e monta o Moonlight.app nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
# `./build.sh icon` redesenha o Resources/AppIcon.icns a partir do Tools/make-icon.swift.
if [[ "${1:-}" == "icon" ]]; then
  swiftc -O Tools/make-icon.swift -o build/make-icon
  build/make-icon build/icon.png
  SET="build/AppIcon.iconset"
  rm -rf "$SET" && mkdir -p "$SET"
  for px in 16 32 128 256 512; do
    sips -z $px $px build/icon.png --out "$SET/icon_${px}x${px}.png" >/dev/null
    sips -z $((px * 2)) $((px * 2)) build/icon.png --out "$SET/icon_${px}x${px}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o Resources/AppIcon.icns
  echo "Ícone: $PWD/Resources/AppIcon.icns"
  exit 0
fi

# Binário universal: roda em Apple Silicon e em Intel.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14.0 Sources/Moonlight/*.swift -o build/Moonlight-$arch
done
lipo -create build/Moonlight-arm64 build/Moonlight-x86_64 -output build/Moonlight
APP="Moonlight.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp build/Moonlight "$APP/Contents/MacOS/Moonlight"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Moonlight</string>
  <key>CFBundleDisplayName</key><string>Moonlight</string>
  <key>CFBundleIdentifier</key><string>br.com.jhosefer.moonlight</string>
  <key>CFBundleExecutable</key><string>Moonlight</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Pronto: $PWD/$APP"

# `./build.sh install` também atualiza a cópia em /Applications e reabre o app.
if [[ "${1:-}" == "install" ]]; then
  # O app se chamava Lightmoon: fecha e remove a versão antiga para as duas não brigarem pela gama.
  pkill -x Moonlight || true
  pkill -x Lightmoon || true
  rm -rf /Applications/Moonlight.app /Applications/Lightmoon.app
  cp -R "$APP" /Applications/Moonlight.app
  open /Applications/Moonlight.app
  echo "Instalado em /Applications/Moonlight.app"
fi

# `./build.sh dmg` gera o Moonlight.dmg com atalho para /Applications.
if [[ "${1:-}" == "dmg" ]]; then
  STAGE="build/dmg"
  rm -rf "$STAGE" Moonlight.dmg
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  cat > "$STAGE/Se não abrir, leia.txt" <<'TXT'
O Moonlight não é notarizado pela Apple, então o macOS pode barrar a primeira abertura,
às vezes dizendo que o app "está danificado". O app não está danificado.

Depois de arrastar o Moonlight para Applications, abra o Terminal e cole:

    xattr -cr /Applications/Moonlight.app

Depois abra o app normalmente.

Alternativa sem este DMG, que já instala e libera de uma vez:

    curl -fsSL https://raw.githubusercontent.com/jhoff66/Moonlight/main/install.sh | bash
TXT
  hdiutil create -volname "Moonlight" -srcfolder "$STAGE" -ov -format UDZO Moonlight.dmg >/dev/null
  rm -rf "$STAGE"
  echo "DMG: $PWD/Moonlight.dmg"
fi
