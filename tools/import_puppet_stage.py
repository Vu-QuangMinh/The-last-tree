"""Puppet Stage pictures: assets/Puppet/Stage/Act<n>/_Source/*.png -> assets/Puppet/Stage/Act<n>/{Backdrop,Wall,Floor,Ceiling,Props}/ in the shape the stage needs (n = the first argument, 1 by default).
 All side (left wall | back wall | right wall, unfolded; the newest "All side*.png") -> cut into back_wall.png, wall_left.png, wall_right.png
 Floor        -> floor.png        the whole picture            Lower Floor -> lower_floor.png   (tilted like the floor, below the front wall)
 Wall (4350x395) -> front_wall.png  1920 px wide, upright under the floor
 Ceiling (1920x146) -> ceiling_overlay.png  NOT tilted or stretched: laid over the top of the screen
 Cloud / Tree / Mountain / Sun / Hanging Sign -> props/<name>.png   trimmed, at most 900 px;   Bush (a sheet of 6) -> props/bush_1..6.png
Run: python tools/import_puppet_stage.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import glob
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP
ACT = int(sys.argv[1]) if len(sys.argv) > 1 else 1  # which act's stage pictures to cut
SRC = os.path.join(AP.PUPPET, "Stage", "Act%d" % ACT, "_Source")
STAGE = os.path.join(AP.PUPPET, "Stage", "Act%d" % ACT)
OUT = STAGE
PROPS = os.path.join(STAGE, "Props")
os.makedirs(PROPS, exist_ok=True)
for _d in ("Backdrop", "Wall", "Floor", "Ceiling"):
    os.makedirs(os.path.join(STAGE, _d), exist_ok=True)
WHERE = {"back_wall.png": "Backdrop", "wall_left.png": "Wall", "wall_right.png": "Wall", "front_wall.png": "Wall", "floor.png": "Floor", "lower_floor.png": "Floor", "ceiling_overlay.png": "Ceiling"}


def find(prefix):
    f = glob.glob(os.path.join(SRC, prefix + "*.png"))
    assert f, prefix
    return Image.open(max(f, key=os.path.getmtime))  # (the newest one: "All side 2.png" after "All side.png")


def _fix_edge(im):
    """The sheets end in a stray row of white pixels (one pixel too tall a crop): it showed as a thin white gap between the backdrop and the floor.
    A last row that is mostly pure white is replaced by the row above it."""
    im = im.convert("RGB")
    w, h = im.size
    last = im.crop((0, h - 1, w, h))
    white = sum(1 for px in last.getdata() if px == (255, 255, 255))
    if white > w * 0.3:
        im.paste(im.crop((0, h - 2, w, h - 1)), (0, h - 1))
    return im


def save(im, name, size=None):
    if name in ("back_wall.png", "wall_left.png", "wall_right.png"):
        im = _fix_edge(im)
    if size:
        im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(OUT, WHERE.get(name, ""), name))
    print("  %-28s %s" % (name, im.size))


# The three walls unfolded in one picture (All side*.png, the newest): left wall | back wall | right wall, as much width as the perspective needs.
# Units are the back wall's own pixels (the back plane, scale 1) from the stage's perspective points (default_verts in
# scripts/ui/puppet_stage.gd): the back wall is as wide and as high as its quad; a side wall is as deep as the floor, which is what the floor
# picture says (its aspect applied to the back wall's width). The back wall takes the picture's whole height; every piece has the same scale,
# so nothing is enlarged or squeezed, and the three keep one horizon. The width the picture has beyond what is needed is trimmed equally from
# both ends.
gd = open(os.path.join(HERE, "..", "scripts", "ui", "puppet_stage.gd"), encoding="utf-8").read()
v = {k: (float(x), float(y)) for k, x, y in re.findall(r'"(back_(?:top|bot)_[lr])": Vector2\((-?[\d.]+), (-?[\d.]+)\)', gd)}
BACK_W = v["back_bot_r"][0] - v["back_bot_l"][0]
HEIGHT = v["back_bot_l"][1] - v["back_top_l"][1]
fl = find("Floor")
DEPTH = BACK_W * fl.height / fl.width
allp = find("All side").convert("RGB")
k = allp.height / HEIGHT  # picture pixels per unit
side_w, back_w = round(DEPTH * k), round(BACK_W * k)
need = 2 * side_w + back_w
print("  perspective: back wall %.0f x %.0f, side depth %.0f units; scale %.3f px/unit; needs %d of %d px wide" % (BACK_W, HEIGHT, DEPTH, k, need, allp.width))
if need <= allp.width:
    x0 = (allp.width - need) // 2
    save(allp.crop((x0 + side_w, 0, x0 + side_w + back_w, allp.height)), "back_wall.png")
    save(allp.crop((x0, 0, x0 + side_w, allp.height)), "wall_left.png")
    save(allp.crop((x0 + side_w + back_w, 0, x0 + need, allp.height)), "wall_right.png")
else:
    # a single scene (Act 2's swamp is one 2048 x 2048 picture, not an unfolded panorama): it is the back wall (the bottom part of it, as high as
    # the wall's shape asks for), and each side wall is the mirror image of the strip of it that lies next to that side, so the seams are
    # continuous and the horizon stays one line.
    print("  (a single scene, not a panorama: the side walls are mirrored from the back wall)")
    k = min(k, allp.width / BACK_W)
    back_w, ch, side_w = round(BACK_W * k), round(HEIGHT * k), round(DEPTH * k)
    ch = min(ch, allp.height)
    xb = (allp.width - back_w) // 2
    back = allp.crop((xb, allp.height - ch, xb + back_w, allp.height))
    save(back, "back_wall.png")
    strip_l = back.crop((0, 0, min(side_w, back_w), ch)).transpose(Image.FLIP_LEFT_RIGHT)
    strip_r = back.crop((max(0, back_w - side_w), 0, back_w, ch)).transpose(Image.FLIP_LEFT_RIGHT)
    left = Image.new("RGB", (side_w, ch))
    right = Image.new("RGB", (side_w, ch))
    left.paste(strip_l.resize((side_w, ch), Image.LANCZOS) if strip_l.width < side_w else strip_l.crop((strip_l.width - side_w, 0, strip_l.width, ch)), (0, 0))
    right.paste(strip_r.resize((side_w, ch), Image.LANCZOS) if strip_r.width < side_w else strip_r.crop((0, 0, side_w, ch)), (0, 0))
    save(left, "wall_left.png")
    save(right, "wall_right.png")
fl = find("Floor").convert("RGB")
save(fl, "floor.png", (2048, round(2048 * fl.height / fl.width)))
lf = find("Lower Floor").convert("RGB")
save(lf, "lower_floor.png", (2048, round(2048 * lf.height / lf.width)))  # (tilted like the floor, below the front wall)
wl = find("Wall").convert("RGBA")
if wl.width / wl.height < 6:  # (not the thin strip Act 1 has: a big picture of planks; its top band, as thin as that strip, is the front wall)
    wl = wl.crop((0, 0, wl.width, round(wl.width / 11.0)))
save(wl, "front_wall.png", (1920, round(1920 * wl.height / wl.width)))  # (upright, not tilted: the stage's front, under the floor)
ce = find("Ceiling").convert("RGBA")
save(ce if ce.size == (1920, 146) else ce.resize((1920, 146), Image.LANCZOS), "ceiling_overlay.png")
names = {"Sun": "sun", "Moon": "sun", "Hanging Sign": "hanging_sign"}  # (the night acts have a moon where the sun stood)
for i in range(1, 4):
    names["Cloud %d" % i] = "cloud_%d" % i
for i in range(1, 6):
    names["Tree %d" % i] = "tree_%d" % i
    names["Mountain %d" % i] = "mountain_%d" % i
for src, dst in names.items():
    if not glob.glob(os.path.join(SRC, src + "*.png")):
        print("  (no %s in this act's _Source: skipped)" % src)
        continue
    im = find(src).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    s = 900.0 / max(im.size)
    if s < 1:
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    im.save(os.path.join(PROPS, dst + ".png"))
    print("  props/%-22s %s" % (dst, im.size))

# the sheet of six bushes
import numpy as np
from scipy import ndimage as ndi
sheet = find("Bush").convert("RGBA")  # ("Bush Sheet*" in Act 2: the same glob)
a = np.asarray(sheet)
lab, n = ndi.label(ndi.binary_dilation(a[:, :, 3] > 8, iterations=12))
boxes = sorted(ndi.find_objects(lab), key=lambda b: (round(b[0].start / 500), b[1].start))
assert len(boxes) == 6, len(boxes)
for i, b in enumerate(boxes):
    im = sheet.crop((b[1].start, b[0].start, b[1].stop, b[0].stop))
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    sc = 700.0 / max(im.size)
    if sc < 1:
        im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
    im.save(os.path.join(PROPS, "bush_%d.png" % (i + 1)))
    print("  props/bush_%d %s" % (i + 1, im.size))
