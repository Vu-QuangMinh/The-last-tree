"""2026-11-11: coin purse (a flat panel for the number), the merchant's "!" sign, one rarity corner each for Rare (green) and Legendary (gold) (the other corners are this one flipped), a floor rug for 3 artifacts and a wooden table for 3 bottles.
ImageSet (Gemini) -> Gemini star reversed -> key cut (solid parts on black) -> trimmed, NEVER scaled. The wide ones (rug, table) are drawn in a 21:9 frame (Gemini draws very long thin pictures badly) and only trimmed afterwards.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_props.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

MER = os.path.join(m.P, "UI", "Characters", "Merchant")
PR = os.path.join(MER, "_Props")
m.OUT = {"Ver2 Purse": [os.path.join(m.P, "UI", "Icons", "coin_purse.png"), "trim"], "Ver2 Exclaim": [os.path.join(MER, "mark_exclaim.png"), "trim"],
         "Ver2 Corner Rare": [os.path.join(m.P, "Card", "rarity_corner_rare.png"), "trim"], "Ver2 Corner Legendary": [os.path.join(m.P, "Card", "rarity_corner_legendary.png"), "trim"],
         "Ver2 Rug": [os.path.join(MER, "rug.png"), "trim"], "Ver2 Table": [os.path.join(MER, "table.png"), "trim"]}
m.BATCHES = [("Props Square", os.path.join(PR, "props_style.txt"), os.path.join(PR, "props_square_prompts.txt"), "1:1", None, {}),
             ("Props Wide", os.path.join(PR, "props_style.txt"), os.path.join(PR, "props_wide_prompts.txt"), "21:9", None, {})]
if __name__ == "__main__":
    m.main()
