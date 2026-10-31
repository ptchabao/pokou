#!/usr/bin/env bash
# =============================================================================
# Pokou — build iOS de production (App Store / TestFlight)
#
# Produit une archive Xcode signée et l'IPA à téléverser (Transporter ou
# `xcrun altool`). La signature est celle configurée dans Xcode (équipe et
# profil du bundle com.pokou.pokou).
#
# Usage : ./build-ios.sh [--clean] [--skip-checks]
# =============================================================================
set -euo pipefail

POKOU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$POKOU_DIR"

# CocoaPods sur Ruby portable, s'il est installé ainsi (voir README).
[ -x "$HOME/development/bin/pod" ] && export PATH="$HOME/development/bin:$PATH"

VERSION_LINE="$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//')"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"
echo "POKOU iOS — v${VERSION_NAME} (build ${VERSION_CODE})"

DO_CLEAN=0
DO_CHECKS=1
for arg in "$@"; do
  case "$arg" in
    --clean)       DO_CLEAN=1 ;;
    --skip-checks) DO_CHECKS=0 ;;
    *) echo "Usage: $0 [--clean] [--skip-checks]" ; exit 1 ;;
  esac
done

command -v pod >/dev/null 2>&1 || { echo "❌ CocoaPods introuvable (voir README)."; exit 1; }

# Sans ce fichier, l'application démarre sans notifications push (main.dart
# le tolère) : acceptable pour un essai, pas pour une publication.
if [ ! -f ios/Runner/GoogleService-Info.plist ]; then
  echo "❌ ios/Runner/GoogleService-Info.plist absent : pas de notifications push."
  echo "   Ajoutez celui de l'app Firebase iOS com.pokou.pokou."
  exit 1
fi

[ "$DO_CLEAN" -eq 1 ] && flutter clean
flutter pub get

if [ "$DO_CHECKS" -eq 1 ]; then
  flutter analyze --no-fatal-infos --fatal-warnings lib test
  flutter test
fi

BUILD_DIR="$POKOU_DIR/build-production"
SYMBOLS_DIR="$BUILD_DIR/symbols-ios-v${VERSION_NAME}"
mkdir -p "$SYMBOLS_DIR"

flutter build ipa --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR"

cp build/ios/ipa/*.ipa "$BUILD_DIR/pokou-v${VERSION_NAME}+${VERSION_CODE}.ipa"
echo "📦 $BUILD_DIR/pokou-v${VERSION_NAME}+${VERSION_CODE}.ipa"
echo "🪲 Symboles : $SYMBOLS_DIR"
