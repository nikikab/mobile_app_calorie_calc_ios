#!/bin/bash
# Takes screenshots of the main screens in the iOS simulator, with demo data, in English and Bulgarian.
# Usage: screenshots.sh <simulator udid> <path to KaloCalc.app> <output dir>
set -euo pipefail
DEVICE=$1
APP=$2
OUT=$3
BUNDLE=com.nikikabadzhov.kalocalc
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl ui "$DEVICE" appearance light
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$DEVICE" "$APP"

# name, language, launch arguments
shot() {
  local name=$1 lang=$2; shift 2
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" -demo -AppleLanguages "($lang)" -AppleLocale "$lang" "$@" >/dev/null
  sleep 7
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name-$lang.png"
}

# The first launch after install is slow; warm it up so no screenshot catches a blank screen.
xcrun simctl launch "$DEVICE" "$BUNDLE" -demo >/dev/null
sleep 10

for lang in en bg; do
  shot diary "$lang" -tab diary
  shot search "$lang" -tab diary -sheet search
  shot photo "$lang" -tab diary -sheet photo
  shot edit-estimate "$lang" -tab diary -sheet edit
  shot manual "$lang" -tab diary -sheet manual
  shot diary-target "$lang" -tab diary -sheet target
  shot progress "$lang" -tab progress
  shot goal "$lang" -tab goal
  shot goal-plan "$lang" -tab goal -sheet plan
  shot settings "$lang" -tab settings -sheet report
  shot settings-model "$lang" -tab settings -sheet model
done
ls -l "$OUT"
