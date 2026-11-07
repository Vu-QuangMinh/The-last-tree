"""Theme "Puppet HUD ver 2": the pieces the user cut himself in assets/Puppet/UI/Hud2/Puppet HUD Nov.pdf (page 2 = the assembled screen, 2048 x 1152 pt) -> assets/Puppet/UI/Hud2/*.png:
the Essence cup (one of the ten cups of the right board, with its own alpha), the round hole at the tray's right end, the vertical glass tube (the page has it turned a quarter and
mirrored: stood up here). Everything else (boards, slot frames, buttons) is made by ImageSet (tools/make_hud2_art.py) and cut by tools/import_hud2_art.py; the tray stays the earlier ImageSet one.
Pictures are found by where they stand on the page (the xrefs change every time the PDF is saved). Saved at 2 px per PDF pt (the game is 1920 x 1080: scripts/ui/hud2_layout.gd scales by 0.9375).
Run: python tools/export_hud2_art.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import os
import sys

import numpy as np
import pymupdf
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "UI", "Hud2", "Puppet HUD Nov.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "Hud2")
os.makedirs(OUT, exist_ok=True)
S = 2  # px per pt
doc = pymupdf.open(SRC)
rng = np.random.default_rng(7)


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


def at(x, y, w=None):
    """The xref of the picture whose top left is near (x, y) pt on page 2 (and, when given, that is about w pt wide)."""
    best = None
    for i in doc[1].get_image_info(xrefs=True):
        if not i.get("xref"):
            continue
        d = abs(i["bbox"][0] - x) + abs(i["bbox"][1] - y)
        if (w is None or abs((i["bbox"][2] - i["bbox"][0]) - w) < 3) and (best is None or d < best[0]):
            best = (d, i["xref"])
    if best is None or best[0] > 6:
        raise SystemExit("no picture at %s, %s (w %s)" % (x, y, w))
    return best[1]


tube = picture(at(1894, 710))


def circle_sprite(x, y, cx, cy, r, name, ppt=6):
    """The user cut the cup and the hole with a round clip in the PDF (the picture itself is a square photo): render the page with only that picture left and keep the disc
    (centre cx, cy pt, radius r pt) around it, `ppt` px per pt. The page's gold board edge (vector art) lies outside the disc."""
    t = pymupdf.open()
    t.insert_pdf(doc, from_page=1, to_page=1)
    p = t[0]
    infos = [i for i in p.get_image_info(xrefs=True) if i.get("xref")]
    keep = {i["xref"] for i in infos if abs(i["bbox"][0] - x) < 3 and abs(i["bbox"][1] - y) < 3}
    for xr in {i["xref"] for i in infos} - keep:
        p.delete_image(xr)
    p.add_redact_annot(pymupdf.Rect(0, 0, 2048, 1152))
    p.apply_redactions(images=pymupdf.PDF_REDACT_IMAGE_NONE, graphics=pymupdf.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED, text=pymupdf.PDF_REDACT_TEXT_REMOVE)
    pm = p.get_pixmap(dpi=72 * ppt, clip=pymupdf.Rect(cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), alpha=True)
    tmp = os.path.join(OUT, "_tmp.png")
    pm.save(tmp)
    im = Image.open(tmp).convert("RGBA")
    os.remove(tmp)
    n = im.width
    m = Image.new("L", (n * 3, n * 3), 0)
    ImageDraw.Draw(m).ellipse([(n / 2 - r * ppt) * 3, (n / 2 - r * ppt) * 3, (n / 2 + r * ppt) * 3, (n / 2 + r * ppt) * 3], fill=255)
    m = m.resize((n, n), Image.LANCZOS)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), m))
    im.save(os.path.join(OUT, name + ".png"))
    print(name, im.size, "disc r = %.1f pt at (%.1f, %.1f)" % (r, cx, cy))


circle_sprite(1107, 930, 1160.2, 982.5, 32.0, "hud2_cup")  # the first cup (its neighbours are 74 pt away)
circle_sprite(1833, 1003, 1896.1, 1066.1, 32.0, "hud2_hole")
# the vertical tube: the page has it turned -90 degrees and mirrored (found by comparing the page's render with the four turns)
tube.rotate(-90, expand=True).transpose(Image.FLIP_LEFT_RIGHT).resize((294, 804), Image.LANCZOS).save(os.path.join(OUT, "hud2_tube_v.png"))
print("hud2_tube_v 294x804")
