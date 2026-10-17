"""Act 1 enemy redo (2026-10-17): ImageSet's "Act 1 Enemies Fix" pictures -> assets/Puppet/Enemies/Act1/<enemy id>.png at FULL size.

The white background is cut with Tachnen's BiRefNet (run this with Tachnen's python), the picture is trimmed and put on a square canvas with its
feet on the bottom edge (the same shape import_puppet_enemies.py makes, but NOT scaled down). The cut picture is also kept in
Enemies/_Source/Act1/Puppet <name>.png (the one it replaces becomes "... (old).png").
The Invoker's three orbs are cut off his hand and saved as Act1/invoker/orb_<fire|water|wind>.png; their places (fractions of the square) are printed
and live in Creature.FLOATERS, where they hover over his palm.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_act1_fix.py [name ...]   (then Godot --headless --editor --quit once)"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

TACHNEN = r"D:\GitHub Projects\Tachnen"
sys.path.insert(0, TACHNEN)
import numpy as np
from PIL import Image
from scipy.ndimage import label

RAW = r"D:\GitHub Projects\ImageSet\output\Act 1 Enemies Fix"
OUT = os.path.join(AP.PUPPET, "Enemies", "Act1")
SRC = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act1")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
IDS = {"Forge Spirit": "forge_spirit", "Greenseer": "greenseer", "Hush Moth": "hush_moth", "Invoker": "invoker", "Mirror Fairy": "mirror_fairy",
       "Rolling Bear": "rolling_bear", "Enraged Rolling Bear": "enraged_bear", "Tomato Knight": "tomato_knight", "Triplet Fire": "triplet_fire",
       "Triplet Water": "triplet_water", "Triplet Air": "triplet_air", "Winged Tortoise": "winged_tortoise", "Yeti": "yeti"}
# the Invoker's orbs in the raw picture (fractions of it): a box that holds the three of them, away from his hand
ORB_BOX = (0.70, 0.33, 0.90, 0.50)
ORB_KINDS = ["fire", "water", "wind"]  # orange, blue, green
_proc = None


def newest(name):
    files = [f for f in glob.glob(os.path.join(glob.escape(RAW), "Puppet " + glob.escape(name) + "_*.png"))
             if os.path.basename(f)[len("Puppet " + name) + 1:-4].replace("_", "").isdigit()]
    return max(files, key=os.path.getmtime) if files else None


def cut(path):
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    return _proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)  # (not trimmed here: the Invoker needs the raw frame to find his orbs)


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    px, py = (side - im.width) // 2, side - im.height - int(side * pad * 0.5)
    c.alpha_composite(im, (px, py))
    return c, px, py


def take_orbs(im):
    """(body without the orbs, [orb picture, ...] in ORB_KINDS order, [(x, y) of each orb's centre in the raw frame])"""
    a = np.array(im)
    W, H = im.size
    mask = a[:, :, 3] > 8
    lab, n = label(mask)
    x0, y0, x1, y1 = ORB_BOX[0] * W, ORB_BOX[1] * H, ORB_BOX[2] * W, ORB_BOX[3] * H
    found = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(xs) < 150 or len(xs) > 20000:
            continue
        cx, cy = xs.mean(), ys.mean()
        if x0 <= cx <= x1 and y0 <= cy <= y1 and xs.min() > x0 - 40 and xs.max() < x1 + 40 and ys.max() < y1 + 40:
            found.append((i, cx, cy, xs.min(), ys.min(), xs.max(), ys.max()))
    if len(found) != 3:
        raise SystemExit("expected 3 separate orbs, found %d: %s" % (len(found), [(round(f[1]), round(f[2])) for f in found]))
    # orange, blue, green by colour of each blob's centre
    def kind(f):
        r, g, b = a[int(f[2]), int(f[1]), :3]
        return "fire" if r > b and r > g else ("water" if b > g else "wind")
    by_kind = {kind(f): f for f in found}
    if sorted(by_kind) != sorted(ORB_KINDS):
        raise SystemExit("could not tell the orbs apart by colour: %s" % [kind(f) for f in found])
    orbs, centres = [], []
    body = a.copy()
    for k in ORB_KINDS:
        i, cx, cy, xa, ya, xb, yb = by_kind[k]
        m = lab == i
        piece = a.copy()
        piece[~m, 3] = 0
        orbs.append(Image.fromarray(piece, "RGBA").crop((xa, ya, xb + 1, yb + 1)))
        centres.append((cx, cy))
        body[m, 3] = 0
    return Image.fromarray(body, "RGBA"), orbs, centres


def main():
    names = sys.argv[1:] or list(IDS)
    os.makedirs(SRC, exist_ok=True)
    for name in names:
        f = newest(name)
        if f is None:
            print("  MISSING raw picture for", name)
            continue
        im = cut(f)
        eid = IDS[name]
        if name == "Invoker":
            im, orbs, centres = take_orbs(im)
            bbox = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            body = im.crop(bbox)
            sq, px, py = square(body)
            ox, oy = px - bbox[0], py - bbox[1]  # (raw frame -> square)
            os.makedirs(os.path.join(OUT, "invoker"), exist_ok=True)
            for k, o, (cx, cy) in zip(ORB_KINDS, orbs, centres):
                o.save(os.path.join(OUT, "invoker", "orb_%s.png" % k))
                print("  invoker orb %-5s %dx%d  centre in the square: (%.4f, %.4f)" % (k, o.width, o.height, (cx + ox) / sq.width, (cy + oy) / sq.height))
        else:
            sq = square(trim(im))[0]
        sq.save(os.path.join(OUT, eid + ".png"))
        keep = os.path.join(SRC, "Puppet " + name + ".png")
        if os.path.exists(keep):
            os.replace(keep, keep[:-4] + " (old).png")
        trim(im).save(keep)
        print("  %-22s -> %s.png  %dx%d  (%s)" % (name, eid, sq.width, sq.height, os.path.basename(f)))


if __name__ == "__main__":
    main()
