# JAKE DRIVE · CINEMATIC PURE · FINAL DESIGN MASTER

## Product
JAKE DRIVE is Jake's iPhone-only landscape OBD cockpit for a green MINI F56. PURE is a real-time cinematic shot, not a conventional dashboard: centered hero speed, tiny gear badge, small green companion car on the lower-right roadway, wet arched tunnel, and dark binary rain derived from the UTF-8 bytes of “一路平安”.

## Locked visual hierarchy
1. Speed is the absolute hero and its visible bounds stay centered at (0.5W,0.5H).
2. Gear is small and subordinate at the hero lower-right.
3. Companion car is environmental narrative, never a second hero.
4. Binary rain is darker than all hero content and fades into the roadway.
5. No km/h label, tachometer, cards, Union Jack, large title, or persistent navigation on PURE.

Reference/APPROVED.png is the minimum art bar. The runtime may improve it, but may not degrade into cheap green lines, generic neon, or full-screen blur.

## Architecture
SwiftUI owns app shell and controls. MTKView owns the driving scene.

Render order:
1. scene + G-buffer
2. virtual-exposure integration
3. optional far-only DOF
4. binary rain / contact / car / proxy reflection / brake emission
5. GPU spray
6. environment-only bloom
7. tone map
8. native-resolution sharp HUD

HUD is never part of background blur, DOF, bloom, or temporal history.

## Camera / shot
- tanHalfVerticalFOV = 0.30 (~62° horizontal near 2:1)
- eye height = 1.22 m
- horizon = 0.61H
- tunnel half width = 6.5 m (art space)
- arch height = 4.2 m (art space)
- car staging = x 4.30 m, z 10.00 m, proxy width 2.35 m, anchorY 0.82
- shutter = 12.5 ms
- default temporal samples = 9; expensive reference = 33

These are authored shot coordinates, not surveyed road geometry.

## Wet-road model
Road material supplies base color, normal XY, roughness, and wetness. Reflection is recomputed at each exposure sample, uses Fresnel and roughness spread, and receives sparse micro-glints. There is no single static reflection bitmap stretched with speed.

Pseudo:
```
N = normalFromMaterial()
V = -cameraRay
R = reflect(cameraRay, N)
F0 = mix(0.04, 0.02037, wetness)
F = F0 + (1-F0) * pow(1-dot(N,V), 5)
reflection = integrateRoughRays(R, roughness)
road = (1-F)*diffuse + F*reflection*wetnessWeight + microGlints
```

## Time / motion
```
mps = validSpeedKph / 3.6
deltaMetres = mps * dt
travelMetres += deltaMetres
shutterDistance = mps * 0.0125
```
0 km/h freezes decorative scene travel, rain drift, spray, and speed streaks. 100 km/h has exactly five times the distance/exposure displacement of 20 km/h over equal time. Frame rate never changes the virtual shutter length.

## Car
For PURE runtime, **the only source of companion-car camera pose is the vehicle already inside `Reference/APPROVED.png`**, the same approved wet-road shot. `tools/build_road_car_from_approved.py` extracts a fixed crop and creates a 1050×655 linear-premultiplied sprite. The distinct `car_cruise` and `car_brake` differ only within two tail-lamp masks; body pixels, wheel placement, license plate, spoiler and alpha are identical. The wheel-wake image is cropped from this very same rainy-road source and only rendered when speed > 0. The independent `Source/Vehicle/car_master.png` and original rear photo are retained for provenance and are no longer used in the PURE runtime because their camera angle does not share the approved road shot.

The car is still a fixed-view photographic impostor, not a 3D mesh. Its projection is calibrated to a scene contact anchor (x=4.3 m, z=10.0 m, proxyWidth=2.35 m, contactY=0.82), with explicit front/rear wheel footprints. The ground shadow and reflection follow the wheel-contact line, and camera-matched photographic water plus a limited GPU wake are speed-controlled. This is a constrained cinematic composite, NOT a complete physically based fluid simulator or full car geometry. The final native Metal output must still be inspected before visual acceptance.

## Hero glyphs
There is no system-font choice for the speed. The JAKE PERFORMANCE BRUSH system covers 0–9, D/N/P/R and dash. 7 and 2 are extracted from the approved baseline's own painted strokes; remaining glyphs use the same italic direction, stroke mass, distressed edge logic, ivory surface and green reflected-light treatment. Runtime metrics are fixed in Resources/Config/glyphs.json.

## Binary rain
The source phrase is exactly “一路平安”. Its UTF-8 bytes are converted MSB-first to 96 bits. Only 0 and 1 are rendered. At least two depth layers use different density/speed/alpha, with downward fade and additional hero-center attenuation.

## G-buffer diagnostics
Scene outputs:
- scene HDR
- motionDepth: shutter-interval UV displacement / axial depth / surface id
- material: roughness / wetness / object id

Debug UI exposes Beauty, Depth, Motion, Roughness, Wetness and ObjectID. If a road highlight looks wrong, diagnose its material channel before changing bloom.

## Data truth
Telemetry readings include origin, epoch, monotonic timestamp, quality and TTL. Exact Dn and brake state are shown only from trusted sources. Never infer D3 from speed/RPM or infer brake from deceleration. Standard Mode 01 is implemented first; supported PID bitmaps are discovered per ECU.

## Quality degradation
Thermal/low-power degradation order:
1. lower background internal resolution
2. lower exposure/blur sample cost
3. lower particle count
4. disable bloom
5. 60→30 fps
HUD remains full drawable resolution.

## Visual gate
Before BLE integration, native output must pass:
- 0 / 20 / 72 / 88 / 100 / 128
- D / D1…D8 / dash
- brake off/on
- all six debug views
- car silhouette/contact inspection
- 0 motion freeze and stronger 100-vs-20 motion
- real drawable capture compared with Reference/APPROVED.png

Tests passing is not visual acceptance. Do not claim final visual quality until native iPhone output is reviewed.
