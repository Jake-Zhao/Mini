# Vehicle binary art masters

The GitHub connector used to reconstruct this repository cannot stream local container PNG bytes into GitHub's blob writer. Do not substitute lower-quality artwork.

The complete distribution archive `JAKE_DRIVE_CINEMATIC_FINAL.zip` contains:

| Path | SHA-256 |
|---|---|
| `Source/Vehicle/car_master.png` | `ca8006f4efe1ab3a0f40a4a72a7161eb0ef1744374dc2589756f6dc32aabc9ee` |
| `Source/Vehicle/rear_original.png` | `0377d987c9a3c66ed1b040e5b60ed96affcc4edaf8c650303698aa1c59e723d5` |
| `Reference/APPROVED.png` | `da8498daf0c5effce4c5654e34cec7de95c4b85af62f8a7eb25af608c276deed` |

Place those files at the exact paths before running `python3 tools/build_assets.py`.

- `rear_original.png` is the user-provided source/pose reference.
- `car_master.png` is the approved high-resolution transparent runtime-quality art master.
- `Reference/APPROVED.png` is the minimum visual benchmark and also supplies the locked brush character of 7/2.

CI deliberately reports asset compilation as SKIP when these masters are absent. Missing binary masters must never be silently replaced by generated placeholder car art.
