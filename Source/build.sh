#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
airveil_output="$(cd .. && pwd)/dist"
airveil_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
airveil_arch=$(uname -m)
airveil_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/airveil-build.XXXXXX")
trap 'rm -rf "$airveil_build_dir"' EXIT
airveil_app="$airveil_build_dir/AirVeil.app"
mkdir -p "$airveil_app/Contents/MacOS" "$airveil_app/Contents/Resources" "$airveil_output"
xcrun clang -fobjc-arc -O2 -mmacosx-version-min=14.0 \
  -framework Cocoa -framework CoreMotion -framework IOBluetooth -framework Carbon \
  -framework CoreImage -framework QuartzCore -framework ScreenCaptureKit \
  -framework Metal -framework CoreMedia -framework CoreVideo \
  main.m -o "$airveil_app/Contents/MacOS/AirVeil"
cp -X Info.plist "$airveil_app/Contents/Info.plist"
cp -X Assets/AirVeil.icns "$airveil_app/Contents/Resources/AirVeil.icns"
cp -X ../LICENSE "$airveil_app/Contents/Resources/LICENSE.txt"
cp -X ../docs/PRIVACY.md "$airveil_app/Contents/Resources/Privacy.md"
codesign --force --sign - --entitlements PublicLab.entitlements "$airveil_app"
codesign --verify --deep --strict "$airveil_app"
airveil_zip="$airveil_output/airveil-${airveil_version}-beta-macos-${airveil_arch}.zip"
ditto -c -k --norsrc --noextattr --keepParent "$airveil_app" "$airveil_zip"
mkdir "$airveil_build_dir/archive-check"
ditto -x -k "$airveil_zip" "$airveil_build_dir/archive-check"
codesign --verify --deep --strict "$airveil_build_dir/archive-check/AirVeil.app"
ditto --norsrc --noextattr "$airveil_app" "$airveil_output/AirVeil.app"
shasum -a 256 "$airveil_zip" | awk '{print $1}' > "$airveil_zip.sha256"
echo "Built $airveil_zip (local ad-hoc signature; not notarized)."
