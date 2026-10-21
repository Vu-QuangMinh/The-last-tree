"""Puppet Stage theme: the candy-cane HP bar of page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 1080 = the screen).
The page draws the stripes as shaded vector pieces (a clip path + `sh`), so this edits the page's content stream and renders only what it keeps:
  hp_bar_frame.png      the ring + border + empty dark track (no stripes, no text: the numbers are typed by the game)
  hp_piece_00..15.png   the 16 red / white stripes of "New HP Bar", each already clipped by the window, left to right
  hp_shield_00..15.png  the blue stripe ("Shield & HP Combination") moved to each of the 16 places and clipped by the same window
Every picture has the same canvas (CANVAS, 2 px per pt), so the game just draws them all at the same place.
Run: python tools/export_hp_bar.py   (needs pymupdf, pillow, numpy)"""
import io
import os
import re
import sys

import numpy as np
import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "Hp")
PAGE = 1
Z = 2
CANVAS = pymupdf.Rect(538, 503, 814, 560)  # the New HP Bar's box on the page (it measures 538.5, 503.3 -> 812.9, 559.5)
PIECES = 16
BAR_SH = 61  # index (among the page's `sh` operators) of the bar's first stripe
COMBO_SH = 40  # the same stripes drawn whole in "Shield & HP Combination": 16 of them, the blue copies come after
BLUE_EVEN, BLUE_ODD = 58, 59  # the blue stripes that lie on the last two (14th, 15th) of them
COMBO_TO_BAR = (-1.0, -121.5)  # measured: the combination's stripe lands on the bar's stripe when moved by this (pt)

doc = pymupdf.open(SRC)
xref = doc[PAGE].get_contents()[0]
orig = doc.xref_stream(xref).decode("latin1").split("\n")
intext = False
for i, ln in enumerate(orig):  # (the text is typed by the game)
    t = ln.strip()
    if t == "BT":
        intext = True
    if intext:
        orig[i] = ""
    if t == "ET":
        intext = False
SH = [i for i, ln in enumerate(orig) if re.search(r"/Sh\d+ sh", ln)]
FILLS = [i for i, ln in enumerate(orig) if ln.strip() in ("f", "f*", "S", "B")]
DOS = [i for i, ln in enumerate(orig) if re.search(r"/\w+ Do", ln)]
assert len(SH) == 77, len(SH)

drawings = doc[PAGE].get_drawings()
forms = [i for i in DOS if re.search(r"/Fm\d+ Do", orig[i])]
form_fills = {}
for m in re.finditer(r"/(Fm\d+) (\d+) 0 R", doc.xref_object(doc[PAGE].xref)):
    form_fills[m.group(1)] = sum(1 for ln in doc.xref_stream(int(m.group(2))).decode("latin1").split("\n") if ln.strip() in ("f", "f*", "S", "B"))
DRAW = []  # drawing index -> the line of its fill operator
for i, k in sorted([(i, "f") for i in FILLS] + [(i, "form") for i in forms]):
    if k == "f":
        DRAW.append(i)
    else:
        DRAW.extend([i] * form_fills[re.search(r"/(Fm\d+) Do", orig[i]).group(1)])
assert len(DRAW) == len(drawings)


def render(sh=(), fills=(), move=(0.0, 0.0), clip=CANVAS):
    ln = list(orig)
    keep = {SH[n] for n in sh}
    for i in SH:
        if i not in keep:
            ln[i] = re.sub(r"/Sh\d+ sh", "", ln[i])
    keep_fills = set(fills)
    for i in FILLS:
        if i not in keep_fills:
            ln[i] = "n"
    for i in DOS:
        ln[i] = re.sub(r"/\w+ Do", "", ln[i])
    # (the whole page moves, so the shading and its clip move together, with sub-pixel accuracy)
    ln = ["q 1 0 0 1 %.4f %.4f cm" % (move[0], -move[1])] + ln + ["Q"]
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = pymupdf.open(stream=doc.tobytes())[PAGE].get_pixmap(matrix=pymupdf.Matrix(Z, Z), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


COMBO = pymupdf.Rect(538, 625, 830, 670)  # (the combination's row, for measuring)


def bbox_x(im):
    return im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()[0] / Z + COMBO.x0


# the bar's drawings (ring, border, track): the ones whose middle lies inside the bar's box
bar_ids = [i for i, d in enumerate(drawings) if 530 <= (d["rect"].x0 + d["rect"].x1) / 2 <= 822 and 498 <= (d["rect"].y0 + d["rect"].y1) / 2 <= 566]
track = [i for i in bar_ids if abs(drawings[i]["rect"].x0 - 597.4) < 1 and abs(drawings[i]["rect"].y0 - 516.2) < 1 and drawings[i]["rect"].width > 200
         and max(drawings[i]["fill"] or (1, 1, 1)) < 0.3]  # (the dark fill of the window)
assert len(track) == 1, track
bar_fills = [DRAW[i] for i in bar_ids]
assert max(bar_fills) < SH[BAR_SH]  # (the frame is painted before the stripes: nothing of it lies over them)

os.makedirs(OUT, exist_ok=True)
frame = render(fills=bar_fills)
frame.save(os.path.join(OUT, "hp_bar_frame.png"))
print("hp_bar_frame.png", frame.size)
mask = np.array(render(fills=[DRAW[track[0]]]).getchannel("A"), dtype=np.float32) / 255.0  # (the window the stripes are clipped to)

# where each place of the combination lies on the page: a straight line through the 16 stripes
xs = [bbox_x(render(sh=[COMBO_SH + k if k < 14 else 56 + (k - 14)], clip=COMBO)) for k in range(PIECES)]
pitch = (xs[-1] - xs[0]) / (PIECES - 1)
print("stripe pitch %.3f pt" % pitch)

for k in range(PIECES):
    im = render(sh=[BAR_SH + k])
    im.save(os.path.join(OUT, "hp_piece_%02d.png" % k))
    blue = BLUE_EVEN if k % 2 == 0 else BLUE_ODD
    src_k = 14 if k % 2 == 0 else 15
    move = (COMBO_TO_BAR[0] + (k - src_k) * pitch, COMBO_TO_BAR[1])
    a = np.array(render(sh=[blue], move=move))
    a[..., 3] = (a[..., 3] * mask).astype(np.uint8)
    Image.fromarray(a).save(os.path.join(OUT, "hp_shield_%02d.png" % k))
    print("  stripe %2d: piece bbox %s, shield bbox %s" % (k, im.getchannel("A").getbbox(), Image.fromarray(a).getchannel("A").getbbox()))
