# Privacy

AirVeil runs on your Mac. It does not require an account, contain analytics,
contact a backend, or upload screen images or head-motion data.

## Screen images

ScreenCaptureKit supplies screen frames to an in-memory Core Image / Metal
renderer. Frames are used to draw the blur. There is no video or image writer
in the app and audio capture is disabled. Pause, Stop, or Quit stops capture.
An unused prepared capture session expires after 60 seconds. Active protection
keeps capture running even when no blur is visible.

## Headphones and settings

Core Motion supplies head orientation. Bluetooth APIs discover already paired
headphones and can request a connection. The optional signal-strength feature
reads a rough signal trend, not a precise distance.

Settings are stored in the app's local macOS preferences. These can include the
comfort zone, window-hiding preference, a selected or remembered headphone
Bluetooth address, and shortcut status. These preferences are not included in
the source repository or release archive. The app does not access your camera.

## Diagnostics

An in-memory event list holds up to 80 recent entries. **Copy diagnostics**
explicitly copies a text report to your clipboard; it does not send it anywhere.
It includes event times, connection and permission status, display IDs, and
rendering measurements. It does not intentionally include screen pixels, raw
motion samples, or headphone addresses. System-generated error text can still
contain context: review a report before sharing it. macOS may maintain its own
system logs outside the app's control.

## Limits

Other screen-recording or screenshot apps can capture the displayed overlay.
Pause before taking a clear screenshot. A visual blur cannot protect against
other software reading a window's original content. For access control, use
the macOS lock screen.

The sandbox enables Bluetooth and does not enable outbound or inbound network
connections. GitHub and any website used to download AirVeil have their own
privacy policies; those services are separate from the app.
