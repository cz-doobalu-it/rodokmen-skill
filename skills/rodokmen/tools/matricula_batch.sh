#!/bin/bash
# matricula_batch.sh URLFILE PREFIX  (URLFILE: řádky "<snímek> <url obrázku>" vytažené z prohlížeče) -> stáhne PREFIX_<pg>.jpg (+ _s.jpg zmenšeninu 1900px)
LOCAL_IM="$(cd "$(dirname "$0")" && pwd)/imagemagick/magick.exe"
M=magick   # ImageMagick 6 nemá magick, jen convert (na Windows je convert.exe jiný program, tam ne)
[ -x "$LOCAL_IM" ] && M="$LOCAL_IM" || command -v magick >/dev/null || { [ "$OS" != Windows_NT ] && command -v convert >/dev/null && M=convert; }
tr -d '"' < "$1" | sed 's/\\n/\n/g' | grep -E '^[0-9]+ https' | while read p u; do
  out="${2}_$p.jpg"; [ -s "$out" ] || bash "$(dirname "$0")/matricula_dl.sh" "$u" "$out"; "$M" "$out" -resize 1900x "${2}_${p}_s.jpg"; done
