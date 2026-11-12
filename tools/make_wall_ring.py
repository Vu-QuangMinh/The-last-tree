"""The ring of bramble round each Essence of the Bramble Matron's hedge walls (2026-11-12). ElementIcon drew it in code (a dark green arc with 8 triangle thorns); now it is a picture: a round wreath of thorny
bramble vines with an EMPTY middle, painted in the flat plywood style of the Matron (tools/make_briar_walls.py: Enemies/Act2/bramble_minions_style.txt), Gemini draws it (the user's quota), the star is reversed
(gemini_star), the cut is a plain key on black that KEEPS the hole (import_newui2_art.key_cut fills holes, so it is not used here), trimmed, never scaled.
Output: assets/Puppet/UI/Essence/wall_ring.png (ElementIcon.wall_ring_tex: it measures the opening itself and scales the ring so the opening is exactly the orb)
Run:  PYTHONIOENCODING=utf-8 "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_wall_ring.py [--no-generate]"""
import glob
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP
import gemini_star

sys.path.insert(0, paths.TACHNEN)
import numpy as np
from scipy import ndimage as ndi
from PIL import Image

ACT2 = os.path.join(AP.PUPPET, "Enemies", "Act2")
ICON = os.path.join(AP.PUPPET, "Icon")
SET = "Bramble Ring"
NAME = "Puppet Bramble Ring"


def generate():
    prompt = [l.split(":", 1)[1].strip() for l in open(os.path.join(ICON, "Essence_wall_ring_prompts.txt"), encoding="utf-8").read().splitlines() if ":" in l][0]
    refs = [{"label": "Matron", "kind": "character", "desc": "the Briar Hedge: copy its teal-green paint, carved leaf shapes and worn-wood finish, but make the ring far simpler", "images": [os.path.join(AP.PUPPET, "Enemies", "Act1", "briar_hedge.png")]}]
    status = os.path.join(tempfile.gettempdir(), "ring_status.json")
    spec = {"set_name": SET, "style": open(os.path.join(AP.PUPPET, "Enemies", "Act1", "briar_walls_style.txt"), encoding="utf-8").read().strip(), "ratio": "1:1",
            "objects": [{"name": NAME, "prompt": prompt, "refs": refs}], "status_path": status, "retries": 1, "redo": [NAME]}
    spec_path = os.path.join(tempfile.gettempdir(), "ring_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(paths.IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=paths.IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet", SET, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), flush=True)


def newest():
    base = os.path.join(paths.IMAGESET_OUT + "/output", SET)
    found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(NAME) + "_*.png")), key=os.path.getmtime)
    return found[-1] if found else None


def key_keep_hole(raw):
    a = np.asarray(raw.convert("RGB"))
    mx = a.max(axis=2)
    m = mx > 14
    m = ndi.binary_opening(m, structure=np.ones((3, 3)))
    lab, n = ndi.label(m)
    m = lab == (1 + int(np.argmax(ndi.sum(m, lab, range(1, n + 1)))))
    soft = np.clip((mx.astype(np.float32) - 6.0) / 30.0, 0.0, 1.0)
    inner = ndi.binary_erosion(m, iterations=2)
    alpha = np.where(inner, 1.0, np.where(m, np.maximum(soft, 0.35), 0.0))
    im = Image.fromarray(np.dstack([a, (alpha * 255).astype(np.uint8)]), "RGBA")
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def main():
    if "--no-generate" not in sys.argv:
        generate()
    path = newest()
    if not path:
        sys.exit("MISSING: " + NAME)
    im = key_keep_hole(gemini_star.remove(Image.open(path).convert("RGBA")))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))  # (square, the ring centred: the ring's centre is the picture's centre)
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    out = os.path.join(AP.PUPPET, "UI", "Essence", "wall_ring.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sq.save(out)
    al = np.asarray(sq.getchannel("A")) > 40
    yy, xx = np.nonzero(~al)
    c = side / 2.0
    d = np.hypot(xx - c, yy - c)
    hole = float(d[(~ndi.binary_dilation(al, iterations=1))[yy, xx] & (d < side * 0.45)].min()) if len(d) else 0.0
    inside = ~al
    lab, _n = ndi.label(inside)
    centre = lab[side // 2, side // 2]
    hr = float(np.sqrt((lab == centre).sum() / np.pi)) if centre else 0.0
    print("  -> UI/Essence/wall_ring.png %s, opening radius about %.0f px of %.0f (%.2f of the outer)" % (sq.size, hr, side / 2.0, hr / (side / 2.0)))


if __name__ == "__main__":
    main()
