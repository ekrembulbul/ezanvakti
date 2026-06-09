#!/usr/bin/env bash
#
# Surum etiketi (tag) olusturup push eder. Tag push'u GitHub Actions'i tetikler
# (.github/workflows/ios-testflight.yml) ve build otomatik olarak TestFlight'a
# yuklenir. Yani: tag at -> sürüm cikar.
#
# Yerel makinede IPA DERLEMEZ; sadece surumu gunceller, commit'ler, tag atar ve
# push eder. Derleme/yukleme bulutta (GitHub) yapilir.
#
# Kullanim (yalnizca 'main' dalinda calisir):
#   ./scripts/release_tag.sh                  # iOS+Android, build +1
#   ./scripts/release_tag.sh 0.1.9            # iOS+Android, surum adi 0.1.9, build +1
#   ./scripts/release_tag.sh 0.1.9+10         # iOS+Android, surumu tam 0.1.9+10
#   ./scripts/release_tag.sh 0.1.9 --ios      # sadece iOS     (tag: ios-v0.1.9)
#   ./scripts/release_tag.sh 0.1.9 --android  # sadece Android (tag: android-v0.1.9)
#
# Varsayilan tag 'vX.Y.Z' iki platformu da tetikler; platform onekli tag (ios-v* /
# android-v*) yalnizca o platformu tetikler. Surum yine ortak pubspec'ten bump'lanir.
#
# Not: CHANGELOG'u once elle guncellemen onerilir; bu script changelog yazmaz.

set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

# Surum yalnizca 'main' dalindan cikilir
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "HATA: release_tag.sh yalnizca 'main' dalinda calisir (su an: $BRANCH)." >&2
  echo "  -> git checkout main && git merge --ff-only dev   (sonra tekrar dene)" >&2
  exit 1
fi

# Calisma agaci temiz olmali (yarim degisiklikle tag atilmasin)
if [[ -n "$(git status --porcelain)" ]]; then
  echo "HATA: calisma agaci temiz degil. Once commit/stash yap." >&2
  git status --short >&2
  exit 1
fi

# Argumanlari ayristir: opsiyonel surum + opsiyonel platform bayragi (--ios/--android)
ARG=""
PLATFORM="all"
for a in "$@"; do
  case "$a" in
    --ios) PLATFORM="ios" ;;
    --android) PLATFORM="android" ;;
    --*) echo "HATA: bilinmeyen secenek: $a (kullan: --ios / --android)" >&2; exit 1 ;;
    *) ARG="$a" ;;
  esac
done

CUR="$(grep '^version: ' pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')"
NAME="${CUR%+*}"; BUILD="${CUR#*+}"
if [[ -z "$ARG" ]]; then
  NEW="${NAME}+$((BUILD + 1))"
elif [[ "$ARG" == *+* ]]; then
  NEW="$ARG"
else
  NEW="${ARG}+$((BUILD + 1))"
fi
if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "HATA: gecersiz surum '$NEW'. Beklenen bicim: X.Y.Z veya X.Y.Z+N" >&2
  exit 1
fi

VNAME="${NEW%+*}"
case "$PLATFORM" in
  ios) TAG="ios-v${VNAME}"; TARGET="sadece iOS" ;;
  android) TAG="android-v${VNAME}"; TARGET="sadece Android" ;;
  *) TAG="v${VNAME}"; TARGET="iOS + Android" ;;
esac
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "HATA: $TAG zaten var. Surum adini artir." >&2
  exit 1
fi

echo "==> Surum: $CUR -> $NEW (tag $TAG, dal $BRANCH)"
sed -i '' "s/^version: .*/version: ${NEW}/" pubspec.yaml
git add pubspec.yaml
git commit -m "chore: ${VNAME} surumu"
git tag -a "$TAG" -m "Surum ${VNAME}"
git push origin "$BRANCH"
git push origin "$TAG"

echo ""
echo "==> $TAG push edildi. Hedef: ${TARGET}."
echo "    GitHub Actions tetiklendi (Android, Play secret'lari yoksa atlanir)."
echo "    Ilerleme: GitHub repo > Actions sekmesi."
