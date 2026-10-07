# Beta status and known issues

AirVeil 0.7.1 beta includes the preview capture-lifecycle fix and Chinese
onboarding added after the 0.7.0 public-source package. It retains the public-API
renderer and connection policies. It is not an App Store release.

- **Signing:** downloads are ad-hoc signed, not Developer ID signed or notarized.
- **Hardware:** the release build targets Apple Silicon. Intel, every AirPods
  model, and every supported macOS version have not been tested.
- **Smoothness:** the renderer requests up to 60 fps; actual smoothness varies.
  Sensor latency, high refresh rates, long sessions, and battery impact need
  more real-device testing. No measured battery-life claim is made.
- **Screen permission:** after changing permission in System Settings, quit and
  reopen the app if retrying does not work. Avoid running another AirVeil copy
  at the same time. Development builds retain the public-lab bundle ID.
- **Setup:** if an action starts screen preparation, wait for the ready message
  and click the action again. This beta does not automatically continue every
  interrupted setup action.
- **Screenshots:** Pause before capturing a clear image. While the overlay is
  visible, window selection may target it instead of the window beneath it.
- **Audio switching:** Bluetooth reconnection does not force AirPods to switch
  from iPhone. Select AirPods in the Mac Bluetooth menu if needed.
- **Multiple displays, Spaces, full-screen apps, sleep/wake, protected video,
  and HDR:** these need broader device testing. Capture can differ from the
  original screen in sharpness or color.
- **Failure behavior:** a last blurred frame may be retained if rendering fails;
  the recovery panel lets you restore the screen. This is not a security lock.
- **Experimental options:** signal strength and repeated-movement detection are
  off by default. They cannot reliably identify whether you left your seat.

The demo GIF is a synthetic illustration. Automated tests check policy logic,
connection-state transitions, real blurred pixels on a synthetic image, and
first-frame / pause cancellation. Neither is a substitute for physical testing.
