#!/usr/bin/env bash
# ERGUVAN uygulama ikonunu (spec D7) uretir.
#
# Geometri, design/Ezan Vakti - Son Tasarim.html icindeki __bundler_thumbnail
# SVG'sinin birebir aynisidir.
#
# Build'in parcasi degil: varliklar degisecekse elle calistirilir, ciktilar
# commit'lenir. Rasterizer olarak headless Chrome kullanilir; makinede
# rsvg-convert / ImageMagick / Inkscape yok ve yeni bir sistem bagimliligi
# eklemek istemiyoruz.
#
# Kullanim:  bash tool/generate_icons.sh
# Sonrasi:   dart run flutter_launcher_icons && dart run flutter_native_splash:create

set -euo pipefail

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
SIZE=1024
OUT="assets/icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -x "$CHROME" ]; then
  echo "Chrome bulunamadi: $CHROME" >&2
  echo "CHROME=/path/to/chrome bash tool/generate_icons.sh ile yol verilebilir." >&2
  exit 1
fi

# Hilal: buyuk daireden kaydirilmis bir daire cikarilir. Yildiz sagda kucuk daire.
GLYPH='<defs><mask id="m">
  <circle cx="233" cy="256" r="141" fill="#fff"/>
  <circle cx="292" cy="218" r="125" fill="#000"/>
</mask></defs>
<circle cx="233" cy="256" r="141" fill="#E09FB8" mask="url(#m)"/>
<circle cx="361" cy="179" r="18" fill="#E09FB8"/>'

# Erguvan gradyani: sol ustte acik, sag altta koyu.
GRADIENT='<defs><radialGradient id="t" cx="30%" cy="0%" r="115%">
  <stop offset="0" stop-color="#5A2A50"/><stop offset="1" stop-color="#150F1F"/>
</radialGradient></defs>
<rect width="512" height="512" fill="url(#t)"/>'

svg_open() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 512 512">' \
    "$SIZE" "$SIZE"
}

# $1 = svg dosyasi, $2 = png dosyasi, $3 = "transparent" ise alfa korunur
render() {
  local args=(--headless --disable-gpu --hide-scrollbars
              --force-device-scale-factor=1
              --window-size="$SIZE,$SIZE" --screenshot="$2" "$1")
  if [ "${3:-}" = "transparent" ]; then
    args=(--default-background-color=00000000 "${args[@]}")
  fi
  "$CHROME" "${args[@]}" >/dev/null 2>&1
}

mkdir -p "$OUT"

# 1) Tam kaplama ikon: iOS, web, macOS, Windows ve Android legacy.
#    Kose yuvarlatmasi yok - her platform kendi maskesini uygular.
{ svg_open; printf '%s%s' "$GRADIENT" "$GLYPH"; printf '</svg>'; } > "$TMP/icon.svg"
render "$TMP/icon.svg" "$OUT/app_icon.png"

# 2) Android adaptive zemin: yalnizca gradyan.
{ svg_open; printf '%s' "$GRADIENT"; printf '</svg>'; } > "$TMP/background.svg"
render "$TMP/background.svg" "$OUT/app_icon_background.png"

# 3) Android adaptive on plan + splash: saydam zeminde hilal.
#    0.62 olcek, hilali adaptive maskesinin guvenli dairesine sokar.
{ svg_open
  printf '<g transform="translate(256 256) scale(0.62) translate(-256 -256)">%s</g>' "$GLYPH"
  printf '</svg>'; } > "$TMP/foreground.svg"
render "$TMP/foreground.svg" "$OUT/app_icon_foreground.png" transparent

echo "Uretildi:"
ls -la "$OUT"
