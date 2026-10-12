"""Puppet Stage puppets -> game files: assets/ui/puppet/asset.pdf (vector sheet of the Act 1 puppets; its sun, clouds, trees and mountains
are not used any more: those come from tools/import_puppet_stage.py) -> assets/ui/puppet/enemies/<enemy id>.png (square canvas, feet on
the bottom edge).
Run: python tools/export_puppet_art.py   (then Godot --headless --editor --quit once so it imports the new files)
"""
import os

import numpy as np
import pymupdf
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "ui", "puppet")
SHEET = os.path.join(OUT, "asset.pdf")
SCALE = 1.5

# reading order of the puppets on the sheet (rows, left to right); None = a piece the sheet does not have yet
ENEMY_ROWS = [
    ["winged_tortoise", "tomato_knight", "zephling", "handyman", "hand_shield", "rolling_bear"],
    ["hand_spear", "purple_slime", "hand_hammer", "triplet_water", "enraged_bear", "triplet_fire", "bramble_matron", "ashling"],
    ["yin_yang_clone_white", "invoker", "briar_hedge", "yin_yang_clone_black", "yellow_slime", "hand_tweezer", "hand_sword"],
    ["mirror_fairy", "leech_bat", "iceling", "hush_moth", "greenseer", "hand_crossbow"],
    ["green_slime", "cinder_hound", "giant_slime", "bramble_back", "forge_spirit", "triplet_air"],
]


def render():
    page = pymupdf.open(SHEET)[0]
    pix = page.get_pixmap(matrix=pymupdf.Matrix(SCALE, SCALE), alpha=True)
    return np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 4).copy()


def pieces(img, dil, y0=0, y1=None):
    """[(row_top, x, Image)] connected pieces in a band of the sheet (dil: how far parts of one piece may be apart)."""
    y1 = y1 or img.shape[0]
    band = img[y0:y1]
    mask = ndi.binary_dilation(band[:, :, 3] > 10, iterations=dil)
    lab, n = ndi.label(mask)
    out = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        own = (lab[sl] == i + 1)
        crop = band[sl].copy()
        crop[:, :, 3] = np.where(ndi.binary_dilation(own, iterations=dil) & (crop[:, :, 3] > 0), crop[:, :, 3], 0)
        pil = Image.fromarray(crop, "RGBA")
        bb = pil.getbbox()
        if bb is None:
            continue
        out.append((sl[0].start + y0, sl[1].start, pil.crop(bb)))
    return out


def rows_of(items, tol):
    items = sorted(items, key=lambda t: t[0])
    rows, cur = [], [items[0]]
    for it in items[1:]:
        if abs(it[0] - cur[0][0]) <= tol:
            cur.append(it)
        else:
            rows.append(cur)
            cur = [it]
    rows.append(cur)
    return [sorted(r, key=lambda t: t[1]) for r in rows]


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * pad * 0.5)))
    return c


def export_sheet():
    img = render()
    s = SCALE
    os.makedirs(os.path.join(OUT, "enemies"), exist_ok=True)
    en = pieces(img, int(14 * s), int(900 * s))  # (the puppets start below the sheet's props)
    erows = rows_of(en, 100 * s)
    assert [len(r) for r in erows] == [len(r) for r in ENEMY_ROWS], [len(r) for r in erows]
    for r, ids in zip(erows, ENEMY_ROWS):
        for (_, _, im), eid in zip(r, ids):
            square(im).save(os.path.join(OUT, "enemies", eid + ".png"))
    print("sheet:", sum(len(r) for r in erows), "puppets")


if __name__ == "__main__":
    export_sheet()
