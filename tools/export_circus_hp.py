"""Cirus theme: the HP bar of assets/ui/Circus UI.pdf (page 1), drawn as two objects + three colour swatches.
  hp_bar_full.png    the whole bar (frame + empty dark inside)
  hp_fill_mask.png   the inside shape: the game centres it in the bar and clips the coloured fills to it (HpBar._draw_full)
  hp_fill_hp / hp_fill_shield / hp_fill_blank.png   the three fills (red = HP, blue = Shield, grey = missing HP)
All at 2 px per PDF point (the bar is about 920 x 52 px, drawn at 460 x 26).
Run AFTER the circus export:  python tools/export_circus_hp.py"""
import io
import os
import sys

import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "Circus UI.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "circus", "panels")
ZOOM = 4  # render zoom; saved at half of it (2 px per pt)
# page-0 areas (pt) that hold just that object, clear of the labels printed under them
AREAS = {
    "hp_bar_full": pymupdf.Rect(30, 315, 520, 353),
    "hp_fill_mask": pymupdf.Rect(30, 366, 520, 392.5),
    "hp_fill_hp": pymupdf.Rect(70, 411, 114, 433),
    "hp_fill_shield": pymupdf.Rect(70, 436, 114, 458),
    "hp_fill_blank": pymupdf.Rect(70, 461, 114, 483),
}
os.makedirs(OUT, exist_ok=True)
page = pymupdf.open(SRC)[0]
for name, clip in AREAS.items():
    pm = page.get_pixmap(matrix=pymupdf.Matrix(ZOOM, ZOOM), clip=clip, alpha=True)
    im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox())
    size = (round(im.width * 2 / ZOOM), round(im.height * 2 / ZOOM))
    im.resize(size, Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print(name, size)
