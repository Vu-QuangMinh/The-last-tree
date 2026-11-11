"""2026-11-11: every bottle icon redone so its SHAPE shows its effect (Healing Tonic = clear red water, Echo Draught = a bell, Frost Phial = a snowflake, Prism Draught = a rainbow arch...), and the Seed of Life (fresh green, a sprout: rebirth).
ImageSet (Gemini) -> Gemini star reversed -> Tachnen BiRefNet -> trimmed, FULL size (no 128 px scaling any more). Old icons are backed up in Enemies/_Source/_Backup_redo_2026-11-11/.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_redo5.py [--no-generate]   (then set mipmaps on the new .import files: tools/set_icon_mipmaps.py, and Godot --headless --editor --quit)"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

ICON = os.path.join(m.P, "Icon")
MAP = json.load(open(os.path.join(ICON, "Bottle", "_redo_map.json"), encoding="utf-8"))
m.OUT = {k: [os.path.join(m.P, v), "trim"] for k, v in MAP.items()}
m.OUT["Artifact Seed of Life"] = [os.path.join(ICON, "Artifact", "seed_of_life.png"), "trim"]
m.BATCHES = [("Redo5 Bottles", os.path.join(ICON, "Bottle", "bottle_redo_style.txt"), os.path.join(ICON, "Bottle", "bottle_redo_prompts.txt"), "1:1", None, {}),
             ("Redo5 Seed", os.path.join(ICON, "Artifact", "artifact_icons_style.txt"), os.path.join(ICON, "Artifact", "seed_redo_prompts.txt"), "1:1", None, {})]
if __name__ == "__main__":
    m.main()
