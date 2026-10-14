"""Puppet Stage enemies: assets/Puppet/Enemies/_Source/Act<n>/Puppet <Name>.png -> assets/Puppet/Enemies/Act<n>/<enemy id>.png (n = the first argument, 1 by default)
(trimmed, on a square canvas with the feet on the bottom edge, at most 512 px; the same shape export_puppet_art.py makes).
The generator's "_YYYYMMDD_HHMMSS" tail is removed from the source names first; when two files end up with one name the newest keeps it.
Run: python tools/import_puppet_enemies.py [act]   (then Godot --headless --editor --quit once so it imports the new files)"""
import glob
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

from PIL import Image

ACT = int(sys.argv[1]) if len(sys.argv) > 1 else 1
SRC = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act%d" % ACT)
OUT = os.path.join(AP.PUPPET, "Enemies", "Act%d" % ACT)
MAX_PX = 512
IDS = {  # the name after "Puppet " -> file name in OUT (enemy id; some enemies share a pattern with a different file)
    "The Blightmother": "blightmother", "The Last Winter": "last_winter",
    "Ember Sprite": "triplet_fire", "Ripple Sprite": "triplet_water", "Zephyr Sprite": "triplet_air",
    "Enraged Rolling Bear": "enraged_bear", "The Handyman": "handyman", "The Invoker": "invoker",
    "Crossbow Hand": "hand_crossbow", "Hammer Hand": "hand_hammer", "Shield Hand": "hand_shield", "Spear Hand": "hand_spear",
    "Sword Hand": "hand_sword", "Tweezer Hand": "hand_tweezer",
    "Yin Yang Cub Black": "yin_yang_clone_black", "Yin Yang Cub White": "yin_yang_clone_white",
    "Yin Yang Beast Black": "yin_yang_beast_black", "Yin Yang Beast White": "yin_yang_beast_white",
}


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * pad * 0.5)))
    return c


def strip_stamps():
    files = sorted(glob.glob(os.path.join(SRC, "*_[0-9]*_[0-9]*.png")), key=os.path.getmtime)  # (oldest first: the newest wins)
    for f in files:
        new = re.sub(r"_\d{8}_\d{6}(?=\.png$)", "", f)
        if os.path.exists(new):
            os.replace(new, new[:-4] + " (old).png")
        os.rename(f, new)
        print("  renamed", os.path.basename(new))


def main():
    strip_stamps()
    os.makedirs(OUT, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(SRC, "Puppet *.png"))):
        name = os.path.basename(f)[len("Puppet "):-4]
        if name.endswith("(old)"):
            continue
        eid = IDS.get(name, re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_"))
        im = Image.open(f).convert("RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        im = square(im)
        if im.width > MAX_PX:
            im = im.resize((MAX_PX, MAX_PX), Image.LANCZOS)
        im.save(os.path.join(OUT, eid + ".png"))
        print("  %-24s -> %s.png" % (name, eid))


if __name__ == "__main__":
    main()
