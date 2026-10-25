# START HERE · JAKE DRIVE CINEMATIC FINAL

Only use this repository/package. Do not import any historical design package.

Read in order:
1. `DESIGN_MASTER.md`
2. `docs/00_DECISIONS.md`
3. `docs/01_ASSETS.md`
4. `docs/02_RENDER_COLOR.md`
5. `docs/03_TEMPORAL.md`
6. `docs/04_RENDER_GRAPH.md`
7. `docs/05_DATA_OBD.md`
8. `docs/06_ACCEPTANCE.md`
9. `docs/07_LUNA_EXECUTION.md`

With the full distribution archive present:
```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/build_assets.py
swift test --package-path Core
```

The renderer already exists. Do not write a second renderer from pseudocode, do not replace Metal with HTML, and do not start BLE integration before native PURE output passes the visual gate.

Current phase intentionally does not claim Xcode/iPhone validation.
