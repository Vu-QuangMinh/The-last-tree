"""Edge colour sampling (2026-11-11): the cut-out's edge pixels carry light specks from the background removal. Every pixel of the edge band (the outer BAND px of the shape) gets the colour of the nearest pixel
that lies INSIDE the shape (the inner side of the band): the rim is sampled from the wood itself. Alpha and size are not touched (no resize). Originals are copied to <folder>/_Redo/<name>_before_defringe.png first.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/defringe_edge.py <png> [<png> ...]"""
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

BAND = 3  # px


def defringe(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).copy()
    alpha = a[..., 3]
    solid = alpha > 200
    inner = ndi.binary_erosion(solid, iterations=BAND)
    w = inner.astype(float)
    own = a[..., :3].astype(float)
    # the rim's colour = the smooth average of the wood just inside the edge (no streaks: a blurred, weighted mean of the inner pixels)
    smp = np.stack([ndi.gaussian_filter(own[..., c] * w, 5) for c in range(3)], axis=2) / np.maximum(ndi.gaussian_filter(w, 5), 1e-4)[..., None]
    band = (alpha > 0) & ~inner
    # only the light specks: pixels brighter than the rim's colour are pulled to it; darker (natural shadow) ones stay
    bright = band & (own.mean(axis=2) > smp.mean(axis=2) + 12)
    out = a.copy()
    k = np.clip((own.mean(axis=2) - smp.mean(axis=2) - 12) / 40.0, 0.0, 1.0)[..., None]  # (the brighter the speck, the more it is pulled)
    mix = own * (1.0 - k) + smp * k
    out[bright, :3] = np.clip(mix[bright], 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), int(band.sum()), int(bright.sum())


def main():
    for p in sys.argv[1:]:
        back = os.path.join(os.path.dirname(p), "_Redo")
        os.makedirs(back, exist_ok=True)
        b = os.path.join(back, os.path.splitext(os.path.basename(p))[0].replace(" ", "_") + "_before_defringe.png")
        if not os.path.exists(b):
            shutil.copy2(p, b)
        im, n, nb = defringe(p)
        im.save(p)
        print(os.path.basename(p), "edge px", n, "of them lighter than the rim:", nb)


if __name__ == "__main__":
    main()
