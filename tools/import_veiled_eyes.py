"""The Veiled Eyes (Act 2 boss, 2026-10-19): the user's cut pictures in Enemies/Act2/Veiled Eyes/ -> square canvases, bottom-aligned, in Enemies/Act2/.
  Veiled Eyes Phase 1 / Phase 2 / Phase 2 Lit -> veiled_eyes.png / veiled_eyes_2.png / veiled_eyes_2_lit.png (all on the SAME canvas size, so the phase change
  does not resize it); Spiderling -> spiderling.png (smaller on its canvas); Silk Cocoon -> spider_cocoon.png.
The unveiling animation (animation.pdf in the same folder) is made of the user's cut pieces, put on the same canvas at the place they have in phase 2 (found by
template matching against Phase 2.png: head at (459, 575), left legs at (1, 469), right legs at (846, 482), all at scale 1; the veil-less ball unveiled.png at scale 1.08,
(195, 0)): veiled_eyes_u_ball / _head / _legl / _legr.png. Creature plays them when the Veiled Eyes go from phase 1 to 2 (see Creature._draw_unveil).
Run:  python -I tools/import_veiled_eyes.py   (then Godot --headless --editor --quit once, to import the new pictures)"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "Enemies", "Act2", "Veiled Eyes")
OUT = os.path.join(AP.PUPPET, "Enemies", "Act2")
PAD = 0.04


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def put(im, side, bottom_pad=PAD * 0.5):
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * bottom_pad)))
    return c


def main():
    pics = {n: trim(Image.open(os.path.join(SRC, n + ".png")).convert("RGBA")) for n in
            ["Veiled Eyes Phase 1", "Veiled Eyes Phase 2", "Veiled Eyes Phase 2 Lit", "Spiderling", "Silk Cocoon"]}
    # phase 2 and its lit twin are one pose: they must land on the same pixels (the lit one is drawn over the other)
    p2, lit = pics["Veiled Eyes Phase 2"], pics["Veiled Eyes Phase 2 Lit"]
    side = int(max(max(p.size) for n, p in pics.items() if n.startswith("Veiled")) * (1 + PAD * 2))
    # phase 1 is scaled so that its ball is as big as the ball of phase 2 (the eyes are as far apart as in phase 2), and the two pairs of eyes lie on the same
    # spot: its ropes then fit phase 2 too
    P1_EYES = ((400, 505), (865, 495))  # (the human eyes in the cut picture of phase 1)
    P2_EYES = ((470, 350), (860, 355))
    k = (P2_EYES[1][0] - P2_EYES[0][0]) / float(P1_EYES[1][0] - P1_EYES[0][0])
    p1 = pics["Veiled Eyes Phase 1"]
    p1 = p1.resize((round(p1.width * k), round(p1.height * k)), Image.LANCZOS)
    ox2, oy2 = (side - p2.width) // 2, side - p2.height - int(side * PAD * 0.5)
    mid2 = ((P2_EYES[0][0] + P2_EYES[1][0]) / 2 + ox2, (P2_EYES[0][1] + P2_EYES[1][1]) / 2 + oy2)
    mid1 = ((P1_EYES[0][0] + P1_EYES[1][0]) / 2 * k, (P1_EYES[0][1] + P1_EYES[1][1]) / 2 * k)
    ox1, oy1 = round(mid2[0] - mid1[0]), round(mid2[1] - mid1[1])
    c1 = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c1.alpha_composite(p1, (ox1, oy1))
    c1.save(os.path.join(OUT, "veiled_eyes.png"))
    put(p2, side).save(os.path.join(OUT, "veiled_eyes_2.png"))
    put(lit, side).save(os.path.join(OUT, "veiled_eyes_2_lit.png"))
    sp = pics["Spiderling"]
    put(sp, int(max(sp.size) * 1.7)).save(os.path.join(OUT, "spiderling.png"))
    co = pics["Silk Cocoon"]
    put(co, int(max(co.size) * 1.5)).save(os.path.join(OUT, "spider_cocoon.png"))
    pieces = {"u_head": ("Layer 2.png", 1.0, (459, 575)), "u_legl": ("Layer 3.png", 1.0, (1, 469)), "u_legr": ("Layer 4.png", 1.0, (846, 482)),
              "u_ball": ("unveiled.png", 1.08, (195, 0))}
    for key, (fname, k2, (px, py)) in pieces.items():
        im = Image.open(os.path.join(SRC, fname)).convert("RGBA")
        if k2 != 1.0:
            im = im.resize((round(im.width * k2), round(im.height * k2)), Image.LANCZOS)
        cv = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        cv.alpha_composite(im, (px + ox2, py + oy2))
        cv.save(os.path.join(OUT, "veiled_eyes_%s.png" % key))
    print('scale of phase 1', round(k, 3), end="  ")
    print("canvas", side, "phase 1 offset", (ox1, oy1), "phase 2 offset", (ox2, oy2), "(phase 2 and lit are different sizes: %s %s)" % (p2.size, lit.size))
    # eye positions, as fractions of the canvas (picked off the pictures: phase 1 human eyes; phase 2 human eyes and the six spider eyes)
    def f(x, y, ox, oy):
        return "Vector2(%.4f, %.4f)" % ((x + ox) / side, (y + oy) / side)
    print("p1 eyes  L", f(400 * k, 505 * k, ox1, oy1), "R", f(865 * k, 495 * k, ox1, oy1))
    print("p2 eyes  L", f(470, 350, ox2, oy2), "R", f(860, 355, ox2, oy2))
    for k, (x, y) in {"outerL": (547, 745), "topL": (617, 717), "bigL": (607, 768), "topR": (716, 715), "outerR": (785, 742), "bigR": (718, 768)}.items():
        print("p2 spider", k, f(x, y, ox2, oy2))


if __name__ == "__main__":
    main()
