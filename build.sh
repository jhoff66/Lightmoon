#!/bin/zsh
# Compila o Lightmoon e monta o Lightmoon.app nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
# Binário universal: roda em Apple Silicon e em Intel.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos14.0 Sources/Lightmoon/*.swift -o build/Lightmoon-$arch
done
lipo -create build/Lightmoon-arm64 build/Lightmoon-x86_64 -output build/Lightmoon
APP="Lightmoon.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp build/Lightmoon "$APP/Contents/MacOS/Lightmoon"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Lightmoon</string>
  <key>CFBundleDisplayName</key><string>Lightmoon</string>
  <key>CFBundleIdentifier</key><string>br.com.jhosefer.lightmoon</string>
  <key>CFBundleExecutable</key><string>Lightmoon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
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
  pkill -x Lightmoon || true
  rm -rf /Applications/Lightmoon.app
  cp -R "$APP" /Applications/Lightmoon.app
  open /Applications/Lightmoon.app
  echo "Instalado em /Applications/Lightmoon.app"
fi

# `./build.sh dmg` gera o Lightmoon.dmg com atalho para /Applications.
if [[ "${1:-}" == "dmg" ]]; then
  STAGE="build/dmg"
  rm -rf "$STAGE" Lightmoon.dmg
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "Lightmoon" -srcfolder "$STAGE" -ov -format UDZO Lightmoon.dmg >/dev/null
  rm -rf "$STAGE"
  echo "DMG: $PWD/Lightmoon.dmg"
fi
