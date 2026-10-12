"""The layer PNGs of docs/puppet_fight_layout_layers/ -> docs/puppet_fight_layout.psd (one real Photoshop layer each, 3840 x 2160,
bottom layer first). Open it in Photoshop, Photopea, Krita, GIMP, Figma... The reference picture is a hidden top layer.
Run: python tools/build_layout_psd.py   (needs psd-tools, pillow)"""
import glob
import os

from PIL import Image
from psd_tools import PSDImage

HERE = os.path.dirname(os.path.abspath(__file__))
layers = os.path.join(HERE, "..", "docs", "puppet_fight_layout_layers")
files = sorted(glob.glob(os.path.join(layers, "0*.png")))
ref = [f for f in files if os.path.basename(f).startswith("00_")]
files = [f for f in files if f not in ref]
psd = PSDImage.new("RGB", (3840, 2160))
for f in files + ref:
    name = os.path.basename(f)[:-4].replace("_", " ")
    im = Image.open(f).convert("RGBA")
    lay = psd.create_pixel_layer(im, name=name, top=0, left=0)
    if f in ref:
        lay.visible = False
out = os.path.join(HERE, "..", "docs", "puppet_fight_layout.psd")
psd.save(out)
print("wrote", out, os.path.getsize(out) // 1024, "KB")
