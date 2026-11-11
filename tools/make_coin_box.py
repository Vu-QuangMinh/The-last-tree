"""2026-11-11: the wooden savings box (coin slot on top, a blank cream label on the front where the Leaves number is written) that replaces the leather purse in the shop.
ImageSet (Gemini) -> Gemini star reversed -> key cut -> trimmed, NEVER scaled.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_coin_box.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

PR = os.path.join(m.P, "UI", "Characters", "Merchant", "_Props")
m.OUT = {"Ver2 Coin Box A": [os.path.join(PR, "coin_box_A.png"), "trim"], "Ver2 Coin Box B": [os.path.join(PR, "coin_box_B.png"), "trim"]}
m.BATCHES = [("Props6 Box", os.path.join(PR, "props_style.txt"), os.path.join(PR, "box_prompts.txt"), "1:1", None, {})]
if __name__ == "__main__":
    m.main()
