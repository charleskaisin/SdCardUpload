#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/CarteClaire"
OUTPUT_DIR="$REPO_ROOT/build-output"
APP_BUNDLE="$OUTPUT_DIR/Carte Claire.app"
ASSET_OUTPUT="$OUTPUT_DIR/AssetOutput"
BUILD_CACHE="${TMPDIR:-/tmp}/carteclaire-build-cache"

case "$OUTPUT_DIR" in
  "$REPO_ROOT/build-output") ;;
  *)
    printf 'Chemin de construction inattendu. Arrêt par sécurité.\n' >&2
    exit 1
    ;;
esac

/bin/rm -rf -- "$OUTPUT_DIR"
/bin/mkdir -p "$ASSET_OUTPUT" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$BUILD_CACHE/clang" "$BUILD_CACHE/swift"

printf 'Compilation universelle de Carte Claire…\n'
(
  cd "$PROJECT_DIR"
  CLANG_MODULE_CACHE_PATH="$BUILD_CACHE/clang" \
  SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_CACHE/swift" \
    /usr/bin/swift build --disable-sandbox -c release --arch arm64 --arch x86_64
)

printf 'Création de l’icône macOS…\n'
/usr/bin/xcrun actool "$PROJECT_DIR/Resources/Assets.xcassets" \
  --compile "$ASSET_OUTPUT" \
  --platform macosx \
  --minimum-deployment-target 11.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$OUTPUT_DIR/AssetInfo.plist" \
  --warnings --notices

/bin/cp "$PROJECT_DIR/.build/apple/Products/Release/CarteClaire" "$APP_BUNDLE/Contents/MacOS/CarteClaire"
/bin/cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/bin/cp "$ASSET_OUTPUT/AppIcon.icns" "$ASSET_OUTPUT/Assets.car" "$APP_BUNDLE/Contents/Resources/"

/usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$OUTPUT_DIR/Carte-Claire.zip"

printf '\nTerminé :\n%s\n%s\n' "$APP_BUNDLE" "$OUTPUT_DIR/Carte-Claire.zip"
