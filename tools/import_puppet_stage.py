"""Puppet Stage pictures: assets/Room Background/Puppet/Act 1/*.png -> assets/ui/puppet/ in the shape the stage needs.
 All side (left wall | back wall | right wall, unfolded; the newest "All side*.png") -> cut into back_wall.png, wall_left.png, wall_right.png
 Floor        -> floor.png        the whole picture            Lower Floor -> lower_floor.png   (tilted like the floor, below the front wall)
 Wall (4350x395) -> front_wall.png  1920 px wide, upright under the floor
 Ceiling (1920x146) -> ceiling_overlay.png  NOT tilted or stretched: laid over the top of the screen
 Cloud / Tree / Mountain / Sun / Hanging Sign -> props/<name>.png   trimmed, at most 900 px;   Bush (a sheet of 6) -> props/bush_1..6.png
Run: python tools/import_puppet_stage.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import glob
import os
import re

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "Room Background", "Puppet", "Act 1")
OUT = os.path.join(HERE, "..", "assets", "ui", "puppet")
os.makedirs(os.path.join(OUT, "props"), exist_ok=True)


def find(prefix):
    f = glob.glob(os.path.join(SRC, prefix + "*.png"))
    assert f, prefix
    return Image.open(max(f, key=os.path.getmtime))  # (the newest one: "All side 2.png" after "All side.png")


def save(im, name, size=None):
    if size:
        im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(OUT, name))
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
assert need <= allp.width, "the picture is too short: it would have to be enlarged by %.2f" % (need / allp.width)
x0 = (allp.width - need) // 2
save(allp.crop((x0 + side_w, 0, x0 + side_w + back_w, allp.height)), "back_wall.png")
save(allp.crop((x0, 0, x0 + side_w, allp.height)), "wall_left.png")
save(allp.crop((x0 + side_w + back_w, 0, x0 + need, allp.height)), "wall_right.png")
fl = find("Floor").convert("RGB")
save(fl, "floor.png", (2048, round(2048 * fl.height / fl.width)))
lf = find("Lower Floor").convert("RGB")
save(lf, "lower_floor.png", (2048, round(2048 * lf.height / lf.width)))  # (tilted like the floor, below the front wall)
wl = find("Wall").convert("RGBA")
save(wl, "front_wall.png", (1920, round(1920 * wl.height / wl.width)))  # (upright, not tilted: the stage's front, under the floor)
save(find("Ceiling").convert("RGBA"), "ceiling_overlay.png")
names = {"Sun": "sun", "Hanging Sign": "hanging_sign"}
for i in range(1, 4):
    names["Cloud %d" % i] = "cloud_%d" % i
for i in range(1, 6):
    names["Tree %d" % i] = "tree_%d" % i
    names["Mountain %d" % i] = "mountain_%d" % i
for src, dst in names.items():
    im = find(src).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    s = 900.0 / max(im.size)
    if s < 1:
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    im.save(os.path.join(OUT, "props", dst + ".png"))
    print("  props/%-22s %s" % (dst, im.size))

# the sheet of six bushes
import numpy as np
from scipy import ndimage as ndi
sheet = find("Bush").convert("RGBA")
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
    im.save(os.path.join(OUT, "props", "bush_%d.png" % (i + 1)))
    print("  props/bush_%d %s" % (i + 1, im.size))
