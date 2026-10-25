# JAKE DRIVE · CINEMATIC METAL BASELINE

This is the only clean repository baseline.

JAKE DRIVE is an iPhone-only landscape OBD cockpit whose PURE screen is rendered as a cinematic real-time Metal shot: centered hero speed, small gear badge, small green MINI companion car on the lower-right roadway, wet arched tunnel, and dark binary rain derived from the UTF-8 bytes of “一路平安”.

## Start
1. `START_HERE.md`
2. `DESIGN_MASTER.md`
3. `docs/00_DECISIONS.md` through `docs/07_LUNA_EXECUTION.md`
4. `Reference/APPROVED.png` from the final distribution archive

## Engineering principles
- SwiftUI shell + MTKView native renderer; no WebView dashboard.
- HDR scene / G-buffer / exposure integration / environment / bloom / tone-map / sharp-HUD pipeline.
- Hero speed and gear are drawn after all background post-processing.
- Virtual shutter is fixed at 12.5 ms and independent of refresh rate.
- 0 km/h freezes decorative travel.
- Unknown gear/brake stays unknown.
- Static art supplies quality; shaders supply coherent space, exposure, reflection, particles, and motion.

Large binary art masters are distributed in `JAKE_DRIVE_CINEMATIC_FINAL.zip`; see `Source/Vehicle/README.md` for exact paths and SHA-256 hashes.
