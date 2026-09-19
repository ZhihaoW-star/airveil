# AirVeil 0.7.0 beta — first public-source release

Turn your head to gently blur your whole Mac screen. Look back to clear it.

This beta uses public macOS APIs, with local screen processing and no camera.
The Home screen walks you through screen access, AirPods connection, and a
short calibration. A configurable comfort zone keeps small turns clear.

## Download

- `airveil-0.7.0-beta-macos-arm64.zip`: Apple Silicon, macOS 14 or later.
- The matching `.sha256` file contains the SHA-256 checksum of that ZIP.
- Intel and Windows binaries are not included.

This is an **ad-hoc signed, unnotarized beta**. macOS may block the download.
See the README for Apple's instructions and the local-build alternative.

## Before you start

Pair compatible AirPods with your Mac. Allow AirVeil screen access in System
Settings, connect, then face the screen and start protection. Pause clears
the screen and stops capture. Pause before taking an unblurred screenshot.

AirVeil is a visual privacy aid, not a screen lock. Audio handoff, multi-display
behavior, smoothness, HDR, and energy use still need broader testing. See
`docs/KNOWN_ISSUES.md` for details.

The README demo is an illustration, not recorded app footage. Automated
regression tests and local build/signature checks pass; these do not establish
all-device compatibility or real-world frame rate.

Free for personal and internal work use under the custom AirVeil Free Use
License. Selling the software or paid derivative versions is not permitted.
This is source-available software, not an OSI-approved open-source release.
