Implement from the current JAKE DRIVE repository/package directly. Do not redesign it and do not consult older packages.

Read START_HERE.md and DESIGN_MASTER.md first. Import the supplied authentic image masters with `python3 tools/import_art_masters.py /path/to/JAKE_DRIVE_CINEMATIC_FINAL.zip`; do not continue with missing masters. Run `python3 tools/check_project.py`, `python3 tools/check_assets.py`, and `swift test --package-path Core` before the native rendering phase. The target is the approved PURE landscape shot: centered hero speed, no km/h/tach/cards/Union Jack, small gear at hero lower-right, small green MINI companion car on the right-lower roadway, wet arched tunnel, and dark 0/1 rain derived from “一路平安”.

Use the existing Swift + Metal renderer. Preserve the exact camera, timing, material, single-shot vehicle crop, wheel-contact/spray, glyph and render-pass contracts. Do not substitute a generic font; do not re-cut the vehicle from brightness; do not blur the hero speed/gear; do not infer gear/brake.

First milestone on Mac/iPhone is compilation + native visual evidence for 0/20/72/88/100/128 and all G-buffer debug modes. If visual output is below Reference/APPROVED.png, improve the existing scene/material/shader path before BLE work.

Binary art masters are in the final distribution archive and have SHA-256 values documented in Source/Vehicle/README.md. Missing binary masters are not permission to generate placeholders.

Report actual commands and PASS/FAIL/NOT RUN. Never call Linux parsing an Apple build and never claim 60fps/visual acceptance without native evidence.


Do not confuse SOURCE COMPLETE with VISUAL ACCEPTED. The three required image masters are now in the GitHub tree; `tools/build_assets.py` deterministically rebuilds 14 PNG/JTX2 runtime textures. The approved road shot is the canonical runtime source of the companion car. On a local clone, the import command will place and verify the masters and regenerate resources. The actual iOS/Metal build and camera-quality validation are still NOT RUN.


## Vehicle warning (mandatory)
The former standalone photo `Source/Vehicle/car_master.png` has a camera angle/lighting different from the approved wet road and must NOT be used on PURE. `tools/build_road_car_from_approved.py` now builds `car_body`, two exact-pose brake states, photo wheel water, shadow and tail-lamp masks from `Reference/APPROVED.png`. Do not regenerate an independent second car view or attach random green bars as water. Freeze the car's camera-relative pose across speed changes; do not move it during brake events. Run `python3 tools/check_assets.py` after rebuild. See `docs/01_ASSETS.md` for the exact contact coordinates.
