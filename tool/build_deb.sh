#!/usr/bin/env bash
# Packages the Flutter Linux build as a .deb installable by double-click.
#
#   tool/build_deb.sh                 # uses build/linux/x64/release/bundle
#   tool/build_deb.sh --build         # runs flutter build linux --release first
#
# Output: dist/straight_1.0.0_amd64.deb
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
WORK="$ROOT/build/deb"
DIST="$ROOT/dist"

if [ "${1:-}" = "--build" ]; then
  flutter build linux --release
fi

[ -x "$BUNDLE/straight" ] || { echo "No release bundle at $BUNDLE. Run with --build."; exit 1; }

VERSION=1.0.0
rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

# --- application payload -----------------------------------------------------
mkdir -p "$WORK/opt/straight" "$WORK/usr/share/applications"
cp -a "$BUNDLE/." "$WORK/opt/straight/"

# Native engines + Moonshine model must live next to the executable.
[ -d "$WORK/opt/straight/native/prebuilt" ] || { echo "Bundle is missing native/prebuilt"; exit 1; }
[ -d "$WORK/opt/straight/models/moonshine/small-streaming-en" ] || { echo "Bundle is missing the Moonshine model"; exit 1; }

install -m644 "$ROOT/packaging/linux/straight.desktop" "$WORK/usr/share/applications/straight.desktop"

# --- icons -------------------------------------------------------------------
cp -a "$ROOT/packaging/linux/icons/hicolor" "$WORK/usr/share/icons/"

# --- package metadata ----------------------------------------------------------
mkdir -p "$WORK/DEBIAN"
cp "$ROOT/packaging/linux/DEBIAN/control" "$WORK/DEBIAN/control"
cp "$ROOT/packaging/linux/DEBIAN/postinst" "$WORK/DEBIAN/postinst"
cp "$ROOT/packaging/linux/DEBIAN/prerm" "$WORK/DEBIAN/prerm"
chmod 775 "$WORK/DEBIAN"
chmod 755 "$WORK/DEBIAN/postinst" "$WORK/DEBIAN/prerm"

# dpkg-deb refuses autoinstall without absolute Section etc; keep them tidy.
sed -i "s/^Version: .*/Version: $VERSION/" "$WORK/DEBIAN/control"

dpkg-deb --build --root-owner-group "$WORK" "$DIST/straight_${VERSION}_amd64.deb"
dpkg-deb --info "$DIST/straight_${VERSION}_amd64.deb" | head -12
echo
echo "Built: $DIST/straight_${VERSION}_amd64.deb"
du -h "$DIST/straight_${VERSION}_amd64.deb"
