"""2026-11-11: the merchant's cart redrawn from the user's sketch (Merchant/_Redo/cart_sketch.png) in the game's style, then split into: the cart WITHOUT the candle and the soup (Merchant/cart_empty.png), the candle
(Merchant/candle.png = the Wax seal) and the bowl of soup (Merchant/soup.png = A hot meal), plus Merchant/cart_items.json: where the two stand on the empty cart (fractions of its picture, measured from the difference between the
full picture and the empty one). ImageSet (Gemini; stage B uses the stage A picture as its reference) -> Gemini star reversed -> BiRefNet cut -> trimmed, NEVER scaled. The old Cart.png is kept as Cart_old.png.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_cart_items.py [--no-generate]"""
import paths
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

sys.path.insert(0, paths.TACHNEN)
import numpy as np
from PIL import Image

MER = os.path.join(m.P, "UI", "Characters", "Merchant")
RD = os.path.join(MER, "_Redo")
A_SET, B_SET = "Cart A", "Cart B"
NAMES_B = ["Puppet Merchant Cart Empty", "Puppet Merchant Candle", "Puppet Merchant Soup"]


def ref(label, desc, *images):
    return {"label": label, "kind": "setting", "desc": desc, "images": list(images)}


def main():
    m.OUT = {}
    gen = "--no-generate" not in sys.argv
    old = os.path.join(MER, "Cart.png")
    if os.path.exists(old) and not os.path.exists(os.path.join(MER, "Cart_old.png")):
        shutil.copy2(old, os.path.join(MER, "Cart_old.png"))
    if gen:
        a = m.run_batch((A_SET, os.path.join(RD, "cart_style.txt"), os.path.join(RD, "cart_prompts_a.txt"), "1:1", None,
                         {"Puppet Merchant Cart Full": [ref("Sketch", "the composition, items and places to copy exactly", os.path.join(RD, "cart_sketch.png")),
                                                       ref("Style", "the material style to copy: the finished merchant's cart prop", os.path.join(MER, "Cart_old.png"))]}))
    else:
        a = m.newest(A_SET, ["Puppet Merchant Cart Full"])
    full = a["Puppet Merchant Cart Full"]
    if gen:
        r = ref("Cart", "the finished cart picture", full)
        b = m.run_batch((B_SET, os.path.join(RD, "cart_style.txt"), os.path.join(RD, "cart_prompts_b.txt"), "1:1", None, {n: [r] for n in NAMES_B}))
    else:
        b = m.newest(B_SET, NAMES_B)
    print("pictures:", {k: os.path.basename(v) for k, v in {**a, **b}.items()}, flush=True)
    import tachnen_core as core
    import gemini_star
    proc = core.Processor()

    def cut(path):
        raw = gemini_star.remove(Image.open(path).convert("RGBA"))
        return proc.run(raw, m.CUT_OPTS)

    full_img = gemini_star.remove(Image.open(full).convert("RGB")).convert("RGB")
    empty_img = gemini_star.remove(Image.open(b["Puppet Merchant Cart Empty"]).convert("RGB")).convert("RGB")
    cart = cut(b["Puppet Merchant Cart Empty"])
    box = cart.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    cart_t = cart.crop(box)
    # where the two items stood: the difference between the full picture and the empty one (same canvas)
    if full_img.size == empty_img.size:
        d = np.abs(np.asarray(full_img).astype(int) - np.asarray(empty_img).astype(int)).max(axis=2) > 40
        from scipy import ndimage as ndi
        lab, n = ndi.label(ndi.binary_closing(d, iterations=6))
        sizes = ndi.sum(d, lab, range(1, n + 1))
        order = np.argsort(sizes)[::-1][:2]
        spots = []
        for i in order:
            ys, xs = np.where(lab == i + 1)
            spots.append([int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())])
        print("difference blobs (x0,y0,x1,y1 in the picture):", spots, flush=True)
    else:
        spots = []
        print("the two pictures differ in size: place the items by hand", flush=True)
    out = {"cart_box": list(box), "cart_canvas": list(cart.size), "diff_blobs": spots}
    cart_t.save(os.path.join(MER, "cart_empty.png"))
    cut(b["Puppet Merchant Candle"]).crop(cut(b["Puppet Merchant Candle"]).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()).save(os.path.join(MER, "candle.png"))
    soup = cut(b["Puppet Merchant Soup"])
    soup.crop(soup.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()).save(os.path.join(MER, "soup.png"))
    json.dump(out, open(os.path.join(MER, "cart_items.json"), "w"), indent=1)
    full_cut = cut(full)
    full_cut.save(os.path.join(RD, "cart_full_cut.png"))
    print("done", out, flush=True)


if __name__ == "__main__":
    main()
