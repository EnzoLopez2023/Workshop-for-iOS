#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <iphone-simulator-udid> <ipad-simulator-udid>" >&2
  exit 64
fi

cd "$(dirname "$0")/.."

capture_set() {
  local udid="$1"
  local slug="$2"
  local expected_width="$3"
  local expected_height="$4"
  local result="AppStore/Captures/${slug}.xcresult"
  local raw="AppStore/Captures/${slug}-raw"
  local mask="AppStore/Captures/${slug}-mask.png"
  local output="AppStore/Screenshots/${slug}"
  local staging="AppStore/Screenshots/.${slug}-staging"
  local derived="${TMPDIR%/}/Workshop-${slug}"

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" content_size large
  xcrun simctl ui "$udid" increase_contrast disabled
  xcrun simctl ui "$udid" appearance dark
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

  rm -rf "$result" "$raw" "$staging"
  mkdir -p AppStore/Captures "$staging"

  xcodebuild test \
    -project Workshop.xcodeproj \
    -scheme Workshop \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${udid}" \
    -derivedDataPath "$derived" \
    -resultBundlePath "$result" \
    -onlyUsePackageVersionsFromResolvedFile \
    -only-testing:WorkshopUITests/WorkshopVisualUITests/testAppStoreScreenshotStory \
    -quiet

  xcrun xcresulttool export attachments \
    --path "$result" \
    --output-path "$raw" >/dev/null
  xcrun simctl io "$udid" screenshot --mask alpha "$mask" >/dev/null

  jq -r '
    .[].attachments[]
    | select(.suggestedHumanReadableName | test("^[0-9]{2}-"))
    | [
        .exportedFileName,
        (.suggestedHumanReadableName | sub("_0_[A-F0-9-]+\\.png$"; ""))
      ]
    | @tsv
  ' "$raw/manifest.json" |
    while IFS=$'\t' read -r source name; do
      Scripts/flatten-simulator-screenshot.swift \
        "$raw/$source" \
        "$staging/$name.jpg" \
        "$mask"
    done

  local count
  count="$(find "$staging" -maxdepth 1 -name '*.jpg' -print | wc -l | tr -d ' ')"
  if [[ "$count" != 5 ]]; then
    echo "error: expected 5 ${slug} screenshots, found ${count}" >&2
    exit 1
  fi

  local -a expected_names=(
    01-dashboard.jpg
    02-project-detail.jpg
    03-shopping-list.jpg
    04-conversion-tables.jpg
    05-insights.jpg
  )
  local expected_name
  for expected_name in "${expected_names[@]}"; do
    if [[ ! -f "$staging/$expected_name" ]]; then
      echo "error: missing expected screenshot $staging/$expected_name" >&2
      exit 1
    fi
  done

  while IFS= read -r file; do
    local width height alpha
    width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')"
    height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/{print $2}')"
    alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/{print $2}')"
    if [[ "$width" != "$expected_width" ||
          "$height" != "$expected_height" ||
          "$alpha" != "no" ]]; then
      echo "error: invalid screenshot $file (${width}x${height}, alpha=${alpha})" >&2
      exit 1
    fi
  done < <(find "$staging" -maxdepth 1 -name '*.jpg' -print | sort)

  rm -rf "$output"
  mv "$staging" "$output"
}

capture_set "$1" "iPhone-6.9" 1320 2868
capture_set "$2" "iPad-13" 2064 2752

echo "Created validated App Store screenshot sets under AppStore/Screenshots/."
