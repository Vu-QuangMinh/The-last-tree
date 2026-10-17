"""Puppet Stage, the three Essence orbs (fire / water / wind) redone with the symbols standing up in raised brass relief on the ball, like the Air Emblem
artifact. From assets/Puppet/UI/Essence/essence_relief_prompts.txt + essence_relief_style.txt:
  1. ImageSet makes one picture per line in the set "Puppet Essence Relief" (the Air Emblem picture is the style reference); it uses the user's Gemini
     quota on the spare accounts (a2..a5) and stops (nothing touched) when it cannot finish.
  2. each picture is cut out (Tachnen's BiRefNet), trimmed and scaled to 128 px -> UI/Essence/essence_fire / essence_water / essence_wind.png
     (the old ones are kept as <name>_old.png in assets/Puppet/UI/_Source/Essence/).
Run with Tachnen's python:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_essence_orbs.py [--no-generate] [Fire Water Wind]
Then Godot --headless --editor --quit once."""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
SET_NAME = "Puppet Essence Relief"
ESS = os.path.join(AP.PUPPET, "UI", "Essence")
STYLE = os.path.join(ESS, "essence_relief_style.txt")
PROMPTS = os.path.join(ESS, "essence_relief_prompts.txt")
REF = os.path.join(AP.PUPPET, "Icon", "Artifact", "Artifact Air Emblem_20261013_145716.png")
TARGET = {"Essence Fire": "essence_fire", "Essence Water": "essence_water", "Essence Wind": "essence_wind"}


def objects():
    out = []
    for line in open(PROMPTS, encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out.append({"name": name.strip(), "prompt": prompt.strip()})
    return out


def generate(objs, redo=False):
    status = os.path.join(tempfile.gettempdir(), "essence_relief_status.json")
    spec = {"set_name": SET_NAME, "style": open(STYLE, encoding="utf-8").read().strip(), "style_ref": REF, "ratio": "1:1", "objects": objs,
            "status_path": status, "retries": 1, "redo": [o["name"] for o in objs] if redo else [], "accounts": ["a2", "a3", "a4", "a5"]}
    spec_path = os.path.join(tempfile.gettempdir(), "essence_relief_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    code = subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    if code != 0 and st.get("state") != "done":
        sys.exit("ImageSet did not finish (exit %s, %s): nothing was changed." % (code, st.get("state")))


def newest(name):
    found = sorted(glob.glob(os.path.join(glob.escape(os.path.join(IMAGESET, "output", SET_NAME)), glob.escape(name) + "_*.png")), key=os.path.getmtime)
    return found[-1] if found else None


def main():
    objs = objects()
    only = [a for a in sys.argv[1:] if not a.startswith("--")]  # (names like "Wind" "Water": only those are made again)
    if only:
        objs = [o for o in objs if any(w.lower() in o["name"].lower() for w in only)]
    if "--no-generate" not in sys.argv:
        generate(objs, redo=bool(only))  # (named ones are made again even when a picture exists: the prompt changed)
    files = {o["name"]: newest(o["name"]) for o in objs}
    missing = [n for n, f in files.items() if f is None]
    if missing:
        sys.exit("No picture yet for: %s. Nothing was changed." % ", ".join(missing))
    import import_puppet_ui as ui  # (needs Tachnen's python)
    from PIL import Image
    old = os.path.join(AP.PUPPET, "UI", "_Source", "Essence")
    os.makedirs(old, exist_ok=True)
    for name, src in files.items():
        im = ui.cut(src)
        k = 128 / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        dst = os.path.join(ESS, TARGET[name] + ".png")
        if os.path.exists(dst) and not os.path.exists(os.path.join(old, TARGET[name] + "_old.png")):
            shutil.copy(dst, os.path.join(old, TARGET[name] + "_old.png"))
        im.save(dst)
        print("  %-14s -> %s %s" % (name, os.path.basename(dst), im.size))


if __name__ == "__main__":
    main()
