"""The Puppet Stage main menu title "Who is The Puppet": docs/title_reference.png (the user's lettering: black letters on grey) -> every letter becomes its own
cut-out wooden piece (painted with milk paint on a wood grain, a dark walnut rim, paint worn off at the edges, scratches, a soft drop shadow) ->
assets/Puppet/UI/Banners/game_title.png. The letters keep the reference's shapes and places; each is turned a hair, like hand-cut work.
Run: python tools/make_game_title.py"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "..", "docs", "title_reference.png")
OUT = os.path.join(AP.PUPPET, "UI", "Banners", "game_title.png")
S = 2  # work at twice the size
rng = np.random.default_rng(7)

OCHRE = np.array([0.84, 0.60, 0.22])
RUST = np.array([0.64, 0.24, 0.16])
CREAM = np.array([0.93, 0.85, 0.65])
RAW = np.array([0.66, 0.46, 0.27])  # bare wood where the paint is worn
WALNUT = np.array([0.20, 0.11, 0.06])

ref = Image.open(REF).convert("L")
a = np.clip((96 - np.array(ref).astype(float)) / 96.0, 0, 1)
a = np.array(Image.fromarray((a * 255).astype(np.uint8)).resize((ref.width * S, ref.height * S), Image.LANCZOS)).astype(float) / 255.0
H, W = a.shape
lab, n = ndi.label(ndi.binary_dilation(a > 0.25, iterations=3 * S))
boxes = ndi.find_objects(lab)
assert n == 14, n
order = sorted(range(n), key=lambda i: (boxes[i][0].start // (130 * S), boxes[i][1].start))


def paint_of(i):
    sl = boxes[i]
    h = sl[0].stop - sl[0].start
    if h > 250 * S:  # the two big T's
        return RUST
    if sl[0].start < 200 * S:  # "WHO IS"
        return OCHRE
    return CREAM


def grain(shape, seed):
    r = np.random.default_rng(seed)
    h, w = shape
    n1 = ndi.gaussian_filter(r.standard_normal((h, w)), (2.0, 60.0))
    n1 /= n1.std() + 1e-6
    n2 = ndi.gaussian_filter(r.standard_normal((h, w)), (0.8, 18.0))
    n2 /= n2.std() + 1e-6
    yy = np.arange(h)[:, None] + r.uniform(0, 400)
    rings = 0.5 + 0.5 * np.sin(yy * 0.12 + n1 * 2.2)
    return np.clip(0.34 * rings + 0.14 * n2 + 0.1 * n1 + 0.38, 0, 1)


canvas = np.zeros((H + 60 * S, W + 60 * S, 4))
shadow = np.zeros((H + 60 * S, W + 60 * S))
pad = 30 * S
for idx, i in enumerate(order):
    sl = boxes[i]
    y0, y1, x0, x1 = max(0, sl[0].start - 8), sl[0].stop + 8, max(0, sl[1].start - 8), sl[1].stop + 8
    m = np.where(ndi.binary_dilation(lab[y0:y1, x0:x1] == i + 1, iterations=3 * S), a[y0:y1, x0:x1], 0.0)
    m = np.clip(m * 1.1, 0, 1)
    h, w = m.shape
    inside = m > 0.5
    dist = ndi.distance_transform_edt(inside)
    soft = ndi.gaussian_filter(m, 2.2 * S)
    gy, gx = np.gradient(soft)
    light = np.clip(0.5 + (-gx - gy) * 2.6 * S, 0.0, 1.0)  # (light from the upper left: edges facing it are bright)
    g = grain((h, w), 100 + idx)
    wood = RAW[None, None, :] * (0.62 + 0.55 * g[:, :, None])
    # paint: milk paint worn thin at the edges and by scratches, blotchy
    blot = ndi.gaussian_filter(rng.standard_normal((h, w)), 7 * S)
    blot /= blot.std() + 1e-6
    worn = np.clip(1.0 - (dist - 2.0 * S) / (7.0 * S), 0, 1) * (0.45 + 0.35 * blot) + 0.12 * np.clip(blot - 1.2, 0, 1)
    scratch = np.zeros((h, w))
    for _ in range(14):
        sy, sx = rng.integers(0, h), rng.integers(0, w)
        ang = rng.uniform(-0.5, 0.5)
        ln = rng.integers(10 * S, 40 * S)
        for t in range(ln):
            yy, xx = int(sy + np.sin(ang) * t), int(sx + np.cos(ang) * t)
            if 0 <= yy < h and 0 <= xx < w:
                scratch[yy, xx] = 1.0
    scratch = ndi.gaussian_filter(scratch, 0.7 * S) > 0.25
    paint_amt = np.clip(1.0 - worn - 0.9 * scratch, 0, 1)
    col = paint_of(i)
    pc = col[None, None, :] * (0.88 + 0.22 * g[:, :, None])
    face = wood * (1 - paint_amt[:, :, None]) + pc * paint_amt[:, :, None]
    # the rim: a dark walnut band along the edge (the wood's thickness), the face inside it
    rim = np.clip(1.0 - (dist - 0.6 * S) / (3.6 * S), 0, 1)
    rimc = WALNUT[None, None, :] * (0.7 + 0.6 * g[:, :, None])
    piece = face * (1 - rim[:, :, None]) + rimc * rim[:, :, None]
    piece *= (0.74 + 0.5 * light)[:, :, None]
    # tiny chips: a few dark specks on the face
    specks = (ndi.gaussian_filter(rng.standard_normal((h, w)), 1.0 * S) > 2.1 * 0.18)
    piece[specks & inside] *= 0.8
    rgba = np.dstack([np.clip(piece, 0, 1), m])
    # a hair of turn and shift, like hand-cut pieces
    im = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").rotate(rng.uniform(-0.9, 0.9), resample=Image.BICUBIC, expand=True)
    arr = np.array(im).astype(float) / 255.0
    oy = pad + y0 - (arr.shape[0] - h) // 2 + int(rng.integers(-2, 3))
    ox = pad + x0 - (arr.shape[1] - w) // 2 + int(rng.integers(-2, 3))
    region = canvas[oy:oy + arr.shape[0], ox:ox + arr.shape[1]]
    al = arr[:, :, 3:4]
    region[:, :, :3] = region[:, :, :3] * (1 - al) + arr[:, :, :3] * al
    region[:, :, 3:4] = np.maximum(region[:, :, 3:4], al)
    shadow[oy:oy + arr.shape[0], ox:ox + arr.shape[1]] = np.maximum(shadow[oy:oy + arr.shape[0], ox:ox + arr.shape[1]], arr[:, :, 3])

# the drop shadow under the whole title (the pieces stand a little off the board)
sh = ndi.gaussian_filter(shadow, 5 * S)
sh = np.roll(np.roll(sh, 7 * S, axis=0), 5 * S, axis=1) * 0.55
out = np.zeros_like(canvas)
out[:, :, :3] = 0.0
out[:, :, 3] = sh
al = canvas[:, :, 3:4]
res = np.zeros_like(canvas)
res[:, :, :3] = canvas[:, :, :3] * al + out[:, :, :3] * (1 - al)
res[:, :, 3:4] = al + (1 - al) * out[:, :, 3:4]
img = Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), "RGBA")
img = img.crop(img.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
img = img.resize((img.width // S, img.height // S), Image.LANCZOS)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print("wrote", OUT, img.size)
