# JAKE DRIVE · iPhone / Metal Cinematic Cockpit

A native SwiftUI + Metal design-and-implementation baseline for a landscape-only iPhone dashboard for Jake's MINI F56. The approved PURE look has a centered brushed speed numeral, a small gear badge, a small companion car on the wet roadway, and restrained binary rain encoding **一路平安**.

**Read `START_HERE.md` before editing.**

## Repository status
The GitHub tree contains the Swift core, Metal render passes, Xcode project generator and project, scene settings, build/test scripts, and contracts. The three full-resolution image masters are in the companion **`JAKE_DRIVE_CINEMATIC_FINAL.zip`** download supplied in the conversation, not yet present in this public Git tree. Do not replace them with inferior placeholders.

## Exact startup

```sh
git clone https://github.com/Jake-Zhao/Mini.git
cd Mini
python3 -m pip install -r tools/requirements.txt
python3 tools/import_art_masters.py ~/Downloads/JAKE_DRIVE_CINEMATIC_FINAL.zip
python3 tools/check_project.py
swift test --package-path Core
# On macOS: open JakeDriveMetal.xcodeproj
```

The art importer verifies all three binary masters, builds **14** PNG/JTX texture pairs, **15** HUD glyphs, icon assets, and regenerates the Xcode project. Generated GPU caches are ignored by Git. After confirming rights to publish the provided source photograph in this **public** repository, run `bash tools/publish_art_masters.sh --push` to commit only the three verified immutable image masters.


## Road-aligned companion vehicle (locked)
The normal/braking companion vehicle in PURE is extracted from the same `Reference/APPROVED.png` roadway camera; `car_cruise.png` / `car_brake.png` share the same transparent silhouette and only the rear lamp pixels change. `car_wake.png` retains matching photo water spray, and the renderer positions road shadow/reflection at explicit front and rear tire contacts. At 0 km/h no new spray is emitted. The old independent `Source/Vehicle/car_master.png` is an archived pose reference, not the PURE running sprite. See `docs/01_ASSETS.md`.

## Design invariants
- SwiftUI shell, Metal/MTKView cinematic background; no WebView cockpit.
- 12.5 ms virtual exposure independent of animation FPS; 0 km/h stops decorative travel.
- Hero speed and gear are drawn last at native resolution and never enter background blur/bloom.
- No `km/h`, tachometer, Union Jack, or extraneous status cards on PURE.
- Unknown live gear or brake state stays unknown; DEMO cannot pose as live OBD.
- Source photos and master art do not imply vehicle/photograph rights; see `SOURCE_RIGHTS.md`.

See [docs/REPO_TREE.md](docs/REPO_TREE.md) for the full file layout, [DESIGN_MASTER.md](DESIGN_MASTER.md) for the visual contract and [DELIVERY_STATUS.md](DELIVERY_STATUS.md) for what has and has not been tested.
