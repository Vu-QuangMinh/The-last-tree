"""NewUI Ver2: ImageSet's buttons (tools/make_newui_buttons.py) -> assets/Puppet/UI/NewUiV2/button_<kind>_<state>.png. Cut with Tachnen (+ the solid-part repair), trimmed, NEVER resized; hover / pressed / disabled are tints.
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_newui2_buttons.py [Name ...]
then Godot --headless --editor --quit once."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_newui2_art as I

# Chant / Pass / Clear are the user's own pictures in HUD.pdf (tools/extract_newui2_pdf.py); only Release is made (tools/make_newui_buttons.py --release: the final Chant with the word changed)
BUTTONS = {"Release Button": ("NewUI Buttons Release Final", "release")}
I.SOLID.extend(BUTTONS)


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, (set_name, kind) in BUTTONS.items():
        if only and name not in only:
            continue
        src = I.newest(set_name, name)
        if src is None:
            print("no picture yet:", name)
            continue
        im = I.cut(src, name)
        for st in ("normal", "hover", "pressed", "disabled"):
            I.save_safe(I.tinted(im, st), os.path.join(I.OUT, "button_%s_%s.png" % (kind, st)))
        print("%-15s %s -> button_%s_* %s" % (name, os.path.basename(src), kind, im.size))


if __name__ == "__main__":
    main()
