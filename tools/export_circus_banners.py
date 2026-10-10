"""Cirus theme: the end-of-fight banners of assets/ui/Circus UI.pdf (page 5), each drawn as ONE finished picture (ribbon +
lettering [+ star / PERFECT]), unlike the New theme's separate ribbon / lettering layers.
Writes assets/ui/circus/title/<kind>_banner.png and, for the layers the fight screen still stacks on top (<kind>_text,
perfect_word), fully transparent pictures of the same size, so UiSkin does not fall back to the New theme's lettering.
Run AFTER  EXPORT_THEME=circus python tools/export_fight_ui.py :   python tools/export_circus_banners.py"""
import io
import os
import sys

import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "Circus UI.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "circus", "title")
PX_PER_PT = 900 / 270.0  # same scale as the New theme's banners (about 900 px wide)
ZOOM = 4
X0, X1 = 20, 335  # the banners; the labels ("Victory Banner"...) start to the right of this
BANDS = {"perfect": (437, 561), "victory": (561, 680), "defeat": (680, 790)}  # page-4 y range (pt) of each banner

os.makedirs(OUT, exist_ok=True)
page = pymupdf.open(SRC)[4]
for kind, (y0, y1) in BANDS.items():
    pm = page.get_pixmap(matrix=pymupdf.Matrix(ZOOM, ZOOM), clip=pymupdf.Rect(X0, y0, X1, y1), alpha=True)
    im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    im = im.crop(box)
    size = (round(im.width / ZOOM * PX_PER_PT), round(im.height / ZOOM * PX_PER_PT))
    im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(OUT, kind + "_banner.png"))
    blank = Image.new("RGBA", size, (0, 0, 0, 0))
    blank.save(os.path.join(OUT, kind + "_text.png"))
    if kind == "perfect":
        blank.save(os.path.join(OUT, "perfect_word.png"))
    print(kind, size)
