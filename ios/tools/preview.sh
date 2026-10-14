#!/bin/zsh
# Builds Lockedmind's iPhone code as a Mac (Catalyst) app with only the
# Command Line Tools, so the screens and the model can be checked without
# Xcode. Not the real iPhone build — that is Lockedmind.xcodeproj.
#
#   tools/preview.sh build                 → build/preview/Lockedmind Preview.app
#   tools/preview.sh run SCRIPT OUTDIR     → runs a PreviewHarness script, scratch data
set -e
# The Command Line Tools are enough, and work even before Xcode's licence is accepted.
[[ -d /Library/Developer/CommandLineTools ]] && export DEVELOPER_DIR=/Library/Developer/CommandLineTools
here=${0:A:h}
ios=${here:h}
out=$ios/build/preview
app="$out/Lockedmind Preview.app"
# The 26 SDK: from 27 on, SwiftUI's @State is a macro whose plugin ships only with Xcode.
SDK=$(xcrun --show-sdk-path --sdk macosx26.5 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
FW=$SDK/System/iOSSupport/System/Library/Frameworks
LIB=$SDK/System/iOSSupport/usr/lib/swift

build() {
  mkdir -p "$app/Contents/MacOS"
  rm -f "$app/Contents/MacOS/Lockedmind"
  swiftc -parse-as-library -swift-version 5 -O -D PREVIEW -D SDK26 \
    -target arm64-apple-ios26.0-macabi -sdk "$SDK" -Fsystem "$FW" -I "$LIB" -L "$LIB" \
    "$ios"/Lockedmind/*.swift \
    -o "$app/Contents/MacOS/Lockedmind" 2>&1 | grep -v -E "is deprecated|^\s*\||^\s*$|#DeprecatedDeclaration|^\[#" || true
  [[ -x "$app/Contents/MacOS/Lockedmind" ]] || { echo "build failed"; exit 1; }
  cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.yenxu0872-max.lockedmind.preview</string>
  <key>CFBundleExecutable</key><string>Lockedmind</string>
  <key>CFBundleName</key><string>Lockedmind Preview</string>
  <key>CFBundleDisplayName</key><string>Lockedmind</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>UIDeviceFamily</key><array><integer>2</integer></array>
  <key>UIApplicationSceneManifest</key><dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
  </dict>
  <key>UILaunchScreen</key><dict/>
</dict></plist>
PLIST
  codesign -s - --force "$app" >/dev/null 2>&1
  echo "built $app"
}

case $1 in
  build) build ;;
  run)
    [[ -x "$app/Contents/MacOS/Lockedmind" ]] || build
    script=${2:?script file}; dest=${3:?output folder}
    mkdir -p "$dest" "$dest/data"
    LM_SCRIPT=$script LM_OUT=$dest LM_DATA=$dest/data "$app/Contents/MacOS/Lockedmind" ;;
  *) echo "usage: preview.sh build | run SCRIPT OUTDIR" ;;
esac
