"""Effect pictures of the Winter Wyvern (Act 3 mini boss), 2026-10-27: ImageSet's set "Fire Dragon" (prompts + style: Act3/fire_dragon_{prompts,style}.txt)
-> assets/Puppet/Enemies/Act3/dragon/<fireball|burst|roar_wave|slam_dust>.png. The white background is cut with Tachnen's BiRefNet (run this with Tachnen's
python), trimmed, FULL size. (The wyvern itself is the user's own art: tools/export_dragon2_rig.py. The ImageSet body / head / tail / wing pieces were dropped.)
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_fire_dragon.py   (then Godot --headless --editor --quit once)"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

TACHNEN = r"D:\GitHub Projects\Tachnen"
sys.path.insert(0, TACHNEN)
from PIL import Image

RAW = r"E:\GitHub\ImageSet\output\Fire Dragon"
ACT3 = os.path.join(AP.PUPPET, "Enemies", "Act3")
OUT = os.path.join(ACT3, "dragon")
SRC = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act3", "Fire Dragon")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
PIECES = {"Fireball": "fireball", "Fireball Burst": "burst", "Roar Wave": "roar_wave", "Slam Dust": "slam_dust"}


def newest(name):
    files = [f for f in glob.glob(os.path.join(glob.escape(RAW), glob.escape(name) + "_*.png"))
             if os.path.basename(f)[len(name) + 1:-4].replace("_", "").isdigit()]
    return max(files, key=os.path.getmtime) if files else None


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def biggest(im):
    """Keep only the largest piece of the cut (the generator sometimes leaves a faint ghost of a head floating above the dragon)."""
    import numpy as np
    from scipy.ndimage import label
    a = np.array(im)
    lab, n = label(a[:, :, 3] > 8)
    if n > 1:
        sizes = np.bincount(lab.ravel())
        sizes[0] = 0
        a[lab != sizes.argmax(), 3] = 0
    return Image.fromarray(a, "RGBA")


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * pad * 0.5)))
    return c


def main():
    import tachnen_core as core
    proc = core.Processor()
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    for name, key in PIECES.items():
        f = newest(name)
        if f is None:
            print("  MISSING", name)
            continue
        im = proc.run(Image.open(f).convert("RGBA"), CUT_OPTS)
        im = trim(im)
        im.save(os.path.join(SRC, name + ".png"))
        im.save(os.path.join(OUT, key + ".png"))
        print("  %-20s -> %s  %dx%d" % (name, key, im.width, im.height))


if __name__ == "__main__":
    main()
