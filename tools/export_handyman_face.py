"""The Handyman's two faces: assets/Puppet/Enemies/Act1/handyman/Face.pdf holds his body twice (smiling, and crying). The smiling one is the same
body as Act1/handyman.png (made by export_handyman_rig.py); the crying one is written as Act1/handyman_sad.png on the same canvas, scaled and placed with
the same transform, so the two can be swapped without anything moving.
Run: python tools/export_handyman_face.py   (needs handyman.png from export_handyman_rig.py first; then Godot --headless --editor --quit)"""
import os
import sys

import numpy as np
import pymupdf
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

DIR = os.path.join(AP.PUPPET, "Enemies", "Act1")
SRC = os.path.join(DIR, "handyman", "Face.pdf")
ZOOM = 4.0

page = pymupdf.open(SRC)[0]
pix = page.get_pixmap(matrix=pymupdf.Matrix(ZOOM, ZOOM), alpha=True)
img = Image.frombytes("RGBA", (pix.width, pix.height), pix.samples)
a = np.array(img.getchannel("A")) > 8
lab, n = ndi.label(ndi.binary_dilation(a, iterations=6))
boxes = [(i + 1, sl) for i, sl in enumerate(ndi.find_objects(lab))]
boxes.sort(key=lambda t: -(lab[t[1]] == t[0]).sum())
two = sorted(boxes[:2], key=lambda t: t[1][1].start)  # left = smiling, right = crying
assert len(two) == 2


def body(t):
    k, sl = t
    own = ndi.binary_dilation(lab[sl] == k, iterations=6)
    crop = np.array(img)[sl].copy()
    crop[:, :, 3] = np.where(own & (crop[:, :, 3] > 0), crop[:, :, 3], 0)
    im = Image.fromarray(crop, "RGBA")
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


happy, sad = body(two[0]), body(two[1])
ref = Image.open(os.path.join(DIR, "handyman.png")).convert("RGBA")
rbox = ref.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
k = (rbox[3] - rbox[1]) / happy.height
print("smiling body %s -> handyman.png content %s (scale %.4f, width ratio %.3f)" % (happy.size, (rbox[2] - rbox[0], rbox[3] - rbox[1]), k, (rbox[2] - rbox[0]) / (happy.width * k)))
# the crying body has the same size as the smiling one (the same drawing, only the face differs): the same scale; it stands in the same place
sad_s = sad.resize((round(sad.width * k), round(sad.height * k)), Image.LANCZOS)
out = Image.new("RGBA", ref.size, (0, 0, 0, 0))
cx = (rbox[0] + rbox[2]) / 2.0
out.alpha_composite(sad_s, (round(cx - sad_s.width / 2.0), rbox[3] - sad_s.height))
out.save(os.path.join(DIR, "handyman_sad.png"))
print("wrote handyman_sad.png", out.size, "sad body", sad_s.size)
