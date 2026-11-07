"""Puppet HUD ver 2: ImageSet's raw pictures (tools/make_hud2_art.py) -> assets/Puppet/UI/Hud2/*.png. The background is cut with Tachnen's BiRefNet (run with Tachnen's python); the
pictures are hand-painted wooden pieces in the style of Buttons/button_close_x_normal.png: Button Chant / Pass / Clear / Menu, Slot Frame (artifact and bottle slots), HUD Board (both
boards: a nine-slice picture, made in two sizes for the two draw sizes). One picture per button, the states are tints in code. They are saved at most 1024 px long (they are drawn
at about 60-130 px; the raw 2048 px pictures stay in ImageSet's output folder). The earlier Essence Tray is kept (its first version: python tools/import_hud2_art.py "Essence Tray").
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_hud2_art.py [Name ...]
then Godot --headless --editor --quit once so it imports the new files."""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

sys.path.insert(0, r"D:\GitHub Projects\Tachnen")
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(AP.PUPPET, "UI", "Hud2")
RAW = [r"E:\GitHub\ImageSet\output", r"D:\GitHub Projects\ImageSet\output"]
# name -> (ImageSet set folder, output name, longest side in px (0 = as cut))
PIECES = {"Button Chant": ("Puppet HUD2 v2 Slots", "hud2_btn_chant", 1024), "Button Pass": ("Puppet HUD2 v2 Slots", "hud2_btn_pass", 1024),
          "Button Clear": ("Puppet HUD2 v2 Slots", "hud2_btn_clear", 1024), "Slot Frame": ("Puppet HUD2 v2 Slots", "hud2_slot_frame", 512),
          "Button Menu": ("Puppet HUD2 v2 Wide", "hud2_btn_menu", 1024), "HUD Board": ("Puppet HUD2 v2 Wide", "hud2_board", 0),
          "Essence Tray": ("Puppet HUD2 Wide", "hud2_tray", 0)}
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
    """Gemini's little star in the bottom right corner: painted black before the cut."""
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


def cut_square(path):
    """Slot Frame: a dark brown piece on black, which the AI cut mistakes (it keeps only the brass). The piece fills the picture, so it is trimmed to its box and given
    the rounded-square outline of the piece (corner radius 10 % of its side)."""
    im = clean_sparkle(Image.open(path).convert("RGBA"))
    lum = np.asarray(im.convert("L"))
    ys, xs = np.where(lum > 22)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    n = max(im.size)
    m = Image.new("L", (im.width * 3, im.height * 3), 0)
    ImageDraw.Draw(m).rounded_rectangle([3, 3, im.width * 3 - 4, im.height * 3 - 4], radius=0.1 * n * 3, fill=255)
    im.putalpha(m.resize(im.size, Image.LANCZOS))
    return im


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, (set_name, out, longest) in PIECES.items():
        if (only and name not in only) or (not only and name == "Essence Tray"):
            continue
        src = newest(set_name, name)
        if src is None:
            print("no picture yet:", name)
            continue
        im = cut_square(src) if name == "Slot Frame" else cut(src)
        if longest and max(im.size) > longest:
            k = longest / max(im.size)
            im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        im.save(os.path.join(OUT, out + ".png"))
        print("%-14s %s -> %s %s" % (name, os.path.basename(src), out, im.size))
        if name == "HUD Board":  # (nine-slice copies at the sizes the boards are drawn: ~200 px tall (the two big boards) and ~60 px (the bottle board))
            for tag, h in (("big", 220), ("s", 64)):
                im.resize((round(im.width * h / im.height), h), Image.LANCZOS).save(os.path.join(OUT, "hud2_board_%s.png" % tag))


if __name__ == "__main__":
    main()
