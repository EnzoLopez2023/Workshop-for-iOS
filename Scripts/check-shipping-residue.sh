#!/bin/bash

set -euo pipefail

cd "$SRCROOT"

shipping_paths=(
  Shared
  Workshop
  WorkshopWidgets
  WorkshopShareExtension
  project.yml
)

forbidden_terms='Concourse|MartianMonoBoard|ArchivoWS|UIAppFonts|Theme\.(concourse|flap|flapShade|steel|steelDark|steelLight|onSteel|flapFace|flapFaceLo|flapLetter|steelFace|flapFaceGradient|board|boardFixed)|WSWidget\.(concourse|flap|flapShade|steel|onSteel|flapFace|flapFaceLo|flapLetter|board)|BoardToolbarButton|boardToolbarItem|boardBackground|SplitFlap|WSFlap|FlapToggleStyle'
forbidden_palette='0x(0C0F10|171B1D|2C3335|2B3238|566269|EFF2ED|A8B3B0|FFB400|F5F0EA|1C0F07|8B7A6B|A0522D|EDE8E3)'

if matches=$(/usr/bin/grep -RInE \
  --include='*.swift' \
  --include='*.plist' \
  --include='project.yml' \
  "$forbidden_terms|$forbidden_palette" \
  "${shipping_paths[@]}" 2>/dev/null); then
  echo "error: retired visual-system residue found in shipping source:"
  echo "$matches"
  exit 1
fi

if resources=$(/usr/bin/find Shared Workshop WorkshopWidgets WorkshopShareExtension \
  -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \) \
  -print); [[ -n "$resources" ]]; then
  echo "error: bundled custom fonts found in shipping source:"
  echo "$resources"
  exit 1
fi
