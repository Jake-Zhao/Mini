# 12 · Luna Execution Contract

## Do not redesign
The project already has a visual direction. Luna's job is implementation and refinement, not visual reinterpretation.

## First milestone: cinematic PURE renderer
Do not start BLE first.

1. Build/generate runtime textures from source assets.
2. Compile the existing Metal renderer.
3. Produce deterministic captures at 0 / 20 / 72 / 100 / 128 km/h.
4. Produce debug captures for depth, motion, roughness, wetness, vehicle alpha and object id.
5. Fix scene-space grounding before adding more post effects.
6. Match `Reference/APPROVED.png` hierarchy and quality.
7. Only after visual acceptance, wire live telemetry.

## Forbidden shortcuts
- WebView dashboard
- generic bold font for speed
- full-screen radial blur as the main speed effect
- car PNG simply positioned with screen coordinates and no ground integration
- random Matrix characters unrelated to `一路平安`
- inferring brake state from deceleration
- inferring exact D gear from RPM/speed
- claiming visual pass because tests compile

## Evidence required per visual iteration
- 0 km/h screenshot
- 72 km/h screenshot
- 100 km/h screenshot
- 0→100 short recording
- vehicle-alpha debug screenshot
- motion-vector debug screenshot
- wetness/roughness debug screenshot

## Definition of done for PURE visual milestone
- Speed remains the first visual read.
- Vehicle silhouette is complete and integrated.
- Road has believable wet reflection hierarchy.
- Near/far motion differs spatially.
- 0 km/h freezes decorative motion.
- 100 km/h feels materially faster than 20 km/h.
- HUD remains sharp under all motion.
- No effect looks like a generic web animation overlay.
