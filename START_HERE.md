# JAKE DRIVE · START HERE

This repository is the clean source of truth for the rebuild.

## Read in this order
1. `README.md`
2. `docs/00_DECISIONS.md`
3. `docs/09_CINEMATIC_REBUILD.md`
4. `docs/10_SHOT_BIBLE.md`
5. `docs/11_RENDER_PASSES.md`
6. `docs/12_LUNA_EXECUTION.md`
7. `docs/03_RENDER_AND_COLOR.md`
8. `docs/04_ASSET_PIPELINE.md`
9. `docs/05_TEMPORAL_MODEL.md`
10. `docs/06_CODE_AND_DATA.md`
11. `docs/07_ACCEPTANCE.md`

Then inspect:
- `Reference/APPROVED.png`
- `Source/Vehicle/`
- `Source/Typography/`
- `Renderer/`
- `Core/`

## First execution order
```bash
python3 tools/build_assets.py
python3 tools/verify.py
cd Core && swift test
```

On macOS/Xcode, build `JakeDriveMetal.xcodeproj` after generated resources are present.

## Project priority
Cinematic PURE renderer first. BLE/OBD integration comes after the rendering baseline reaches the accepted visual quality.
