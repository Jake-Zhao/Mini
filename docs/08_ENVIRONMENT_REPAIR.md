# Environment repair · 2026-10-27

Environment: macOS 26.7.1 (25G241), Apple silicon, Xcode 27.1 (27A9275), iOS SDK 27.1; running device: iPhone 18 Pro / iOS 27.0 (24A434), UDID `4839B1E9-16AF-4168-965A-BE8E128F8640`.

## Cause and fix

The old project copied the entire `Resources` folder into the root of the flat iOS app. CFBundle interpreted that folder as a legacy bundle resource location, so `Bundle(path: appPath)?.bundleIdentifier` returned nil even though the root Info.plist contained `com.jake.drivemetal`. This also explains the earlier `codesign` result `Info.plist=not bound`, the unexpected signing error mentioning `default.metallib`, and the installer's `IXErrorDomain code=13: Missing bundle ID`.

In a diagnostic copy, renaming only this Resources folder immediately restored Bundle's identifier and made `simctl install` succeed on the same simulator. The source fix in `tools/make_project.py` now copies `Resources/Art` and `Resources/Config` separately as `Art/` and `Config/` in the app. `TextureStore` uses `Bundle.resourceURL`. A project check prevents reintroducing the ambiguous root `Resources/` folder. Art, camera, shader and glyph contracts were not changed by this packaging fix.

The existing Xcode installation includes `Contents/Applications/DeviceHub.app`, which is the Xcode 27 simulator UI. The prior inference that missing Simulator.app meant Xcode was damaged was wrong. The prior `/usr/bin/id mobile` diagnostic used a Mac executable and did not prove that the simulator lacked mobile users. No Xcode reinstallation or Playgrounds installation was needed for this repair.

Official documentation: [Device Hub](https://developer.apple.com/documentation/xcode/device-hub), [Running apps on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).

## Commands and results

Working directory for the commands below: `/Users/Jake/Documents/Projects/Mini`.

```sh
python3 tools/make_project.py
python3 tools/check_project.py
/tmp/jakedrive-art-venv/bin/python tools/check_assets.py
xcodebuild -project JakeDriveMetal.xcodeproj -scheme JakeDriveMetal \
  -destination 'platform=iOS Simulator,id=4839B1E9-16AF-4168-965A-BE8E128F8640' \
  -derivedDataPath /Users/Jake/Library/Developer/JakeDriveRepair/DerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- build
codesign -dv /Users/Jake/Library/Developer/JakeDriveRepair/DerivedData/Build/Products/Debug-iphonesimulator/JakeDriveMetal.app
codesign --verify --strict --verbose=2 /Users/Jake/Library/Developer/JakeDriveRepair/DerivedData/Build/Products/Debug-iphonesimulator/JakeDriveMetal.app
xcrun simctl install 4839B1E9-16AF-4168-965A-BE8E128F8640 /Users/Jake/Library/Developer/JakeDriveRepair/DerivedData/Build/Products/Debug-iphonesimulator/JakeDriveMetal.app
xcrun simctl launch 4839B1E9-16AF-4168-965A-BE8E128F8640 com.jake.drivemetal
xcrun simctl io 4839B1E9-16AF-4168-965A-BE8E128F8640 screenshot /Users/Jake/Documents/Projects/Mini/Evidence/native/environment-repair-72-D3.png
xcrun simctl io 4839B1E9-16AF-4168-965A-BE8E128F8640 screenshot /Users/Jake/Documents/Projects/Mini/Evidence/native/environment-repair-128-D3.png
xcrun simctl io 4839B1E9-16AF-4168-965A-BE8E128F8640 recordVideo --codec=h264 --force /Users/Jake/Documents/Projects/Mini/Evidence/native/environment-repair-running.mp4
```

Project check, asset check, signed Swift/Metal build, signature validation, install and launch: **PASS**. Launch returned `com.jake.drivemetal: 55476`; signing reports `Format=app bundle` and `Info.plist entries=28`. Device Hub showed the running app and its accessibility reading changed from DEMO 72/D3 to DEMO 128/D3. Recording was stopped with SIGINT; simctl confirmed that the video was written to disk.

Build log: `/Users/Jake/Library/Developer/JakeDriveRepair/build.log`, also copied to `Evidence/native/environment-repair-build.log`. Images and video are actual simulator captures. The first immediate launch capture was a transition frame; the 72/D3 and 128/D3 files show the running renderer.

Core test rerun initially **FAIL**: the old Documents-local `Core/.build/out/Products/Debug/JakeCoreTests.xctest` had `com.apple.FinderInfo` and file-provider attributes, which codesign rejected. Rebuild into a clean local cache with:

```sh
swift test --package-path Core --scratch-path /Users/Jake/Library/Developer/JakeDriveRepair/CoreBuild
```

Clean-cache result: **PASS**, 58 XCTest tests, 0 failures at 23:31:48 CST. Full log: `/Users/Jake/Library/Developer/JakeDriveRepair/core-tests-clean.log`. This does not change visual or hardware acceptance.

Real iPhone execution, real-device performance, BLE/OBD access and GPU frame capture: **NOT RUN**. Visual acceptance: **NOT ACCEPTED**. Current simulator output reveals existing visual issues and does not close the PURE quality gate.
