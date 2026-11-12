"""Turns mipmaps on in the .import files of the full-size icons (Icon/Bottle, Icon/Artifact seed_of_life): they are drawn at 28-150 px from 1000+ px pictures, which aliases without mipmaps.
Run once after tools/make_redo5.py, then Godot --headless --editor --quit."""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

n = 0
for f in glob.glob(os.path.join(AP.PUPPET, "Icon", "Bottle", "*.png.import")) + [os.path.join(AP.PUPPET, "Icon", "Artifact", n + ".png.import") for n in ["seed_of_life", "water_emblem", "fire_emblem", "shield_of_silence"]] + [os.path.join(AP.PUPPET, "UI", "Characters", "Merchant", n + ".png.import") for n in ["shelf", "mark_exclaim", "mark_question", "Cart_true_empty", "candle", "soup", "Layer 1", "Layer 2"]] + [os.path.join(AP.PUPPET, "UI", "Icons", "coin_purse.png.import"), os.path.join(AP.PUPPET, "UI", "Icons", "Icon Wooden Coin Stack_20261013_160743.png.import")]:
    s = open(f, encoding="utf-8").read()
    if "mipmaps/generate=false" in s:
        open(f, "w", encoding="utf-8").write(s.replace("mipmaps/generate=false", "mipmaps/generate=true"))
        n += 1
print(n, "import files changed")
