#!/bin/bash

# Regenerate the PNG icons from Octicons (https://github.com/primer/octicons,
# MIT). macOS only: rasterizes with rsvg-convert (brew install librsvg), falling
# back to qlmanage. Run via `make icons`. The PNGs are committed, so neither the
# build nor CI needs a rasterizer.

base="https://raw.githubusercontent.com/primer/octicons/main/icons"
tmp="$(mktemp -d)"
mkdir -p icons

GREEN="#3fb950"
BLUE="#58a6ff"
RED="#f85149"
GRAY="#8b949e"

# Rasterize one octicon into a colored PNG.
# $1 output path  $2 octicon name  $3 pixel size  $4 fill color
render() {
  local out="$1" octicon="$2" size="$3" color="$4"
  if ! curl -sfL "$base/$octicon.svg" -o "$tmp/in.svg"; then
    echo "  MISSING $octicon"
    return 0
  fi
  sed -E 's/<svg /<svg fill="'"$color"'" /' "$tmp/in.svg" > "$tmp/c.svg"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$size" -h "$size" "$tmp/c.svg" -o "$out"
  else
    qlmanage -t -s "$size" -o "$tmp" "$tmp/c.svg" >/dev/null 2>&1
    cp "$tmp/c.svg.png" "$out"
  fi
  echo "  $out"
  return 0
}

# name:octicon:color
icons="link:link-24:$GRAY tag:tag-24:$GRAY folder:file-directory-24:$GRAY \
add:plus-circle-24:$GREEN trash:trash-24:$RED gear:gear-24:$GRAY \
search:search-24:$GRAY update:sync-24:$BLUE"

echo "generating item icons..."
for entry in $icons; do
  name="${entry%%:*}"
  rest="${entry#*:}"
  render "icons/$name.png" "${rest%%:*}" 256 "${rest#*:}"
done

echo "generating workflow icon..."
render icon.png link-24 512 "$GRAY"

rm -rf "$tmp"
echo "done"
