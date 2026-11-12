"""NewUI Ver2 buttons made from DESCRIPTION ONLY (no reference pictures: they washed the details out): Chant + Release (red, same description, only the word differs), Pass (white), Clear (yellow).
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_newui_buttons.py   (sets "NewUI Buttons T 16x9" and "NewUI Buttons T 1x1")
"""
import json
import os
import subprocess
import sys
import tempfile


HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

IMAGESET = paths.IMAGESET
OUT = (paths.IMAGESET_OUT + r"\output")
DIR = os.path.join(AP.PUPPET, "UI", "NewUiV2")
REFS = os.path.join(DIR, "_Refs")
FACE = "a smooth hand-painted enamel face; a thick polished aged-brass rim ring; raised aged-brass serif capitals"
WIDE = ("A wide rounded-rectangle push-button (about 3:2), seen straight from the front. Layers from the outside in: a thick outer rim frame of {colour} enamel paint with softly rounded corners; just inside it a thin polished aged-brass rectangular ring with rounded corners "
        "set into a shadowed groove; inside the ring a raised soft cushion-like face of the same {colour} enamel paint, domed, with deep soft shadows around it. In the middle of the face the raised aged-brass serif capital letters of the single word {word}, "
        "large, spanning about two thirds of the face's width, centred.")
SQUARE = ("A square rounded push-button (1:1), seen straight from the front. Layers from the outside in: a thick outer rim frame of {colour} enamel paint with softly rounded corners; just inside it a thin polished aged-brass rounded-square ring "
          "set into a shadowed groove; inside the ring a raised soft cushion-like rounded-square face of the same {colour} enamel paint, domed, with deep soft shadows around it. In the middle of the face the raised aged-brass serif capital letters of the single word {word}, "
          "about half the face's width, centred.")
PARTS = {
    "Chant Button": ("16:9", WIDE.format(colour="deep theatre-red", word="CHANT")),
    "Release Button": ("16:9", WIDE.format(colour="deep theatre-red", word="RELEASE")),
    "Pass Button": ("1:1", SQUARE.format(colour="warm ivory-white", word="PASS")),
    "Clear Button": ("1:1", SQUARE.format(colour="mustard-yellow", word="CLEAR")),
}


def flat(src, dst):
    im = Image.open(src).convert("RGBA")
    f = Image.new("RGB", im.size, (0, 0, 0))
    f.paste(im, mask=im.split()[3])
    f.save(dst)


def newest(folder, start):
    d = os.path.join(OUT, folder)
    return os.path.join(d, sorted(f for f in os.listdir(d) if f.startswith(start + "_"))[-1])


def run(set_name, ratio, names):
    """TEXT ONLY: reference pictures washed out the details, so none are sent."""
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "newui_style_buttons.txt"), encoding="utf-8").read().strip()
    objs = [{"name": n, "prompt": PARTS[n][1]} for n in names]
    status = os.path.join(tempfile.gettempdir(), "newui_btn_status.json")
    spec = {"set_name": set_name, "style": style, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts, "objects": objs, "redo": names}
    sp = os.path.join(tempfile.gettempdir(), "newui_btn_spec.json")
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print(set_name, "->", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    for n, f in (st.get("files") or {}).items():
        print("  ", n, f)


def release_from_chant():
    """Release = the user's final Chant (HUD.pdf, extracted as button_chant_normal.png) with only the word changed: that ONE picture is sent as the form to copy (it is a clean photo, so it does not wash the details)."""
    from PIL import Image
    src = Image.open(os.path.join(DIR, "button_chant_normal.png")).convert("RGBA")
    w, h = src.size
    cw = max(w, round(h * 16 / 9)); ch = round(cw * 9 / 16)
    cv = Image.new("RGB", (cw, ch), (0, 0, 0))
    cv.paste(src, ((cw - w) // 2, (ch - h) // 2), src)
    os.makedirs(REFS, exist_ok=True)
    ref = os.path.join(REFS, "Chant final 16x9.png")
    cv.save(ref)
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "newui_style_buttons.txt"), encoding="utf-8").read().strip()
    prompt = ("The attached picture is a finished red push-button with the raised brass word CHANT. Make the SAME button again: identical shape, size, proportions, rim, brass ring, red enamel paint, paint wear, lighting and brass lettering style, "
              "in the same position of the frame at the same size; the ONLY change is the word: the raised brass capitals say RELEASE instead of CHANT, with the letters scaled to fit the same lettering area.")
    objs = [{"name": "Release Button", "prompt": prompt, "refs": [{"label": "finished Chant", "kind": "extra", "desc": "the finished button to copy exactly; only the word changes", "images": [ref]}]}]
    status = os.path.join(tempfile.gettempdir(), "newui_btn_status.json")
    spec = {"set_name": "NewUI Buttons Release Final", "style": style, "ratio": "16:9", "status_path": status, "retries": 1, "accounts": accounts, "objects": objs, "redo": ["Release Button"]}
    sp = os.path.join(tempfile.gettempdir(), "newui_btn_spec.json")
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print(st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), st.get("files"))


def main():
    if "--release" in sys.argv:
        return release_from_chant()
    run("NewUI Buttons T 16x9", "16:9", ["Chant Button", "Release Button"])
    run("NewUI Buttons T 1x1", "1:1", ["Pass Button", "Clear Button"])


if __name__ == "__main__":
    main()
