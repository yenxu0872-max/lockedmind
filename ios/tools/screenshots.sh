#!/bin/zsh
# Makes the App Store screenshots from the real app in the iPhone Simulator:
# builds Lockedmind with the PREVIEW flag, runs tools/shots.txt in a 6.9-inch
# iPhone with a clean status bar, takes each screenshot with simctl, then
# frames them (tools/frame.swift) into AppStore/screenshots/.
#
#   tools/screenshots.sh            needs Xcode with the iOS platform installed
#
# The Simulator uses this Mac's Apple Intelligence for the model, so the
# answers in the pictures are real ones.
set -e
here=${0:A:h}
ios=${here:h}
raw=$ios/build/shots/raw
out=$ios/AppStore/screenshots
dd=$ios/build/dd
bundle=io.github.yenxu0872-max.lockedmind

# The biggest current iPhone ("Pro Max") gives the 6.9-inch pictures Apple asks for.
device=$(xcrun simctl list devices available | grep -E "iPhone [0-9]+ Pro Max" | tail -1 | sed -E 's/^ *(.*) \(([0-9A-F-]+)\).*/\2/')
[[ -n $device ]] || { echo "No 'Pro Max' iPhone simulator found. Add one in Xcode › Window › Devices and Simulators."; exit 1; }
echo "simulator $device"

xcodebuild -project "$ios/Lockedmind.xcodeproj" -scheme Lockedmind -configuration Debug \
  -destination "id=$device" -derivedDataPath "$dd" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG PREVIEW' CODE_SIGNING_ALLOWED=NO -quiet build
app=$dd/Build/Products/Debug-iphonesimulator/Lockedmind.app

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl status_bar "$device" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$device" appearance light
xcrun simctl uninstall "$device" $bundle 2>/dev/null || true
xcrun simctl install "$device" "$app"

rm -rf "$raw"; mkdir -p "$raw/data" "$raw/samples"
# The photo and the PDF the screenshots attach: made here, so they're ours to show.
python3 "$here/samples.py" "$raw/samples"
sed -e "s|PHOTO|$raw/samples/note.jpg|" -e "s|PDF|$raw/samples/lease.pdf|" "$here/shots.txt" > "$raw/script.txt"
SIMCTL_CHILD_LM_SCRIPT=$raw/script.txt SIMCTL_CHILD_LM_OUT=$raw SIMCTL_CHILD_LM_DATA=$raw/data \
SIMCTL_CHILD_LM_SHOTS=external xcrun simctl launch "$device" $bundle >/dev/null

# Take each screenshot when the app asks for it.
for i in {1..1200}; do
  for flag in "$raw"/*.ready(N); do
    sleep 0.6
    xcrun simctl io "$device" screenshot --type=png "${flag:r}.png" >/dev/null 2>&1
    echo "  ${flag:t:r}"
    rm "$flag"
  done
  [[ -e $raw/finished ]] && break
  sleep 0.25
done
[[ -e $raw/finished ]] || { echo "the script didn't finish"; exit 1; }

xcrun simctl status_bar "$device" clear
mkdir -p "$out"
rm -f "$out"/*.png
swift "$here/frame.swift" "$raw" "$out"
