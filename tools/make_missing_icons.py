"""Puppet Stage, the icons found missing by tools/icon_audit.gd (2026-10-18), made with ImageSet from the prompt + style files that sit beside the art:
  Magic Box (artifact)  Icon/Artifact/artifact_extra_prompts.txt + artifact_icons_style.txt -> Icon/Artifact/magic_box.png
  Tinkers Glue (bottle) Icon/Bottle/bottle_extra_prompts.txt     + bottle_icons_style.txt   -> Icon/Bottle/tinkers_glue.png
  Intent Revive         Icon/Intent/intent_extra_prompts.txt     + intent_extra_style.txt   -> Icon/Intent/intent_revive.png
  Cursor Hand Open / Fist (the steal cursor, back of the hand) UI/Icons/hand_prompts.txt + hand_style.txt -> UI/Icons/cursor_hand_open.png / cursor_hand_fist.png
  Intent Missing (7 intents), Icon Paintbrush, Word Extension / Double / Triple / Quadruple / Quintuple (2026-10-19, see the JOBS list)
Each is cut out (Tachnen's BiRefNet), trimmed and scaled to 128 px (the hands 160 px: they are the mouse cursor). Uses the spare Gemini accounts (a2..a5).
Run with Tachnen's python:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_missing_icons.py [--no-generate] [Name ...]
Then Godot --headless --editor --quit once."""
import glob
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
P = AP.PUPPET
# set name, style file, prompts file, {picture name: (file written, longest edge)}
JOBS = [
    ("Puppet Artifact Extra", "Icon/Artifact/artifact_icons_style.txt", "Icon/Artifact/artifact_extra_prompts.txt", {"Artifact Magic Box": ("Icon/Artifact/magic_box.png", 128)}),
    ("Puppet Bottle Extra", "Icon/Bottle/bottle_icons_style.txt", "Icon/Bottle/bottle_extra_prompts.txt", {"Bottle Tinkers Glue": ("Icon/Bottle/tinkers_glue.png", 128)}),
    ("Puppet Intent Extra", "Icon/Intent/intent_extra_style.txt", "Icon/Intent/intent_extra_prompts.txt", {"Intent Revive": ("Icon/Intent/intent_revive.png", 128)}),
    ("Puppet Hands", "UI/Icons/hand_style.txt", "UI/Icons/hand_prompts.txt",
     {"Cursor Hand Open": ("UI/Icons/cursor_hand_open.png", 160), "Cursor Hand Fist": ("UI/Icons/cursor_hand_fist.png", 160)}),
    # 2026-10-19: the intents without a picture, the Repaint brush and the lettering of the Extension banners
    ("Puppet Intent Missing", "Icon/Intent/intent_extra_style.txt", "Icon/Intent/missing_intents_prompts.txt",
     {"Intent " + n: ("Icon/Intent/intent_%s.png" % n.lower().replace(" ", "_"), 128) for n in ["Grow Thorns", "Hold", "Cleanse Self", "Drain Essence", "Disarm", "Brittle", "Regrow"]}),
    ("Puppet Brush", "UI/Icons/icons_style.txt", "UI/Icons/brush_prompts.txt", {"Icon Paintbrush": ("UI/Icons/icon_brush.png", 128)}),
    ("Puppet Extension Words", "UI/Banners/extension_words_style.txt", "UI/Banners/extension_words_prompts.txt",
     {"Word " + n: ("UI/Banners/word_%s.png" % n.lower(), 1024) for n in ["Extension", "Double", "Triple", "Quadruple", "Quintuple"]}, "16:9"),
    # the paint splats of Repaint / Expose, three of each colour (PaintSplash lays several over each other into one puddle)
    ("Puppet Splash", "UI/Fx/splash_style.txt", "UI/Fx/splash_prompts.txt",
     {"Splash %s %d" % (c, k): ("UI/Fx/splash_%s_%d.png" % (c.lower(), k), 320) for c in ["Fire", "Water", "Wind"] for k in [1, 2, 3]}),
    ("Puppet Splash White", "UI/Fx/splash_white_style.txt", "UI/Fx/splash_white_prompts.txt",
     {"Splash Any %d" % k: ("UI/Fx/splash_any_%d.png" % k, 320) for k in [1, 2, 3]}),
]


def objects(path):
    out = []
    for line in open(os.path.join(P, path), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out.append({"name": name.strip(), "prompt": prompt.strip()})
    return out


def generate(set_name, style, objs, ratio="1:1"):
    status = os.path.join(tempfile.gettempdir(), "missing_icons_status.json")
    spec = {"set_name": set_name, "style": open(os.path.join(P, style), encoding="utf-8").read().strip(), "ratio": ratio, "objects": objs,
            "status_path": status, "retries": 1, "accounts": ["a2", "a3", "a4", "a5"]}
    if os.path.exists(status):
        os.remove(status)  # (a status left by the last run would look like this one finished)
    spec_path = os.path.join(tempfile.gettempdir(), "missing_icons_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    code = subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", set_name, st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), flush=True)
    if code != 0 and st.get("state") != "done":
        sys.exit("ImageSet did not finish (exit %s, %s): nothing was changed." % (code, st.get("state")))


OUTPUTS = [os.path.join(IMAGESET, "output"), r"E:\GitHub\ImageSet\output"]  # (ImageSet's output folder was moved to E: on 2026-10-19: look in both)


def newest(set_name, name):
    found = []
    for out in OUTPUTS:
        found += glob.glob(os.path.join(glob.escape(os.path.join(out, set_name)), glob.escape(name) + "_*.png"))
    found.sort(key=os.path.getmtime)
    return found[-1] if found else None


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    import import_puppet_ui as ui  # (needs Tachnen's python)
    from PIL import Image
    for job in JOBS:
        set_name, style, prompts, targets = job[:4]
        ratio = job[4] if len(job) > 4 else "1:1"
        objs = [o for o in objects(prompts) if not only or any(w.lower() in o["name"].lower() for w in only)]
        if not objs:
            continue
        if "--no-generate" not in sys.argv:
            generate(set_name, style, objs, ratio)
        for o in objs:
            src = newest(set_name, o["name"])
            if src is None:
                print("  (no picture yet)", o["name"])
                continue
            rel, size = targets[o["name"]]
            im = ui.cut(src)
            k = size / max(im.size)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            im.save(os.path.join(P, *rel.split("/")))
            print("  %-22s -> %s %s" % (o["name"], rel, im.size), flush=True)


if __name__ == "__main__":
    main()
