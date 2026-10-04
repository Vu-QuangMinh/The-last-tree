"""Turns the square 2048 px room backgrounds in assets/Room Background/ into 16:9 game backgrounds
assets/ui/new/room_<id>.jpg (1920 x 1080). A square picture is cropped to a 16:9 band: Y0 says where the band starts
(in source px, band height 1152) so the subject and the log along the bottom both stay in. Run: python tools/import_room_backgrounds.py"""
import glob
import os
import re
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "new", "backgrounds"), exist_ok=True)
SRC = os.path.join(HERE, "..", "assets", "Room Background")
OUT = os.path.join(HERE, "..", "assets", "ui", "new", "backgrounds")
DEFAULT_Y0 = 230
Y0 = {}  # room id -> band start, where the default does not suit the picture


def room_id(path):
    name = re.sub(r"_\d{8}_\d{6}$", "", os.path.splitext(os.path.basename(path))[0])
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


if __name__ == "__main__":
    for f in sorted(glob.glob(os.path.join(SRC, "*.png"))):
        rid = room_id(f)
        im = Image.open(f).convert("RGB")
        y0 = Y0.get(rid, DEFAULT_Y0)
        bh = round(im.width * 9 / 16)
        if im.height <= bh + 4:  # already 16:9: use it whole
            y0, band = 0, im.resize((1920, 1080), Image.LANCZOS)
        else:
            band = im.crop((0, y0, im.width, y0 + bh)).resize((1920, 1080), Image.LANCZOS)
        band.save(os.path.join(OUT, "room_%s.jpg" % rid), quality=90)
        print(rid, y0)
