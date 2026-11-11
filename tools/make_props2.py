"""2026-11-11 pass 2: redo the merchant's "!" (ONE dot only), a "?" sign, the Water and Fire emblems (flat front view like the Wind emblem) and a 2-tier wooden shelf.
ImageSet (Gemini) -> Gemini star reversed -> key cut -> trimmed, NEVER scaled.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_props2.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

MER = os.path.join(m.P, "UI", "Characters", "Merchant")
PR = os.path.join(MER, "_Props")
ART = os.path.join(m.P, "Icon", "Artifact")
m.OUT = {"Ver2 Exclaim": [os.path.join(MER, "mark_exclaim.png"), "trim"], "Ver2 Question": [os.path.join(MER, "mark_question.png"), "trim"],
         "Ver2 Water Emblem": [os.path.join(ART, "water_emblem.png"), "trim"], "Ver2 Fire Emblem": [os.path.join(ART, "fire_emblem.png"), "trim"],
         "Ver2 Shelf": [os.path.join(MER, "shelf.png"), "trim"]}
WIND = [{"label": "Wind emblem", "kind": "character", "desc": "the wind emblem: copy its flat front view, round shape, brass rim, paint wear and relief symbol", "images": [r"E:/GitHub/ImageSet/output/Puppet Icons/Artifact Air Emblem_20261013_145716.png"]}]
if "--exclaim" in sys.argv:  # (the first "!" came without its dot: draw it again, with the "?" sign as the style reference)
    m.OUT = {"Ver2 Exclaim": m.OUT["Ver2 Exclaim"]}
    QREF = [{"label": "Question sign", "kind": "character", "desc": "the sign style: carved golden-yellow wood, brass rim, rivets", "images": [os.path.join(MER, "mark_question.png")]}]
    m.BATCHES = [("Props3b Exclaim", os.path.join(PR, "props_style.txt"), os.path.join(PR, "props3_prompts.txt"), "1:1", None, {})]
else:
  m.BATCHES = [("Props2 Square", os.path.join(PR, "props_style.txt"), os.path.join(PR, "props2_prompts.txt"), "1:1", None, {"Ver2 Water Emblem": WIND, "Ver2 Fire Emblem": WIND}),
               ("Props2 Shelf", os.path.join(PR, "props_style.txt"), os.path.join(PR, "props2_shelf_prompts.txt"), "4:3", None, {})]
if __name__ == "__main__":
    m.main()
