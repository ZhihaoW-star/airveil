#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/airveil-public-tests.XXXXXX")
trap 'rm -rf "$test_build_dir"' EXIT
frameworks=(-framework Cocoa -framework CoreMotion -framework IOBluetooth -framework Carbon -framework CoreImage -framework QuartzCore -framework ScreenCaptureKit -framework Metal -framework CoreMedia -framework CoreVideo)
clang PolicyTests.c -o "$test_build_dir/policy"
"$test_build_dir/policy"
for name in RecoveryTests PublicRendererTests CaptureGateTests PreviewLifecycleTests; do
  clang -fobjc-arc -O2 -mmacosx-version-min=14.0 "${frameworks[@]}" "$name.m" -o "$test_build_dir/$name"
  "$test_build_dir/$name"
done
if grep -En 'CABackdropLayer|CAFilter|windowServerAware|canHostLayersInWindowServer|shouldAutoFlatten|CGSSet|dlsym|NSClassFromString' ../main.m ../PublicVeil.inc ../ConnectionRecovery.inc; then
  echo 'FAIL: private compositor access detected'
  exit 1
fi
echo 'PASS: private compositor symbol audit'
