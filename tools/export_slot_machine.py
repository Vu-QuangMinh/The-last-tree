"""Puppet Stage: the new Essence machine ("slot machine") of assets/Puppet/_Source/Slot_machine.pdf.
The page is 1920 x 1080 pt = the screen, so every position written here is a screen position (the game subtracts the Bag strip's corner).
Cuts the pieces to assets/Puppet/UI/SlotMachine/*.png (rendered at 2 x: the game draws them at half their size) and writes scripts/ui/puppet_slot_machine.gd.
Where each piece comes from (see tools/slot_pdf.py for how a page is taken apart):
  the finished machine at the bottom right of the page gives the cabinet (the window well is painted dark), the two funnels, the glass tube and its clamps;
  the loose pieces on the left give the reel drum, the lever, the lamps on / off; the lever's turned (pulled) place is read off the pulled machine at the top;
  the two copies of the port picture at the end of the Bag strip give the port (hole + ring) and the ring alone (over the Essence that come up out of it).
Run: python tools/export_slot_machine.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import math
import os
import sys

import pymupdf
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP
from slot_pdf import Slot

SRC = os.path.join(AP.PUPPET, "_Source", "Slot_machine.pdf")
OUT = os.path.join(AP.PUPPET, "UI", "SlotMachine")
GD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "ui", "puppet_slot_machine.gd")
Z = 2.0  # render zoom: px of the png per pt of the page
BAG_AT = (767.2, 967.0)  # the Bag strip's top-left on the screen (PuppetLayout.BAG_AT)

S = Slot(SRC)
os.makedirs(OUT, exist_ok=True)
layout = {}


def save(name, im, at):
    im.save(os.path.join(OUT, name + ".png"))
    layout[name] = (at[0], at[1], im.width / Z, im.height / Z)
    print("  %-22s at (%.1f, %.1f)  %.1f x %.1f pt" % (name, at[0], at[1], im.width / Z, im.height / Z))


def part(idx, grow=6.0, with_sh=False, with_img=False):
    """Render these painted paths alone; returns (trimmed image, top-left in pt)."""
    r = S.box(idx)
    clip = pymupdf.Rect(r.x0 - grow, r.y0 - grow, r.x1 + grow, r.y1 + grow)
    sh = S.shadings_in(clip, 0) if with_sh else []
    im = []
    if with_img:
        im = [ti for ti, x0, y0, x1, y1 in S.images if clip.x0 <= (x0 + x1) / 2 <= clip.x1 and clip.y0 <= (y0 + y1) / 2 <= clip.y1]
    img = S.render(idx, clip, Z, shadings=sh, images=im)
    return S.trim(img, Z, (clip.x0, clip.y0))


# ---- the finished machine (bottom right of the page) -----------------------------------------------------------------------
print("cabinet, funnels, tube")
img, at = part(range(376, 664))
save("slot_funnel_top", img, at)

body_idx = list(range(664, 2421))
img, at = part(body_idx)
# the window well behind the reels (the page has none: the reels fill it): dark, a touch lighter at the top
well = pymupdf.Rect(1657.0, 685.0, 1827.0, 759.0)
canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
dr_ = ImageDraw.Draw(canvas)
dr_.rectangle([(well.x0 - at[0]) * Z, (well.y0 - at[1]) * Z, (well.x1 - at[0]) * Z, (well.y1 - at[1]) * Z], fill=(34, 24, 19, 255))
canvas.alpha_composite(img)
save("slot_body", canvas, at)

funnel, clamp, tube = [], [], []
for i in range(0, 376):
    d = S.dr[i]
    r = d["rect"]
    f = d.get("fill") or d.get("color") or (0, 0, 0)
    dark = max(f) < 0.3 and abs(f[0] - f[2]) < 0.08
    if r.y1 <= 871 and r.x0 > 1630 and f[0] > f[2] + 0.05 and f[0] < 0.7 and not dark:
        funnel.append(i)
    elif dark:
        clamp.append(i)
    else:
        tube.append(i)
img, at = part(funnel)
save("slot_funnel_bottom", img, at)
# the tube and its clamps share one canvas (the same top-left), so they lie exactly over each other
box = S.box(tube + clamp)
clip = pymupdf.Rect(box.x0 - 4, box.y0 - 4, box.x1 + 4, box.y1 + 4)
for name, idx in (("slot_tube", tube), ("slot_tube_clamps", clamp)):
    im = S.render(idx, clip, Z)
    save(name, im, (clip.x0, clip.y0))

# ---- the loose pieces (left of the machines) ---------------------------------------------------------------------------------
print("reel, lever, lamps")
reel_idx = list(range(5921, 6158))
rbox = S.box(reel_idx)
third = rbox.width / 3.0
mid = [i for i in reel_idx if rbox.x0 + third <= (S.dr[i]["rect"].x0 + S.dr[i]["rect"].x1) / 2 < rbox.x0 + 2 * third]
img, at = part(mid, grow=4.0)
save("slot_reel", img, at)

lever_idx = list(range(3067, 3234))  # (the lever of the finished machine: the same drawing as the loose one, already in place)
img, at = part(lever_idx, grow=28.0, with_sh=True, with_img=True)
save("slot_lever", img, at)

lamp_idx = list(range(5905, 5921))
lbox = S.box(lamp_idx)
clip = pymupdf.Rect(lbox.x0 - 20, lbox.y0 - 30, lbox.x1 + 20, lbox.y1 + 25)
rows = {}
for ti, x, y in S.shadings:
    if clip.x0 <= x <= clip.x1 and clip.y0 <= y <= clip.y1:
        rows.setdefault(round(y / 4.0), []).append((x, y, ti))
print("  lamp rows (y):", {k * 4: len(v) for k, v in rows.items()})
ys = sorted(rows)
for name, key in (("slot_lamp_on", ys[0]), ("slot_lamp_off", ys[-1])):
    lamps = sorted(rows[key])
    x, y, _ = lamps[0]
    c = pymupdf.Rect(x - 12, y - 12, x + 12, y + 12)
    sh = [ti for ti, sx, sy in S.shadings if c.x0 <= sx <= c.x1 and c.y0 <= sy <= c.y1]
    im = [ti for ti, x0, y0, x1, y1 in S.images if c.x0 <= (x0 + x1) / 2 <= c.x1 and c.y0 <= (y0 + y1) / 2 <= c.y1]
    img = S.render([], c, Z, shadings=sh, images=im)
    img, at = S.trim(img, Z, (c.x0, c.y0))
    save(name, img, at)

# where the 8 lamps of the finished machine are (centres): the 8 small pictures on its lamp strip
lamp_sh = sorted({round(x, 1) for ti, x, y in S.shadings if abs(y - 668.3) < 1.0})
assert len(lamp_sh) == 8, lamp_sh
lamp_imgs = lamp_sh
lamp_y = 668.3
print("  lamp strip centres x:", [round(v, 1) for v in lamp_imgs], "y", round(lamp_y, 1))

# ---- the port (end of the Bag strip) ---------------------------------------------------------------------------------------
print("port")
ports = [t for t in S.images if t[1] > 1500 and t[2] > 940 and t[3] - t[1] > 100]
assert len(ports) == 2, ports
pc = pymupdf.Rect(1510, 945, 1650, 1080)
for name, entry in (("slot_port", ports[0]), ("slot_port_ring", ports[1])):
    img = S.render([], pc, Z, images=[entry[0]])
    img, at = S.trim(img, Z, (pc.x0, pc.y0))
    save(name, img, at)

# ---- the lever's pulled place ----------------------------------------------------------------------------------------------
# idle: the knob is straight above the hub; pulled (the machine at the top of the page): the knob is level with the hub, on its right
lv = layout["slot_lever"]
hub = (lv[0] + lv[2] / 2.0, lv[1] + lv[3] - 13.0 - 3.0)  # (bottom of the picture is the hub's silver ring, 13 pt radius, 3 pt of margin)

# ---- the reels' places (of the finished machine) -------------------------------------------------------------------------
reel = layout["slot_reel"]
reel_dx = [1662.0 + 0.5, 1716.0 + 0.5, 1769.0 + 0.5]  # (left edges of the three drums in the window)
reel_y = 690.5

with open(GD, "w", encoding="utf-8", newline="\n") as f:
    f.write("class_name PuppetSlotMachine\nextends RefCounted\n")
    f.write("## GENERATED by tools/export_slot_machine.py from Slot_machine.pdf: do not edit by hand.\n")
    f.write("## The Essence machine of the Puppet Stage. Every position is a SCREEN position in px (the page of the PDF is the screen); the game subtracts the Bag\n")
    f.write("## strip's corner (PuppetLayout.BAG_AT). A piece is (x, y, w, h) of its picture on the screen; the pngs are 2 x that size.\n\n")
    for name, (x, y, w, h) in layout.items():
        f.write("const %s := Rect2(%.2f, %.2f, %.2f, %.2f)\n" % (name.upper().replace("SLOT_", ""), x, y, w, h))
    f.write("\n## The three reels (left edge x of each, top y, size) and the eight lamps (centres).\n")
    f.write("const REEL_X := [%s]\n" % ", ".join("%.1f" % v for v in reel_dx))
    f.write("const REEL_Y := %.1f\n" % reel_y)
    f.write("const REEL_SIZE := Vector2(%.2f, %.2f)\n" % (reel[2], reel[3]))
    f.write("const LAMP_X := [%s]\n" % ", ".join("%.1f" % v for v in lamp_imgs))
    f.write("const LAMP_Y := %.1f\n" % lamp_y)
    f.write("\n## The lever turns about its hub; PULLED_ANGLE is how far it turns (radians, clockwise on the screen) when it is pulled down.\n")
    f.write("const LEVER_HUB := Vector2(%.1f, %.1f)\nconst LEVER_PULLED_ANGLE := %.5f\n" % (hub[0], hub[1], math.pi / 2.0))
    f.write("\n## The port: where Essence come up out of the Bag strip (centre).\n")
    f.write("const PORT_C := Vector2(1578.46, 1012.1)\n")
print("wrote", GD)
