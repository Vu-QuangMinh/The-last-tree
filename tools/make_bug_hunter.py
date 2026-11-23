"""2026-11-12 Bug Hunter redone as a brass bell with one big eye, two arms (magnifying glass + striker): the code-drawn picture
(tools/bug_hunter_ref.gd -> Enemies/Act2/_Refs/bug_hunter_ref.png) is the ImageSet reference; Gemini (the user's quota) paints 2 variants;
Tachnen's BiRefNet cuts the black background; the cut picture is trimmed and put on a square canvas, feet on the bottom edge, NEVER scaled.
Variant 1 -> Enemies/Act2/bug_hunter.png (the old robot is backed up in Enemies/_Source/_Backup_bug_hunter/); both kept in Enemies/_Source/Act2/.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_bug_hunter.py [--no-generate]   (then Godot --headless --editor --quit once)"""
import glob
import json
import os
import shutil
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
REF = os.path.join(ACT2, "_Refs", "bug_hunter_ref.png")
SET = "Act 2 Bug Hunter"
NAMES = ["Puppet Bug Hunter", "Puppet Bug Hunter B"]
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}


def generate():
    objs = []
    for line in open(os.path.join(ACT2, "bug_hunter_prompts.txt"), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            objs.append({"name": name.strip(), "prompt": prompt.strip(),
                         "refs": [{"label": "Design", "kind": "character", "desc": "the exact shape: bell body, one big eye, two arms with a magnifying glass and a striker, thin legs; repaint it as a wooden marionette", "images": [REF]}]})
    status = os.path.join(tempfile.gettempdir(), "bug_hunter_status.json")
    spec = {"set_name": SET, "style": open(os.path.join(ACT2, "act2_mobs_style.txt"), encoding="utf-8").read().strip(), "ratio": "1:1",
            "objects": objs, "status_path": status, "retries": 1}
    spec_path = os.path.join(tempfile.gettempdir(), "bug_hunter_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(paths.IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=paths.IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet", SET, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))


def newest(name):
    base = os.path.join(paths.IMAGESET_OUT + "/output", SET)
    found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(name) + "_*.png")), key=os.path.getmtime)
    return found[-1] if found else None


def main():
    if "--no-generate" not in sys.argv:
        generate()
    import tachnen_core as core
    proc = core.Processor()
    backup = os.path.join(ENEMIES, "_Source", "_Backup_bug_hunter")
    for i, name in enumerate(NAMES):
        path = newest(name)
        if not path:
            print("MISSING:", name)
            continue
        im = proc.run(gemini_star.remove(Image.open(path).convert("RGBA")), CUT_OPTS)  # (the star reversed first, nothing cut)
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        side = int(max(im.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * 0.02)))
        im.save(os.path.join(ENEMIES, "_Source", "Act2", name + ".png"))
        if i == 0:
            dest = os.path.join(ACT2, "bug_hunter.png")
            os.makedirs(backup, exist_ok=True)
            if os.path.exists(dest) and not os.path.exists(os.path.join(backup, "bug_hunter.png")):
                shutil.copy2(dest, os.path.join(backup, "bug_hunter.png"))
            sq.save(dest)
        else:
            sq.save(os.path.join(ENEMIES, "_Source", "Act2", name + "_square.png"))
        print("  %-24s %dx%d" % (name, sq.width, sq.height))


if __name__ == "__main__":
    main()
