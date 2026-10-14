"""Puppet Stage, Act 3 enemies, from the prompt + style files in assets/Puppet/Enemies/Act3/ (act3_enemies_prompts.txt, act3_enemies_style.txt):
  1. ImageSet makes one picture per line ("Puppet <Name>") in the set "Puppet Act 3 Enemies" (the same carved-and-painted marionette style as Acts 1
     and 2, in a snowy palette); it uses the user's Gemini quota, and stops (exit 3, nothing touched) when the quota is used up: run it again later,
     the pictures that are already made are kept.
  2. every new picture has its white background cut out (the Tachnen tool's BiRefNet, as for the Act 1 / 2 puppets) -> Enemies/_Source/Act3/Puppet <Name>.png
  3. only when all of them are cut: every file in Enemies/Act3/ is deleted and the new ones are written there by import_puppet_enemies.py
     (trimmed, square canvas, feet on the bottom edge, 512 px), and the prompt + style files are put back.
Run with Tachnen's python:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_act3_enemies.py [--no-generate]
(--no-generate: skip step 1 and use the newest pictures of ImageSet's output/Puppet Act 3 Enemies). Then Godot --headless --editor --quit once."""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
SET_NAME = "Puppet Act 3 Enemies"
ACT3 = os.path.join(AP.PUPPET, "Enemies", "Act3")
SRC3 = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act3")
STYLE = os.path.join(ACT3, "act3_enemies_style.txt")
PROMPTS = os.path.join(ACT3, "act3_enemies_prompts.txt")


def objects():
    out = []
    for line in open(PROMPTS, encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out.append({"name": name.strip(), "prompt": prompt.strip()})
    return out


def generate(objs):
    status = os.path.join(tempfile.gettempdir(), "act3_status.json")
    spec = {"set_name": SET_NAME, "style": open(STYLE, encoding="utf-8").read().strip(), "ratio": "1:1", "objects": objs, "status_path": status, "retries": 2}
    spec_path = os.path.join(tempfile.gettempdir(), "act3_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    code = subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    if code != 0 and st.get("state") != "done":
        sys.exit("ImageSet did not finish (exit %s, %s): nothing was changed. Run this again when it can." % (code, st.get("state")))
    return st["files"]


def newest_outputs(objs):
    base = os.path.join(IMAGESET, "output", SET_NAME)
    files = {}
    for o in objs:
        found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(o["name"]) + "_*.png")), key=os.path.getmtime)
        if found:
            files[o["name"]] = found[-1]
    return files


def main():
    objs = objects()
    assert len(objs) == 9, len(objs)
    files = newest_outputs(objs) if "--no-generate" in sys.argv else generate(objs)
    missing = [o["name"] for o in objs if o["name"] not in files]
    if missing:
        sys.exit("No picture yet for: %s. Nothing was changed." % ", ".join(missing))
    import import_puppet_ui as ui  # (needs Tachnen's python)
    cut = {}
    for name, path in files.items():
        im = ui.cut(path)
        cut[name] = im
        print("  cut", name, im.size)
    keep = {p: open(p, encoding="utf-8").read() for p in (STYLE, PROMPTS)}
    for folder in (ACT3, SRC3):  # (every file that is there now goes)
        if os.path.isdir(folder):
            for f in glob.glob(os.path.join(folder, "*")):
                os.remove(f)
        os.makedirs(folder, exist_ok=True)
    for name, im in cut.items():
        im.save(os.path.join(SRC3, name + ".png"))
    sys.argv = [sys.argv[0], "3"]
    import import_puppet_enemies as imp
    imp.main()
    for p, text in keep.items():
        open(p, "w", encoding="utf-8").write(text)
    print("done: %d puppets in %s" % (len(cut), ACT3))


if __name__ == "__main__":
    main()
