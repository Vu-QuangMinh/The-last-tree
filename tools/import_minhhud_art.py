"""Theme MinhHUD: ImageSet's raw pictures (tools/make_minhhud_art.py, sets "MinhHUD v3 ...") -> assets/Puppet/UI/MinhHUD/minhhud_*.png. The background is cut with Tachnen's
BiRefNet (full size, nothing resized; the Gemini star in the corner is painted black first). Glass parts stay opaque: the user adjusts opacity / blend mode later and may replace
any of these files by his own edit (same names).
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_minhhud_art.py [Name ...]
then Godot --headless --editor --quit once so it imports the new files."""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

sys.path.insert(0, r"D:\GitHub Projects\Tachnen")
from PIL import Image, ImageDraw

OUT = os.path.join(AP.PUPPET, "UI", "MinhHUD")
RAW = [r"E:\GitHub\ImageSet\output", r"D:\GitHub Projects\ImageSet\output"]
# object name -> (ImageSet set folder, output name)
PIECES = {
    "Artifact Cabinet": ("MinhHUD v3 Wide", "minhhud_artifact_cabinet"),
    "Chant Tray": ("MinhHUD v3 Wide", "minhhud_chant_tray"),
    "Glass Tray": ("MinhHUD v3 Wide", "minhhud_glass_tray"),
    "HUD Base": ("MinhHUD v3 Wide", "minhhud_base"),
    "Bottle Cabinet": ("MinhHUD v3 Square", "minhhud_bottle_cabinet"),
    "Button Chant Pass": ("MinhHUD v3 Square", "minhhud_btn"),
    "Glass Pipe": ("MinhHUD v3 Square", "minhhud_pipe"),
    "Glass Flask Disc": ("MinhHUD v3 Square", "minhhud_flask"),
    "Brass Hub": ("MinhHUD v3 Square", "minhhud_hub"),
    "Brass Lever": ("MinhHUD v3 Tall", "minhhud_lever"),
    "Button Chant Pressed": ("MinhHUD v3 Pressed", "minhhud_btn_chant_pressed"),
    "Button Pass Pressed": ("MinhHUD v3 Pressed", "minhhud_btn_pass_pressed"),
}
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": True, "pad": 0}
_proc = None


def newest(set_name, name):
    files = []
    for root in RAW:
        files += glob.glob(os.path.join(root, set_name, name + "_2*.png"))
    return max(files, key=os.path.getmtime) if files else None


def clean_sparkle(im):
    d = ImageDraw.Draw(im)
    w, h = im.size
    d.rectangle([w - 190, h - 190, w, h], fill=(0, 0, 0, 255))
    return im


def cut(path):
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    im = _proc.run(clean_sparkle(Image.open(path).convert("RGBA")), CUT_OPTS)
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, (set_name, out) in PIECES.items():
        if only and name not in only:
            continue
        src = newest(set_name, name)
        if src is None:
            print("no picture yet:", name)
            continue
        im = cut(src)
        im.save(os.path.join(OUT, out + ".png"))
        print("%-20s %s -> %s %s" % (name, os.path.basename(src), out, im.size))


if __name__ == "__main__":
    main()
