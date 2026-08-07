#!/usr/bin/env bash

set -euo pipefail

# Check dependencies
for cmd in zenity gsettings matugen; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' is not installed."
    exit 1
  }
done

# Pick a wallpaper
WALLPAPER=$(zenity --file-selection \
  --title="Select Wallpaper" \
  --filename="$HOME/Pictures/wallpaper/")

# User pressed Cancel
[ -z "$WALLPAPER" ] && exit 0

URI="file://$WALLPAPER"

# Set wallpaper (light + dark + lock screen)
gsettings set org.gnome.desktop.background picture-uri "$URI"
gsettings set org.gnome.desktop.background picture-uri-dark "$URI"
gsettings set org.gnome.desktop.screensaver picture-uri "$URI"

# Generate Matugen colors
matugen image "$WALLPAPER"

echo "✓ Wallpaper changed!"
