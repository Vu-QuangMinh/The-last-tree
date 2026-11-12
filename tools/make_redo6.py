"""2026-11-11 second pass on nine bottles (Aegis Elixir = a medieval shield, Thorn Oil = a thorny branch, Purifying Water = a lotus, Liquid Fire = lava, Shatter Salts = a heap of crumbled salt (no bottle),
Smoke Bomb = clear glass with black smoke, Thief's Brew = a stealing hand, Venom Vial = a snake head with fangs, Tinker's Glue = a wrench). Same flow as make_redo5.py.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_redo6.py [--no-generate]   (then tools/set_icon_mipmaps.py and Godot --headless --editor --quit)"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

ICON = os.path.join(m.P, "Icon")
IDS = {"Aegis Elixir": "aegis_elixir", "Thorn Oil": "thorn_oil", "Purifying Water": "purifying_water", "Liquid Fire": "liquid_fire", "Shatter Salts": "shatter_salts",
       "Smoke Bomb": "smoke_bomb", "Thiefs Brew": "thiefs_brew", "Venom Vial": "venom_vial", "Tinkers Glue": "tinkers_glue", "Broken Bottle": "broken_bottle"}
m.OUT = {"Bottle " + k: [os.path.join(ICON, "Bottle", v + ".png"), "trim"] for k, v in IDS.items()}
m.BATCHES = [("Redo7 Bottles" if "--pass3" in sys.argv else "Redo6 Bottles",  # (ImageSet does not redraw an object whose picture already exists in the set: a redo needs a new set name)
               os.path.join(ICON, "Bottle", "bottle_redo_style.txt"), os.path.join(ICON, "Bottle", "bottle_redo4_prompts.txt" if "--pass3" in sys.argv else ("bottle_redo3_prompts.txt" if "--smoke" in sys.argv else "bottle_redo2_prompts.txt")), "1:1", None, {})]
if __name__ == "__main__":
    m.main()
