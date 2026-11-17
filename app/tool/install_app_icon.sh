#!/bin/sh
# Copies the icon rendered by tool/app_icon_test.dart into the iOS and
# Android projects, at every size they ask for. macOS (uses sips).
set -eu
cd "$(dirname "$0")/.."
src=build/app_icon
[ -f "$src/icon.png" ] || { echo "Run: flutter test tool/app_icon_test.dart" >&2; exit 1; }

# iOS: every file the asset catalogue lists, at size × scale pixels.
set_dir=ios/Runner/Assets.xcassets/AppIcon.appiconset
python3 - "$set_dir/Contents.json" <<'PY' | while read -r file px; do
import json, sys
for i in json.load(open(sys.argv[1]))["images"]:
    size = float(i["size"].split("x")[0])
    scale = int(i["scale"].rstrip("x"))
    print(i["filename"], int(round(size * scale)))
PY
  sips -s format png -Z "$px" "$src/icon.png" --out "$set_dir/$file" >/dev/null
done

# Android: legacy icons for old launchers, adaptive layers for API 26+.
res=android/app/src/main/res
for pair in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  d=${pair%%:*}; rest=${pair#*:}; legacy=${rest%%:*}; layer=${rest#*:}
  sips -s format png -Z "$legacy" "$src/icon.png" --out "$res/mipmap-$d/ic_launcher.png" >/dev/null
  sips -s format png -Z "$layer" "$src/foreground.png" --out "$res/mipmap-$d/ic_launcher_foreground.png" >/dev/null
  sips -s format png -Z "$layer" "$src/background.png" --out "$res/mipmap-$d/ic_launcher_background.png" >/dev/null
done
mkdir -p "$res/mipmap-anydpi-v26"
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
XML
echo "Installed. Store listing icon: $src/play.png (512²)."
