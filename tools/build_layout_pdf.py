"""Puppet Stage fight screen -> a layered PDF to edit the layout on (docs/puppet_fight_layout.pdf).
Step 1 (Godot, renders each layer as a transparent 2x PNG + layout.json):
  Godot --path . --position 6000,0 --no-focus -s res://tools/export_stage_layers.gd -- <layers_dir>
Step 2:  python tools/build_layout_pdf.py <layers_dir>
Page 1 is the 1920 x 1080 screen (1 px = 1 pt) with one PDF layer (optional content group) per layer; page 2 lists the pixel
rectangles of the main elements. The PNGs are copied to docs/puppet_fight_layout_layers/ too (same size, transparent)."""
import glob
import json
import os
import shutil
import sys

import pymupdf

HERE = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1]
docs = os.path.join(HERE, "..", "docs")
dst_png = os.path.join(docs, "puppet_fight_layout_layers")
os.makedirs(dst_png, exist_ok=True)
pngs = sorted(glob.glob(os.path.join(src, "0*.png")))
for p in pngs:
    shutil.copy(p, dst_png)
shutil.copy(os.path.join(src, "layout.json"), dst_png)

doc = pymupdf.open()
page = doc.new_page(width=1920, height=1080)
rect = pymupdf.Rect(0, 0, 1920, 1080)
ref = None
for p in pngs:
    name = os.path.basename(p)[:-4]
    if name.startswith("00_"):
        ref = (name, p)
        continue
    oc = doc.add_ocg(name.replace("_", " "), on=True)
    page.insert_image(rect, filename=p, oc=oc)
oc = doc.add_ocg("00 reference flat (hidden: the same screen in one picture)", on=False)
page.insert_image(rect, filename=ref[1], oc=oc)

lay = json.load(open(os.path.join(src, "layout.json"), encoding="utf-8"))
page2 = doc.new_page(width=1920, height=1080)
page2.insert_text((40, 60), "Puppet Stage fight screen: element rectangles (px, 1920 x 1080 screen: x, y, width, height)", fontsize=26)
y = 110
for k in sorted(lay):
    v = lay[k]
    page2.insert_text((40, y), "%-44s  x %5d   y %5d   w %5d   h %5d" % (k, v[0], v[1], v[2], v[3]), fontsize=17, fontname="cour")
    y += 26
page2.insert_text((40, y + 20), "Layers on page 1 (bottom to top): 01 stage, 02 props, 03 spotlights, 04 enemies, 05 spell cards, 06 chant strip, 07 bag and machine, 08 keeper panel, 09 hud.", fontsize=17)
out = os.path.join(docs, "puppet_fight_layout.pdf")
doc.save(out, deflate=True)
print("wrote", out, os.path.getsize(out) // 1024, "KB")
