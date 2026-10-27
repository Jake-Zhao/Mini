# Verified delivery status

**Repository:** Jake-Zhao/Mini, branch `main`.

| Workstream | State | Evidence and limit |
|---|---|---|
| Swift telemetry, OBD framing, scene geometry and timing source | COMMITTED | `Core/Sources` |
| Metal render graph and sharp HUD source | COMMITTED | `Renderer/` |
| iPhone landscape shell and deterministic Xcode project | COMMITTED | `App/`, `JakeDriveMetal.xcodeproj/`, `tools/make_project.py` |
| 14 runtime textures, alpha premultiplication, 15 glyph atlas | GENERATED + OFFLINE CHECKED (2026-10-27) | Rebuilt locally from the companion archive with `tools/build_assets.py`; `.png`/`.jtex` generated caches remain Git-ignored |
| Three full-resolution immutable art masters | COMMITTED | `Reference/APPROVED.png`, `Source/Vehicle/car_master.png`, `Source/Vehicle/rear_original.png` in commit `6b4558a` |
| Asset import, generated AppIcons, source/project validators | COMMITTED | `tools/import_art_masters.py`, `build_app_icons.py`, `check_assets.py`, `check_project.py` |
| Swift tests | PASS (2026-10-27 23:31 CST) | Clean-cache rerun: 58 tests, 0 failures; `swift test --package-path Core --scratch-path /Users/Jake/Library/Developer/JakeDriveRepair/CoreBuild`. The old Documents-local cache hit a Finder-metadata signing error; full diagnosis is in `docs/08_ENVIRONMENT_REPAIR.md`. |
| .jtex and glyph validations | PASS (offline) | 14 JTX files, 15 glyphs, mandatory photo hashes. |
| Apple Metal Toolchain | DOWNLOADED | `xcodebuild -downloadComponent MetalToolchain` installed Metal Toolchain `27A266a` on 2026-10-27. |
| iOS Simulator Swift + Metal compilation and signing | PASS (2026-10-27 23:29 CST) | Xcode 27.1 (27A9275), iOS SDK 27.1, arm64, normal ad hoc signing with `CODE_SIGN_IDENTITY=-`. Signature now binds 28 Info.plist entries and verifies successfully. |
| iOS Simulator app install and launch | PASS (2026-10-27 23:29 CST) | Installed and launched `com.jake.drivemetal` (PID 55476) on iPhone 18 Pro / iOS 27.0. Corrected the project resource packaging; no Xcode reinstallation or Playgrounds installation required. See `docs/08_ENVIRONMENT_REPAIR.md`. |
| Native simulator frames and recording | CAPTURED | `Evidence/native/environment-repair-72-D3.png`, `environment-repair-128-D3.png`, `environment-repair-running.mp4`. Actual running Metal scene, explicitly DEMO. These are environment-repair evidence, not the complete visual acceptance matrix. |
| Metal API Validation, GPU capture, real iPhone execution | NOT RUN | Simulator launch does not prove these checks, device performance, or hardware compatibility. |
| Visual equality/cinematic acceptance | NOT ACCEPTED | First native frames show material/geometry issues, including a visible hero glyph seam and an extra gear numeral. Native output is below the approved visual target; visual work remains open. |
| Real CoreBluetooth/Vgate/MINI signals | NOT IMPLEMENTED | DEMO input only, no fabricated D3/brake. |

**Commands actually run on 2026-10-27 (macOS arm64, Xcode 27.1, iOS SDK 27.1):**

```sh
python3 -m venv /tmp/jakedrive-art-venv
/tmp/jakedrive-art-venv/bin/pip install -r tools/requirements.txt
PATH=/tmp/jakedrive-art-venv/bin:$PATH python3 tools/import_art_masters.py /Users/Jake/Downloads/JAKE_DRIVE_CINEMATIC_FINAL.zip
python3 tools/check_project.py
PATH=/tmp/jakedrive-art-venv/bin:$PATH python3 tools/check_assets.py
swift test --package-path Core
xcodebuild -downloadComponent MetalToolchain
xcodebuild -project JakeDriveMetal.xcodeproj -scheme JakeDriveMetal -destination 'platform=iOS Simulator,id=4839B1E9-16AF-4168-965A-BE8E128F8640' -derivedDataPath /tmp/jakedrive-derived ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
xcodebuild -project JakeDriveMetal.xcodeproj -scheme JakeDriveMetal -destination 'platform=iOS Simulator,id=4839B1E9-16AF-4168-965A-BE8E128F8640' -derivedDataPath /tmp/jakedrive-deepsign ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='-' OTHER_CODE_SIGN_FLAGS='--deep' ASSETCATALOG_COMPILER_APPICON_NAME= build
xcodebuild -downloadPlatform iOS
xcodebuild -runFirstLaunch -checkForNewerComponents
xcrun simctl spawn 7AA68A42-BDAF-476D-BC7B-6AB851B1A9C8 /usr/bin/id mobile
xcrun simctl install 4839B1E9-16AF-4168-965A-BE8E128F8640 /tmp/jakedrive-deepsign/Build/Products/Debug-iphonesimulator/JakeDriveMetal.app
xcodebuild -runFirstLaunch -checkForNewerComponents
xcodebuild -downloadPlatform iOS -buildVersion 27.0 -exportPath /Users/Jake/Downloads/JAKE_DRIVE_iOS27_RUNTIME_REPAIR
hdiutil verify /Users/Jake/Downloads/JAKE_DRIVE_iOS27_RUNTIME_REPAIR/iphonesimulator_27.0_24A434.exportedBundle/Restore/043-70362-657.dmg
xcrun simctl runtime delete E622D7F3-6D70-4196-97CF-CB0706D311E7
xcrun simctl runtime add /Users/Jake/Downloads/JAKE_DRIVE_iOS27_RUNTIME_REPAIR/iphonesimulator_27.0_24A434.exportedBundle/Restore/043-70362-657.dmg
xcrun simctl runtime verify 4A39A32C-BFCE-4220-8549-3D618B43921B
xcodebuild -project JakeDriveMetal.xcodeproj -scheme JakeDriveMetal -destination 'platform=iOS Simulator,id=4839B1E9-16AF-4168-965A-BE8E128F8640' -derivedDataPath /tmp/jakedrive-final-check ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
xcrun simctl spawn 4839B1E9-16AF-4168-965A-BE8E128F8640 /usr/bin/id -u mobile
xcrun simctl install 4839B1E9-16AF-4168-965A-BE8E128F8640 /tmp/jakedrive-final-check/Build/Products/Debug-iphonesimulator/JakeDriveMetal.app
```

The commands above include earlier failed diagnostic attempts and do not establish a damaged Xcode installation. Xcode 27 uses Device Hub for simulator UI. `simctl spawn DEVICE /usr/bin/id mobile` uses a host-root absolute executable; its output was not valid evidence that the simulated OS account service was missing. A root-level `Resources/` in this app made CFBundle misidentify the flat iOS bundle layout, leaving its Info.plist invisible to the installer and codesign. Packaging `Art/` and `Config/` directly and loading them through `Bundle.resourceURL` fixed normal signing, installation and launch on the existing Xcode 27.1. The final successful commands and logs are recorded in `docs/08_ENVIRONMENT_REPAIR.md`. Generated GPU caches and local evidence remain Git-ignored.

Do **not** change the visual gate to make tests pass. Source completeness, real-device execution, and visual approval are independent criteria.


## 2026-10-28 · Full companion vehicle road-registration rebuild

- **Runtime actor source changed:** the standalone studio-like `Source/Vehicle/car_master.png` is no longer rendered on PURE; the road companion is extracted from the car already inside the same `Reference/APPROVED.png` wet-road shot by `tools/build_road_car_from_approved.py`.
- **Perspective & contact:** camera and tire contact points are authored, registered and tested in `Config/scene.json`, `SceneGeometry.swift` and `Source/Vehicle/runtime_registration.json`.
- **Photo wet-road details:** separate PNG/JTX2 `car_wake` (only nonzero-speed), `contact_shadow` (road only), dampened camera-aligned reflection; `car_cruise` and `car_brake` have identical alpha and non-lamp pixels.
- **Metal integration:** `Renderer/JakeRenderer.swift` binds all seven vehicle/environment sprite resources; `Renderer/Shaders/JakeShaders.metal` uses the same `carRect` for body, wake and lighting, removes artificially pulsing tint and does not alter vehicle pose while braking.
- **Assets uploaded:** GitHub Actions compiled and committed seven vehicle-related PNGs from the checked-in approved source to `Resources/Art/`. Derived JTX2 files remain reproducible ignored caches; no user intervention needed.
- **Offline QA:** the build log checks 14 texture pairs and alpha/taillight equality, and `Core` verifies world projection. Photo-crop + road-base local composition inspection was performed but is **not native iOS output**.
- **Still unverified:** Xcode/Metal compile, iPhone GPU screenshots and cinematic subjective acceptance; real F56 brake signal remains unknown. The vehicle is a single-view photo impostor with matched tire effects, **not** measured 3D vehicle geometry or full fluid physics.

Do not mark the entire cinematic interface as accepted just because the asset/tool checks pass.
