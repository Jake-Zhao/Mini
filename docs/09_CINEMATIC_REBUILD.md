# 09 · Cinematic Rebuild Plan

## Objective
PURE is not a conventional dashboard. It is a fixed-camera cinematic cockpit shot whose primary subject is the live vehicle speed. Every visual system exists to support that shot.

## Why the previous visual approach failed
1. Vehicle, road, reflections and motion did not share one camera/space.
2. The vehicle was treated as a screen-space sticker instead of a grounded scene object.
3. Motion blur was decorative rather than exposure-based.
4. Wet-road reflections were duplicated as art plus procedural effects.
5. Binary rain was treated as a foreground effect instead of atmospheric depth.
6. The speed glyph quality was not guaranteed for every runtime number.

## Reconstruction strategy
### A. Shot first
Lock camera, horizon, vanishing point, road plane, vehicle anchor and hero HUD safe area before adding effects.

### B. Material truth
Every surface channel has one responsibility:
- base color = intrinsic color only
- normal = micro-surface direction
- roughness = reflection spread
- wetness = blend toward smoother / darker wet response
- emission = actual luminous sources only

### C. Temporal truth
Use meters, seconds and exposure duration. Do not let frame rate change perceived travel distance or blur length.

### D. Layer truth
Background and scene passes may blur. The hero speed and gear are composited after all cinematic post effects and must remain razor sharp.

## Final rendering hierarchy
1. Tunnel / road geometry
2. Road material and wet response
3. Environmental practical lights
4. Companion car + ground contact + reflection proxy
5. Binary rain depth field
6. Water spray / atmospheric particles
7. Exposure motion integration
8. Controlled bloom + tone map
9. Speed streak accent
10. Hero digits and gear

## Mandatory visual bar
`Reference/APPROVED.png` is the minimum bar for composition, hierarchy, atmosphere and perceived quality. Runtime output may diverge only when the result is demonstrably better.
