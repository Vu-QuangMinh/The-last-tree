"""Puppet Stage: the lever of the slot machine as page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf draws it (right of the machine, side view).
Cuts into assets/Puppet/UI/SlotMachine/ (4 px per pt):
  slot_lever_ball.png    the red ball (14 x 13 pt at (1825, 762))
  slot_lever_stick.png   the brown stick (inside x 1829..1835, y 776..827)
  slot_lever_hub.png     the silver cylinder and the nub on its right (1828..1842 x 827..846)
FightScreen's SlotMachine (slot_machine.gd, LEVER_* constants) places them by those page positions.
Run: python tools/export_lever.py   (needs pymupdf, pillow)"""
import io
import os
import sys

import pymupdf
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "SlotMachine")
Z = 4
doc = pymupdf.open(SRC)
pg = doc[1]


def render(x0, y0, x1, y1):
    clip = pymupdf.Rect(x0, y0, x1, y1)
    pm = pg.get_pixmap(matrix=pymupdf.Matrix(Z, Z), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


# the page draws these small pictures as inline images (no xref to extract), so each is rendered from the page, inside a box where nothing else is drawn.
# The ball overlaps the machine's right edge by 2.5 pt: its right half (clean) is mirrored over its left half (the ball is round).
ball_im = render(1825, 762, 1839, 775)
half = ball_im.width // 2
right = ball_im.crop((ball_im.width - half, 0, ball_im.width, ball_im.height))
ball_im.paste(right.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
ball_im.save(os.path.join(OUT, "slot_lever_ball.png"))
stick = render(1829, 776, 1835, 827)
stick.save(os.path.join(OUT, "slot_lever_stick.png"))
hub = render(1828, 827, 1842, 846)  # (the cylinder starts at 1827: the half point that touches the machine is left out)
hub.save(os.path.join(OUT, "slot_lever_hub.png"))
print("ball", ball_im.size, "stick", stick.size, "hub", hub.size)
