# Verified delivery status

**Repository:** Jake-Zhao/Mini, branch `main`.

| Workstream | State | Evidence and limit |
|---|---|---|
| Swift telemetry, OBD framing, scene geometry and timing source | COMMITTED | `Core/Sources` |
| Metal render graph and sharp HUD source | COMMITTED | `Renderer/` |
| iPhone landscape shell and deterministic Xcode project | COMMITTED | `App/`, `JakeDriveMetal.xcodeproj/`, `tools/make_project.py` |
| 11 runtime textures, alpha premultiplication, 15 glyph atlas | GENERATED + OFFLINE CHECKED | Included in companion art ZIP, rebuilt with `tools/build_assets.py`; intentionally not Git-tracked caches |
| Three full-resolution immutable art masters | COMPANION ZIP ONLY | `car_master.png`, `rear_original.png`, `APPROVED.png`. GitHub binary upload incomplete; do not mark committed. |
| Asset import, generated AppIcons, source/project validators | COMMITTED | `tools/import_art_masters.py`, `build_app_icons.py`, `check_assets.py`, `check_project.py` |
| Swift tests | PASS (offline) | 58 tests, 0 failures after matching source camera / proxy geometry. |
| .jtex and glyph validations | PASS (offline) | 11 JTX files, 15 glyphs, mandatory photo hashes. |
| Xcode compilation, Metal API Validation, GPU capture | NOT RUN | Mac + Xcode needed; not inferred from Linux success. |
| Visual equality/cinematic acceptance | NOT ACCEPTED | Native output still has to be compared against APPROVED.png. |
| Real CoreBluetooth/Vgate/MINI signals | NOT IMPLEMENTED | DEMO input only, no fabricated D3/brake. |

**Known remaining GitHub step:** import and commit the three source PNG masters. Companion archive `JAKE_DRIVE_CINEMATIC_FINAL.zip` contains the full-resolution originals plus inspectable prebuilt textures. The `main` branch has complete text source and build logic, not the full binary master set.

Do **not** change the visual gate to make tests pass. Source completeness, real-device execution, and visual approval are independent criteria.
