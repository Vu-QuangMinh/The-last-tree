"""NewUI Ver2: the user's sheet assets/Puppet/UI/NewUiV2/Buttons.png (4 columns Chant / Release / Clear / Pass, 3 rows Normal / Hover / Pressed, on black, labels and the Gemini star on it)
-> ONLY button_<kind>_<hover|pressed>.png (the user's own hover and pressed pictures; run it AFTER extract_newui2_pdf.py and import_newui2_buttons.py, which write the normal ones and the tints). The star is reversed out (tools/gemini_star.py), every button is cut by the black key (tools/import_newui2_art.key_cut), trimmed, NEVER resized;
the disabled one is a tint of the normal one.
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_newui2_sheet.py"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gemini_star
import import_newui2_art as I

KINDS = ["chant", "release", "clear", "pass"]
STATES = ["normal", "hover", "pressed"]


def main():
    sheet = gemini_star.remove(Image.open(os.path.join(I.OUT, "Buttons.png")).convert("RGBA"))
    a = np.asarray(sheet.convert("RGB"))
    h, w = a.shape[:2]
    m = a.max(axis=2) > 24
    m = ndi.binary_closing(m, structure=np.ones((3, 3)), iterations=6)  # (a button's soft shadow joins its pieces; the labels are thin text: dropped by size)
    lab, n = ndi.label(m)
    boxes = []
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if hh > h * 0.12 and ww > w * 0.12:
            boxes.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop))
    if len(boxes) != 12:
        raise SystemExit("expected 12 buttons, found %d: %s" % (len(boxes), boxes))
    boxes.sort(key=lambda b: (b[0] + b[2]) / 2)
    for r in range(3):
        row = sorted(boxes[r * 4:(r + 1) * 4], key=lambda b: b[1])
        for c in range(4):
            y0, x0, y1, x1 = row[c]
            pad = 12
            crop = sheet.crop((max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)))
            im = I.key_cut(crop)
            if im is None:
                raise SystemExit("not black around %s %s" % (KINDS[c], STATES[r]))
            if STATES[r] == "normal":
                continue  # (the normal ones are the PDF's own pictures / the made Release, see the module doc)
            I.save_safe(im, os.path.join(I.OUT, "button_%s_%s.png" % (KINDS[c], STATES[r])))
            print("%-8s %-8s %s" % (KINDS[c], STATES[r], im.size))


if __name__ == "__main__":
    main()
