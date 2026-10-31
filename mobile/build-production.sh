#!/usr/bin/env bash
# =============================================================================
# Pokou — build du bundle de production (Play Store)
#
# Produit un Android App Bundle signé, plus les APK par ABI pour la
# distribution directe, et les symboles de désobfuscation à déposer dans la
# Play Console.
#
# Usage : ./build-production.sh [--clean] [--apk] [--skip-checks]
# =============================================================================
set -euo pipefail

POKOU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$POKOU_DIR"

# La version vient de pubspec.yaml et de nulle part ailleurs.
#
# Elle était recopiée dans ce script, et les deux avaient divergé : le script
# annonçait « v1.4.0+6 » et nommait ses fichiers ainsi alors que pubspec était
# à 1.6.0+8. Un binaire mal nommé se dépose dans la mauvaise fiche Play Store,
# et personne ne s'en aperçoit avant les retours d'utilisateurs.
VERSION_LINE="$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//')"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"

echo "═══════════════════════════════════════════════════════════════════════"
echo "  POKOU — build de production (v${VERSION_NAME}, code ${VERSION_CODE})"
echo "═══════════════════════════════════════════════════════════════════════"

DO_CLEAN=0
DO_APK=0
DO_CHECKS=1
for arg in "$@"; do
  case "$arg" in
    --clean)       DO_CLEAN=1 ;;
    --apk)         DO_APK=1 ;;
    --skip-checks) DO_CHECKS=0 ;;
    *) echo "Usage: $0 [--clean] [--apk] [--skip-checks]" ; exit 1 ;;
  esac
done

# Le Flutter du PATH, et pas un autre.
#
# Ce script plaçait ~/flutter/bin EN TÊTE du PATH. Cette installation-là est
# restée à Flutter 3.32.6 (Dart 3.8.1) alors que le projet exige Dart ^3.11 :
# `pub get` échouait, et surtout le bundle n'aurait pas été compilé avec la
# chaîne d'outils sur laquelle l'analyse et les tests viennent de passer.
# Construire la production avec un autre SDK que celui qu'on vérifie, c'est
# vérifier autre chose que ce qu'on livre.
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter introuvable. Vérifiez votre PATH."
  exit 1
fi
echo "🛠  Flutter : $(command -v flutter)"
flutter --version 2>&1 | sed -n 1p

# Le SDK doit satisfaire la contrainte de pubspec. `pub get` le dirait aussi,
# mais après le `flutter clean` — donc après avoir jeté le build précédent.
REQUIRED_SDK="$(grep -A2 '^environment:' pubspec.yaml | grep 'sdk:' | sed 's/.*[\^>=]//;s/[^0-9.].*//')"
# `sed -E` et non `grep -oP` : le grep de macOS n'a pas -P, et sous `set -e
# -o pipefail` le script s'arrêtait là, avant toute compilation.
CURRENT_SDK="$(flutter --version 2>&1 | sed -nE 's/.*Dart ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | sed -n 1p)"
if [ -n "$REQUIRED_SDK" ] && [ -n "$CURRENT_SDK" ]; then
  LOWEST="$(printf '%s\n%s\n' "$REQUIRED_SDK" "$CURRENT_SDK" | sort -V | head -1)"
  if [ "$LOWEST" != "$REQUIRED_SDK" ]; then
    echo "❌ Dart $CURRENT_SDK < $REQUIRED_SDK exigé par pubspec.yaml."
    exit 1
  fi
fi

# La signature, vérifiée AVANT de compiler.
#
# Sans key.properties, Gradle retombe sur les clés de debug et produit quand
# même un .aab — refusé par le Play Store, et qui casse la vérification des
# App Links. L'avertissement de Gradle se noie dans la sortie de build ; ici
# il arrête tout, parce qu'un binaire signé en debug n'a aucune raison
# d'exister dans build-production/.
if [ ! -f android/key.properties ]; then
  echo "❌ android/key.properties absent : le bundle serait signé avec les clés"
  echo "   de DEBUG et refusé par le Play Store. Build interrompu."
  exit 1
fi
KEYSTORE="$(grep -m1 '^storeFile=' android/key.properties | cut -d= -f2-)"
if [ ! -f "$KEYSTORE" ]; then
  echo "❌ Keystore introuvable : $KEYSTORE"
  echo "   (chemin lu dans android/key.properties)"
  exit 1
fi
echo "🔑 Signature : $KEYSTORE"

if [ "$DO_CLEAN" -eq 1 ]; then
  echo ""
  echo "[1/4] Nettoyage (flutter clean)..."
  flutter clean
fi

echo ""
echo "[2/4] Dépendances..."
flutter pub get

if [ "$DO_CHECKS" -eq 1 ]; then
  # Analyse et tests BLOQUANTS, sur tout le projet.
  #
  # Ils ne portaient que sur le module marketplace, et leurs échecs étaient
  # avalés par `|| true` : la vérification était décorative. Un build de
  # production qui ne s'arrête pas sur un test rouge ne vérifie rien.
  #
  # Bloquants sur les erreurs et les avertissements, pas sur les `info` :
  # `flutter analyze` traite ces derniers comme fatals par défaut, et la
  # barrière s'arrêtait sur 71 remarques de style préexistantes (accolades,
  # `withOpacity` déprécié) alors qu'il n'y avait ni erreur ni avertissement.
  # Une barrière que le projet ne peut pas franchir finit désactivée, et on
  # revient au point de départ.
  echo ""
  echo "[3/4] Analyse statique (tout le projet)..."
  flutter analyze --no-fatal-infos --fatal-warnings lib test

  echo ""
  echo "[3b/4] Tests..."
  flutter test
else
  echo ""
  echo "[3/4] ⚠️  Analyse et tests SAUTÉS (--skip-checks)."
fi

echo ""
echo "[4/4] Compilation release..."

BUILD_DIR="$POKOU_DIR/build-production"
SYMBOLS_DIR="$BUILD_DIR/symbols-v${VERSION_NAME}"
mkdir -p "$SYMBOLS_DIR"

echo "   → App Bundle"
flutter build appbundle --release \
  --obfuscate --split-debug-info="$SYMBOLS_DIR"
cp build/app/outputs/bundle/release/app-release.aab \
   "$BUILD_DIR/pokou-v${VERSION_NAME}+${VERSION_CODE}-release.aab"

if [ "$DO_APK" -eq 1 ]; then
  echo "   → APK par ABI (distribution directe)"
  flutter build apk --release --split-per-abi \
    --obfuscate --split-debug-info="$SYMBOLS_DIR"
  for abi in arm64-v8a armeabi-v7a x86_64; do
    src="build/app/outputs/flutter-apk/app-$abi-release.apk"
    [ -f "$src" ] && \
      cp "$src" "$BUILD_DIR/pokou-v${VERSION_NAME}+${VERSION_CODE}-$abi-release.apk"
  done
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
ls -lh "$BUILD_DIR"/pokou-v${VERSION_NAME}+${VERSION_CODE}-* 2>/dev/null
echo ""
echo " 📦 Play Store  : pokou-v${VERSION_NAME}+${VERSION_CODE}-release.aab"
echo " 🪲 Symboles    : $SYMBOLS_DIR (à déposer dans la Play Console)"
echo "═══════════════════════════════════════════════════════════════════════"
