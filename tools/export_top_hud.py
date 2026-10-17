"""Puppet Stage theme: the TOP HUD of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 1080 = the screen, 1 pt = 1 design px).
One wide frame holds Act / Floor / Turn, HP, Shield, the HP block tray, the bottles' frame and the artifacts' frame; the Menu button stands at the top right.
Cut here (every piece is a 3-slice made of the three template pieces drawn under the frame, put side by side with no gap):
  UI/Panels/hud_frame.png            the big frame   (margins: left cap, right cap)
  UI/Panels/bottle_board.png         the 9-slice frame of the bottles / of the artifacts (and the boards of the encounter screen)
  UI/Panels/artifact_hover_board.png the 9-slice board behind an artifact's hover panel (3 x 3 pieces side by side, no gaps)
Written: scripts/ui/puppet_top_hud.gd (PuppetTopHud): where everything stands.
The pieces are found by their place on the page (the paint operator groups of page.get_drawings(), see tools/slot_pdf.py).
Run: python tools/export_top_hud.py   (needs pymupdf, pillow)"""
import os
import sys

import pymupdf
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP
from slot_pdf import Slot

SRC = os.path.join(AP.PUPPET, "_Source", "Chant UI for puppet.pdf")
GD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "ui", "puppet_top_hud.gd")
Z = 1.0
S = Slot(SRC)
dr = S.dr


def find(x0, y0, x1, y1, tol=1.5):
    """The operator indexes of the contiguous group whose box is this one (the page is made of such groups)."""
    out = []
    for i, d in enumerate(dr):
        r = d["rect"]
        if r.x0 >= x0 - tol and r.y0 >= y0 - tol and r.x1 <= x1 + tol and r.y1 <= y1 + tol:
            out.append(i)
    return out


def piece(rect, inset=(0, 0, 0, 0)):
    """(image) of the operators inside `rect` (pt), rendered alone at 1 px per pt. The rect's edges are rounded OUT to whole px, and `inset` (left, top, right, bottom)
    takes that many px off the edges that join another piece: the half-covered pixel there would show as a faint line."""
    ids = find(*rect)
    assert ids, rect
    import math
    clip = pymupdf.Rect(math.floor(rect[0]), math.floor(rect[1]), math.ceil(rect[2]), math.ceil(rect[3]))
    im = S.render(ids, clip, Z)
    l, t, r, b = inset
    return im.crop((l, t, im.width - r, im.height - b))


def row(rects):
    """The pieces side by side, no gap: one 3-slice texture."""
    ims = []
    n = len(rects)
    for k, r in enumerate(rects):
        ims.append(piece(r, (1 if k > 0 else 0, 0, 1 if k < n - 1 else 0, 0)))
    h = max(i.height for i in ims)
    out = Image.new("RGBA", (sum(i.width for i in ims), h), (0, 0, 0, 0))
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0))
        x += i.width
    return out, [i.width for i in ims]


def bbox(ids):
    r = pymupdf.Rect(dr[ids[0]]["rect"])
    for i in ids:
        r |= dr[i]["rect"]
    return r


def group(a, b):
    return bbox(list(range(a, b + 1)))


# the template pieces (left cap, middle, right cap) of the big frame and of the small frame, and the 9 pieces of the hover board
BIG = [group(582, 587), group(594, 601), group(588, 593)]
HOV = {"tl": group(602, 608), "bl": group(609, 615), "tr": group(616, 622), "br": group(623, 629), "bm": group(630, 635), "tm": group(636, 641),
       "mr": group(642, 646), "ml": group(647, 651), "c": group(652, 652)}
# the bottle board: 3 x 3 pieces (the frame of the bottles' and artifacts' slots; also of the boards of the encounter screen)
BOT = {"tl": group(653, 654), "bl": group(655, 656), "tr": group(657, 658), "br": group(659, 659), "bm": group(660, 660), "tm": group(661, 662),
       "ml": group(663, 664), "c": group(665, 665), "mr": group(666, 666)}
print("big pieces", [[round(v, 1) for v in r] for r in BIG])


def rows3(r3):
    out = []
    for r in r3:  # (the pieces' own boxes: a piece may carry a faint outline that the neighbour's box shares)
        out.append((r.x0, r.y0, r.x1, r.y1))
    return out


big_img, big_w = row(rows3(BIG))
big_img.save(os.path.join(AP.PUPPET, "UI", "Panels", "hud_frame.png"))

def board(P, name):
    """The 9 pieces (tl tm tr / ml c mr / bl bm br) put together into one 9-slice texture; returns its margins (left, top, right, bottom)."""
    cols = [["tl", "ml", "bl"], ["tm", "c", "bm"], ["tr", "mr", "br"]]
    col_imgs = []
    for ci, c in enumerate(cols):
        ims = []
        for r_i, k in enumerate(c):
            ims.append(piece((P[k].x0, P[k].y0, P[k].x1, P[k].y1), (1 if ci > 0 else 0, 1 if r_i > 0 else 0, 1 if ci < 2 else 0, 1 if r_i < 2 else 0)))
        w = max(i.width for i in ims)
        col = Image.new("RGBA", (w, sum(i.height for i in ims)), (0, 0, 0, 0))
        y = 0
        for i in ims:
            col.alpha_composite(i, (0, y))
            y += i.height
        col_imgs.append(col)
    out = Image.new("RGBA", (sum(c.width for c in col_imgs), max(c.height for c in col_imgs)), (0, 0, 0, 0))
    x = 0
    for c in col_imgs:
        out.alpha_composite(c, (x, 0))
        x += c.width
    out.save(os.path.join(AP.PUPPET, "UI", "Panels", name + ".png"))
    m = (P["tl"].width, P["tl"].height, P["br"].width, P["br"].height)
    print(name, out.size, "margins l/t/r/b", [round(v) for v in m])
    return m


hov_m = board(HOV, "artifact_hover_board")
bot_m = board(BOT, "bottle_board")

# the red board left of the Chant frame (the debuffs): one picture, drawn as a 9-slice that stretches to fit its icons
dbox = group(184, 353)
dim = piece((dbox.x0, dbox.y0, dbox.x1, dbox.y1))
dim.save(os.path.join(AP.PUPPET, "UI", "Panels", "debuff_board.png"))
print("debuff_board", dim.size, [round(v, 1) for v in dbox])

# ---- where things stand (the page's own full frame and its contents)
full = group(529, 581)  # the top frame, assembled
menu = group(524, 528)  # the Menu plate, bottom left of the Chant frame
tray = (903.8, 41.1, 1178.0 - 903.8, 99.2 - 41.1)  # the HP block tray picture's box
slot_h = BOT["tl"].height + (BOT["ml"].height) + BOT["bl"].height  # (the board as the page has it)
slot_y = (full.y0 + full.y1) / 2.0 - slot_h / 2.0  # (the slot frames are centred on the big frame)
print("top frame", [round(v, 1) for v in full], "menu", [round(v, 1) for v in menu], "slot y/h", round(slot_y, 1), round(slot_h, 1))

out = ["class_name PuppetTopHud", "extends RefCounted",
       "## GENERATED by tools/export_top_hud.py from Chant UI for puppet.pdf: do not edit by hand.",
       "## The top HUD (one wide frame with Act / Floor / Turn, HP, Shield, the HP block tray, the bottles and the artifacts) and the Menu button, in px of the 1920 x 1080 screen.",
       "",
       "const FRAME_AT := Vector2(%.1f, %.1f)  # the frame's top-left" % (full.x0, full.y0),
       "const FRAME_H := %.1f" % full.height,
       "const FRAME_W := %.1f  # its width on the page (with a bottle frame and an artifact frame of the page's own width)" % full.width,
       "const FRAME_MARGINS := Vector2(%.1f, %.1f)  # 3-slice: the left cap and the right cap of hud_frame.png" % (big_w[0], big_w[2]),
       "const ACT_AT := Vector2(544.0, 52.0)  # the Act / Floor / Turn text (top-left of the label)",
       "const ACT_PX := 18",
       "const HEART_AT := Vector2(780.0, 43.0)  # (28 px picture)",
       "const HP_TEXT_AT := Vector2(814.0, 44.0)",
       "const HP_PX := 18",
       "const SHIELD_AT := Vector2(781.0, 72.0)  # (28 px picture)",
       "const SHIELD_TEXT_AT := Vector2(814.0, 77.0)",
       "const SHIELD_PX := 15",
       "const TRAY := Rect2(%.1f, %.1f, %.1f, %.1f)  # the HP block tray" % tray,
       "const SLOT_Y := %.1f  # the bottles' and the artifacts' frames: top" % slot_y,
       "const SLOT_H := %.1f" % slot_h,
       "const BOARD_MARGINS := [%.1f, %.1f, %.1f, %.1f]  # bottle_board.png (9-slice): left, top, right, bottom" % bot_m,
       "const BOTTLES_X := 1193.0  # left edge of the bottles' frame",
       "const SLOT_GAP := 15.0  # between the bottles' frame and the artifacts' frame",
       "const SLOT_MIN_W := 89.0  # a frame is never narrower than this (the page's own)",
       "const FRAME_PAD_RIGHT := %.1f  # from the last frame's right edge to the big frame's" % (full.x1 - 1386.0),
       "const MENU := Rect2(%.1f, %.1f, %.1f, %.1f)  # bottom left of the Chant frame" % (menu.x0, menu.y0, menu.width, menu.height),
       "const DEBUFF_RIGHT := %.1f  # the debuff board: its right edge and bottom edge stay put, it grows left and up" % dbox.x1,
       "const DEBUFF_BOTTOM := %.1f" % dbox.y1,
       "const DEBUFF_MIN := Vector2(%.1f, %.1f)  # its size on the page (never smaller)" % (dbox.width, dbox.height),
       "const DEBUFF_MARGIN := 24  # 9-slice margin of debuff_board.png",
       "const HOVER_MARGINS := [%.1f, %.1f, %.1f, %.1f]  # artifact_hover_board.png: left, top, right, bottom" % hov_m,
       ]
with open(GD, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
print("wrote", GD)
