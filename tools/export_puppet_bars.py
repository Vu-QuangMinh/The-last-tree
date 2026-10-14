"""Puppet Stage theme: the Chant bar, the Bag bar, their buttons and the three Essence balls of assets/Puppet/_Source/Chant UI for puppet.pdf.
Cuts, at the game's scale (S: the PDF's 62.3 pt balls become 52 px), into assets/Puppet/UI/ (Panels, Buttons, Essence):
  panels/chant_frame.png  panels/bag_frame.png   the two bars (3-slice: a cap at each end, a plain middle; no stretch in height)
  panels/chant_slot_empty.png                    one empty ring of the chant (2x: it is scaled down in the game)
  buttons/button_{chant,clear,pass}_{normal,hover,pressed,disabled}.png   the wooden buttons WITHOUT their stamped word (the game writes
                                                 the word itself: it changes, "Chant" / "Release", "Clear" / "Undo"); hover / disabled are
                                                 made from the normal one
  essence/essence_{fire,water,wind}.png          the balls, 128 px
and writes scripts/ui/puppet_layout.gd (PuppetLayout): where the rings, balls and buttons sit, in px from the top-left of their bar.
The PDF mixes vector bars with raster pieces (rings, buttons, balls) that sit on top of them. A piece is rendered alone by turning every
other paint / image operator of the page stream into a no-op (see render). The stamped words are separate form XObjects ("Fm"), left out.
Run:  python tools/export_puppet_bars.py   (needs pymupdf, numpy, pillow)
(The old tools/export_puppet_chant.py cut the previous PDF: do not run it any more.)"""
import io
import os
import re
import sys

import numpy as np
import pymupdf
from PIL import Image, ImageEnhance

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP
UI = AP.PUPPET
SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
LAYOUT = os.path.join(HERE, "..", "scripts", "ui", "puppet_layout.gd")
S = 52.0 / 62.3  # px per pt
ZOOM = 6
for d in ("UI/Panels", "UI/Buttons", "UI/Essence"):
    os.makedirs(os.path.join(UI, *d.split("/")), exist_ok=True)

doc = pymupdf.open(SRC)
pg = doc[0]
xref = pg.get_contents()[0]
lines = doc.xref_stream(xref).decode("latin1").split("\n")
intext = False
for i, ln in enumerate(lines):  # the labels (BT ... ET) are not art
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
names = [xobj.search(orig[e]).group(0).split()[0].lstrip("/") if xobj.search(orig[e]) else None for e in ends]
by_name = {n: k for k, n in enumerate(names) if n}
img_rect = [pymupdf.Rect(item["bbox"]) for item in pg.get_image_info()]
# images are listed in drawing order = the order of their Do operators
do_order = [k for k, n in enumerate(names) if n and n.startswith("Im")]
assert len(do_order) == len(img_rect), (len(do_order), len(img_rect))
rect_of = {names[k]: img_rect[i] for i, k in enumerate(do_order)}


def render(keep, zoom, clip):
    ln = list(orig)
    ks = {ends[k] for k in keep}
    for e in ends:
        if e not in ks:
            ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", ln[e])
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = doc.load_page(0).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


def bbox_of(im, thresh=8):
    return im.getchannel("A").point(lambda v: 255 if v > thresh else 0).getbbox()


def small(im, scale):
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    return im.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")


vector_only = [k for k, n in enumerate(names) if n is None]
vec = render(vector_only, 1.0, pymupdf.Rect(0, 0, pg.rect.width, pg.rect.height))
a = np.array(vec)[..., 3] > 0
rows = np.where(a.any(1))[0]
bands = []
s0 = p0 = rows[0]
for r in rows[1:]:
    if r != p0 + 1:
        bands.append((s0, p0))
        s0 = r
    p0 = r
bands.append((s0, p0))
BAR = {}
for tag, b in (("chant", bands[0]), ("bag", bands[1])):
    cols = np.where(a[b[0]: b[1] + 1].any(0))[0]
    BAR[tag] = pymupdf.Rect(cols.min(), b[0], cols.max() + 1, b[1] + 1)
    print("  %s bar at pt %s" % (tag, BAR[tag]))
CAP_PT = (106.0 - BAR["chant"].x0, BAR["chant"].x1 - 976.0)  # the 9-slice guides of the PDF (the plain middle is 106..976)


def cut_bar(tag, out):
    r = BAR[tag]
    clip = pymupdf.Rect(r.x0 - 1, r.y0 - 1, r.x1 + 1, r.y1 + 1)
    im = render(vector_only, ZOOM, clip)
    box = bbox_of(im)
    im = im.crop(box)
    sm = small(im, S / ZOOM)
    sm.save(AP.panel_path(UI, out[:-4]))
    print("  %-22s %s" % (out, sm.size))
    return sm.size


size_chant = cut_bar("chant", "chant_frame.png")
size_bag = cut_bar("bag", "bag_frame.png")


def cut_piece(keep, rect, zoom=ZOOM):
    """Render the pieces `keep` (indices into ends) inside `rect`; returns the image and its alpha bbox in pt."""
    im = render(keep, zoom, rect)
    box = bbox_of(im)
    return im, box


# ---- the ring (one of the ten) and the balls ---------------------------------------------------------------------------------
ring_r = rect_of["Im0"]
im, box = cut_piece([by_name["Im0"]], ring_r)
ring_pt = pymupdf.Rect(ring_r.x0 + box[0] / ZOOM, ring_r.y0 + box[1] / ZOOM, ring_r.x0 + box[2] / ZOOM, ring_r.y0 + box[3] / ZOOM)
ring_im = im.crop(box)
small(ring_im, 2 * S / ZOOM).save(AP.panel_path(UI, "chant_slot_empty"))
ring_step_pt = (rect_of["Im9"].x0 - rect_of["Im0"].x0) / 9.0
print("  ring %.1f x %.1f pt, step %.2f pt" % (ring_pt.width, ring_pt.height, ring_step_pt))
BALLS = {"fire": "Im16", "water": "Im27", "wind": "Im28"}
for el, nm in BALLS.items():
    r = rect_of[nm]
    im, box = cut_piece([by_name[nm]], r)
    im = im.crop(box)
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    sq = sq.convert("RGBa").resize((128, 128), Image.LANCZOS).convert("RGBA")
    sq.save(os.path.join(UI, "UI", "Essence", "essence_%s.png" % el))
    print("  essence_%-12s %.1f x %.1f pt" % (el, (box[2] - box[0]) / ZOOM, (box[3] - box[1]) / ZOOM))
bag_ball = rect_of["Im17"]  # the first ball laid on the bag bar
im, box = cut_piece([by_name["Im17"]], bag_ball)
bag_ball_pt = pymupdf.Rect(bag_ball.x0 + box[0] / ZOOM, bag_ball.y0 + box[1] / ZOOM, bag_ball.x0 + box[2] / ZOOM, bag_ball.y0 + box[3] / ZOOM)

# ---- the buttons: (picture, its stamped word) normal and pressed ---------------------------------------------------------------
PAIRS = {("chant", "normal"): "Im10", ("clear", "normal"): "Im11", ("pass", "normal"): "Im12",
         ("pass", "pressed"): "Im13", ("chant", "pressed"): "Im14", ("clear", "pressed"): "Im15"}
btn = {}
for (kind, state), nm in PAIRS.items():
    r = rect_of[nm]
    im, box = cut_piece([by_name[nm]], r)  # (no word)
    btn[(kind, state)] = (im, r, box)
for kind in ("chant", "clear", "pass"):
    n, p = btn[(kind, "normal")], btn[(kind, "pressed")]
    # every picture of the PDF has its own raster (placed differently in its 157 pt square), so each is cut to its own box; the two states
    # then share one canvas (the larger of the two), each centred on it
    nim, pim = n[0].crop(n[2]), p[0].crop(p[2])
    cw, ch = max(nim.width, pim.width), max(nim.height, pim.height)
    print("    %s: normal %s pressed %s" % (kind, nim.size, pim.size))

    def centred(img):
        c = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        c.paste(img, ((cw - img.width) // 2, (ch - img.height) // 2))
        return c

    shots = {"normal": centred(nim), "pressed": centred(pim)}
    hov = ImageEnhance.Brightness(shots["normal"]).enhance(1.18)
    hov = ImageEnhance.Contrast(hov).enhance(1.05)
    hov.putalpha(shots["normal"].getchannel("A"))
    shots["hover"] = hov
    dis = ImageEnhance.Color(shots["normal"]).enhance(0.25)
    dis = ImageEnhance.Brightness(dis).enhance(0.62)
    dis.putalpha(shots["normal"].getchannel("A").point(lambda v: int(v * 0.85)))
    shots["disabled"] = dis
    for st, img in shots.items():
        sm = small(img, S / ZOOM)
        sm.save(os.path.join(UI, "UI", "Buttons", "button_%s_%s.png" % (kind, st)))
    cx, cy = n[1].x0 + (n[2][0] + n[2][2]) / 2 / ZOOM, n[1].y0 + (n[2][1] + n[2][3]) / 2 / ZOOM  # (the normal picture's centre on the page)
    btn[(kind, "rect")] = pymupdf.Rect(cx - cw / ZOOM / 2, cy - ch / ZOOM / 2, cx + cw / ZOOM / 2, cy + ch / ZOOM / 2)
    print("  button_%-6s %s px, at pt %s" % (kind, sm.size, btn[(kind, "rect")]))

# ---- the layout: px from the top-left of the bar ---------------------------------------------------------------------------------
C0 = (BAR["chant"].x0, BAR["chant"].y0)
B0 = (BAR["bag"].x0, BAR["bag"].y0)


def rect_chant(r):
    return "Rect2(%.1f, %.1f, %.1f, %.1f)" % ((r.x0 - C0[0]) * S, (r.y0 - C0[1]) * S, r.width * S, r.height * S)


out = ["class_name PuppetLayout",
       "extends RefCounted",
       "## GENERATED by tools/export_puppet_bars.py from Chant UI for puppet.pdf: do not edit by hand.",
       "## Puppet Stage theme. Positions are px from the top-left of the Bag strip unless the name says Chant (then from the Chant strip's).",
       "",
       "const FRAME_CHANT := Vector2(%d, %d)  # the Chant strip picture's size" % size_chant,
       "const FRAME_BAG := Vector2(%d, %d)  # the Bag strip picture's size" % size_bag,
       "const CHANT_AT := Vector2(0.0, %.1f)  # where the Chant strip's top-left is, from the Bag strip's (the two bars are drawn far apart in the PDF)" % -(size_chant[1] + 7.6),
       "const CAP := Vector2(%d, %d)  # 3-slice margins of both strips: left, right" % (round(CAP_PT[0] * S), round(CAP_PT[1] * S)),
       "const RING_X0 := %.1f  # chant strip: left edge of the first ring" % ((ring_pt.x0 - C0[0]) * S),
       "const RING_STEP := %.1f" % (ring_step_pt * S),
       "const RING_CY := %.1f  # chant strip: the rings' centre row" % (((ring_pt.y0 + ring_pt.y1) / 2 - C0[1]) * S),
       "const BTN_CHANT := " + rect_chant(btn[("chant", "rect")]) + "  # chant strip: the Chant button",
       "const BTN_CLEAR := " + rect_chant(btn[("clear", "rect")]),
       "const BTN_PASS := " + rect_chant(btn[("pass", "rect")]),
       "const REST_X := %.1f  # bag strip: left edge of the leftmost resting Essence" % ((bag_ball_pt.x0 - B0[0]) * S),
       "const AXIS_Y := %.1f  # the row the Essence roll along" % (((bag_ball_pt.y0 + bag_ball_pt.y1) / 2 - B0[1]) * S),
       "const REST_END := 636.1  # the resting Essence end before this x (the Pipe's left end: see PuppetMachine)"]
with open(LAYOUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("wrote", os.path.relpath(LAYOUT, HERE))
