"""New UI theme: the HUD pieces painted in page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf -> assets/Puppet/UI/NewUi/*.png (and the straight tube of the machine).
The page is 1920 x 1080 pt = the screen, so a piece's place on the page is its place on the screen (written in scripts/ui/new_ui_layout.gd; the positions printed here are
what is there). Pictures are taken straight from the PDF (page.get_image_info / extract_image, with their soft masks); the glass HP tube is vector art in the page's legend
("HP Bar") and the straight tube is the legend's "Tube bong lan": both are rendered alone on a transparent background.
Run: python tools/export_new_ui_art.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import os
import sys

import numpy as np
import pymupdf
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "NewUi")
SLOT = os.path.join(AP.PUPPET, "UI", "SlotMachine")
doc = pymupdf.open(SRC)
page = doc[1]


def picture(xref):
    info = doc.extract_image(xref)
    pix = pymupdf.Pixmap(doc, xref)
    if pix.n - pix.alpha == 4:
        pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
    if info.get("smask"):
        pix = pymupdf.Pixmap(pix, pymupdf.Pixmap(doc, info["smask"]))
    tmp = os.path.join(OUT, "_tmp.png")
    pix.save(tmp)
    im = Image.open(tmp).convert("RGBA")
    os.remove(tmp)
    return im


def scaled(im, k):
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def place_of(xref):
    r = [i["bbox"] for i in page.get_image_info(xrefs=True) if i.get("xref") == xref]
    return [tuple(round(v, 2) for v in b) for b in r]


os.makedirs(OUT, exist_ok=True)
INFO = page.get_image_info(xrefs=True)


def find(w, h, near=None):
    """The xref of the picture w x h px (the first one nearest to `near` = (x, y) of its top left, when it is used more than once)."""
    c = [i for i in INFO if i["width"] == w and i["height"] == h and i.get("xref")]
    if near is not None:
        c.sort(key=lambda i: abs(i["bbox"][0] - near[0]) + abs(i["bbox"][1] - near[1]))
    return c[0]["xref"] if c else None


# (the xrefs change every time the PDF is saved: the pictures are found by their size in px, and the two HP layers by where the legend ("Lower layer" / "Upper layer") has them)
for name, xref, k in [("nu_block_left", find(2373, 583), 0.5), ("nu_block_wide", find(3080, 746), 0.5), ("nu_slot_strip", find(1662, 353), 0.5), ("nu_bag_tray", find(2954, 320), 0.5),
                      ("nu_hp_lower", find(1961, 276, (249.0, 384.0)), 0.5), ("nu_hp_upper", find(1961, 276, (249.0, 467.0)), 0.5)]:
    im = scaled(picture(xref), k)
    im.save(os.path.join(OUT, name + ".png"))
    print("%-14s %s  places (x0, y0, x1, y1): %s" % (name, im.size, place_of(xref)))

# the tube's mouth: the picture is turned a quarter (its columns run down the page): stand it up
mouth_x = [i for i in INFO if i["width"] == 2048 and i["height"] == 2048 and i["bbox"][2] - i["bbox"][0] < 20 and i.get("xref")]
im = picture(mouth_x[0]["xref"])
arr = np.array(im).transpose(1, 0, 2)[:, ::-1]
from scipy import ndimage
if arr[:, :, 3].min() == 255:  # (this one comes without its soft mask: the white around it is cut out by flood fill from the border)
    white = arr[:, :, :3].min(axis=2) > 225
    lab, n = ndimage.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    arr = arr.copy()
    arr[np.isin(lab, list(edge)), 3] = 0
mouth = Image.fromarray(arr).resize((31, 197), Image.LANCZOS)
mouth.save(os.path.join(OUT, "nu_tube_mouth.png"))
print("nu_tube_mouth  ", mouth.size, [tuple(round(v, 2) for v in mouth_x[0]["bbox"])])

# the glass HP tube's own pieces, from the page's legend ("HP fill" = the glass with its shine, a pill flat at the left end and round at the right; "HP cap" = the brass cap on its
# left end). The legend sits on a grey board: the board's vector fill is taken out on a copy of the page (a redaction that removes the line art it covers, keeping pictures and text),
# so these two pieces render alone on a transparent background (3 px per pt). Each piece is the exact box the page gives it (the layout's own place is printed in NewUiLayout).
Z3 = 3
tmpdoc = pymupdf.open()
tmpdoc.insert_pdf(doc, from_page=1, to_page=1)
tp = tmpdoc[0]
tp.add_redact_annot(pymupdf.Rect(50, 230, 640, 660))
tp.apply_redactions(images=pymupdf.PDF_REDACT_IMAGE_NONE, graphics=pymupdf.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED, text=pymupdf.PDF_REDACT_TEXT_NONE)
for name, box in [("nu_hp_gloss", pymupdf.Rect(274, 461, 584, 493)), ("nu_hp_cap", pymupdf.Rect(267, 419, 279, 452))]:
    pm = tp.get_pixmap(dpi=72 * Z3, clip=box, alpha=True)
    tmp = os.path.join(OUT, "_tmp.png")
    pm.save(tmp)
    gi = Image.open(tmp).convert("RGBA")
    os.remove(tmp)
    gi.save(os.path.join(OUT, name + ".png"))
    print("%-14s %s  (%.0f x %.0f pt)" % (name, gi.size, box.width, box.height))

# a debuff circle: the thin brass ring of the first one (the page draws it in a 67.87 pt box); its bounding box is printed
ring_box = pymupdf.Rect(345.4 - 22.0, 884.45 - 22.0, 345.4 + 22.0, 884.45 + 22.0)  # (only this ring: the boxes of the neighbours overlap it)
rp = page.get_pixmap(dpi=72 * 4, clip=ring_box, alpha=True)
tmp = os.path.join(OUT, "_tmp.png")
rp.save(tmp)
ri = Image.open(tmp).convert("RGBA")
os.remove(tmp)
bb = ri.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
ri = ri.crop(bb)
ri.save(os.path.join(OUT, "nu_debuff_ring.png"))
print("nu_debuff_ring  %s  at pt (%.2f, %.2f) size %.2f x %.2f" % (ri.size, ring_box.x0 + bb[0] / 4.0, ring_box.y0 + bb[1] / 4.0, ri.width / 4.0, ri.height / 4.0))

# the straight tube of the machine (legend "Tube bong lan", 2 px per pt): only the part right of the mouth (88 px = 44 pt from its left end) is seen
tube = page.get_pixmap(dpi=72 * 2, clip=pymupdf.Rect(806, 503, 1116, 593), alpha=True)
tube.save(os.path.join(OUT, "_tube.png"))
t = Image.open(os.path.join(OUT, "_tube.png")).convert("RGBA")
os.remove(os.path.join(OUT, "_tube.png"))
t.crop((88, 0, t.width, t.height)).save(os.path.join(SLOT, "slot_tube_straight.png"))
print("slot_tube_straight", (t.width - 88, t.height))
