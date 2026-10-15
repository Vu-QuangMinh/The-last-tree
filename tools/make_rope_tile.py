"""Raw ImageSet picture of a straight vertical rope -> assets/Puppet/Map/map_rope.png, a tile that repeats seamlessly along its length (the game tiles it along
every rope, MapScreen.MapRope). The background is cut out with the Tachnen tool's BiRefNet, the twist's period is found by self-similarity down the picture,
one period is kept and its ends are blended so the join does not show. Nothing is resized.
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_rope_tile.py <raw picture> [out.png]"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_puppet_ui as ui

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "Puppet", "Map", "map_rope.png")
im = ui.cut(src)
a = np.asarray(im.getchannel("A"), dtype=np.float32) / 255.0
cols = np.where(a.mean(axis=0) > 0.25)[0]  # the rope's core: columns that are mostly rope (drops the loose fibres)
x0, x1 = int(cols.min()), int(cols.max()) + 1
im = im.crop((x0, 0, x1, im.height))
rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
h = rgb.shape[0]
lum = rgb.mean(axis=2)
win = h // 4
best = None
for p in range(int(h * 0.08), int(h * 0.4)):  # candidate period, px
    for y0 in range(0, h - p - win, max(1, h // 40)):
        d = np.abs(lum[y0:y0 + win] - lum[y0 + p:y0 + p + win]).mean()
        if best is None or d < best[0]:
            best = (d, p, y0)
d, p, y0 = best
blend = max(8, p // 6)
arr = np.asarray(im, dtype=np.float32)
tile = arr[y0:y0 + p].copy()
if y0 + p + blend <= h:
    # the first rows of the tile become a mix of themselves and what follows the tile: so the last row runs straight into the first
    for i in range(blend):
        w = i / blend
        tile[i] = arr[y0 + p + i] * (1.0 - w) + arr[y0 + i] * w
Image.fromarray(tile.astype(np.uint8), "RGBA").save(out)
print("period %d px, seam error %.2f, tile %dx%d -> %s" % (p, d, tile.shape[1], tile.shape[0], out))
