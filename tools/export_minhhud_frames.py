"""MinhHUD.pdf -> one flat "frame" picture per part (the layout the user drew: shape, proportions, where the sockets are), padded to the ratio
of the ImageSet set that will redraw it. Only the vector drawings are replayed (no text labels, arrows or Essence pictures), on white.
Output: assets/Puppet/UI/MinhHUD/_Frames/<Name>.png  (Name = object name in minhhud_prompts.txt).
Run:  python tools/export_minhhud_frames.py"""
import os
import sys

import pymupdf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

DIR = os.path.join(AP.PUPPET, "UI", "MinhHUD")
PDF = os.path.join(DIR, "MinhHUD.pdf")
OUT = os.path.join(DIR, "_Frames")
SCALE = 3.0

# name: (ratio w/h, bbox on the page (pt) that contains the part, or explicit drawing indexes)
INSIDE = {
    "Artifact Cabinet": (16 / 9, (82, 80, 381, 279)),
    "Bottle Cabinet": (1.0, (539, 78, 747, 277)),
    "Button Chant Pass": (1.0, (932, 46, 1163, 277)),
    "Chant Tray": (16 / 9, (946, 589, 1540, 667)),
    "Glass Tray": (16 / 9, (872, 411, 1464, 487)),
    "Glass Pipe": (1.0, (432, 331, 842, 677)),  # the looped pipe the user drew on its own (2026-11-10 PDF)
}
# parts taken from the assembled HUD at the bottom of the page (the pieces drawn twice on the page top are only a hint for the animation)
EXPLICIT = {
    "Glass Flask Disc": (1.0, [147]),
    "Brass Hub": (1.0, [148]),
    "Brass Lever": (9 / 16, [149]),
    "HUD Base": (16 / 9, [0]),
}


def replay(page, d):
    sh = page.new_shape()
    for it in d["items"]:
        k = it[0]
        if k == "l":
            sh.draw_line(it[1], it[2])
        elif k == "c":
            sh.draw_bezier(it[1], it[2], it[3], it[4])
        elif k == "re":
            sh.draw_rect(it[1])
        elif k == "qu":
            sh.draw_quad(it[1])
    sh.finish(fill=d.get("fill"), color=d.get("color"), width=d.get("width") or 1, closePath=d.get("closePath", False), even_odd=d.get("even_odd", False),
              fill_opacity=d.get("fill_opacity") or 1, stroke_opacity=d.get("stroke_opacity") or 1)
    sh.commit()


def render(drawings, ratio, path, margin=0.08):
    rect = drawings[0]["rect"]
    for d in drawings[1:]:
        rect |= d["rect"]
    w, h = rect.width, rect.height
    pad = max(w, h) * margin
    cw, ch = w + 2 * pad, h + 2 * pad
    if cw / ch < ratio:
        cw = ch * ratio
    else:
        ch = cw / ratio
    cx, cy = (rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2
    doc = pymupdf.open()
    page = doc.new_page(width=cw, height=ch)
    page.draw_rect(page.rect, color=None, fill=(1, 1, 1))
    off = pymupdf.Matrix(1, 0, 0, 1, cw / 2 - cx, ch / 2 - cy)
    for d in drawings:
        d2 = dict(d)
        d2["items"] = [(it[0],) + tuple(x * off if isinstance(x, (pymupdf.Point, pymupdf.Rect, pymupdf.Quad)) else x for x in it[1:]) for it in d["items"]]
        replay(page, d2)
    page.get_pixmap(matrix=pymupdf.Matrix(SCALE, SCALE)).save(path)
    print(os.path.basename(path), int(cw * SCALE), "x", int(ch * SCALE))


def main():
    os.makedirs(OUT, exist_ok=True)
    page = pymupdf.open(PDF)[0]
    drawings = page.get_drawings()
    for name, (ratio, box) in INSIDE.items():
        b = pymupdf.Rect(box)
        sel = [d for d in drawings if b.contains(d["rect"]) and d["rect"].width + d["rect"].height > 0]
        render(sel, ratio, os.path.join(OUT, name + ".png"))
    for name, (ratio, idx) in EXPLICIT.items():
        render([drawings[i] for i in idx], ratio, os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    main()
