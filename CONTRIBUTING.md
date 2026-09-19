# Contributing

Thank you for trying AirVeil. This project currently focuses on macOS only.

## Report a problem

Include your macOS version, Mac chip (Apple Silicon or Intel), AirPods model,
the AirVeil version, steps to reproduce, and what you expected. Do not include
serial numbers, Bluetooth addresses, private screen content, passwords, or
account details. Review diagnostics before posting them.

The most useful testing areas are connection recovery, smoothness, multiple
displays, screenshot compatibility, and energy use.

## Propose a change

For substantial changes, open an issue first. Keep changes focused, use public
macOS APIs, and preserve Pause as an immediate way to clear the screen. Do not
add analytics, screen uploads, or dependencies without discussing the purpose.
Run `bash Source/Tests/run.sh` and `bash Source/build.sh` on a Mac.

Submit only work you have the right to contribute. Contributions must be
available under this repository's custom AirVeil Free Use License; it is not an
OSI-approved open-source license. Contributor copyright remains with the
contributor. No copyright assignment or blanket relicensing right is required.

Media can be regenerated with `python3 tools/make_media.py` after installing
Pillow. The schematic is not actual app footage; preserve that disclosure.
