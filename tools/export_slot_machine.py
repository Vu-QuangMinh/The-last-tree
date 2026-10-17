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
# The paint operators of the page come in this order (found by looking at where the clumps are on the page; the last line of the file said which index each
# one has): the tube with its clamps and collar, the top funnel, the cabinet (frame, then the three reels, then the 8 lamp sockets), the Bag strip, the lever, ...
# There is no bottom funnel any more (the tube starts right under the cabinet), and the whole machine is smaller than the first version.
def clump_start(near):
    for k, d in enumerate(S.dr):
        r = d["rect"]
        if abs(r.x0 - near[0]) < 2 and abs(r.y0 - near[1]) < 2:
            return k
    raise SystemExit("no path at %s" % (near,))


print("cabinet, funnel, tube")
FUNNEL_OPS = list(range(603, 891))
BODY_OPS = list(range(891, 2648))
REEL_OPS = list(range(2648, 2932))
LAMPSOCKET_OPS = list(range(2932, 2940))
LEVER_OPS = list(range(3294, 3461))
for name, ops, ref in (("funnel", FUNNEL_OPS, (1746, 715)), ("lever", LEVER_OPS, (1703, 798))):
    r = S.box(ops)
    assert abs(r.x0 - ref[0]) < 8 and abs(r.y0 - ref[1]) < 8, (name, r)  # (the page was edited: look at the indexes again)

img, at = part(FUNNEL_OPS)
save("slot_funnel_top", img, at)

# the cabinet: the frame and the sockets of the lamps (the reels, the lamps and the lever are separate pieces)
rbox = S.box(REEL_OPS[1:])  # (the first operator is the shadow of the window: it is not a reel)
well = pymupdf.Rect(rbox.x0 - 5.0, rbox.y0 - 4.0, rbox.x1 + 5.0, rbox.y1 + 4.0)
img, at = part(BODY_OPS + LAMPSOCKET_OPS)
# the window well behind the reels (the page has none: the reels fill it): dark
canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
dr_ = ImageDraw.Draw(canvas)
dr_.rectangle([(well.x0 - at[0]) * Z, (well.y0 - at[1]) * Z, (well.x1 - at[0]) * Z, (well.y1 - at[1]) * Z], fill=(34, 24, 19, 255))
canvas.alpha_composite(img)
save("slot_body", canvas, at)

# the glass tube is three layers, each drawn in its own frame on the left of the page (the three frames share one coordinate system with the "demo" frame, which
# shows the tube as it looks assembled; the finished machine's tube has the very same size as the metal layer, so that is what gives the shift to the game):
#   glass_under: under the Essence (normal, 100 %)   glass: over the Essence (Screen blend, 50 %)   metal (collars, clamps): over everything (normal, 100 %)
FRAMES = {"slot_tube_glass": (439.56, 269.66, range(296, 457)), "slot_tube_metal": (687.85, 269.66, range(457, 587)),
          "slot_tube_glass_under": (942.42, 269.66, range(587, 603))}
mb = S.box(list(FRAMES["slot_tube_metal"][2]))
fin = S.box(list(range(2, 296)))  # (the tube of the finished machine at the bottom right)
assert abs(mb.width - fin.width) < 0.5 and abs(mb.height - fin.height) < 0.5, (mb, fin)
sx = fin.x0 - (mb.x0 - FRAMES["slot_tube_metal"][0])  # game x of a frame's left edge
sy = fin.y0 - (mb.y0 - FRAMES["slot_tube_metal"][1])
union = None
for name, (ox, oy, rg) in FRAMES.items():
    b = S.box(list(rg))
    b = pymupdf.Rect(b.x0 - ox, b.y0 - oy, b.x1 - ox, b.y1 - oy)
    union = b if union is None else union | b
for name, (ox, oy, rg) in FRAMES.items():
    clip = pymupdf.Rect(ox + union.x0 - 4, oy + union.y0 - 4, ox + union.x1 + 4, oy + union.y1 + 4)
    im = S.render(list(rg), clip, Z)
    save(name, im, (sx + union.x0 - 4, sy + union.y0 - 4))

# ---- the reels, the lever and the lamps of the finished machine ----------------------------------------------------------------
print("reel, lever, lamps")
reel_idx = REEL_OPS[1:]
third = rbox.width / 3.0
thirds = [[i for i in reel_idx if rbox.x0 + k * third <= (S.dr[i]["rect"].x0 + S.dr[i]["rect"].x1) / 2 < rbox.x0 + (k + 1) * third + (0.01 if k == 2 else 0)] for k in range(3)]
img, at = part(thirds[1], grow=4.0)
save("slot_reel", img, at)
reel_left = [S.box(t).x0 for t in thirds]
reel_top = S.box(thirds[1]).y0

img, at = part(LEVER_OPS, grow=14.0, with_sh=True, with_img=True)
save("slot_lever", img, at)

# the lamps: the 8 shadings on the cabinet's strip are the lamps ON the page; the loose ones (left of the page) give the two pictures, scaled to the machine
lamp_sh = sorted({round(x, 1) for ti, x, y in S.shadings if x > 1650 and 700 < y < 800 and abs(y - min(yy for _, xx, yy in S.shadings if xx > 1650 and yy > 700)) < 1.0})
assert len(lamp_sh) == 8, lamp_sh
lamp_y = min(yy for _, xx, yy in S.shadings if xx > 1650 and yy > 700)
spacing = lamp_sh[1] - lamp_sh[0]
lamp_zoom = Z * spacing / 22.83  # (the loose lamps are 22.83 pt apart on the page; the machine's are smaller)
lamp_idx = list(range(6132, 6148))
lbox = S.box(lamp_idx)
clip = pymupdf.Rect(lbox.x0 - 20, lbox.y0 - 30, lbox.x1 + 20, lbox.y1 + 25)
rows = {}
for ti, x, y in S.shadings:
    if clip.x0 <= x <= clip.x1 and clip.y0 <= y <= clip.y1:
        rows.setdefault(round(y / 4.0), []).append((x, y, ti))
ys = sorted(rows)
for name, key in (("slot_lamp_on", ys[0]), ("slot_lamp_off", ys[-1])):
    x, y, _ = sorted(rows[key])[0]
    c = pymupdf.Rect(x - 12, y - 12, x + 12, y + 12)
    sh = [ti for ti, sx, sy in S.shadings if c.x0 <= sx <= c.x1 and c.y0 <= sy <= c.y1]
    img = S.render([], c, lamp_zoom, shadings=sh)
    box_ = img.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    img = img.crop(box_)
    img.save(os.path.join(OUT, name + ".png"))
    layout[name] = (x - 12 + box_[0] / lamp_zoom, y - 12 + box_[1] / lamp_zoom, img.width / lamp_zoom, img.height / lamp_zoom)
    print("  %-22s %d x %d px" % (name, img.width, img.height))
lamp_imgs = lamp_sh

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
# idle: the knob is straight above the hub (the silver ring at the bottom of the picture); pulled: the knob is level with the hub, on its right
lv = layout["slot_lever"]
hub = (lv[0] + lv[2] / 2.0, lv[1] + lv[3] - lv[2] / 2.0)
reel = layout["slot_reel"]
reel_dx = [reel[0] + (k - 1) * third for k in range(3)]  # (the picture of the middle drum, moved by one drum pitch to each side)
reel_y = reel_top

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
    f.write("const LAMP_SIZE := Vector2(%.2f, %.2f)\n" % (layout["slot_lamp_on"][2], layout["slot_lamp_on"][3]))
    f.write("\n## The lever turns about its hub; PULLED_ANGLE is how far it turns (radians, clockwise on the screen) when it is pulled down.\n")
    f.write("const LEVER_HUB := Vector2(%.1f, %.1f)\nconst LEVER_PULLED_ANGLE := %.5f\n" % (hub[0], hub[1], math.pi / 2.0))
    f.write("\n## The port: where Essence come up out of the Bag strip (centre).\n")
    f.write("const PORT_C := Vector2(1578.46, 1012.1)\n")
print("wrote", GD)
