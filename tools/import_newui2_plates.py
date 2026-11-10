"""NewUI Ver2: ImageSet's plates (tools/make_newui_plates_art.py, sets "NewUI Plates <ratio>") -> assets/Puppet/UI/NewUiV2/. Cut with Tachnen (BiRefNet, + the hole/notch repair of
import_newui2_art.cut for the solid plates), trimmed, NEVER resized (the user's rule: they are edited by hand later; the game scales them).
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_newui2_plates.py [Name ...]
then Godot --headless --editor --quit once so it imports the new files."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_newui2_art as I

PLATES = {"Plate Left": ("NewUI Plates 16x9", "nu2_plate_left"), "Plate Small": ("NewUI Plates 16x9", "nu2_plate_small"), "Plate Right": ("NewUI Plates 4x3", "nu2_plate_right"),
          "Plate Long": ("NewUI Plates 21x9", "nu2_plate_long"), "HP Glass Tube": ("NewUI Plates 21x9", "nu_hp_lower")}
I.SOLID.extend(n for n in PLATES if n != "HP Glass Tube")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, (set_name, out) in PLATES.items():
        if only and name not in only:
            continue
        src = I.newest(set_name, name)
        if src is None:
            print("no picture yet:", name)
            continue
        im = I.cut(src, name)
        im.save(os.path.join(I.OUT, out + ".png"))
        print("%-14s %s -> %s %s" % (name, os.path.basename(src), out, im.size))


if __name__ == "__main__":
    main()
