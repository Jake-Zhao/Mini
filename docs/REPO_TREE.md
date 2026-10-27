# Clean repository tree and asset roles

```text
Mini/
├── .github/workflows/build.yml       source contracts; manual macOS native/art gate
├── App/
│   ├── Assets.xcassets/               AppIcon metadata; PNGs compiled by tools/build_app_icons.py
│   ├── Info.plist                      iPhone-only, landscape both directions
│   ├── JakeDriveMetalApp.swift         SwiftUI shell / developer controls
│   ├── LabModel.swift                  explicitly marked DEMO source
│   └── MetalHost.swift                 SwiftUI ↔ MTKView adapter
├── Core/
│   ├── Package.swift
│   ├── Sources/JakeCore/               Telemetry, OBD decoder contract, motion, layout, scene geometry
│   └── Tests/JakeCoreTests/            58 deterministic Linux-compatible Swift tests
├── Renderer/
│   ├── JakeRenderer.swift             Metal pass scheduler
│   ├── RenderTargets.swift            offscreen HDR targets
│   ├── RenderTypes.swift              224-byte uniforms and sprite/particle layouts
│   ├── SceneSettings.swift            typed camera / optics settings
│   ├── TextureStore.swift             validated .jtex loader + mipmaps
│   └── Shaders/
│       ├── JakeShaders.metal           environment, shutter, spray, HDR → display, sharp glyphs
│       ├── SceneCore.inc               scene rays, road/wall materials, reflection sampling
│       └── ShaderTypes.h
├── Source/
│   ├── Vehicle/
│   │   ├── car_master.png              source archive; NOT PURE runtime actor
│   │   ├── rear_original.png           archival source pose reference
│   │   ├── registration.json           authoring/coverage registration
│   │   └── README.md                   source master identity
│   ├── Materials/recipe.json           deterministic road/wall/noise inputs
│   └── Typography/metrics.json         generator metadata; no external font files
├── Reference/
│   └── APPROVED.png                    REQUIRED 1774×887 visual gate + car-camera art source
├── Config/
│   ├── scene.json                      authoritative lens, wet-road and vehicle staging
│   └── render_graph.json               render pass data contract
├── Resources/
│   ├── Config/{scene,assets,glyphs}.json  runtime manifest (compiler refreshes)
│   └── Art/                            14 PNG + 14 JTX derived textures (compiler output, ignored)
├── tools/
│   ├── build_assets.py                 deterministic high-resolution asset pipeline
│   ├── build_app_icons.py              no-font app icon generator
│   ├── check_assets.py                 integrity, JTX, premultiplied alpha, glyph bounds
│   ├── check_project.py                plist/project/UTF-8 shader and camera contracts
│   ├── import_art_masters.py           one-command verified art ZIP import
│   ├── make_project.py                 deterministic Xcode project generation
│   └── requirements.txt                offline image-compiler libraries
├── JakeDriveMetal.xcodeproj/
├── README.md
├── START_HERE.md
├── DESIGN_MASTER.md
├── LAUNCH_PROMPT.md
├── SOURCE_RIGHTS.md
└── DELIVERY_STATUS.md
```

## Why no binary GPU caches in Git?
`Resources/Art/*.jtex` includes tens of MiB of RGBA16F cache bytes, which are deterministic build products. The compiler generates them from authentic master artwork and material/typography recipes. This keeps the public source Git tree reviewable and avoids duplicated, divergent caches.

The **three image masters** are *not* generable from procedural recipes. They are supplied exactly, with SHA-256 validation, in `JAKE_DRIVE_CINEMATIC_FINAL.zip`. The GitHub connection used here could write UTF-8 and Git objects but did not expose a reliable local-byte-to-Git blob transfer for large images; they have **not** been uploaded to this repo. Import them before compiling runtime art. Do not claim the repository is self-contained until they are committed.

## Last checked
- Swift core: 58 tests passed on Linux Swift 6.2.1, with the camera and car proxy aligned to the shot bible.
- Pixel asset pipeline: 11 JTX texture payloads, 15 glyphs and required-source hashes passed offline checks.
- Xcode project file: regenerated and passed `plutil -lint` on the available environment.
- Xcode/iPhone/real OBD: NOT RUN.
- Visual quality vs approved image: NOT ACCEPTED without native Metal evidence.


## 2026-10-28 · Canonical car pipeline
- `tools/build_road_car_from_approved.py` extracts only the right-side companion car from `Reference/APPROVED.png`; it writes the exact-pose normal/brake art, wheel wake, shadow, lamp emissions and `Source/Vehicle/runtime_registration.json`.
- `tools/build_assets.py` calls that single builder; the obsolete studio-angle runtime builder has been removed.
- The 14 runtime textures include `car_cruise`, `car_brake`, `car_wake`, `contact_shadow`, and rear-lamp light masks. The rest of the previously approved art is unchanged.
- `Renderer/JakeRenderer.swift` and `Renderer/Shaders/JakeShaders.metal` use identical `carRect` and contact anchors across cruise/brake. At 0 km/h, new photo wake is suppressed.
- Before shipping, inspect actual iOS Metal frames. A browser or Python composite does not count as native GPU acceptance.
