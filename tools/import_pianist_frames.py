r"""2026-11-10: the 12 frames of the Pianist's right hand (the user's hand-edited cut-outs, 1024 px, in right_hand_frames/source/No-piano) -> game sprites.
  1. registered: each frame is shifted (whole pixels) so that its STOOL lies exactly on the stool of frame 1 (the stool never moves, so the frames then lie on each other and
     swapping between them does not make the figure jump);
  2. cleaned: below the coat tails (y >= TAIL_Y) only what frame 1 has there is kept (stool legs): shoes and stray legs left in some frames (6, 12) are erased, so that the legs
     are the same in every frame (the rig draws the hanging legs itself);
  3. cropped: ALL frames to one common box (the union of their opaque pixels), so every sprite has the same size and the same origin.
Writes assets/Puppet/Enemies/Act2/pianist/back/rh_01..12.png and prints the numbers the rig needs (crop box, hat centre, fingertips, stool).
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_pianist_frames.py"""
import json
import os
import sys

import numpy as np
from PIL import Image

D = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
SRC = os.path.join(D, "right_hand_frames", "source", "No-piano")
OUT = os.path.join(D, "back")
TAIL_Y = 872
STOOL = (slice(900, 1000), slice(330, 420))  # (rows, columns): the stool's legs, left of the coat


def shift_of(ref, m):
    """(dx, dy) to apply to `m` so that it lies on `ref`: the best of all whole-pixel shifts within +-6 px (sum of differences of the stool-legs mask)."""
    best = None
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            d = np.abs(ref - np.roll(np.roll(m, dy, 0), dx, 1)).sum()
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best[1], best[2]


def moved(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, xs = slice(max(0, dy), min(h, h + dy)), slice(max(0, dx), min(w, w + dx))
    yd, xd = slice(max(0, -dy), min(h, h - dy)), slice(max(0, -dx), min(w, w - dx))
    out[ys, xs] = a[yd, xd]
    return out


frames = [np.array(Image.open(os.path.join(SRC, "frame_%02d.png" % k)).convert("RGBA")) for k in range(1, 13)]
ref = (frames[0][:, :, 3] > 128)[STOOL].astype(float)
reg = []
for k, a in enumerate(frames, 1):
    dx, dy = shift_of(ref, (a[:, :, 3] > 128)[STOOL].astype(float))
    reg.append(moved(a, dx, dy))
    print("frame %02d shift (%d, %d)" % (k, dx, dy))
base_alpha = reg[0][:, :, 3] > 128
for k, a in enumerate(reg):
    low = np.zeros(a.shape[:2], bool)
    low[TAIL_Y:, :] = True
    a[low & ~base_alpha] = 0  # (what frame 1 does not have down there is erased)
boxes = [Image.fromarray(a).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() for a in reg]
x0 = min(b[0] for b in boxes)
y0 = min(b[1] for b in boxes)
x1 = max(b[2] for b in boxes)
y1 = max(b[3] for b in boxes)
print("common crop box", (x0, y0, x1, y1), "size", (x1 - x0, y1 - y0))
info = []
for k, a in enumerate(reg, 1):
    im = Image.fromarray(a).crop((x0, y0, x1, y1))
    try:  # (no white outline: needs scipy; if this python has none, run  python312 tools/alpha_bleed.py back/rh_*.png  afterwards)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from alpha_bleed import bleed
        im = bleed(im)
    except ImportError:
        print("alpha_bleed skipped (no scipy here): run tools/alpha_bleed.py on rh_*.png with a python that has scipy")
    im.save(os.path.join(OUT, "rh_%02d.png" % k))
    al = np.array(im)[:, :, 3] > 128
    hat = al[:60]
    hx = np.where(hat.any(0))[0]
    ys, xs = np.where(al[:, 200:])  # (the arm's tip: the rightmost opaque pixel)
    tip = int(xs.max()) + 200
    tip_y = int(np.median(ys[xs == xs.max()]))
    info.append({"hat_cx": float((hx.min() + hx.max()) / 2), "tip": [tip, tip_y]})
    print("rh_%02d  hat centre x %.1f  fingertip (%d, %d)" % (k, info[-1]["hat_cx"], tip, tip_y))
bw = np.array(Image.open(os.path.join(OUT, "rh_01.png")))[:, :, 3] > 128
rows = np.where(bw[:, :].any(1))[0]
print("sprite size", Image.open(os.path.join(OUT, "rh_01.png")).size, "opaque rows", rows.min(), rows.max())
json.dump({"crop": [x0, y0, x1, y1], "frames": info}, open(os.path.join(OUT, "rh_frames.json"), "w"), indent=1)
