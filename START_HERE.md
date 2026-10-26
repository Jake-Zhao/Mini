# START HERE · JAKE DRIVE

This repository is the canonical source tree. Do not merge a prior experimental visual ZIP into it.

## Step 1 — Reconstruct assets
Retrieve `JAKE_DRIVE_CINEMATIC_FINAL.zip` from this conversation. It includes the *actual* approved photo masters and precompiled runtime textures. Run:

```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/import_art_masters.py /path/to/JAKE_DRIVE_CINEMATIC_FINAL.zip
```

The importer validates the three original binary files by their exact hashes, rebuilds 11 runtime textures, the 15-glyph atlas and all AppIcons, then regenerates `JakeDriveMetal.xcodeproj`. It will **fail** rather than create a substitute car or dashboard image.

## Step 2 — Pure core and project contracts
```sh
swift test --package-path Core
python3 tools/check_project.py
python3 tools/check_assets.py
```

## Step 3 — Native work on a Mac (not yet run here)
Open `JakeDriveMetal.xcodeproj`, select `JakeDriveMetal`, set signing Team, build, turn on Metal API/Shader validation, and capture real iPhone 15 Pro frames for 0, 20, 72, 88, 100 and 128. Use the supplied reference shot as a **minimum visual acceptance target**, not as a runtime full-screen image. Keep the 3D environment + wet surface, same camera and weather, crisp digits after post processing.

## Step 4 — Live vehicle input only after PURE visual acceptance
Vgate iCar Pro 2S BLE must be discovered with CoreBluetooth inside the app. GATT services, MINI F56 private gear/brake signals and actual acquisition rate require live discovery and validation. Never guess `D3` or brake-on from RPM/deceleration.

Read `DESIGN_MASTER.md`, `docs/00_DECISIONS.md`–`docs/07_LUNA_EXECUTION.md` and `docs/REPO_TREE.md` next. Test status is in `DELIVERY_STATUS.md`.
