"""Puppet Stage theme: the Chant strip, the Bag strip and the lottery-ball machine of assets/Puppet/_Source/Chant UI for puppet.pdf.
Cuts, at the game's scale (S = 1100 / 576 px per PDF point), into assets/Puppet/UI/Panels/ (and UI/Hp, UI/Machine):
  chant_frame.png  bag_frame.png   the two strips (3-slice: a cap at each end, a plain middle; no stretch in height)
  chant_slot_empty.png             one empty ring of the chant
  globe_front.png                  the glass globe's bowl, bands, hinge and highlights (the 3 Essence tumble behind it)
  box_front.png                    the red box under the globe: chute window, front panel, legs (Essence hide behind it)
  tube_front.png                   the launcher tube's glass and brass bands (Essence ride behind it)
  pipe_front.png                   the elbow pipe a spell's Essence rolls down into the box
and writes scripts/ui/puppet_layout.gd (PuppetLayout): where each piece goes, in px from the top-left of the Bag strip.
The PDF is all plain fills, so every paint operator is one entry of page.get_drawings(); a piece is a range of operators of the page
stream, rendered alone by turning every other operator into a no-op (see lib below). The isolated master copies at the bottom of the
page (balls, globe, box, tube, pipe) are matched to the assembled picture at the top by path coordinates to find their positions.
If the PDF is redrawn the operator ranges below (RANGES) must be checked: python tools/export_puppet_chant.py prints what it found.
Run:  python tools/export_puppet_chant.py   (needs pymupdf, pillow)"""
import io
import os
import re
import sys

import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP
SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "Panels")
LAYOUT = os.path.join(HERE, "..", "scripts", "ui", "puppet_layout.gd")
S = 1100.0 / 576.0
ZOOM = 8
os.makedirs(OUT, exist_ok=True)

# operator ranges (indices into the page's paint operators, = page.get_drawings())
RANGES = {
    "bag_frame": range(0, 170),
    "chant_frame": range(170, 342),  # (342..347 are the green Chant button: the game draws its own)
    "chant_slot_empty": range(386, 416),  # first ring of the chant
    "globe_front": range(7788, 7883),  # master copy at the bottom of the page ...
    "box_front": range(6418, 6555),
    "tube_front": range(7883, 7991),
    "pipe_front": range(7991, 8066),
}
# ... and its shift to the assembled picture at the top (found by matching, see find_shift)
MASTERS = ("globe_front", "box_front", "tube_front", "pipe_front")

doc = pymupdf.open(SRC)
pg = doc[0]
xref = pg.get_contents()[0]
lines = doc.xref_stream(xref).decode("latin1").split("\n")
intext = False
for i, ln in enumerate(lines):  # the text (BT ... ET) is not art
    t = ln.strip()
    if t == "BT":
        intext = True
    if intext:
        lines[i] = ""
    if t == "ET":
        intext = False
paint = ("f", "f*", "S", "s", "B", "B*", "b", "b*")
xobj = re.compile(r"/\w+ Do")
ends = [i for i, ln in enumerate(lines) if ln.strip() in paint or xobj.search(ln)]
orig = list(lines)
dr = pg.get_drawings()
assert len(ends) == len(dr), (len(ends), len(dr))


def render(keep, zoom, clip):
    ln = list(orig)
    ks = {ends[k] for k in keep}
    for e in ends:
        if e not in ks:
            ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", ln[e])
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = doc.load_page(0).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


def bbox(ids):
    r = pymupdf.Rect(dr[ids[0]]["rect"])
    for i in ids:
        r |= dr[i]["rect"]
    return r


def key(i):
    r = dr[i]["rect"]
    return (round(r.width, 2), round(r.height, 2), tuple(round(c, 3) for c in (dr[i]["fill"] or (0, 0, 0))))


def find_shift(ids):
    """The (dx, dy) that lands a master copy on the same art in the assembled picture (operators 0..5556)."""
    big = max(ids, key=lambda i: dr[i]["rect"].width * dr[i]["rect"].height)
    best = None
    for j in range(5557):
        if key(j) != key(big):
            continue
        dx = dr[j]["rect"].x0 - dr[big]["rect"].x0
        dy = dr[j]["rect"].y0 - dr[big]["rect"].y0
        hit = 0
        for i in ids:
            r = dr[i]["rect"]
            if any(abs(dr[k]["rect"].x0 - (r.x0 + dx)) < 0.02 and abs(dr[k]["rect"].y0 - (r.y0 + dy)) < 0.02 and key(k) == key(i) for k in range(5557)):
                hit += 1
        if best is None or hit > best[2]:
            best = (dx, dy, hit)
    assert best and best[2] >= 0.8 * len(ids), "could not place a master copy"
    return best[0], best[1]


def cut(name, shift=(0.0, 0.0), pad=1.5):
    """Render one piece alone, trim it, save it; returns its top-left (pt, in the assembled picture) and its px size."""
    ids = list(RANGES[name])
    r = bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = render(set(ids), ZOOM, clip)
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop(box)
    x0 = clip.x0 + box[0] / ZOOM + shift[0]
    y0 = clip.y0 + box[1] / ZOOM + shift[1]
    size = (max(1, round(im.width / ZOOM * S)), max(1, round(im.height / ZOOM * S)))
    im.resize(size, Image.LANCZOS).save(AP.panel_path(AP.PUPPET, name))
    print("  %-18s %s at pt (%.2f, %.2f)" % (name, size, x0, y0))
    return x0, y0, size


print("cutting:")
shifts = {n: find_shift(list(RANGES[n])) for n in MASTERS}
print("  master shifts:", {k: (round(v[0], 2), round(v[1], 2)) for k, v in shifts.items()})
bag = cut("bag_frame")
chant = cut("chant_frame")
ring = cut("chant_slot_empty")
globe = cut("globe_front", shifts["globe_front"])
box = cut("box_front", shifts["box_front"])
tube = cut("tube_front", shifts["tube_front"])
pipe = cut("pipe_front", shifts["pipe_front"])
ORIGIN = (bag[0], bag[1])  # the Bag strip's top-left in pt


def px(x, y):
    return round((x - ORIGIN[0]) * S, 1), round((y - ORIGIN[1]) * S, 1)


def pxv(x, y):
    return "Vector2(%s, %s)" % px(x, y)


def size_v(sz):
    return "Vector2(%d, %d)" % sz


# measured on the page: the rings, the balls, the buttons, the pipe's path (the 4 Essence drawn inside it), the globe
RING_X0, RING_STEP_PT = 39.94, 30.4  # (the 10 rings are 30.26..31.98 pt apart: one even step is used)
RING_Y_MID = 158.18  # chant ring row centre (pt)
BALL_X0, BALL_Y_MID = 39.94, 207.2  # first bag Essence, and the row they roll along
globe_balls = [(508.31, 116.91), (523.97, 142.67), (495.65, 144.72)]
pipe_path = [(583.93, 150.83), (584.59, 181.36), (570.65, 203.23), (546.87, 207.52)]  # head, down the leg, round the bend, into the box
chute_x = 508.3
btn_chant = (351.1, 145.9, 408.9, 168.7)
btn_clear = (416.5, 142.7, 453.6, 157.9)
btn_pass = (416.5, 158.5, 453.6, 173.6)
S_ = S
gc = bbox(list(range(7788, 7790)))  # (the globe's bowl is the big operator of its master)
bowl = dr[7788]["rect"]
sh = shifts["globe_front"]
bowl_c = ((bowl.x0 + bowl.x1) / 2 + sh[0], (bowl.y0 + bowl.y1) / 2 + sh[1])
bowl_r = (bowl.width + bowl.height) / 4.0


def rel_chant(x, y):  # px from the Chant strip's top-left
    return round((x - chant[0]) * S, 1), round((y - chant[1]) * S, 1)


def rect_chant(r):
    a = rel_chant(r[0], r[1])
    return "Rect2(%s, %s, %s, %s)" % (a[0], a[1], round((r[2] - r[0]) * S, 1), round((r[3] - r[1]) * S, 1))


box_left = px(box[0], 0)[0]
out = ["class_name PuppetLayout", "extends RefCounted",
       "## GENERATED by tools/export_puppet_chant.py from Chant UI for puppet.pdf: do not edit by hand.",
       "## Puppet Stage theme. Positions are px from the top-left of the Bag strip unless the name says Chant (then from the Chant strip's).",
       "",
       "const FRAME_CHANT := %s  # the Chant strip picture's size" % size_v(chant[2]),
       "const FRAME_BAG := %s  # the Bag strip picture's size" % size_v(bag[2]),
       "const CHANT_AT := %s  # where the Chant strip's top-left is, from the Bag strip's" % pxv(chant[0], chant[1]),
       "const CAP := Vector2(%d, %d)  # 3-slice margins of both strips: left, right" % (round(32.3 * S), round(31.5 * S)),
       "const RING_X0 := %.1f  # chant strip: left edge of the first ring" % rel_chant(RING_X0, 0)[0],
       "const RING_STEP := %.1f" % (RING_STEP_PT * S),
       "const RING_CY := %.1f  # chant strip: the rings' centre row" % rel_chant(0, RING_Y_MID)[1],
       "const BTN_CHANT := %s  # chant strip: the Chant button" % rect_chant(btn_chant),
       "const BTN_CLEAR := %s" % rect_chant(btn_clear),
       "const BTN_PASS := %s" % rect_chant(btn_pass),
       "const REST_X := %.1f  # bag strip: left edge of the leftmost resting Essence" % px(BALL_X0, 0)[0],
       "const AXIS_Y := %.1f  # the row the Essence roll along" % px(0, BALL_Y_MID)[1],
       "const REST_END := %.1f  # the resting Essence end before this x (the tube's left end)" % (px(tube[0], 0)[0] + 4.0),
       "const TUBE_FRONT := %s" % pxv(tube[0], tube[1]),
       "const GLOBE_FRONT := %s" % pxv(globe[0], globe[1]),
       "const BOX_FRONT := %s" % pxv(box[0], box[1]),
       "const PIPE_FRONT := %s" % pxv(pipe[0], pipe[1]),
       "const BOX_LEFT := %.1f  # an Essence right of this x is behind the box" % box_left,
       "const CHUTE_X := %.1f  # centre x of the chute the Essence fall down from the globe into the box" % px(chute_x, 0)[0],
       "const GLOBE_C := %s  # centre of the glass bowl (the three Essence tumble round it)" % pxv(*bowl_c),
       "const GLOBE_R := %.1f  # radius of the bowl" % (bowl_r * S),
       "const GLOBE_SLOTS := [%s]  # where 3 Essence rest in the bowl (centres)" % ", ".join(pxv(*p) for p in globe_balls),
       "const PIPE_PATH := [%s]  # centres: the pipe's mouth, down its leg, round the bend, into the box" % ", ".join(pxv(*p) for p in pipe_path),
       "const TOTAL_W := %.1f  # the whole machine ends here" % (px(pipe[0], 0)[0] + pipe[2][0])]
# the Chant button: the Cirus pill, redrawn 44 px tall (the strip's Chant button is 110 x 44)
BTN_DIR = os.path.join(AP.PUPPET, "UI", "Buttons")
os.makedirs(BTN_DIR, exist_ok=True)
for state in ("normal", "hover", "pressed", "disabled"):
    src = Image.open(os.path.join(AP.ASSETS, "_Archive", "Circus", "buttons", "button_chant_%s.png" % state)).convert("RGBA")
    w = round(src.width * 44 / src.height)
    src.resize((w, 44), Image.LANCZOS).save(os.path.join(BTN_DIR, "button_chant_%s.png" % state))
with open(LAYOUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("wrote", os.path.relpath(LAYOUT, HERE))
