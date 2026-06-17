#!/usr/bin/env bash
# Build MindGrid release artifacts: Linux (.tar.gz, .deb, .rpm) and Android (.apk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)}"
DIST="$ROOT/dist"
STAGING="$DIST/staging-linux"

echo "==> MindGrid release build v${VERSION}"

flutter pub get
flutter build linux --release
flutter build apk --release

mkdir -p "$DIST"
rm -rf "$STAGING"

echo "==> Packaging Linux tarball"
TAR_OUT="$DIST/MindGrid-${VERSION}-linux-amd64.tar.gz"
tar -czf "$TAR_OUT" -C build/linux/x64/release bundle

echo "==> Packaging Linux .deb and .rpm"
mkdir -p "$STAGING/opt/mindgrid"
cp -a build/linux/x64/release/bundle/. "$STAGING/opt/mindgrid/"

mkdir -p "$STAGING/usr/share/applications"
cp packaging/linux/com.mindgrid.mindgrid.desktop "$STAGING/usr/share/applications/"

mkdir -p "$STAGING/usr/share/icons/hicolor/256x256/apps"
cp assets/images/app_icon.png \
  "$STAGING/usr/share/icons/hicolor/256x256/apps/com.mindgrid.mindgrid.png"

INSTALLED_KB="$(du -sk "$STAGING/opt" "$STAGING/usr" | awk '{s+=$1} END {print s}')"

mkdir -p "$STAGING/DEBIAN"
cat > "$STAGING/DEBIAN/control" <<EOF
Package: mindgrid
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: MindGrid Team <mindgrid@localhost>
Depends: libgtk-3-0, libglib2.0-0, libgdk-pixbuf-2.0-0, libpango-1.0-0, libharfbuzz0b, libcairo2, libatk1.0-0, libx11-6, libstdc++6
Installed-Size: ${INSTALLED_KB}
Homepage: https://github.com/Noctis-Architect/mindgrid
Description: MindGrid — Local and cloud AI assistant
 MindGrid is a cross-platform app for chatting with Ollama and
 OpenAI-compatible APIs. Supports vision, audio, image generation,
 and prompt engineering with fully local storage.
EOF

DEB_OUT="$DIST/MindGrid-${VERSION}-linux-amd64.deb"
fakeroot dpkg-deb -Zgzip --build "$STAGING" "$DEB_OUT"

if command -v fpm >/dev/null 2>&1; then
  echo "==> Packaging Linux .rpm (Fedora/RHEL)"
  RPM_OUT="$DIST/MindGrid-${VERSION}-linux-amd64.rpm"
  fpm -s dir -t rpm \
    -n mindgrid \
    -v "$VERSION" \
    --iteration 1 \
    --url "https://github.com/Noctis-Architect/mindgrid" \
    --license MIT \
    --description "MindGrid — Local and cloud AI assistant for Ollama and OpenAI APIs" \
    --depends gtk3 \
    --depends glib2 \
    --depends gdk-pixbuf2 \
    --depends pango \
    --depends harfbuzz \
    --depends cairo \
    --depends atk \
    --depends libX11 \
    --depends libstdc++ \
    --rpm-os linux \
    -p "$RPM_OUT" \
    -C "$STAGING" \
    opt usr
else
  echo "==> Skipping .rpm (fpm not installed)"
fi

rm -rf "$STAGING"

APK_OUT="$DIST/MindGrid-${VERSION}-android.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$APK_OUT"

echo ""
echo "Release artifacts:"
ls -lh "$DIST"/MindGrid-"${VERSION}"-*
