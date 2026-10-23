"""New UI theme: ImageSet's raw frames (tools/make_new_ui_frames.py) -> the game-ready PNGs in assets/Puppet/UI/NewUi/ (lookup names nu_*).
The white background is cut by flood fill from the picture's border, the picture is trimmed, round pieces get a clean circle edge, and everything is scaled to the size
scripts/ui/new_ui_layout.gd expects (the 9-slice margins there are in pixels of THESE sizes). The raw pictures are copied to assets/Puppet/UI/_Source/NewUi/.
The wide block has Gemini's sparkle mark in its bottom right corner: that corner is replaced by the mirrored bottom left one (the corners are identical by design).
Run: python tools/import_new_ui_frames.py   (then Godot --headless --editor --quit once)"""
import glob
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

OUT = os.path.join(AP.PUPPET, "UI", "NewUi")
SRC = os.path.join(AP.PUPPET, "UI", "_Source", "NewUi")
RAW = [r"E:\GitHub\ImageSet\output", r"D:\GitHub Projects\ImageSet\output"]
# lookup name: (set folder, ImageSet object name, kind, size)
PIECES = {
    "nu_hud_block": ("Puppet New UI Wide", "HUD Block Dark", "block", (1024, 256)),
    "nu_hp_frame": ("Puppet New UI Wide", "HP Bar Frame", "bar", (800, 82)),
    "nu_artifact_slot": ("Puppet New UI Slots", "Artifact Slot", "square", (128, 128)),
    "nu_bottle_slot": ("Puppet New UI Slots", "Bottle Slot", "square", (128, 128)),
    "nu_debuff_socket": ("Puppet New UI Slots", "Debuff Socket", "round", (128, 128)),
    "nu_orb_well": ("Puppet New UI Slots", "Orb Well", "round", (128, 128)),
}


def newest(folder, name):
    found = []
    for root in RAW:
        found += glob.glob(os.path.join(glob.escape(os.path.join(root, folder)), glob.escape(name) + "_*.png"))
    found.sort(key=os.path.getmtime)
    return found[-1] if found else None


def foreground(rgb, dark=None):
    """True where the object is: not the white background that touches the border (or, with `dark`, only the clearly dark / saturated pixels)."""
    a = rgb.astype(int)
    if dark is not None:
        return a.sum(axis=2) < dark
    near_white = a.min(axis=2) > 232
    lab, n = ndimage.label(near_white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    return ~bg


def trim(im, mask):
    ys, xs = np.where(mask)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return im.crop(box), Image.fromarray((mask[box[1]:box[3], box[0]:box[2]] * 255).astype(np.uint8))


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    for name, (folder, obj, kind, size) in PIECES.items():
        path = newest(folder, obj)
        if path is None:
            print("missing", obj)
            continue
        shutil.copy(path, os.path.join(SRC, os.path.basename(path)))
        im = Image.open(path).convert("RGB")
        mask = foreground(np.array(im), dark=330 if kind == "bar" else None)
        mask = ndimage.binary_fill_holes(mask)
        mask = ndimage.binary_opening(mask, iterations=6)
        lab, n = ndimage.label(mask)
        if n > 1:  # (only the biggest piece: loose specks and soft shadows of the background are not the object)
            mask = lab == (1 + int(np.argmax(ndimage.sum(mask, lab, range(1, n + 1)))))
        im, alpha = trim(im, mask)
        if kind == "block":  # Gemini's sparkle mark (grey, bottom right): painted over with the plain wood 180 px to its left
            w, h = im.size
            arr = np.array(im).astype(int)
            grey = (arr.max(axis=2) - arr.min(axis=2) < 24) & (arr.mean(axis=2) > 115)
            region = np.zeros_like(grey)
            region[h - 330:h - 30, w - 520:w - 40] = True
            sp = ndimage.binary_dilation(grey & region, iterations=8)
            shifted = np.roll(arr, 180, axis=1)
            arr[sp] = shifted[sp]
            im = Image.fromarray(arr.astype(np.uint8))
        if kind == "round":
            s = min(im.size)
            im = im.resize((s, s), Image.LANCZOS) if im.width != im.height else im
            big = 4
            circle = Image.new("L", (s * big, s * big), 0)
            from PIL import ImageDraw
            ImageDraw.Draw(circle).ellipse([0, 0, s * big - 1, s * big - 1], fill=255)
            alpha = circle.resize((s, s), Image.LANCZOS)
        im = im.convert("RGBA")
        im.putalpha(alpha if alpha.size == im.size else alpha.resize(im.size))
        im = im.resize(size, Image.LANCZOS)
        im.save(os.path.join(OUT, name + ".png"))
        print("%-18s <- %s  %s" % (name, os.path.basename(path), size))


if __name__ == "__main__":
    main()
