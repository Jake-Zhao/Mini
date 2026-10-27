# Vehicle source assets and camera contract

## Canonical PURE production vehicle
**The running iPhone PURE companion car is now extracted from `Reference/APPROVED.png` itself** using `tools/build_road_car_from_approved.py`. This is intentional: a separately photographed/generative car has a different perspective than the approved wet roadway. Both normal and braking states use the **same approved-shot crop**, registered tire contacts, size and camera pose.

The extractor uses:
- approved 1774×887 image, crop `(1300,480,1725,745)`;
- sprite size `1050×655`;
- tire road contacts in approved coordinates `(1399,672)`, `(1501,697)`, `(1701,693)`;
- two tail-lamp-only masks; outside them every RGB pixel in the two states is identical;
- separate photographic wake `car_wake`, a road footprint mask `contact_shadow`, and separate emissive/halo assets.

The renderer selects `car_brake` **only** from a valid independent brake state. Spray scales with actual speed and freezes at zero. Under no circumstances draw both cars at once or change pose while braking.

## Archived original photos (kept, not running PURE)
- `Source/Vehicle/rear_original.png`: 676×451 user-supplied pose reference (copyright not separately verified).
- `Source/Vehicle/car_master.png`: 2172×724 transparent stand-alone studio-like visual master. Kept for provenance and other future UIs, **not** the camera-matched PURE runtime texture. Do not revive it because its angle/light does not share the approved tunnel camera.

The old `registration.json` documents this earlier source photo; `runtime_registration.json` is the current produced camera source and footprint. Use **runtime_registration** for runtime placement.

## Rebuild (no guessing)
```sh
python3 -m pip install -r tools/requirements.txt
python3 tools/build_assets.py
python3 tools/check_assets.py
```

Images generated into `Resources/Art/` are: `car_body.png`, `car_cruise.png`, `car_brake.png`, `car_wake.png`, `brake_emission.png`, `brake_halo.png`, and `contact_shadow.png`, with matching JTX2 runtime textures. `.github/workflows/publish-companion-art.yml` commits inspectable PNGs automatically.

## Unchanged high-res master identifiers
`car_master.png` SHA-256: `ca8006f4efe1ab3a0f40a4a72a7161eb0ef1744374dc2589756f6dc32aabc9ee`

`rear_original.png` SHA-256: `0377d987c9a3c66ed1b040e5b60ed96affcc4edaf8c650303698aa1c59e723d5`

`Reference/APPROVED.png` SHA-256: `da8498daf0c5effce4c5654e34cec7de95c4b85af62f8a7eb25af608c276deed`
