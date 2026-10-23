"""Puppet Stage theme: the cream slot frame (Bottle Slot / Artifact Slot) of page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 1080 = the screen).
The page shows the artifact slot's template as 3 x 3 pieces with gaps between them (rows 39.3 / 9.9 / 39 pt, columns 68.6 / 98.2 / 53.3 pt); this puts them together
with no gap into UI/Panels/slot_board.png, a 9-slice that holds the bottles' frame (one row, 88 pt tall) and the artifacts' frame (two rows, 104 pt tall).
Each piece is the page rendered inside its box.
Run: python tools/export_slot_boards.py   (needs pymupdf, pillow)"""
import io
import math
import os
import sys

import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "Panels", "slot_board.png")
PAGE = 1
P = {"tl": (163.1, 875.0, 231.7, 914.3), "tm": (255.9, 875.0, 354.1, 914.3), "tr": (379.5, 875.0, 432.8, 914.3),
     "ml": (163.1, 920.5, 231.7, 930.4), "c": (255.9, 920.5, 354.1, 930.4), "mr": (379.5, 920.5, 432.8, 930.4),
     "bl": (163.1, 940.0, 231.7, 979.0), "bm": (255.9, 940.0, 354.1, 979.0), "br": (379.5, 940.0, 432.8, 979.0)}

doc = pymupdf.open(SRC)
pg = doc[PAGE]


def piece(box, inset):
    """The page's picture of this box (nothing else is drawn in the template's area, and the pieces have gaps between them)."""
    clip = pymupdf.Rect(math.floor(box[0]), math.floor(box[1]), math.ceil(box[2]), math.ceil(box[3]))
    pm = pg.get_pixmap(matrix=pymupdf.Matrix(1, 1), clip=clip, alpha=True)
    im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
    l, t, r, b = inset
    return im.crop((l, t, im.width - r, im.height - b))


cols = [["tl", "ml", "bl"], ["tm", "c", "bm"], ["tr", "mr", "br"]]
col_imgs = []
for ci, c in enumerate(cols):  # (the edges that join another piece lose 1 px: the half-covered pixel there would show as a faint line)
    ims = [piece(P[k], (1 if ci > 0 else 0, 1 if ri > 0 else 0, 1 if ci < 2 else 0, 1 if ri < 2 else 0)) for ri, k in enumerate(c)]
    col = Image.new("RGBA", (max(i.width for i in ims), sum(i.height for i in ims)), (0, 0, 0, 0))
    y = 0
    for i in ims:
        col.alpha_composite(i, (0, y))
        y += i.height
    col_imgs.append(col)
out = Image.new("RGBA", (sum(c.width for c in col_imgs), max(c.height for c in col_imgs)), (0, 0, 0, 0))
x = 0
for c in col_imgs:
    out.alpha_composite(c, (x, 0))
    x += c.width
out.save(OUT)
m = (col_imgs[0].width, col_imgs[0].height // 3, col_imgs[2].width, col_imgs[2].height // 3)
print("slot_board", out.size, "corner margins l/t/r/b ~", m, [im.size for im in col_imgs])
