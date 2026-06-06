#!/usr/bin/env bash
#
# iOS TestFlight yukleme otomasyonu (Seviye 1 — yerel tek komut).
#
# Yaptiklari:
#   1. pubspec.yaml'deki surumu gunceller (asagidaki kurallara gore)
#   2. App Store imzali IPA derler (flutter build ipa --export-method app-store)
#   3. IPA'yi App Store Connect API anahtariyla TestFlight'a yukler (xcrun altool)
#
# Gerekli yapilandirma (ikisinden biri):
#   - ios/.release.env dosyasi (ios/.release.env.example'dan kopyala), VEYA
#   - APP_STORE_ISSUER_ID / APP_STORE_KEY_ID ortam degiskenleri
#
# Onkosul: API anahtari (.p8) ~/.appstoreconnect/private_keys/ icinde olmali.
#
# Kullanim:
#   ./scripts/release_ios.sh            # surum adini koru, build numarasini +1 artir
#   ./scripts/release_ios.sh 1.0.0      # surum adini 1.0.0 yap, build numarasini +1 artir
#   ./scripts/release_ios.sh 1.0.0+1    # surumu tam olarak 1.0.0+1 yap
#
# Not: App Store build numarasi (X.Y.Z+N icindeki N) ayni surum adi icinde her
# yuklemede artmalidir; bu yuzden ad degisse bile build numarasi tasiyip +1 artar.

set -euo pipefail

# Repo kokune gec (script nereden cagrilirsa cagrilsin).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Yapilandirmayi yukle: once gitignore'lu env dosyasi, sonra ortam degiskenleri.
ENV_FILE="ios/.release.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

ISSUER_ID="${APP_STORE_ISSUER_ID:-}"
KEY_ID="${APP_STORE_KEY_ID:-}"

if [[ -z "${ISSUER_ID}" || -z "${KEY_ID}" ]]; then
  echo "HATA: APP_STORE_ISSUER_ID ve APP_STORE_KEY_ID tanimli olmali." >&2
  echo "  -> ios/.release.env.example'i ios/.release.env olarak kopyalayip doldur," >&2
  echo "     ya da: export APP_STORE_ISSUER_ID=<uuid> APP_STORE_KEY_ID=<key-id>" >&2
  exit 1
fi

# --- 1) Surumu belirle ---
# Opsiyonel ilk arguman:
#   (yok)     -> surum adini koru, build numarasini +1
#   X.Y.Z     -> surum adini degistir, build numarasini +1 (tasiyarak, hep artar)
#   X.Y.Z+N   -> surumu aynen kullan
CURRENT_VERSION="$(grep '^version: ' pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')"
CURRENT_NAME="${CURRENT_VERSION%+*}"
CURRENT_BUILD="${CURRENT_VERSION#*+}"

ARG_VERSION="${1:-}"
if [[ -z "${ARG_VERSION}" ]]; then
  NEW_VERSION="${CURRENT_NAME}+$((CURRENT_BUILD + 1))"
elif [[ "${ARG_VERSION}" == *+* ]]; then
  NEW_VERSION="${ARG_VERSION}"
else
  NEW_VERSION="${ARG_VERSION}+$((CURRENT_BUILD + 1))"
fi

if [[ ! "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "HATA: gecersiz surum '${NEW_VERSION}'. Beklenen bicim: X.Y.Z veya X.Y.Z+N" >&2
  exit 1
fi

echo "==> Surum: ${CURRENT_VERSION} -> ${NEW_VERSION}"
sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml

# --- 2) IPA derle ---
echo "==> IPA derleniyor (App Store)..."
flutter build ipa --export-method app-store

# IPA'yi bul (dosya adinda bosluk olabilir).
shopt -s nullglob
IPA_FILES=(build/ios/ipa/*.ipa)
shopt -u nullglob
if [[ ${#IPA_FILES[@]} -eq 0 ]]; then
  echo "HATA: build/ios/ipa altinda IPA bulunamadi." >&2
  exit 1
fi
IPA_PATH="${IPA_FILES[0]}"
echo "==> IPA: ${IPA_PATH}"

# --- 3) Yukle ---
echo "==> TestFlight'a yukleniyor (Key ID: ${KEY_ID})..."
xcrun altool --upload-app --type ios \
  -f "${IPA_PATH}" \
  --apiKey "${KEY_ID}" \
  --apiIssuer "${ISSUER_ID}"

echo ""
echo "==> Tamam. Build ${NEW_VERSION} App Store Connect'e gonderildi."
echo "    Islenmesi ~5-30 dk surer; sonra App Store Connect > TestFlight'ta gorunur."
echo "    Unutma: pubspec.yaml'deki yeni build numarasini commit'le."
