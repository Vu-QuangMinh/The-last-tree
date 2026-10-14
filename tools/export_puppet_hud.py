"""Puppet Stage theme: the whole bottom HUD of assets/Puppet/_Source/Chant UI for puppet.pdf (a 1920 x 1080 page, 1 pt = 1 design px).
Cuts into assets/Puppet/UI/Panels, Buttons and writes scripts/ui/puppet_layout.gd (PuppetLayout):
  panels/chant_frame, bag_frame, bottles_frame, artifacts_frame   3-slice frames (a cap at each end, a plain middle)
  panels/chant_slot_empty                                          one empty ring of the chant
  panels/hp_bar_full + hp_fill_mask                                the HP bar frame and the shape the fills are clipped to
  buttons/button_chant_*, button_clear_*, button_pass_*            the wooden buttons WITHOUT their lettering (the game writes the word)
  buttons/button_menu_*                                            the Menu plate
  panels/intent_bubble_h_left, _mid, _right                        the horizontal intent bubble (pointing right, at its enemy): a cap, a stretchy middle, a cap with the pointer
The PDF holds vectors (frames, HP bar, bottles, menu plate: drawing i of page.get_drawings() is the i-th paint operator, forms included)
and four pictures (rings, wooden buttons, the fire Essence, the machine). A piece is rendered alone by turning every other paint
operator and picture of the stream into a no-op.  Run:  python tools/export_puppet_hud.py   (needs pymupdf, pillow, numpy, scipy)"""
import io
import os
import re
import sys

import numpy as np
import pymupdf
from PIL import Image
from scipy import ndimage

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP
SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
PANELS = os.path.join(AP.PUPPET, "UI", "Panels")  # (a piece goes to Panels / Hp / Machine / Hint by its name: AP.panel_path)
BUTTONS = os.path.join(AP.PUPPET, "UI", "Buttons")
LAYOUT = os.path.join(HERE, "..", "scripts", "ui", "puppet_layout.gd")
Z = 1  # export scale: 1 px per pt = the game's design px (a StyleBoxTexture draws its margins at texture size, so no 2x)
os.makedirs(PANELS, exist_ok=True)
os.makedirs(BUTTONS, exist_ok=True)

doc = pymupdf.open(SRC)
pg = doc[0]
xref = pg.get_contents()[0]
lines = doc.xref_stream(xref).decode("latin1").split("\n")
intext = False
for i, ln in enumerate(lines):  # (the text is typed by the game)
    t = ln.strip()
    if t == "BT":
        intext = True
    if intext:
        lines[i] = ""
    if t == "ET":
        intext = False
orig = list(lines)
fills = [i for i, ln in enumerate(orig) if ln.strip() in ("f", "f*", "S", "B")]
dos = [i for i, ln in enumerate(orig) if re.search(r"/\w+ Do", ln)]
imgs = [i for i in dos if re.search(r"/Im\d+ Do", orig[i])]
forms = [i for i in dos if re.search(r"/Fm\d+ Do", orig[i])]
dr = pg.get_drawings()
formn = {}
for m in re.finditer(r"/(Fm\d+) (\d+) 0 R", doc.xref_object(pg.xref)):
    st = doc.xref_stream(int(m.group(2))).decode("latin1").split("\n")
    formn[m.group(1)] = sum(1 for ln in st if ln.strip() in ("f", "f*", "S", "B"))
DRAW = []  # drawing index -> the line of its paint operator (a form's drawings: the line of its Do)
for i, k in sorted([(i, "f") for i in fills] + [(i, "form") for i in forms]):
    if k == "f":
        DRAW.append(i)
    else:
        DRAW.extend([i] * formn[re.search(r"/(Fm\d+) Do", orig[i]).group(1)])
assert len(DRAW) == len(dr), (len(DRAW), len(dr))
assert len(imgs) == 24, len(imgs)  # 10 rings, 3 buttons, 10 Essence, 1 machine


def render(ids=(), pics=(), zoom=Z, clip=None):
    keep = {DRAW[i] for i in ids}
    ln = list(orig)
    for i in fills:
        if i not in keep:
            ln[i] = "n"
    for i in dos:
        if not (i in keep or i in pics):
            ln[i] = re.sub(r"/\w+ Do", "", ln[i])
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = doc.load_page(0).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


def col(i):
    return tuple(round(c, 2) for c in (dr[i]["fill"] or (0, 0, 0)))


def inside(rect):
    x0, y0, x1, y1 = rect
    return [i for i, d in enumerate(dr) if x0 <= (d["rect"].x0 + d["rect"].x1) / 2 <= x1 and y0 <= (d["rect"].y0 + d["rect"].y1) / 2 <= y1]


def cut(im, clip, name, folder=PANELS, scale=Z, trim=True):
    """Trim the picture to what is drawn, bring it to 1 px per pt; returns (x0, y0, w, h) in pt on the page and saves it."""
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() if trim else (0, 0, im.width, im.height)
    im = im.crop(box)
    rect = (clip.x0 + box[0] / scale, clip.y0 + box[1] / scale, im.width / scale, im.height / scale)
    if scale != 1:
        im = im.resize((max(1, round(im.width / scale)), max(1, round(im.height / scale))), Image.LANCZOS)
    im.save(AP.panel_path(AP.PUPPET, name) if folder == PANELS else os.path.join(folder, name + ".png"))
    print("  %-26s %4d x %-4d at pt (%.1f, %.1f, %.1f x %.1f)" % (name, im.width, im.height, *rect))
    return rect


# ------------------------------------------------------------------ frames: the operators coloured like the frame's own bars
FRAME_AREAS = {"chant_frame": (765, 870, 1630, 965), "bag_frame": (765, 968, 1630, 1060), "bottles_frame": (465, 870, 750, 965),
               "artifacts_frame": (210, 968, 750, 1060)}
DECAL = (0.94, 0.84, 0.67)  # the CHANT / CLEAR / PASS lettering under the buttons
R = {}
print("cutting:")
for name, area in FRAME_AREAS.items():
    inreg = inside(area)
    palette = {col(i) for i in inreg if dr[i]["rect"].width >= 60 or dr[i]["rect"].height >= 70}
    ids = [i for i in inreg if col(i) in palette and col(i) != DECAL]
    u = pymupdf.Rect(dr[ids[0]]["rect"])
    for i in ids:
        u |= dr[i]["rect"]
    clip = pymupdf.Rect(u.x0 - 1, u.y0 - 1, u.x1 + 1, u.y1 + 1)
    R[name] = cut(render(ids, clip=clip), clip, name)

# HP bar: its frame (everything of the bar's rows) and the track (the dark fill) as the mask
hp_ids = [i for i in inside((60, 870, 430, 913)) if dr[i]["rect"].y1 <= 912]
clip = pymupdf.Rect(69, 877, 414, 913)
R["hp_bar_full"] = cut(render(hp_ids, clip=clip), clip, "hp_bar_full")
mask = render([28], clip=clip)  # (operator 28 is the dark track)
a = np.asarray(mask.getchannel("A"))
a = (ndimage.binary_fill_holes(a > 8) * 255).astype(np.uint8)  # (operator 28 is a ring: the mask is the pill it encloses)
m = Image.fromarray(np.dstack([np.full_like(a, 255)] * 3 + [a]), "RGBA")
box = Image.open(AP.panel_path(AP.PUPPET, "hp_bar_full")).size
full = Image.new("RGBA", (round(R["hp_bar_full"][2] * Z), round(R["hp_bar_full"][3] * Z)), (0, 0, 0, 0))
ox, oy = round((R["hp_bar_full"][0] - clip.x0) * Z), round((R["hp_bar_full"][1] - clip.y0) * Z)
full.paste(m.crop((ox, oy, ox + full.width, oy + full.height)), (0, 0))
full.save(AP.panel_path(AP.PUPPET, "hp_fill_mask"))

# the Menu plate (vector): the button without lettering, normal / hover / pressed
menu_ids = inside((50, 995, 200, 1050))
clip = pymupdf.Rect(55, 996, 195, 1050)
mp = render([i for i in menu_ids if dr[i]["rect"].width > 40], clip=clip)
R["menu"] = cut(mp, clip, "button_menu_normal", BUTTONS)
base = Image.open(os.path.join(BUTTONS, "button_menu_normal.png"))
for state, f in (("hover", 1.18), ("pressed", 0.82)):
    arr = np.asarray(base).astype(np.float32)
    arr[..., :3] = np.clip(arr[..., :3] * f, 0, 255)
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(os.path.join(BUTTONS, "button_menu_%s.png" % state))
Image.open(os.path.join(BUTTONS, "button_menu_normal.png")).save(os.path.join(BUTTONS, "button_menu_disabled.png"))

# the horizontal intent bubble: three pieces (their drawing numbers were found by position: x 83..104, 112..129, 135..171 on the page)
for name, (x0, x1) in {"intent_bubble_h_left": (80, 106), "intent_bubble_h_mid": (110, 131), "intent_bubble_h_right": (133, 175)}.items():
    ids = [i for i in inside((x0, 700, x1, 790)) if dr[i]["rect"].x0 >= x0 - 1 and dr[i]["rect"].x1 <= x1 + 1 and dr[i]["rect"].y0 >= 700]
    u = pymupdf.Rect(dr[ids[0]]["rect"])
    for i in ids:
        u |= dr[i]["rect"]
    clip = pymupdf.Rect(u.x0 - 1, u.y0 - 1, u.x1 + 1, u.y1 + 1)
    cut(render(ids, clip=clip, zoom=4), clip, name, PANELS, 4)

# ------------------------------------------------------------------ pictures: rings, buttons, the machine
clip = pymupdf.Rect(768, 876, 855, 963)
ring = cut(render(pics=[imgs[0]], clip=clip, zoom=4), clip, "chant_slot_empty", PANELS, 4)
RING_BOX = pymupdf.Rect(768.3, 876.4, 854.8, 962.9)  # (the picture's own box; the ring is drawn in its middle)
btn_names = ["chant", "clear", "pass"]
btn_clip = [pymupdf.Rect(1365, 880, 1502, 1018), pymupdf.Rect(1476, 896, 1556, 976), pymupdf.Rect(1538, 896, 1618, 976)]
BTN = {}
for k, n in enumerate(btn_names):
    im = render(pics=[imgs[10 + k]], clip=btn_clip[k], zoom=4)
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    face = im.crop(box)
    # the lettering is bright beige on brown wood: paint it over with the wood around it (the game writes the word in its own font)
    arr = np.asarray(face).astype(np.float32)
    lum = arr[..., :3].mean(axis=2)
    h, w = lum.shape
    zone = np.zeros_like(lum, bool)
    zone[int(h * 0.2):int(h * 0.8), int(w * 0.1):int(w * 0.9)] = True
    text = (lum > 150) & zone
    text = ndimage.binary_dilation(text, iterations=4)
    keep = ~text
    idx = ndimage.distance_transform_edt(~keep, return_distances=False, return_indices=True)
    out = arr.copy()
    for c in range(4):
        out[..., c][text] = arr[..., c][idx[0][text], idx[1][text]]
    out[..., 3] = arr[..., 3]
    blank = Image.fromarray(out.astype(np.uint8), "RGBA")
    blank = blank.resize((max(1, round(blank.width / 4)), max(1, round(blank.height / 4))), Image.LANCZOS)
    for state, f in (("normal", 1.0), ("hover", 1.2), ("pressed", 0.8), ("disabled", 0.55)):
        arr2 = np.asarray(blank).astype(np.float32)
        arr2[..., :3] = np.clip(arr2[..., :3] * f, 0, 255)
        Image.fromarray(arr2.astype(np.uint8), "RGBA").save(os.path.join(BUTTONS, "button_%s_%s.png" % (n, state)))
    BTN[n] = (btn_clip[k].x0 + box[0] / 4, btn_clip[k].y0 + box[1] / 4, face.width / 4, face.height / 4)
    print("  button_%-18s %4d x %-4d at pt (%.1f, %.1f)" % (n + "_*", face.width, face.height, BTN[n][0], BTN[n][1]))

# (the machine in the PDF is only a placeholder picture: the game's machine is made from Essence Machine.psd by tools/export_puppet_machine.py,
# anchored on this layout's Bag strip: X0 = where the Pipe leaves the Bag, AXIS_Y = the row the Essence roll along)
PIPE_LEFT = 1407.0  # (pt, the placeholder machine's left end = where the Essence leave the Bag strip)

# ------------------------------------------------------------------ the layout file (everything in px of the 1920 x 1080 screen, or
# relative to the Bag strip's top-left for the Essence and the machine)
bag = R["bag_frame"]
chant = R["chant_frame"]
bag0 = (bag[0], bag[1])


def rel(x, y):
    return "Vector2(%.1f, %.1f)" % (x - bag0[0], y - bag0[1])


def vec(x, y):
    return "Vector2(%.1f, %.1f)" % (x, y)


def rect_abs(r):
    return "Rect2(%.1f, %.1f, %.1f, %.1f)" % tuple(r)


def rect_chant(r):
    return "Rect2(%.1f, %.1f, %.1f, %.1f)" % (r[0] - chant[0], r[1] - chant[1], r[2], r[3])


AXIS = 985.9 + 52.29 / 2.0  # the row the Essence roll along: the bag's balls' centre (also the tube's axis)
out = ["class_name PuppetLayout", "extends RefCounted",
       "## GENERATED by tools/export_puppet_hud.py from Chant UI for puppet.pdf: do not edit by hand.",
       "## Puppet Stage theme. Absolute positions are px of the 1920 x 1080 screen; the Essence and the machine are relative to the Bag strip's top-left.",
       "",
       "const FRAME_CHANT := Vector2(%.1f, %.1f)" % (chant[2], chant[3]),
       "const FRAME_BAG := Vector2(%.1f, %.1f)" % (bag[2], bag[3]),
       "const BAG_AT := %s  # the Bag strip's top-left on the screen" % vec(*bag0),
       "const CHANT_AT := %s  # the Chant strip's top-left, from the Bag strip's" % rel(chant[0], chant[1]),
       "const CAP := Vector2(62, 62)  # 3-slice margins of the two long strips (pt)",
       "const RING_X0 := %.1f  # chant strip: left edge of the first ring (the ring pictures are 86.5 pt boxes with the ring in the middle)" % (RING_BOX.x0 + (RING_BOX.width - 52.5) / 2.0 - chant[0]),
       "const RING_STEP := 60.1",
              "const RING_CY := %.1f  # chant strip: the rings' centre row" % ((RING_BOX.y0 + RING_BOX.y1) / 2.0 - chant[1]),
       "const BTN_CHANT := %s  # chant strip: the buttons" % rect_chant(BTN["chant"]),
       "const BTN_CLEAR := %s" % rect_chant(BTN["clear"]),
       "const BTN_PASS := %s" % rect_chant(BTN["pass"]),
       "const REST_X := %.1f  # bag strip: left edge of the leftmost resting Essence" % (785.3 - bag0[0]),
       "const AXIS_Y := %.1f  # the row the Essence roll along" % (AXIS - bag0[1]),
       "const REST_STEP := 60.1",
       "const REST_END := %.1f  # the resting Essence end before this x (the Pipe's left end)" % (PIPE_LEFT - bag0[0] + 4.0),
       "const PIPE_LEFT := %.1f  # where the Pipe (the tube out of the machine) starts, from the Bag strip's left" % (PIPE_LEFT - bag0[0]),
       "",
       "# the left part of the HUD, absolute",
       "const HP_BAR := %s" % rect_abs(R["hp_bar_full"]),
       "const HEART_AT := %s  # top-left of the heart (28 px)" % vec(72.0, 923.0),
       "const HP_TEXT_AT := %s  # top-left of the \"HP 37 / 50\" text" % vec(126.0, 924.0),
       "const SHIELD_AT := %s  # top-left of the shield picture (28 px)" % vec(246.0, 923.0),
       "const SHIELD_TEXT_AT := %s" % vec(288.0, 924.0),
       "const MENU := %s" % rect_abs(R["menu"]),
       "const BOTTLES := %s  # the bottles' frame; the bottles are 52 px squares side by side, 8 px in" % rect_abs(R["bottles_frame"]),
       "const ARTIFACTS := %s  # the artifacts' frame: ten slots" % rect_abs(R["artifacts_frame"]),
       "const ART_X0 := 14.0  # first artifact slot: x from the frame's left",
       "const ART_STEP := 50.5",
       "const ART_PX := 48.0",
       ]
with open(LAYOUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("wrote", os.path.relpath(LAYOUT, HERE))
