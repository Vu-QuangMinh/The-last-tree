"""Crops the Pianist out of the frames tools/pianist_flow.gd writes and lays them out in one sheet: python tools/pianist_flow_crop.py <folder> [names...]"""
import sys
from PIL import Image
d = sys.argv[1]
names = sys.argv[2:] or ["play_1", "play_4", "page_1", "page_3", "end_0", "end_2"]
box = (380, 40, 1020, 760)
W = Image.new("RGB", (640 * 3, 720 * ((len(names) + 2) // 3)))
for i, n in enumerate(names):
    W.paste(Image.open("%s/%s.png" % (d, n)).crop(box), ((i % 3) * 640, (i // 3) * 720))
W.save(d + "/sheet.png")
