"""Act 2 mob enemies (2026-11-06): ImageSet's "Act 2 Mobs" pictures -> assets/Puppet/Enemies/Act2/<enemy id>.png at FULL size.

Same recipe as import_act1_fix.py: Tachnen's BiRefNet cuts the (black) background, the picture is trimmed and put on a square canvas with
its feet on the bottom edge, NOT scaled. The cut picture is also kept in Enemies/_Source/Act2/Puppet <name>.png.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_act2_mobs.py [name ...]   (then Godot --headless --editor --quit once)"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

sys.path.insert(0, r"D:\GitHub Projects\Tachnen")
from PIL import Image

RAW = r"E:\GitHub\ImageSet\output\Act 2 Mobs"
OUT = os.path.join(AP.PUPPET, "Enemies", "Act2")
SRC = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act2")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
IDS = {"Pitchfork Peasant": "mob_pitchfork", "Slingshot Peasant": "mob_slingshot", "Torch Peasant": "mob_torch",
       "Skeleton Shield Bearer": "shield_bearer", "Necromancer": "necromancer", "Sentinel": "sentinel",
       "Headless Horseman": "headless_horseman", "Scavenger Rat": "scav_rat", "Scavenger Hyena": "scav_hyena",
       "Scavenger Vulture": "scav_vulture", "Scavenger Dung Beetle": "scav_beetle", "Maddened Soldier": "mad_soldier",
       "Tree Dweller Man": "tree_dweller_a", "Tree Dweller Woman": "tree_dweller_b", "Bog Lantern": "bog_fish",
       "Bog Lamp": "bog_lamp", "Bug Hunter 1.0": "bug_hunter",
       # 2026-11-06, the second batch: the Anxious Armadillo and the enemies kept in reserve (act 0)
       "Anxious Armadillo": "anxious_armadillo", "Anxious Armadillo Sad": "anxious_armadillo_sad", "Puddle Slime": "puddle_slime", "Gale Sprite": "gale_sprite", "Stone Knight": "stone_knight",
       "Tidecaller": "tidecaller", "Mirror Wisp": "mirror_wisp", "Frost Hex": "frost_hex", "Pickpocket Imp": "pickpocket_imp", "The Woodcutter": "woodcutter"}
_proc = None


def newest(name):
    pre = "Puppet " + name + "_"
    files = [f for f in glob.glob(os.path.join(glob.escape(RAW), glob.escape(pre) + "*.png"))
             if os.path.basename(f)[len(pre):-4].replace("_", "").isdigit()]
    return max(files, key=os.path.getmtime) if files else None


def cut(path):
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    return _proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * pad * 0.5)))
    return c


def main():
    names = sys.argv[1:] or list(IDS)
    os.makedirs(SRC, exist_ok=True)
    for name in names:
        f = newest(name)
        if f is None:
            print("  MISSING raw picture for", name)
            continue
        im = trim(cut(f))
        sq = square(im)
        sq.save(os.path.join(OUT, IDS[name] + ".png"))
        im.save(os.path.join(SRC, "Puppet " + name + ".png"))
        print("  %-24s -> %s.png  %dx%d  (%s)" % (name, IDS[name], sq.width, sq.height, os.path.basename(f)))


if __name__ == "__main__":
    main()
