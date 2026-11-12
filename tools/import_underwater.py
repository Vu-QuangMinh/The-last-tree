"""The underwater stage and the fish of Elemental Fishing (2026-11-01), from ImageSet:
  set "Puppet Underwater Props"  -> assets/Puppet/Stage/Act4/Props/{reef,kelp,algae}_N.png   (cut with Tachnen, full size)
  set "Puppet Fish"              -> assets/Puppet/Events/event_fish_<name>.png               (cut with Tachnen, full size)
  set "Puppet Underwater"        -> assets/Puppet/Stage/Act4/Backdrop/back_wall.png          (the newest "Underwater Backdrop<suffix>", centre band cropped to the back wall's 3464:1013)
Run with Tachnen's python:  python tools/import_underwater.py [--force] [--backdrop " B"]   (then Godot --headless --editor --quit once)"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_event_art as I
import paths
import asset_paths as AP
from PIL import Image

OUT = (paths.IMAGESET_OUT + r"\output")
STAGE4 = os.path.join(AP.PUPPET, "Stage", "Act4")


def newest(folder, name):
    files = [f for f in glob.glob(os.path.join(glob.escape(os.path.join(OUT, folder)), glob.escape(name) + "_*.png")) if re.search(r"_\d{8}_\d{6}\.png$", f)]
    return max(files, key=os.path.getmtime) if files else None


def cut_to(folder, name, dest, force):
    if os.path.exists(dest) and not force:
        print("  (have)", name)
        return
    src = newest(folder, name)
    if src is None:
        print("  (no picture yet)", name)
        return
    im = I.trim(I.decontaminate(I.cut(src)))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest)
    print("  ", name, "->", os.path.relpath(dest, AP.PUPPET), im.size)


def main():
    force = "--force" in sys.argv
    suffix = ""
    if "--backdrop" in sys.argv:
        suffix = sys.argv[sys.argv.index("--backdrop") + 1]
    for kind in ("Reef", "Kelp"):
        for n in range(1, 6):
            cut_to("Puppet Underwater Props", "%s %d" % (kind, n), os.path.join(STAGE4, "Props", "%s_%d.png" % (kind.lower(), n)), force)
    for n in range(1, 7):
        cut_to("Puppet Underwater Props", "Algae %d" % n, os.path.join(STAGE4, "Props", "algae_%d.png" % n), force)
    for name in ("Swordfish", "Barracuda", "Clownfish", "Pufferfish", "Angelfish", "Whale", "Shark"):
        cut_to("Puppet Fish", "Fish " + name, os.path.join(AP.PUPPET, "Events", "event_fish_%s.png" % name.lower()), force)
    src = newest("Puppet Underwater", "Underwater Backdrop" + suffix)
    dest = os.path.join(STAGE4, "Backdrop", "back_wall.png")
    if src and (force or not os.path.exists(dest)):
        im = Image.open(src).convert("RGB")
        h = round(im.width * 1013 / 3464)  # (the same shape as the other acts' back walls)
        top = (im.height - h) // 2
        im = im.crop((0, top, im.width, top + h))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im.save(dest)
        print("   backdrop ->", os.path.relpath(dest, AP.PUPPET), im.size)


if __name__ == "__main__":
    main()
