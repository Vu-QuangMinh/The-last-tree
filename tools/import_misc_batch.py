"""Puppet Stage, the 2026-10-14 batch of small art made with ImageSet (sets "Puppet Misc Icons 2", "Puppet Essence Unknown", "Puppet Slot Strips",
"Puppet Result Signs"): the newest picture of each is cut out (Tachnen's BiRefNet), trimmed, scaled, and written where the game looks for it:
  Hot Meal            -> UI/Misc/hot_meal.png
  Card Overlay *      -> Card/card_overlay_silenced / _locked / _used.png      (the pictures over a silenced / locked / used spell card)
  Wax Seal On Card    -> Card/wax_seal_on_card.png                            (the seal on a sealed orb of a spell card)
  Icon Close          -> UI/Buttons/button_close_x_normal / _hover / _pressed.png (the hint panel's close button)
  Essence Unknown     -> UI/Essence/essence_unknown.png                       (what a blinded / never seen Essence looks like)
  Slot Strip Wood     -> UI/Panels/slot_strip_wood.png                        (frame of the bottles row, 3-slice 22/16)
  Slot Strip Brass    -> UI/Panels/slot_strip_brass.png                       (frame of the artifacts row)
  Sign Victory / Perfect Victory / Defeat -> Stage/Shared/sign_victory / sign_perfect_victory / sign_defeat.png  (the boards that drop in after a fight)
Run with Tachnen's python:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_misc_batch.py   (then Godot --headless --editor --quit once)"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP
import import_puppet_ui as ui
from PIL import Image

OUTPUT = r"D:\GitHub Projects\ImageSet\output"
P = AP.PUPPET

# (ImageSet set, object name) -> (file under assets/Puppet, longest edge or exact size)
JOBS = {
    ("Puppet Misc Icons 2", "Icon Hot Meal"): ("UI/Misc/hot_meal.png", 128),
    ("Puppet Misc Icons 2", "Card Overlay Silenced"): ("Card/card_overlay_silenced.png", 200),
    ("Puppet Misc Icons 2", "Card Overlay Locked"): ("Card/card_overlay_locked.png", 200),
    ("Puppet Misc Icons 2", "Card Overlay Used"): ("Card/card_overlay_used.png", 200),
    ("Puppet Misc Icons 2", "Wax Seal On Card"): ("Card/wax_seal_on_card.png", 128),
    ("Puppet Misc Icons 2", "Icon Close"): ("UI/Buttons/button_close_x_normal.png", 96),
    ("Puppet Essence Unknown", "Essence Unknown"): ("UI/Essence/essence_unknown.png", 128),
    ("Puppet Slot Strips", "Slot Strip Wood"): ("UI/Panels/slot_strip_wood.png", (150, 54)),
    ("Puppet Slot Strips", "Slot Strip Brass"): ("UI/Panels/slot_strip_brass.png", (150, 54)),
    ("Puppet Result Signs", "Sign Victory"): ("Stage/Shared/sign_victory.png", 760),
    ("Puppet Result Signs", "Sign Perfect Victory"): ("Stage/Shared/sign_perfect_victory.png", 760),
    ("Puppet Result Signs", "Sign Defeat"): ("Stage/Shared/sign_defeat.png", 760),
}


PICK_OLDEST = {"Icon Hot Meal"}  # (two pictures were made: the first one is the one without the sticker-like cream outline)


def newest(set_name, name):
    found = glob.glob(os.path.join(glob.escape(OUTPUT), glob.escape(set_name), glob.escape(name) + "_*.png"))
    found = [f for f in found if re.search(r"_\d{8}_\d{6}\.png$", f)]
    if not found:
        return None
    return (min if name in PICK_OLDEST else max)(found, key=os.path.getmtime)


def main(only=None):
    for (set_name, name), (rel, size) in JOBS.items():
        if only and name not in only:
            continue
        src = newest(set_name, name)
        if src is None:
            print("  (no picture yet)", name)
            continue
        im = ui.cut(src)
        if isinstance(size, tuple):
            im = im.resize(size, Image.LANCZOS)
        else:
            k = size / max(im.size)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        dst = os.path.join(P, *rel.split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        im.save(dst)
        print("  %-22s -> %s %s" % (name, rel, im.size))
        if name == "Icon Close":  # the other two states of the button: brighter under the mouse, darker and richer pressed
            ui.tone(im, 1.14, 1.05).save(dst.replace("_normal", "_hover"))
            ui.tone(im, 0.78, 1.15, 1.1).save(dst.replace("_normal", "_pressed"))


if __name__ == "__main__":
    main(sys.argv[1:] or None)
