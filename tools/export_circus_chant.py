"""Cirus theme: the redesigned Chant / Bag strip of assets/ui/circus/Chant UI for Circus.pdf.
Cuts, at the game's scale (the 576 pt wide strip = 1100 px, so S = 1100 / 576 px per point), into assets/ui/circus/panels/:
  chant_frame.png      the Chant strip (9-slice: caps left / right)       bag_frame.png   the Bag strip (9-slice)
  chant_slot_empty.png one empty ring of the chant
  tube_back.png / tube_glass.png   the launcher tube: back layer (behind the Essence) and glass layer (in front)
  tube_gear.png (turns twice) / crank_plate.png (the base) / crank_handle.png (turns once, around its round bottom end)
and writes scripts/ui/chant_layout.gd: where each piece goes, in px from the top-left of the Bag strip.
Nothing is measured by hand: every paint operator of the page is rendered alone to find its box (cached in
tools/.circus_chant_boxes.json, keyed by the PDF's size and date: delete it to force a re-measure, about 4 minutes), the
operators are grouped by where they sit, and each group is rendered on its own (the page stream is replayed with every
other paint operator turned into a no-op).  Run:  python tools/export_circus_chant.py   (needs pymupdf, pillow, numpy, scipy)
The strip frames are the first operators of each strip (CHANT_FRAME_OPS / BAG_FRAME_OPS): if the PDF is redrawn, check them."""
import collections
import io
import json
import os
import re
import sys

import numpy as np
import pymupdf
from PIL import Image
from scipy import ndimage

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "circus", "Chant UI for Circus.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "circus", "panels")
LAYOUT = os.path.join(HERE, "..", "scripts", "ui", "chant_layout.gd")
CACHE = os.path.join(HERE, ".circus_chant_boxes.json")
S = 1100.0 / 576.0  # px per PDF point
ZOOM = 8
CHANT_RECT = (18, 365, 594, 427)  # the Chant strip (pt)
BAG_RECT = (18, 433, 594, 495)  # the Bag strip with its tube (pt)
CHANT_FRAME_OPS = range(0, 184)  # caps + bars of the Chant strip frame
BAG_FRAME_OPS = range(470, 658)  # ... and of the Bag strip frame
os.makedirs(OUT, exist_ok=True)

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
shade = re.compile(r"/\w+ sh")
xobj = re.compile(r"/\w+ Do")
ends = [i for i, ln in enumerate(lines) if ln.strip() in paint or shade.search(ln) or xobj.search(ln)]


def render(keep, zoom, clip):
    ln = list(lines)
    for e in ends:
        if e in keep:
            continue
        ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", shade.sub("", ln[e]))
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = doc.load_page(0).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


def measure():
    stamp = [os.path.getsize(SRC), int(os.path.getmtime(SRC)), len(ends)]
    if os.path.exists(CACHE):
        c = json.load(open(CACHE))
        if c.get("stamp") == stamp:
            return {int(k): v for k, v in c["boxes"].items()}
    area = pymupdf.Rect(0, 340, 612, 792)
    boxes = {}
    for k, e in enumerate(ends):
        a = np.asarray(render({e}, 1.0, area).getchannel("A")) > 0
        ys, xs = np.nonzero(a)
        if len(xs):
            boxes[k] = [float(xs.min()) + area.x0, float(ys.min()) + area.y0, float(xs.max() + 1) + area.x0, float(ys.max() + 1) + area.y0]
    json.dump({"stamp": stamp, "boxes": boxes}, open(CACHE, "w"))
    return boxes


B = measure()
print("operators:", len(ends), "measured:", len(B))


def cluster(ids, pad=0.6):
    par = {i: i for i in ids}

    def f(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x

    for a in ids:
        for b in ids:
            if a < b:
                p, q = B[a], B[b]
                if p[0] - pad <= q[2] and q[0] - pad <= p[2] and p[1] - pad <= q[3] and q[1] - pad <= p[3]:
                    par[f(a)] = f(b)
    g = collections.defaultdict(list)
    for i in ids:
        g[f(i)].append(i)
    return list(g.values())


def bbox(ids):
    return [min(B[i][0] for i in ids), min(B[i][1] for i in ids), max(B[i][2] for i in ids), max(B[i][3] for i in ids)]


def inside(ids, rect):
    return [i for i in ids if B[i][0] >= rect[0] - 1 and B[i][1] >= rect[1] - 1 and B[i][2] <= rect[2] + 1 and B[i][3] <= rect[3] + 1]


# the loose parts under the strips, told apart by where they sit on the page
loose = {}
for c in cluster([i for i, b in B.items() if b[1] >= 500]):
    r = bbox(c)
    key = {(444, 503): "plate", (430, 509): "handle", (437, 557): "gear", (468, 609): "tube", (471, 669): "back", (474, 716): "glass", (468, 718): "glass_ring"}.get((round(r[0]), round(r[1])))
    if key is None:
        print("WARNING: an unknown part at", [round(v) for v in r])
    else:
        loose[key] = c
for need in ("plate", "handle", "gear", "back", "glass", "glass_ring"):
    if need not in loose:
        sys.exit("part missing: " + need)
# the base plate = the plate with the handle's own operators taken out
hsz = [(round(B[i][2] - B[i][0], 1), round(B[i][3] - B[i][1], 1)) for i in loose["handle"]]
plate_ids = []
for i in loose["plate"]:
    sz = (round(B[i][2] - B[i][0], 1), round(B[i][3] - B[i][1], 1))
    if any(abs(sz[0] - h[0]) < 0.35 and abs(sz[1] - h[1]) < 0.35 for h in hsz):
        continue
    plate_ids.append(i)
glass_ids = loose["glass"] + loose["glass_ring"]
chant_ids = inside([i for i in B if i in CHANT_FRAME_OPS], CHANT_RECT)
bag_ids = inside([i for i in B if i in BAG_FRAME_OPS], BAG_RECT)
# the first empty ring of the Chant strip
slot_box = (72, 383, 107, 414)
slot_ids = [i for i in inside([i for i in B if 184 <= i < 470], CHANT_RECT) if slot_box[0] <= (B[i][0] + B[i][2]) / 2 <= slot_box[2] and slot_box[1] <= (B[i][1] + B[i][3]) / 2 <= slot_box[3]
            and B[i][2] - B[i][0] < 40]
print("frame ops: chant %d, bag %d; slot %d, gear %d, plate %d (+%d handle), back %d, glass %d" % (len(chant_ids), len(bag_ids), len(slot_ids), len(loose["gear"]), len(plate_ids), len(loose["handle"]), len(loose["back"]), len(glass_ids)))


def seal_seams(im):
    """The bars of a frame touch each other, and the anti-aliasing leaves hairlines between them: fill every
    not-quite-opaque pixel inside the silhouette from its nearest solid neighbour."""
    a = np.asarray(im).copy()
    alpha = a[..., 3]
    solid = alpha > 235
    inner = ndimage.binary_erosion(ndimage.binary_closing(alpha > 128, iterations=4), iterations=2)
    seam = inner & ~solid
    if seam.any():
        idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
        for ch in range(3):
            a[..., ch][seam] = a[..., ch][idx[0][seam], idx[1][seam]]
        a[..., 3][seam] = 255
    return Image.fromarray(a, "RGBA")


def cut(ids, name, fix=False, pad=1.5):
    r = bbox(ids)
    clip = pymupdf.Rect(r[0] - pad, r[1] - pad, r[2] + pad, r[3] + pad)
    im = render({ends[k] for k in ids}, ZOOM, clip)
    if fix:
        im = seal_seams(im)
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop(box)
    # the picture's own top-left, in page points
    x0 = clip.x0 + box[0] / ZOOM
    y0 = clip.y0 + box[1] / ZOOM
    size = (max(1, round(im.width / ZOOM * S)), max(1, round(im.height / ZOOM * S)))
    im.resize(size, Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print("  %-18s %s at pt (%.2f, %.2f)" % (name, size, x0, y0))
    return x0, y0, size


def px(x0, y0):  # page point -> px from the top-left of the Bag strip
    return round((x0 - BAG_RECT[0]) * S, 1), round((y0 - BAG_RECT[1]) * S, 1)


print("cutting:")
cf = cut(chant_ids, "chant_frame", True)
bf = cut(bag_ids, "bag_frame", True)
cut(slot_ids, "chant_slot_empty")
back = cut(loose["back"], "tube_back")
glass = cut(glass_ids, "tube_glass")
gear = cut(loose["gear"], "tube_gear")
plate = cut(plate_ids, "crank_plate")
hnd = cut(loose["handle"], "crank_handle")
# Where each loose part sits inside the strip: found once by matching pixels (a part's box in the loose drawing, and the
# shift that lands it on the same art in the Bag strip, in PDF points).
SHIFT = {"plate": (7.17, -60.83), "gear": (17.5, -111.25), "glass": (0.0, -275.5)}
BACK_AT = (471.0, 442.0)  # (the back layer is mostly hidden by the Essence in the strip: placed in the middle of the glass)
HANDLE_ON_PLATE = (7.5, 6.0)  # the handle's box from the plate's box, matched the same way
gw, gh = gear[2]
pw, ph = plate[2]
hw, hh = hnd[2]


def at(name, ids):
    r = bbox(ids)
    return px(r[0] + SHIFT[name][0], r[1] + SHIFT[name][1])


plate_pos = at("plate", loose["plate"])
gear_pos = at("gear", loose["gear"])
glass_pos = at("glass", glass_ids)
back_pos = px(*BACK_AT)
handle_pos = (round(plate_pos[0] + HANDLE_ON_PLATE[0] * S, 1), round(plate_pos[1] + HANDLE_ON_PLATE[1] * S, 1))
out = ["class_name ChantLayout", "extends RefCounted",
       "## GENERATED by tools/export_circus_chant.py from Chant UI for Circus.pdf: do not edit by hand.",
       "## Cirus theme. Every position is in px from the top-left of the Bag strip; the strip is 1100 px wide (S = %.4f px per PDF point)." % S, "",
       "const FRAME_CHANT := Vector2(%d, %d)  # the Chant strip picture's size" % cf[2],
       "const FRAME_BAG := Vector2(%d, %d)  # the Bag strip picture's size" % bf[2],
       "const CAP := Vector2(%d, %d)  # 9-slice margins of the strips: left, right" % (round(38 * S), round(36 * S)),
       "const TUBE_BACK := Vector2(%s, %s)" % back_pos,
       "const TUBE_GLASS := Vector2(%s, %s)" % glass_pos,
       "const GEAR := Vector2(%s, %s)  # top-left; turns twice for one turn of the crank" % gear_pos,
       "const GEAR_SIZE := Vector2(%d, %d)" % (gw, gh),
       "const PLATE := Vector2(%s, %s)" % plate_pos,
       "const HANDLE := Vector2(%s, %s)  # top-left of the handle at rest (pointing up)" % handle_pos,
       "const HANDLE_SIZE := Vector2(%d, %d)" % (hw, hh),
       "const HANDLE_PIVOT := Vector2(%.1f, %.1f)  # inside the handle picture: the centre of its round bottom end" % (hw / 2.0, hh - hw / 2.0),
       # the Essence: the leftmost rests where the strip's mock-up fire Essence sits, the tube's axis is the strip's middle
       "const AXIS_Y := %.1f  # the row the Essence roll along, from the strip's top" % ((464.0 - BAG_RECT[1]) * S),
       "const REST_X := %.1f  # left edge of the leftmost resting Essence" % ((73.0 - BAG_RECT[0]) * S),
       "const REST_END := %.1f  # the Essence rest left of this x (the crank plate)" % ((451.0 - BAG_RECT[0]) * S),
       "const TUBE_HIDE_X := %.1f  # right of this x the Essence are inside the machine, under the red block" % ((553.0 - BAG_RECT[0]) * S),
       "const TUBE_RIGHT := %.1f  # the tube's right end" % ((594.0 - BAG_RECT[0]) * S)]
with open(LAYOUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("wrote", os.path.relpath(LAYOUT, HERE))
