# Materials and dependencies

- The app uses Apple system frameworks supplied by macOS. They are linked at
  runtime, not bundled as copied third-party libraries.
- Interface symbols come from macOS system symbol APIs, not bundled symbol files.
- The release icon and illustrative demo are original procedural drawings;
  their generator is included in `tools/make_media.py`. No real screens,
  people, headphone names, or private documents appear in the demo.
- The media generator uses Pillow as an optional development tool. Pillow is
  not bundled in the application; its own license applies to that tool.
- Fonts are rendered using locally installed fonts; no font files are shipped.

Apple, AirPods, and macOS names identify compatibility. AirVeil does not claim
endorsement or affiliation.
