# JAKE DRIVE

iPhone-only landscape OBD cockpit for Jake's MINI F56, built around a native Swift + Metal rendering pipeline.

## Status
This repository is the clean reconstruction baseline. The visual target is the approved PURE cockpit: cinematic wet-tunnel motion, centered hero speed, small gear indicator, dark binary rain derived from “一路平安”, and a small green JCW-style car integrated into the roadway.

## Start
Read `START_HERE.md` first. Then follow `docs/` in numeric order.

## Principles
- Native iOS; no WebView dashboard.
- Metal owns the driving scene and post-processing.
- Hero digits and gear remain sharp after background post-processing.
- Static art provides material quality; shaders provide motion, depth, lighting, and atmosphere.
- 0 km/h freezes decorative motion; higher speed increases spatial motion, exposure blur, rain drift, and road reflection flow.
- Unknown gear/brake data remains unknown; never infer vehicle state from speed alone.

Generated GPU cache textures are intentionally not committed. They are rebuilt from source assets by `tools/build_assets.py`.
