"""After `EXPORT_THEME=circus python tools/export_fight_ui.py`: delete every picture in assets/ui/circus/ that is pixel-identical
to the New theme's one (same folder, same name). UiSkin falls back to assets/ui/new/ for a missing name, so only the art that
was really redrawn for the Cirus theme stays in assets/ui/circus/.  Run:  python tools/prune_circus_art.py"""
import os
import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
NEW = os.path.join(HERE, "..", "assets", "ui", "new")
CIRCUS = os.path.join(HERE, "..", "assets", "ui", "circus")


def same(a, b):
    if os.path.getsize(a) == os.path.getsize(b):
        with open(a, "rb") as fa, open(b, "rb") as fb:
            if fa.read() == fb.read():
                return True
    ia, ib = Image.open(a).convert("RGBA"), Image.open(b).convert("RGBA")
    if ia.size != ib.size:
        return False
    d = np.abs(np.asarray(ia).astype(int) - np.asarray(ib).astype(int))
    return int(d.max()) <= 2  # re-rendered with the same vector art: allow rounding noise


kept, dropped = [], []
for root, _dirs, files in os.walk(CIRCUS):
    for f in files:
        if not f.lower().endswith((".png", ".jpg")):
            continue
        p = os.path.join(root, f)
        q = os.path.join(NEW, os.path.relpath(p, CIRCUS))
        if os.path.exists(q) and same(p, q):
            os.remove(p)
            imp = p + ".import"
            if os.path.exists(imp):
                os.remove(imp)
            dropped.append(os.path.relpath(p, CIRCUS))
        else:
            kept.append(os.path.relpath(p, CIRCUS))
print("kept (redrawn):", len(kept))
for k in sorted(kept):
    print("  ", k)
print("dropped (same as New):", len(dropped))
for k in sorted(dropped):
    print("  ", k)
