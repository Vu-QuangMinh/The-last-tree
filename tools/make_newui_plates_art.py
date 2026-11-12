"""NewUI Ver2, the background plates the user cut out in assets/Puppet/UI/NewUiV2/HUD.pdf (page 2: five flat shapes) redone in the cabinet's style + the game's own puppet-theatre style.
Each shape is rendered flat from the PDF (zoom 3) and placed in a frame of a MODERATE ratio (never beyond 21:9 / 9:21: Gemini does badly with very long thin pictures, the user's rule),
white around it; the frame is the layout reference. Refs: [layout frame, the finished cabinet v2 (design), the game's stage picture from page 1 of the PDF (mood)].
After the cut only TRIM the empty border (never resize: the user's rule) to get the long thin shape back.
Run with the system python (pymupdf; it starts ImageSet itself):  python tools/make_newui_plates_art.py [--frames-only] [Name ...]"""
import json
import os
import subprocess
import sys
import tempfile

import pymupdf
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

IMAGESET = paths.IMAGESET
OUT = (paths.IMAGESET_OUT + r"\output")
DIR = os.path.join(AP.PUPPET, "UI", "NewUiV2")
REFS = os.path.join(DIR, "_Refs")
PDF = os.path.join(DIR, "HUD.pdf")
FILL = "dark stained walnut with a thin polished aged-brass rim running all along its whole edge, tiny brass studs near the corners and a faint hand-carved scroll border just inside the rim"
# name -> (drawing rect on page 2 of the PDF, frame ratio (w, h), prompt)
NO_FLOOR = ". The background is pure black only: no floor, no stage boards, no table, no reflection, nothing under or behind the part (the stage picture is only a mood reference)"
PARTS = {
    "Plate Left": ((79.3, 126.0, 491.5, 330.1), (16, 9),
                   "A flat wide HUD plate, a four-sided panel whose left edge is vertical and whose right edge is slanted, exactly the outline of the layout frame, made of " + FILL),
    "Plate Small": ((183.2, 626.7, 473.8, 775.6), (16, 9),
                    "A flat wide HUD plate cut from ONE single continuous slab of walnut (one uniform grain, no joins, no planks), a four-sided panel whose left edge is vertical and whose right edge is slanted, exactly the outline of the layout frame, made of " + FILL + NO_FLOOR),
    "Plate Right": ((1493.1, 407.7, 1760.4, 611.8), (4, 3),
                    "A flat HUD plate, a four-sided panel whose right edge is vertical and whose left edge is slanted, exactly the outline of the layout frame, made of " + FILL),
    "Plate Long": ((719.9, 143.5, 1779.5, 347.6), (21, 9),
                   "A very long flat HUD plate with a raised step at its upper right, slanted left and right ends, exactly the outline of the layout frame, made of " + FILL + NO_FLOOR),
    "HP Glass Tube": ((371.5, 519.4, 1368.9, 560.6), (21, 9),
                      "A very long thin glass gauge tube lying horizontally, exactly the outline of the layout frame (its two ends slightly slanted): a thick clear glass cylinder with real refraction, a polished aged-brass cap with two small screws at each end, "
                      "the inside is completely empty and clear (no liquid), a soft highlight running along the glass" + NO_FLOOR),
}


def frames():
    os.makedirs(REFS, exist_ok=True)
    doc = pymupdf.open(PDF)
    page = doc[1]
    for name, (r, (rw, rh), _p) in PARTS.items():
        pm = page.get_pixmap(matrix=pymupdf.Matrix(3, 3), clip=pymupdf.Rect(r[0] - 3, r[1] - 3, r[2] + 3, r[3] + 3))
        pm.save(os.path.join(REFS, "_tmp.png"))
        im = Image.open(os.path.join(REFS, "_tmp.png")).convert("RGB")
        w = im.width / 0.92
        h = w * rh / rw
        if im.height > 0.92 * h:
            h = im.height / 0.92
            w = h * rw / rh
        canvas = Image.new("RGB", (round(w), round(h)), (255, 255, 255))
        canvas.paste(im, ((canvas.width - im.width) // 2, (canvas.height - im.height) // 2))
        canvas.save(os.path.join(REFS, name + " frame.png"))
    os.remove(os.path.join(REFS, "_tmp.png"))
    # the game's stage (the picture behind the HUD on page 1): the mood reference
    stage = [i for i in doc[0].get_image_info(xrefs=True) if i["bbox"][2] - i["bbox"][0] > 1900][0]
    pix = pymupdf.Pixmap(doc, stage["xref"])
    if pix.n - pix.alpha >= 4:
        pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
    pix.save(os.path.join(REFS, "Game Stage.png"))


def newest(folder, start):
    d = os.path.join(OUT, folder)
    return os.path.join(d, sorted(f for f in os.listdir(d) if f.startswith(start + "_"))[-1])


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    frames()
    if "--frames-only" in sys.argv:
        return
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "newui_style_v2.txt"), encoding="utf-8").read().strip()
    design = {"label": "finished showcase", "kind": "extra", "desc": "the finished showcase of the new design: copy its walnut, brass, red velvet, red lacquer and gold scrollwork",
              "images": [newest("MinhHUD Cabinet v2", "Artifact Cabinet v2")]}
    mood = {"label": "game stage", "kind": "extra", "desc": "the stage of the game: the warm hand-made puppet-theatre mood to match; do not copy its scenery", "images": [os.path.join(REFS, "Game Stage.png")]}
    groups = {}
    for name, (r, ratio, prompt) in PARTS.items():
        if only and name not in only:
            continue
        frame = {"label": "layout frame", "kind": "extra", "desc": "flat layout frame of this part in its picture frame: keep its exact outline, proportions and place; the white around it is only the frame",
                 "images": [os.path.join(REFS, name + " frame.png")]}
        groups.setdefault("%d:%d" % ratio, []).append({"name": name, "prompt": prompt, "refs": [frame, design, mood]})
    for ratio, objs in groups.items():
        tag = ratio.replace(":", "x")
        status = os.path.join(tempfile.gettempdir(), "newui_plates_%s.json" % tag)
        spec = {"set_name": "NewUI Plates " + tag, "style": style, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts,
                "objects": objs, "redo": [o["name"] for o in objs] if only else []}
        sp = os.path.join(tempfile.gettempdir(), "newui_plates_spec_%s.json" % tag)
        json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
        st = json.load(open(status, encoding="utf-8"))
        print(ratio, "->", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
        for n, f in (st.get("files") or {}).items():
            print("  ", n, f)


if __name__ == "__main__":
    main()
