"""NewUI Ver2: takes the pictures the user placed in assets/Puppet/UI/NewUiV2/HUD.pdf (page 1 = the HUD layout, page 2 = the notes) out of the PDF AT THEIR OWN PIXEL SIZE (never resized: the user's rule) and
writes them under the names the game looks for. The alpha is the PDF image's own mask. The buttons' hover / pressed / disabled are tints of the normal one.
    python tools/extract_newui2_pdf.py        (system python: pymupdf)
The places and sizes of everything on that page are the constants of scripts/ui/newui2_layout.gd (read off the PDF's content stream)."""
import io
import os
import sys

import pymupdf
from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP
import import_newui2_art as _I  # (save_safe: an existing sprite is backed up to _Backup before it is replaced)

DIR = os.path.join(AP.PUPPET, "UI", "NewUiV2")
# PDF image xref -> output name ("states:" = four button states)
XREFS = {599: "nu2_plate_red", 600: "nu2_plate_small", 603: "nu2_hose", 612: "nu2_plate_long", 618: "nu_hp_lower", 619: "slot_tube_straight", 620: "nu2_connector", 615: "slot_funnel_top",
         617: "slot_funnel_upper", 601: "slot_body", 602: "chant_slot_empty", 614: "states:button_clear", 604: "states:button_chant", 613: "states:button_pass", 605: "nu2_art_cabinet", 606: "nu_bag_tray",
         607: "nu2_tube_hole", 626: "nu2_rack5", 627: "nu2_rack5_upper", 608: "nu2_rack3", 625: "nu2_rack3_upper", 609: "nu2_menu", 610: "nu2_paper"}
# (616 is a marker Essence the user put in the funnel to show where the bonus Essence go and its z order; not a sprite)
# (the debuff ring, xref 611, is the 165 px placeholder of the old theme: the 2047 px redo nu_debuff_ring.png stays)


def image_of(doc, xref):
    info = doc.extract_image(xref)
    im = Image.open(io.BytesIO(info["image"])).convert("RGBA")
    if info.get("smask"):
        m = Image.open(io.BytesIO(doc.extract_image(info["smask"])["image"])).convert("L")
        if m.size != im.size:
            raise SystemExit("mask size differs from the picture: %s" % xref)
        im.putalpha(m)
    return im


def tinted(im, state):
    if state == "normal":
        return im
    rgb, a = im.convert("RGB"), im.getchannel("A")
    if state == "hover":
        rgb = ImageEnhance.Brightness(rgb).enhance(1.15)
    elif state == "pressed":
        rgb = ImageEnhance.Brightness(rgb).enhance(0.72)
    else:
        rgb = ImageEnhance.Brightness(ImageEnhance.Color(rgb).enhance(0.45)).enhance(0.8)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def main():
    doc = pymupdf.open(os.path.join(DIR, "HUD.pdf"))
    for xref, name in XREFS.items():
        im = image_of(doc, xref)
        if name.startswith("states:"):
            for st in ("normal", "hover", "pressed", "disabled"):
                _I.save_safe(tinted(im, st), os.path.join(DIR, "%s_%s.png" % (name[7:], st)))
        else:
            _I.save_safe(im, os.path.join(DIR, name + ".png"))
        print("%-22s xref %-3d %s" % (name, xref, im.size))


if __name__ == "__main__":
    main()
