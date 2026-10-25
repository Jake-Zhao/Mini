# Luna implementation prompt

Work directly in this repository. Do not create a new parallel project and do not import any older JAKE DRIVE package.

Read `START_HERE.md` and follow its reading order. Treat `Reference/APPROVED.png` as the minimum visual-quality benchmark, but never use it as a runtime full-screen background.

Your first milestone is the cinematic PURE Metal renderer. Do not start BLE integration until the PURE visual baseline is objectively reviewed.

You must use the checked-in source assets and generation pipeline. Do not guess a replacement speed font, vehicle silhouette, material color, camera composition or animation hierarchy.

Mandatory behavior:
- landscape only
- centered hero speed
- small gear lower-right of speed
- dark upper-half binary rain encoded from `一路平安`
- small green companion car grounded in the right-lower road scene
- no km/h, tachometer, flag, large title or permanent navigation in PURE
- background motion freezes at 0 km/h
- higher speed increases actual spatial travel/exposure blur, not arbitrary CSS-like animation speed
- hero speed and gear remain razor-sharp after all background post-processing
- brake and exact gear stay unknown unless supplied by a trusted telemetry source

Use `docs/11_RENDER_PASSES.md` as the render graph contract and `docs/12_LUNA_EXECUTION.md` as the execution/acceptance contract.
