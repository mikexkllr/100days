#!/usr/bin/env bash
# Store screenshots from the demo, as docs/stores.md describes them:
#
#   tool/store_screenshots.sh <simulator-udid> [en] [de]
#
# The simulator should be an iPhone 17 Pro Max (1320×2868). The status bar
# is set to 9:41; integration_test/store_screenshots_test.dart opens each
# screen and prints SHOT:<name>, and this script takes the simulator's
# screenshot right then. Writes the App Store images, the Play images (the
# same, padded to 9:16 and scaled to 1080×1920, en-GB a copy of en-US) and
# the subscription review screenshot to build/store_screenshots/.
set -euo pipefail
cd "$(dirname "$0")/.."

udid=${1:?usage: tool/store_screenshots.sh <simulator-udid> [en] [de]}
shift
locales=("$@")
[ ${#locales[@]} -eq 0 ] && locales=(en de)

xcrun simctl status_bar "$udid" override --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charging --batteryLevel 100

extra=build/store_screenshots
mkdir -p "$extra"

for locale in "${locales[@]}"; do
  case $locale in
    en) ios=en-US; play=(en-US en-GB) ;;
    de) ios=de-DE; play=(de-DE) ;;
    *) echo "unknown locale $locale" >&2; exit 2 ;;
  esac
  raw=$(mktemp -d)
  log=$raw/run.log
  flutter test integration_test/store_screenshots_test.dart -d "$udid" \
    --dart-define=DEMO_LOCALE="$locale" >"$log" 2>&1 &
  pid=$!

  taken=0
  shoot() {
    local names
    names=$(grep -o 'SHOT:[a-z0-9_]*' "$log" | cut -d: -f2 || true)
    local count
    count=$(printf '%s\n' "$names" | grep -c . || true)
    while [ "$taken" -lt "$count" ]; do
      taken=$((taken + 1))
      local name
      name=$(printf '%s\n' "$names" | sed -n "${taken}p")
      sleep 2 # let the screen settle after the tap
      xcrun simctl io "$udid" screenshot --type=png "$raw/$name.png" >/dev/null
      echo "$locale: $name"
    done
  }
  while kill -0 "$pid" 2>/dev/null; do
    shoot
    sleep 0.5
  done
  shoot
  if ! wait "$pid"; then
    cat "$log" >&2
    exit 1
  fi

  for png in "$raw"/*.png; do
    name=$(basename "$png" .png)
    if [[ $name == iap_* ]]; then
      cp "$png" "$extra/${name}_$locale.png"
      continue
    fi
    sips -s format jpeg -s formatOptions 85 "$png" \
      --out "ios/fastlane/screenshots/$ios/iphone69_$name.jpg" >/dev/null
    padded=$raw/$name.padded.jpg
    sips -s format jpeg -s formatOptions 90 --padToHeightWidth 2868 1613 \
      --padColor 05060B "$png" --out "$padded" >/dev/null
    for p in "${play[@]}"; do
      sips -z 1920 1080 "$padded" \
        --out "android/fastlane/metadata/android/$p/images/phoneScreenshots/$name.jpg" >/dev/null
    done
  done
  rm -rf "$raw"
done
echo "Done. Subscription review screenshots: $extra/"
