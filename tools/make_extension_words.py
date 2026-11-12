"""The carved lettering of the last three Extension slams (2026-11-12): Sextuple, Septuple, Octuple (an active row holds at most 8 spells (RunState.MAX_ACTIVE), and the slams count the
spells one Extension wakes, so 8 is the most: "Octuple Extension!"). Same prompt and style as Double..Quintuple (UI/Banners/extension_words_*.txt), with those two as references.
Gemini (the user's quota) draws them; the star watermark is reversed (gemini_star), Tachnen's BiRefNet cuts the black, the cut is trimmed and NEVER scaled.
Output: assets/Puppet/UI/Banners/word_sextuple.png / word_septuple.png / word_octuple.png
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_extension_words.py [--no-generate] [Septuple ...]  (names = only those words; set PYTHONIOENCODING=utf-8)   (then Godot --headless --editor --quit once)"""
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

BAN = os.path.join(AP.PUPPET, "UI", "Banners")
SET = "Puppet Extension Words 2"
NAMES = {"Word Sextuple": "word_sextuple.png", "Word Septuple": "word_septuple.png", "Word Octuple": "word_octuple.png"}
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}


def only():
    return [a.lower() for a in sys.argv[1:] if not a.startswith("--")]


def generate():
    refs = [{"label": "Style", "kind": "character", "desc": "the same carved wooden lettering (colours, chunky carved letters, tilt, sparks) to copy exactly",
             "images": [os.path.join(BAN, "word_quadruple.png"), os.path.join(BAN, "word_quintuple.png")]}]
    objs = []
    for line in open(os.path.join(BAN, "extension_words2_prompts.txt"), encoding="utf-8").read().splitlines():
        if ":" in line.strip() and (not only() or any(w in line.split(":")[0].lower() for w in only())):
            name, prompt = line.split(":", 1)
            objs.append({"name": name.strip(), "prompt": prompt.strip(), "refs": refs})
    status = os.path.join(tempfile.gettempdir(), "ext_words_status.json")
    spec = {"set_name": SET, "style": open(os.path.join(BAN, "extension_words_style.txt"), encoding="utf-8").read().strip(), "ratio": "16:9",
            "objects": objs, "status_path": status, "retries": 1, "redo": [o["name"] for o in objs] if only() else []}  # (redo: draw again even if a picture exists)
    spec_path = os.path.join(tempfile.gettempdir(), "ext_words_spec.json")
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
        im.save(os.path.join(BAN, out))
        print("  %-14s -> %s %s" % (name, out, im.size), flush=True)


if __name__ == "__main__":
    main()
