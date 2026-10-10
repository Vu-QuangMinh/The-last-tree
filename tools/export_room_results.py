"""Page 2 of assets/ui/Room Background.pdf: the pictures shown after a room's choice (so far the Wandering Apothecary: Snatch,
Walk on, Pay). Each is cut out of the page (the labels beside them removed) in two layers, both drawn 1930 px wide and cropped
to the middle 1920 x 1080 (so the swaying wood never shows a picture edge):
  room_<room>_<name>.png        the whole picture, still (it also fills any gap the swaying wood opens up)
  room_<room>_<name>_trees.png  the wood: the drawings the picture shares with page 1's loose "Rừng cây" forest (found by
                                their drawing signature). The game sways this layer in the wind.
  room_<room>_<name>_front.png  everything else (ground, roots, characters...), still, drawn over the wood.
Both go to assets/ui/new/room/ and Backdrop.room picks them up by name.

Run:  python tools/export_room_results.py     (needs pymupdf, pillow)
"""
import io
import os
import re
import sys

import pymupdf
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from export_room_background import align, stream_ops, sig, centre  # noqa: E402  (the same page-stream helpers)

SRC = os.path.join(HERE, "..", "assets", "ui", "Room Background.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "new", "room")
ROOM = "apothecary"
LABELS = {"Snatch": "snatch", "Walk": "walk", "Pay": "pay"}  # the label word beside each picture -> its name
W_BIG = 1930  # drawn a little larger than the stage, then cropped


def main():
    doc = pymupdf.open(SRC)
    page0, page = doc[0], doc[1]
    d0, d1 = page0.get_drawings(), page.get_drawings()
    # the loose forest of page 1 (below the main picture, left of its label)
    lw = [w for w in page0.get_text("words") if w[4] == "Rừng"][0]
    forest = [x for x in d0 if x["rect"].x1 < 420 and x["rect"].y1 > 283 and centre(x["rect"]).y < lw[1] + 2]
    forest_sigs = {sig(x) for x in forest}
    print("forest drawings", len(forest))
    words = [(w[:4], w[4]) for w in page.get_text("words")]
    lines = doc.xref_stream(page.get_contents()[0]).decode("latin1").split("\n")
    ops = stream_ops(lines, page.rect.height)
    op_line = align(ops, d1)
    all_ops = [n for n, _bb in ops]
    no_text = [("" if re.search(r"\bT[jJ]\b", ln) else ln) for ln in lines]
    d2 = pymupdf.open(SRC)
    x2 = d2[1].get_contents()[0]
    SH = re.compile(r"/\w+ sh")
    XO = re.compile(r"/\w+ Do")
    PAINT = ("f", "f*", "S", "s", "B", "B*", "b", "b*")

    def render(idxs, pic):
        ln = list(no_text)
        keep = {op_line[i] for i in idxs}
        for e in all_ops:
            if e not in keep:
                ln[e] = "n" if ln[e].strip() in PAINT else XO.sub("", SH.sub("", ln[e]))
        d2.update_stream(x2, "\n".join(ln).encode("latin1"))
        k = W_BIG / pic.width
        pm = d2.load_page(1).get_pixmap(matrix=pymupdf.Matrix(k, k), clip=pic, alpha=True)
        im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
        h = round(W_BIG * pic.height / pic.width)
        im = im.resize((W_BIG, h), Image.LANCZOS)
        x0, y0 = (W_BIG - 1920) // 2, (h - 1080) // 2
        return im.crop((x0, y0, x0 + 1920, y0 + 1080))

    for r, t in words:
        if t not in LABELS:
            continue
        cy = (r[1] + r[3]) / 2
        band = pymupdf.Rect(0, cy - 125, 440, cy + 125)  # the picture is left of its label, level with it
        wide = pymupdf.Rect(band.x0, band.y0 - 40, band.x1, band.y1 + 40)  # (artwork that pokes out of the picture's frame is clipped by the page)
        idx = [i for i, x in enumerate(d1) if wide.contains(centre(x["rect"]))]
        # the picture's frame: what shows when everything is drawn
        probe = doc[1].get_pixmap(matrix=pymupdf.Matrix(2, 2), clip=band, alpha=True)
        a = Image.open(io.BytesIO(probe.tobytes("png"))).convert("RGBA").getchannel("A").point(lambda v: 255 if v > 200 else 0)
        bb = a.getbbox()
        pic = pymupdf.Rect(band.x0 + bb[0] / 2.0, band.y0 + bb[1] / 2.0, band.x0 + bb[2] / 2.0, band.y0 + bb[3] / 2.0)
        trees = [i for i in idx if sig(d1[i]) in forest_sigs]
        rest = [i for i in idx if i not in set(trees)]
        name = "room_%s_%s" % (ROOM, LABELS[t])
        render(trees, pic).save(os.path.join(OUT, name + "_trees.png"))
        render(rest, pic).save(os.path.join(OUT, name + "_front.png"))
        render(idx, pic).save(os.path.join(OUT, name + ".png"))
        print(name, "trees", len(trees), "rest", len(rest), [round(v, 1) for v in pic])


if __name__ == "__main__":
    main()
