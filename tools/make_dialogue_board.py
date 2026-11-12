"""2026-11-11: one plain cream dialogue board (light ivory card, thin honey-wood rim) for every dialogue box (events, boss talk, the merchant): it is cut as a nine-patch in the game (ScaledBox), so it never stretches out of shape.
ImageSet (Gemini) -> Gemini star reversed -> key cut -> trimmed, NEVER scaled.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_dialogue_board.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

PR = os.path.join(m.P, "UI", "Characters", "Merchant", "_Props")
m.OUT = {"Ver2 Dialogue Board": [os.path.join(m.P, "UI", "Panels", "dialogue_board_cream.png"), "trim"]}
m.BATCHES = [("Dialog1 Board", os.path.join(PR, "props_style.txt"), os.path.join(PR, "board_prompts.txt"), "4:3", None, {})]
if __name__ == "__main__":
    m.main()
