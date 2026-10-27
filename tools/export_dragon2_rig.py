"""Winter Wyvern rig (2026-10-28), from the user's Dragon2/Dragon.pdf (frost dragon drawn as separate pieces: head, jaw, throat, neck, body, open wing,
closed wing, 3 tail segments) -> assets/Puppet/Enemies/Act3/dragon_rig/<piece>.png (full size, as placed in the PDF) + scripts/ui/dragon_layout.gd (generated)
+ assets/Puppet/Enemies/Act3/winter_wyvern.png (the idle pose assembled: menus / codex / shadow).
The PDF shows the dragon in four poses (idle, breathing fire, wing covering the front, wing covering the back) built from the same pictures, each
placed with its own matrix. The joints of the head / neck chain are found from them: a joint is the one point that the parent and the child carry
along together when the dragon goes from idle to the fire pose. The tail pegs and the wing root are read off the pictures by hand (TAIL_PEG, WING_ROOT).
Coordinates of the layout file: the BODY picture's own pixels (origin top left of the body, 1 unit = 1 body pixel).
Run with a python that has pymupdf, numpy and Pillow:  C:/Users/sonvt/AppData/Local/Programs/Python/Python312/python.exe tools/export_dragon2_rig.py
(then Godot --headless --editor --quit once)."""
import math
import os
import sys

import numpy as np
import pymupdf
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

ACT3 = os.path.join(AP.PUPPET, "Enemies", "Act3")
PDF = os.path.join(ACT3, "Dragon2", "Dragon.pdf")
OUT = os.path.join(ACT3, "dragon_rig")  # (NOT inside Dragon2/: that folder is the user's own, its head.png was overwritten once)
LAYOUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "ui", "dragon_layout.gd")
NAMES = {12: "tail1", 14: "tail2", 13: "tail3", 15: "body", 16: "neck", 17: "wing_open", 18: "throat", 19: "jaw", 20: "head", 21: "wing_closed"}
GROUPS = {"idle": range(0, 9), "fire": range(9, 18), "front": range(18, 27), "back": range(27, 36)}  # (indices in page.get_image_info: paint order)
CHAIN = [("neck", "body"), ("throat", "neck"), ("head", "throat"), ("jaw", "head")]
# hand-read joints, as fractions of the child's picture: where the peg of a tail segment goes into the one before it; where the wing's arm meets the body
TAIL_PEG = {"tail1": (0.04, 0.30), "tail2": (0.04, 0.30), "tail3": (0.06, 0.38)}
WING_ROOT = (0.05, 0.91)
PAINT = ["tail1", "tail3", "tail2", "body", "neck", "wing_open", "throat", "jaw", "head"]  # idle paint order (back to front)


def main():
    doc = pymupdf.open(PDF)
    page = doc[0]
    info = page.get_image_info(xrefs=True)
    os.makedirs(OUT, exist_ok=True)
    size = {}
    for x, n in NAMES.items():
        pix = pymupdf.Pixmap(doc, x)
        sm = doc.extract_image(x).get("smask", 0)
        if sm:
            pix = pymupdf.Pixmap(pix, pymupdf.Pixmap(doc, sm))
        pix.save(os.path.join(OUT, n + ".png"))
        size[n] = (pix.width, pix.height)
    poses = {}
    for g, rng in GROUPS.items():
        poses[g] = {}
        for i in rng:
            im = info[i]
            a, b, c, d, e, f = im["transform"]
            w, h = im["width"], im["height"]
            poses[g][NAMES[im["xref"]]] = np.array([[a / w, c / h, e], [b / w, d / h, f], [0, 0, 1]])  # (picture pixel -> page)
    binv = {g: np.linalg.inv(poses[g]["body"]) for g in poses}
    rel = {g: {k: binv[g] @ m for k, m in poses[g].items()} for g in poses}  # (-> the body's own pixels)

    def disp(k):
        return rel["fire"][k] @ np.linalg.inv(rel["idle"][k])

    joint = {}
    angle = {}
    for c, par in CHAIN:
        dc = disp(c)
        dp = np.eye(3) if par == "body" else disp(par)
        j = np.linalg.lstsq(dc[:2, :2] - dp[:2, :2], dp[:2, 2] - dc[:2, 2], rcond=None)[0]
        joint[c] = j
        ang = lambda m: math.degrees(math.atan2(m[1, 0], m[0, 0]))
        angle[c] = ang(dc) - (ang(dp) if par != "body" else 0.0)
        print("  joint %-7s body px (%.1f, %.1f)   fire angle %.1f" % (c, j[0], j[1], angle[c]))
    for k, (fx, fy) in TAIL_PEG.items():
        w, h = size[k]
        p = rel["idle"][k] @ np.array([fx * w, fy * h, 1.0])
        joint[k] = p[:2]
    w, h = size["wing_open"]
    joint["wing_open"] = (rel["idle"]["wing_open"] @ np.array([WING_ROOT[0] * w, WING_ROOT[1] * h, 1.0]))[:2]

    def tf(m):  # a Godot Transform2D(x axis, y axis, origin)
        return "Transform2D(Vector2(%.5f, %.5f), Vector2(%.5f, %.5f), Vector2(%.3f, %.3f))" % (m[0, 0], m[1, 0], m[0, 1], m[1, 1], m[0, 2], m[1, 2])

    # the idle pose assembled (also the single picture of the dragon)
    corners = []
    for k in PAINT:
        w, h = size[k]
        for px, py in ((0, 0), (w, 0), (0, h), (w, h)):
            corners.append((rel["idle"][k] @ np.array([px, py, 1.0]))[:2])
    cs = np.array(corners)
    x0, y0 = math.floor(cs[:, 0].min()) - 4, math.floor(cs[:, 1].min()) - 4
    x1, y1 = math.ceil(cs[:, 0].max()) + 4, math.ceil(cs[:, 1].max()) + 4
    canvas = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    for k in PAINT:
        im = Image.open(os.path.join(OUT, k + ".png")).convert("RGBA")
        inv = np.linalg.inv(rel["idle"][k] @ np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1.0]]))
        shift = np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1.0]])
        a = inv @ shift
        canvas.alpha_composite(im.transform(canvas.size, Image.AFFINE, (a[0, 0], a[0, 1], a[0, 2], a[1, 0], a[1, 1], a[1, 2]), Image.BICUBIC))
    bb = canvas.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    full = canvas.crop(bb)
    ground = bb[3] + y0  # (the lowest painted row, in body px: the dragon's feet)
    ext = (bb[0] + x0, bb[1] + y0, bb[2] + x0, bb[3] + y0)
    side = int(max(full.size) * 1.08)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(full, ((side - full.width) // 2, side - full.height - int(side * 0.02)))
    sq.save(os.path.join(ACT3, "winter_wyvern.png"))

    lines = ["# Generated by tools/export_dragon2_rig.py from Dragon2/Dragon.pdf: do not edit by hand.",
             "class_name DragonLayout", "extends RefCounted",
             "## Coordinates: the body picture's own pixels (origin top left). A piece's IDLE transform maps its picture pixels into that space.",
             "", "const SIZE := {"]
    for k in size:
        lines.append('\t"%s": Vector2(%d, %d),' % (k, size[k][0], size[k][1]))
    lines += ["}", "const IDLE := {"]
    for k in size:
        lines.append('\t"%s": %s,' % (k, tf(rel["idle"][k] if k in rel["idle"] else rel["front"][k])))  # (the closed wing is not in the idle pose: its front placement)
    lines += ["}", "## The closed wing: where it lies when it covers the front / the back of the body.",
              "const WING_FRONT := " + tf(rel["front"]["wing_closed"]), "const WING_BACK := " + tf(rel["back"]["wing_closed"]),
              "## Joints (body px): neck on the body, throat on the neck, head on the throat, jaw on the head; each tail segment on the one before; the wing's root.",
              "const JOINT := {"]
    for k, j in joint.items():
        lines.append('\t"%s": Vector2(%.2f, %.2f),' % (k, j[0], j[1]))
    lines += ["}", "## The fire-breathing pose of the PDF (degrees, each relative to its parent; clockwise is positive).", "const FIRE_DEG := {"]
    for k, a in angle.items():
        lines.append('\t"%s": %.2f,' % (k, a))
    lines += ["}", "const EXTENT := Rect2(%d, %d, %d, %d)  # (the idle dragon's box)" % (ext[0], ext[1], ext[2] - ext[0], ext[3] - ext[1]),
              "const GROUND := %d  # (y of its feet)" % ground, "const PAINT := %s" % str(PAINT).replace("'", '"'), ""]
    with open(LAYOUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("done: layout, %d pieces, extent %s, ground %d" % (len(size), ext, ground))


if __name__ == "__main__":
    main()
