# 11 · Render Pass Contract

## Pass 0 — Frame state
Resolve immutable per-frame telemetry snapshot and cinematic state.

```text
speedKph
gearDisplay
gracefulDataValidity
isBraking?  // optional/unknown allowed
exposureSeconds
travelMeters
qualityTier
```

## Pass 1 — Scene G-buffer
Outputs:
- HDR scene color
- linear depth
- world / view normal
- material roughness / wetness
- object id
- motion vector over exposure interval

## Pass 2 — Wet-road lighting
Compute direct practical light contribution and environment reflection in linear HDR.
Do not bake road reflection twice.

## Pass 3 — Vehicle composite
Vehicle is a fixed-view image proxy in v1, but must be positioned through scene projection.
Outputs vehicle object id and depth before particles.

Vehicle rules:
- linear premultiplied alpha
- preserve complete silhouette
- explicit contact points
- brake emission separate from body image
- reflection proxy clipped to road

## Pass 4 — Atmospheric layers
- binary rain depth slices
- tire spray
- road mist
- subtle light shafts only if justified

Particles must depth-test against vehicle/object depth where appropriate.

## Pass 5 — Exposure integration / motion blur
Blur based on exposure-interval motion vectors, not previous-frame delta alone.
Do not blur HUD.

Suggested reference exposure:
- 0–30 km/h: 1/120–1/90 s equivalent
- 30–80 km/h: 1/90–1/70 s
- 80–140 km/h: 1/70–1/55 s

Art direction may clamp blur to preserve readability.

## Pass 6 — Bloom / tone map
- thresholded bloom from genuine bright sources
- no full-screen haze
- preserve black level and road texture
- use controlled filmic shoulder

## Pass 7 — Speed accent
Render left-side streaks behind hero digits only.
The streak field may respond to speed and acceleration but must not alter the digit itself.

## Pass 8 — HUD
Composite hero glyphs and gear after all scene post-processing.
- no temporal blur
- no DoF
- no parent-view blur
- no scale pulse on number changes

## Debug views
Required toggles:
- scene color
- linear depth
- motion vectors
- roughness
- wetness
- object id
- vehicle alpha
- binary rain depth layers
- pre/post tone map
