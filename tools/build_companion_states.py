#!/usr/bin/env python3
"""Generate two perfectly registered companion-car states from ONE source master.

Invoked by tools/build_assets.py after car_body and brake_emission are generated.
The car angle, silhouette, wheel placement, spoiler and license plate must be
bit-identical across states. Only painted pixels within the red tail-light mask
change. Both sprites are sRGB/straight-alpha source PNGs; pack() converts to
linear-premultiplied JTX2 textures for Metal.
"""
from pathlib import Path
import numpy as np
from PIL import Image


def build(art_directory: str | Path) -> None:
    art = Path(art_directory)
    base = np.asarray(Image.open(art / 'car_body.png').convert('RGBA'), dtype=np.uint8).copy()
    mask_image = np.asarray(Image.open(art / 'brake_emission.png').convert('RGBA'), dtype=np.uint8)
    if base.shape != mask_image.shape:
        raise ValueError(f'car_body/brake_emission dimensions disagree: {base.shape} / {mask_image.shape}')
    mask = mask_image[..., 3].astype(np.float32) / 255.0
    if np.count_nonzero(mask > 0.04) <= 300:
        raise ValueError('Brake-light mask empty; refusing placeholder variants')
    mask = np.minimum(mask, base[..., 3].astype(np.float32) / 255.0)
    rgb = base[..., :3].astype(np.float32) / 255.0

    # sRGB -> linear light before adjusting luminous material.
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)**2.4)
    weight = np.clip(mask * 1.35, 0.0, 1.0)[..., None]
    cruise, brake = linear.copy(), linear.copy()
    cruise[..., 0:1] *= 1.0 - 0.36 * weight
    cruise[..., 1:2] *= 1.0 - 0.18 * weight
    cruise[..., 2:3] *= 1.0 - 0.18 * weight
    brake[..., 0:1] = np.clip(brake[..., 0:1] * (1.0 + 0.42 * weight) + 0.25 * weight, 0, 1)
    brake[..., 1:2] *= 1.0 - 0.04 * weight
    brake[..., 2:3] *= 1.0 - 0.04 * weight

    def encode(arr):
        arr = np.clip(arr, 0, 1)
        srgb = np.where(arr <= 0.0031308, arr * 12.92, 1.055 * np.power(arr, 1 / 2.4) - 0.055)
        out = base.copy()
        out[..., :3] = np.clip(srgb * 255 + 0.5, 0, 255).astype(np.uint8)
        # No differences outside the light mask, not even antialias edge pixels.
        out[mask <= 0] = base[mask <= 0]
        out[..., 3] = base[..., 3]
        return out

    off, on = encode(cruise), encode(brake)
    assert np.array_equal(off[..., 3], on[..., 3])
    assert np.array_equal(off[mask <= 0], on[mask <= 0])
    changed = (off[..., :3] != on[..., :3]).any(axis=2)
    assert np.count_nonzero(changed) > 300
    assert np.all(mask[changed] > 0), 'Difference escaped the tail-lamp mask'
    for filename, arr in [('car_cruise.png', off), ('car_brake.png', on)]:
        Image.fromarray(arr, 'RGBA').save(art / filename, optimize=True)
    print('Companion states: identical pose, alpha and body; tail-lamp pixels changed:', int(np.count_nonzero(changed)))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--art', type=Path, default=Path(__file__).resolve().parents[1] / 'Resources/Art')
    args = parser.parse_args()
    build(args.art)
