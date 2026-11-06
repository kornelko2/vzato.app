#!/bin/sh
# Renders the app icons from the SVG sources in Design/icon into the asset catalog.
# Requires Inkscape (brew install --cask inkscape). Run from the repository root.
set -e
CATALOG="Vzato/Resources/Assets.xcassets"
render() {  # render <svg> <appiconset dir> <preview imageset dir>
  svg="$1"; set_dir="$2"; preview_dir="$3"
  mkdir -p "$set_dir" "$preview_dir"
  inkscape "$svg" --export-type=png --export-background="#3F8A5C" --export-background-opacity=1 \
    --export-filename="$set_dir/icon-1024.png" -w 1024 -h 1024 2>/dev/null
  # App Store icons must not have an alpha channel; PNG → JPEG → PNG drops it.
  tmp="$(mktemp -d)"
  sips -s format jpeg -s formatOptions best "$set_dir/icon-1024.png" --out "$tmp/icon.jpg" >/dev/null
  sips -s format png "$tmp/icon.jpg" --out "$set_dir/icon-1024.png" >/dev/null
  for s in 16 32 64 128 256 512; do
    inkscape "$svg" --export-type=png --export-background="#3F8A5C" --export-background-opacity=1 \
      --export-filename="$set_dir/mac-$s.png" -w "$s" -h "$s" 2>/dev/null
  done
  inkscape "$svg" --export-type=png --export-filename="$preview_dir/preview.png" -w 180 -h 180 2>/dev/null
  rm -rf "$tmp"
}
render Design/icon/E-pulena-tableta-fajfka.svg "$CATALOG/AppIcon.appiconset" "$CATALOG/IconPreviewPill.imageset"
render Design/icon/F-davkovac-fajfka.svg "$CATALOG/AppIcon-Organizer.appiconset" "$CATALOG/IconPreviewOrganizer.imageset"
echo "icons rendered"
