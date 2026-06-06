#!/usr/bin/env bash
#
# Surum etiketi (tag) olusturup push eder. Tag push'u GitHub Actions'i tetikler
# (.github/workflows/ios-testflight.yml) ve build otomatik olarak TestFlight'a
# yuklenir. Yani: tag at -> sürüm cikar.
#
# Yerel makinede IPA DERLEMEZ; sadece surumu gunceller, commit'ler, tag atar ve
# push eder. Derleme/yukleme bulutta (GitHub) yapilir.
#
# Kullanim (genelde main dalinda calistir):
#   ./scripts/release_tag.sh            # build numarasini +1, ayni surum adi
#   ./scripts/release_tag.sh 0.1.9      # surum adini 0.1.9 yap, build +1
#   ./scripts/release_tag.sh 0.1.9+10   # surumu tam olarak 0.1.9+10 yap
#
# Not: CHANGELOG'u once elle guncellemen onerilir; bu script changelog yazmaz.

set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

# Calisma agaci temiz olmali (yarim degisiklikle tag atilmasin)
if [[ -n "$(git status --porcelain)" ]]; then
  echo "HATA: calisma agaci temiz degil. Once commit/stash yap." >&2
  git status --short >&2
  exit 1
fi

ARG="${1:-}"
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
TAG="v${VNAME}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "HATA: $TAG zaten var. Surum adini artir (orn. ./scripts/release_tag.sh ${VNAME%.*}.$(( ${VNAME##*.} + 1 )))." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "==> Surum: $CUR -> $NEW (tag $TAG, dal $BRANCH)"
sed -i '' "s/^version: .*/version: ${NEW}/" pubspec.yaml
git add pubspec.yaml
git commit -m "chore: ${VNAME} surumu"
git tag -a "$TAG" -m "Surum ${VNAME}"
git push origin "$BRANCH"
git push origin "$TAG"

echo ""
echo "==> $TAG push edildi."
echo "    GitHub Actions TestFlight yuklemesini baslatti."
echo "    Ilerleme: GitHub repo > Actions sekmesi > 'iOS TestFlight'."
