"""Lays the stills of tools/pianist_sign_flow.gd out in one sheet: python tools/pianist_sign_crop.py <folder>"""
import sys
from PIL import Image
d = sys.argv[1]
box = (480, 60, 1000, 520)
W = Image.new("RGB", (520 * 5, 460 * 3))
for i in range(14):
    W.paste(Image.open("%s/sign_%02d.png" % (d, i)).crop(box), ((i % 5) * 520, (i // 5) * 460))
W.save(d + "/sheet.png")
