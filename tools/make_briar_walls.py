"""The Bramble Matron's two hedge-wall minions (2026-11-12): pictures for HedgeWall (it drew them in code). Prompts: Enemies/Act1/briar_walls_prompts.txt, style: briar_walls_style.txt (= act1_fix_style)
(the carved-and-painted wood look of the other Act 1 enemies, on black), with the Matron (Enemies/Act1/bramble_matron.png) as a reference so the three belong together.
Gemini (the user's quota) draws them; the star watermark is reversed (gemini_star); Tachnen's BiRefNet cuts the black; the cut is trimmed and put on a square canvas, feet on the
bottom edge, NEVER scaled. Output: Enemies/Act1/briar_wall_left.png / briar_wall_right.png (the left one stands left of the Matron and faces right, the right one the other way).
Run:  PYTHONIOENCODING=utf-8 "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_briar_walls.py [--no-generate] [Left|Right]   (then Godot --headless --editor --quit once)"""
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
from PIL import Image

ENEMIES = os.path.join(AP.PUPPET, "Enemies")
ACT2 = os.path.join(ENEMIES, "Act2")
OUT = os.path.join(ENEMIES, "Act1")
SET = "Briar Walls"
NAMES = {"Puppet Briar Wall Left": "briar_wall_left.png", "Puppet Briar Wall Right": "briar_wall_right.png"}
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}


def only():
    return [a.lower() for a in sys.argv[1:] if not a.startswith("--")]


def generate():
    refs = [{"label": "Matron", "kind": "character", "desc": "the Bramble Matron these hedge walls belong to: copy her flat painted plywood look, leaf greens and thorn colours", "images": [os.path.join(OUT, "bramble_matron.png")]},
            {"label": "Hedge", "kind": "character", "desc": "the Briar Hedge: copy its carved leaves, thorns, berries, teal-green paint and worn-wood finish exactly", "images": [os.path.join(OUT, "briar_hedge.png")]}]
    objs = []
    for line in open(os.path.join(OUT, "briar_walls_prompts.txt"), encoding="utf-8").read().splitlines():
        if ":" in line.strip() and (not only() or any(w in line.split(":")[0].lower() for w in only())):
            name, prompt = line.split(":", 1)
            objs.append({"name": name.strip(), "prompt": prompt.strip(), "refs": refs})
    status = os.path.join(tempfile.gettempdir(), "briar_status.json")
    spec = {"set_name": SET, "style": open(os.path.join(OUT, "briar_walls_style.txt"), encoding="utf-8").read().strip(), "ratio": "1:1",
            "objects": objs, "status_path": status, "retries": 1, "redo": [o["name"] for o in objs]}
    spec_path = os.path.join(tempfile.gettempdir(), "briar_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(paths.IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=paths.IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet", SET, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), flush=True)


def newest(name):
    base = os.path.join(paths.IMAGESET_OUT + "/output", SET)
    found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(name) + "_*.png")), key=os.path.getmtime)
    return found[-1] if found else None


def main():
    if "--no-generate" not in sys.argv:
        generate()
    import tachnen_core as core
    proc = core.Processor()
    for name, out in NAMES.items():
        if only() and not any(w in name.lower() for w in only()):
            continue
        path = newest(name)
        if not path:
            print("MISSING:", name)
            continue
        im = proc.run(gemini_star.remove(Image.open(path).convert("RGBA")), CUT_OPTS)
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        side = int(max(im.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * 0.02)))
        sq.save(os.path.join(OUT, out))
        print("  %-26s -> %s %s" % (name, out, sq.size), flush=True)


if __name__ == "__main__":
    main()
