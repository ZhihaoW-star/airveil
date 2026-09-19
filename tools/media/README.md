# Demo media

The launch film is an illustration, not a recording or performance benchmark.
All desktop text is synthetic. No personal screen content or real person's
likeness was used. The film does not imply guaranteed reconnect, protection
against every observer, or control of Apple's audio switching.

`character-poses.png` is an original anonymous character sheet generated with
the built-in OpenAI image-generation tool on 2026-09-19. The three poses are
cropped and composited into the film. The monitor, sample workspace, labels,
background, and motion sequence are drawn programmatically. No model download
or face photograph was needed. The existing AirVeil icon remains unchanged.

## Rebuild

On macOS, with Python, Pillow, NumPy, and Xcode Command Line Tools:

```sh
python3 tools/make_demo.py --preview
python3 tools/make_demo.py
```

Outputs: `docs/media/airveil-demo-1080p.mp4` (1920×1080, 30 fps, 28 seconds),
`docs/media/airveil-demo.gif` (960×540, 10 fps timeline), and `demo-poster.png`.
Identical GIF frames may be combined without changing their total duration.
The Objective-C encoder streams frames to AVFoundation rather than saving
hundreds of full-resolution intermediates. Audio is intentionally omitted.
Fonts are drawn from the local macOS installation; no font files are bundled.

## Character prompt

Create a premium editorial vector-style character sprite sheet, landscape
1536×1024 or equivalent. Exactly three equally spaced poses, equal-width
columns with padding. The same anonymous androgynous young adult: short navy
hair, neutral warm skin, a refined calm friendly face, a pale teal crewneck
sweater, and white wireless earbuds with visible short stems. Head and
shoulders with full upper chest; no hands. Left column: head 65 degrees toward
the viewer's left, shoulders forward. Middle: facing front. Right: head 65
degrees toward the viewer's right. Same scale, baseline, and person. A
sophisticated minimalist design-studio illustration with smooth navy outlines,
muted flat colors, and soft shading. No stick figure, cartoon, anime,
photograph, text, or logos. Pure white background. Each head about 300 pixels
wide, each bust about 600 pixels tall. An original character, not a real person.

The resulting asset has transparency and a more detailed illustration style
than the prompt requested; the included source asset is the version used.
