"""Cuts the objects of assets/ui/Fight UI.pdf into game-sized PNGs in assets/ui/new/ (the "New" theme).
Run:  python tools/export_fight_ui.py     (needs pymupdf + pillow)

Nothing is hand-measured: each page is rendered (labels removed), and the pieces of art that touch or nearly touch are
grouped into objects by connected components. Each object takes the name of the label printed under it (see name_for).
The digits and signs have no label: they are named from their position (DIGITS)."""
import io
import os
import re
import sys
import unicodedata

import numpy as np
import pymupdf
from PIL import Image
from scipy import ndimage

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "Fight UI.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "new")
os.makedirs(OUT, exist_ok=True)

# short labels that repeat across pages get a prefix from the page they are on
PAGE_PREFIX = {
    1: {"Thorns": "status_", "Weak": "status_", "Silenced": "status_", "Burn": "status_", "Freeze": "status_", "Poison": "status_",
        "Aegis": "status_", "Echo Ready": "status_", "Overloard": "status_",
        "Orange": "bottle_", "Green": "bottle_", "Purple": "bottle_", "Gray": "bottle_", "Blue": "bottle_"},
    5: {k: "intent_" for k in ["Bubble", "Redirect", "Armor", "Attack", "Burn", "Freeze", "Poison", "Steal", "Summon", "Unknown", "Mend", "Bleed", "Blind", "Confuse", "Empower",
                               "Ethereal", "Frail", "Hex", "Invert", "Lock", "Mimic", "Shuffle", "Silence", "Toll"]},  # page 5 top: the INTENT icons
    7: {"common": "rarity_", "rare": "rarity_", "legendary": "rarity_", "fleeting": "special_", "power": "special_", "fused": "special_",
        "Defense": "kind_", "Utility": "kind_"},  # the card's icon strip (the card looks for rarity_*, special_*, kind_*)
    2: {"Locked": "card_overlay_", "Silenced": "card_overlay_", "Used": "card_overlay_", "Charged": "card_overlay_",
        "Armor": "intent_", "Attact": "intent_", "Attack": "intent_", "Burn": "intent_", "Freeze": "intent_", "Poison": "intent_", "Steal": "intent_",
        "Summon": "intent_", "Unknown": "intent_"},
}
RENAME = {"attact": "attack", "air": "wind", "press": "pressed", "overloard": "overload"}
SKIP = {"BOTTLE", "STATUS", "FIRE BALL", "Remove the rightmost", "Essence of the target.", "X", "INTENT", "Card Overlay", "Leaf set", "Treasure"}  # headings, and the text of the mock card
# page 1 has two "Button Small Pressed" labels: the grey one (right) is the disabled state
DUP = {("button_small_pressed", 1): "button_small_disabled"}
# unlabeled shapes on page 0, read row by row, left to right
DIGITS = ["num_%d" % i for i in range(10)] + ["num_plus", "num_minus", "num_divide", "num_times"]
DIGIT_BAND = (555, 650)  # page-0 y range (points) where the digits sit
ROW2_Y = 599  # ...and below this centre line is the row of signs

# pieces that are 9-sliced / drawn 1:1 are cut to an exact on-screen size (FIT); everything else is fitted into MAXSIDE px
# (the key is a name, or a prefix ending in "_"; the value is the final HEIGHT in px for "h:" or WIDTH for "w:")
FIT = {"panel_wood_frame": "w:140", "panel_paper_frame": "w:190", "status_badge_pill": "h:36",
       "button_chant_": "h:58", "button_play_": "h:58", "button_close_x_": "h:64", "intent_bubble_": "k:1.1", "card_overlay_": "k:4", "scroll_bar_": "w:20", "volume_bar_grabber": "w:28", "hp_head_": "h:26", "button_small_": "h:36", "button_menu_": "h:44", "amber_counter_pill": "h:46", "toast_strip": "h:44"}
MAXSIDE = {"game_title": 900, "hp_bar_frame": 460, "banner_grimoire_ink": 520, "board_pause_menu": 260, "enemy_stand": 300}
DEFAULT_MAX = 128
COMMON = {"button_close_x_": "button_close_x_normal", "button_chant_": "button_chant_normal", "button_small_": "button_small_normal", "button_menu_": "button_menu_normal"}
TIGHT_ART = {"bottle_orange", "bottle_green", "bottle_purple", "bottle_gray", "bottle_blue"}  # drawn nearly touching: group finely
NEAR_PT = 6.0  # pieces of one object (3x3 board, 3-part strips) lie closer than this
MERGE_PX = 16  # pieces closer than this (px at 4x) belong to one object (sparkles stay with their icon)
DIGIT_MERGE_PX = 2  # the digits and signs sit close together: group them tighter
TIGHT_MERGE_PX = 4  # pieces drawn right next to each other (scroll bar head / body / head): split at ~1 pt gaps


def snake(label):
    label = unicodedata.normalize("NFKC", label).replace("'", "")  # "Shuﬄe" ligature, "Scholar's Quill"
    return "_".join(label.replace("  ", " ").lower().split())


def clusters(page, gap=4.0):
    """Drawing-rect groups (only used to find the one big picture on a background page)."""
    out = [pymupdf.Rect(d["rect"]) for d in page.get_drawings() if d["rect"].width or d["rect"].height]
    while True:
        merged, nxt = False, []
        for r in out:
            for o in nxt:
                if (o + (-gap, -gap, gap, gap)).intersects(r):
                    o |= r
                    merged = True
                    break
            else:
                nxt.append(pymupdf.Rect(r))
        out = nxt
        if not merged:
            return out


def components(doc, pg, merge=MERGE_PX):
    """[(rect in points, labelled-pixel mask, RGBA image)] for every object on a page (text must already be removed)."""
    pm = doc[pg].get_pixmap(matrix=pymupdf.Matrix(4, 4), alpha=True)
    im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
    solid = np.asarray(im.getchannel("A")) > 10
    grown = ndimage.binary_dilation(solid, iterations=merge)
    lab, n = ndimage.label(grown)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        mine = (lab[sl] == i) & ndimage.binary_dilation(solid[sl], iterations=2)
        if mine.sum() < 400:
            continue
        ys, xs = sl
        rect = pymupdf.Rect(xs.start / 4.0, ys.start / 4.0, xs.stop / 4.0, ys.stop / 4.0)
        out.append((rect, (mine & solid[sl]), im.crop((xs.start, ys.start, xs.stop, ys.stop))))
    return out


LABEL_GAP = 5.0  # points: two words further apart than this are two labels that merely share a text line ("Poison   Aegis")


def labels(page):
    """Text lines, with the two-line "Floating / Number X" labels joined."""
    ls = []
    words = page.get_text("words")
    for b in page.get_text("dict")["blocks"]:
        for line in b.get("lines", []):
            t = "".join(s["text"] for s in line["spans"]).strip()
            if not t:
                continue
            lr = pymupdf.Rect(line["bbox"])
            mine = sorted([w for w in words if pymupdf.Rect(w[:4]).intersects(lr) and abs((w[1] + w[3]) / 2 - (lr.y0 + lr.y1) / 2) < 3], key=lambda w: w[0])
            groups = [[mine[0]]] if mine else []
            for w in mine[1:]:
                if w[0] - groups[-1][-1][2] > LABEL_GAP:
                    groups.append([w])
                else:
                    groups[-1].append(w)
            if len(groups) > 1 and page.number in (1,):  # only the status / icon rows run labels together
                for g in groups:
                    r = pymupdf.Rect(g[0][:4])
                    for w in g[1:]:
                        r |= pymupdf.Rect(w[:4])
                    ls.append([" ".join(w[4] for w in g), r])
                continue
            ls.append([t, lr])
    merged = []
    for t, r in ls:
        for m in merged:
            top, bot = (m, [t, r]) if m[0] == "Floating" else ([t, r], m)  # "Floating" sits above "Number X"
            if top[0] == "Floating" and bot[0].startswith("Number") and abs((top[1].x0 + top[1].x1) / 2 - (bot[1].x0 + bot[1].x1) / 2) < 25 and -3 <= bot[1].y0 - top[1].y1 < 8:
                m[0] = "float_" + bot[0].split()[-1]
                m[1] |= r
                break
        else:
            merged.append([t, pymupdf.Rect(r)])
    return merged


# page-0 labels that are sentences: matched by their start (and a keyword for the two "Right HP Head" ones)
LABEL_RULES = [("Left HP Head", None, "hp_head_left_hp"), ("Left Shield Head", None, "hp_head_left_shield"),
               ("Left Blank Head", None, "hp_head_left_blank"), ("Right Blank Head", None, "hp_head_right_blank"),
               ("Right HP Head", "không có", "hp_head_right_hp"), ("Right HP Head", "và có", "hp_head_right_shield"),
               ("Demo HP Body", None, "hp_body_demo")]
SKIP_PREFIX = ("HP Bar", "HP", "Shield", "Blank (")  # headings / legend text on the HP-bar block
ART_LEFT = ("Scroll Bar", "Volume Bar", "Button Close X", "Menu Leaf")  # these labels sit to the RIGHT of their art


def art_is_left(label_rect, pg):
    """Treasure art (page 5 below the intents, pages 6 and 7): the label is printed to the RIGHT of its picture."""
    return pg in (6, 7, 8) or (pg == 5 and label_rect.y0 > 450)


def name_for(label, pg):
    if label.startswith("BG ") or label in SKIP or (label.strip() in SKIP_PREFIX or label.startswith("Blank (")) or label.startswith("Perfect Victory Banner") or label.startswith("Victory Banner") or label.startswith("Defeat Banner"):
        return None
    for start, kw, nm in LABEL_RULES:
        if label.startswith(start) and (kw is None or kw in label):
            return nm
    pre = PAGE_PREFIX.get(pg, {}).get(unicodedata.normalize("NFKC", label).strip(), "")
    n = pre + snake(label)
    if pg >= 7:  # the flasks and merchant items keep their names ("Air Flask" is air_flask; RENAME turns air into wind for the Air Emblem)
        return n
    return "_".join(RENAME.get(p, p) for p in n.split("_"))


MULTI = {"board_pause_menu": "near", "banner_grimoire_ink": "near", "toast_strip": "near", "intent_bubble": "row", "game_title": "row"}  # drawn as several separate pieces (gaps between)


def gather_siblings(comps, best, taken, mode):
    """The pieces of one object that sit apart (the pause board's three rows, the intent bubble's five parts) become one
    picture again, gaps included: the pieces are told apart later by those gaps."""
    r0 = comps[best][0]
    chosen = [best]
    if mode == "near":  # grow outwards over every piece within a few points of the group (the 3x3 board, the 3-part strips)
        union = pymupdf.Rect(r0)
        grew = True
        while grew:
            grew = False
            for i, (r, _m, _im) in enumerate(comps):
                if i not in chosen and i not in taken and (union + (-NEAR_PT, -NEAR_PT, NEAR_PT, NEAR_PT)).intersects(r):
                    chosen.append(i)
                    union |= r
                    grew = True
    for i, (r, _m, _im) in enumerate(comps):
        if mode == "near":
            break
        if i == best or i in taken:
            continue
        if mode == "stack" and abs(r.x0 - r0.x0) < 6 and abs(r.x1 - r0.x1) < 6:
            chosen.append(i)
        elif mode == "row" and abs(r.y0 - r0.y0) < 12 and (r.x0 - r0.x1 < 60 and r0.x0 - r.x1 < 60):
            chosen.append(i)
    taken.update(chosen)
    ux0 = min(comps[i][0].x0 for i in chosen)
    uy0 = min(comps[i][0].y0 for i in chosen)
    ux1 = max(comps[i][0].x1 for i in chosen)
    uy1 = max(comps[i][0].y1 for i in chosen)
    canvas = Image.new("RGBA", (round((ux1 - ux0) * 4), round((uy1 - uy0) * 4)))
    for i in chosen:
        r, mask, im = comps[i]
        a = np.asarray(im).copy()
        a[~mask] = 0
        canvas.alpha_composite(Image.fromarray(a, "RGBA"), (round((r.x0 - ux0) * 4), round((r.y0 - uy0) * 4)))
    full = np.asarray(canvas.getchannel("A")) > 10
    return (pymupdf.Rect(ux0, uy0, ux1, uy1), full, canvas)


doc = pymupdf.open(SRC)
bg = {}
for pg in doc:  # labels are real text: read them first, then take them out so they never end up in a cut
    bg[pg.number] = (clusters(pg), labels(pg))
    for w in pg.get_text("words"):
        pg.add_redact_annot(pymupdf.Rect(w[:4]))
    pg.apply_redactions(images=pymupdf.PDF_REDACT_IMAGE_NONE, graphics=pymupdf.PDF_REDACT_LINE_ART_NONE)

pics = {}  # name -> RGBA image (4 px per point) with only that object's pixels
for pg in range(len(doc)):
    cl, ls = bg[pg]
    if pg >= 3:  # backgrounds: one big picture each
        big = max(cl, key=lambda r: r.width * r.height)
        for t, lr in ls:
            if t.startswith("BG "):
                k = 1920 / big.width
                pm = doc[pg].get_pixmap(matrix=pymupdf.Matrix(k, k), clip=big, alpha=False)
                name = snake(t)
                Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGB").resize((1920, 1080), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
                print(name, (1920, 1080))
        if pg == 3:
            continue
    comps = components(doc, pg)
    tight_comps = components(doc, pg, TIGHT_MERGE_PX)
    taken, seen = set(), {}
    taken_tight = set()
    for t, lr in sorted(ls, key=lambda x: (x[1].y0, x[1].x0)):
        nm = name_for(t, pg)
        if nm is None:
            continue
        cx = (lr.x0 + lr.x1) / 2.0
        if art_is_left(lr, pg):  # treasure art: picture to the left of the label, same row (normal grouping keeps its sparkles)
            cy = (lr.y0 + lr.y1) / 2.0
            bl, bdl = None, 1e9
            for i, (r, _m, _im) in enumerate(tight_comps if pg == 5 else comps):
                if i in taken or r.x1 > lr.x0 + 8 or lr.x0 - r.x1 > 70 or not (r.y0 - 6 <= cy <= r.y1 + 6):
                    continue
                d2 = lr.x0 - r.x1
                if d2 < bdl:
                    bl, bdl = i, d2
            if bl is None:
                print("no art for label", repr(t), "page", pg)
                continue
            taken.add(bl)
            pics[nm] = (tight_comps if pg == 5 else comps)[bl]
            continue
        if t.startswith(ART_LEFT):  # art sits left of its label: look among the finely grouped pieces
            cy = (lr.y0 + lr.y1) / 2.0
            bl, bdl = None, 1e9
            for i, (r, _m, _im) in enumerate(tight_comps):
                if i in taken_tight or r.x1 > lr.x0 + 8 or lr.x0 - r.x1 > 90:
                    continue
                d2 = 0.0 if r.y0 <= cy <= r.y1 else min(abs(cy - r.y0), abs(cy - r.y1))
                d2 += (lr.x0 - r.x1) * 0.2
                if d2 < bdl:
                    bl, bdl = i, d2
            if bl is None:
                print("no art for label", repr(t), "page", pg)
                continue
            taken_tight.add(bl)
            pics[nm] = tight_comps[bl]
            continue
        pool, tk = (tight_comps, taken_tight) if nm in TIGHT_ART else (comps, taken)
        best, bd = None, 1e9
        for i, (r, _m, _im) in enumerate(pool):
            inside = r.contains(pymupdf.Point((lr.x0 + lr.x1) / 2, (lr.y0 + lr.y1) / 2))  # label printed on the art itself
            if i in tk or (r.y1 > lr.y0 + 14 and not inside):
                continue
            if not (r.x0 - 25 <= cx <= r.x1 + 25 or r.x0 - 6 <= lr.x0 <= r.x1 + 6):
                continue
            d = (lr.y0 - r.y1) + abs(cx - (r.x0 + r.x1) / 2.0) * 0.05
            if inside:  # a label printed on top of some art only claims it when no art sits above the label
                d = 30.0 + abs(cx - (r.x0 + r.x1) / 2.0) * 0.05
            if d < bd:
                best, bd = i, d
        if best is None:
            print("no art for label", repr(t), "page", pg)
            continue
        if nm in seen:
            nm = DUP.get((nm, pg), nm + "_2")
        seen[nm] = True
        tk.add(best)
        if nm in MULTI:
            pool[best] = gather_siblings(pool, best, tk, MULTI[nm])
        if os.environ.get("EXPORT_DEBUG"):
            print("  %s <- %s" % (nm, [round(v) for v in pool[best][0]]))
        pics[nm] = pool[best]
    if pg == 0:  # the digits and signs: no labels, read them in order
        tight = components(doc, pg, DIGIT_MERGE_PX)
        band = sorted([c for c in tight if DIGIT_BAND[0] < c[0].y0 < DIGIT_BAND[1] and c[0].y1 < DIGIT_BAND[1] + 10 and c[0].width < 130],
                      key=lambda c: (1 if (c[0].y0 + c[0].y1) / 2 > ROW2_Y else 0, c[0].x0))
        for c, nm in zip(band, DIGITS):
            pics[nm] = c
        if len(band) != len(DIGITS):
            print("WARNING: found %d digit shapes, expected %d" % (len(band), len(DIGITS)))


# ---------------------------------------------------------------- the leaf sets (page 3 = act 1, page 4 = act 3): ten leaves each
LEAF_PX = 96  # longest side of one leaf


def export_leaves():
    for pg, pre, ymin, ymax in ((3, "leaf_a1_", 715, 800), (4, "leaf_a3_", 372, 445)):
        row = [c for c in components(doc, pg, 1 if pg == 3 else TIGHT_MERGE_PX) if c[0].width < 80 and c[0].height < 80 and c[0].y0 > ymin - 5 and c[0].y1 < ymax + 40 and c[0].y0 < ymax - 20]
        if pg == 3:
            row = [c for c in row if c[0].y0 > 715]
        row.sort(key=lambda c: c[0].x0)
        if len(row) != 10:
            print("WARNING: leaf set on page %d: expected 10 leaves, found %d" % (pg, len(row)))
        for i, c in enumerate(row):
            im = finish(c)
            k = LEAF_PX / max(im.size)
            im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS).save(os.path.join(OUT, "%s%02d.png" % (pre, i)))
        print("leaves", pre, len(row))


def finish(comp):
    _rect, mask, im = comp
    a = np.asarray(im).copy()
    a[~mask] = 0  # drop pixels of neighbouring objects (and any tint of the page behind)
    out = Image.fromarray(a, "RGBA")
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox())


def target_size(name, wpt, hpt):
    for key, f in FIT.items():
        if name == key or (key.endswith("_") and name.startswith(key)):
            if f[0] == "k":  # a fixed scale: pixels per PDF point
                return round(wpt * float(f[2:])), round(hpt * float(f[2:]))
            k = float(f[2:]) / (hpt if f[0] == "h" else wpt)
            return round(wpt * k), round(hpt * k)
    k = MAXSIDE.get(name, DEFAULT_MAX) / max(wpt, hpt)
    return round(wpt * k), round(hpt * k)


cuts = {n: finish(c) for n, c in pics.items()}
export_leaves()


def split_runs(im, axis, min_gap=6):
    """Cut an image into the pieces separated by fully transparent bands (axis 0 = pieces side by side, 1 = stacked).
    Every piece keeps the full extent of the other axis, so pieces of one object stay aligned."""
    a = np.asarray(im.getchannel("A")) > 10
    prof = a.any(axis=0 if axis == 0 else 1)
    runs, start, gap = [], None, 0
    for i, v in enumerate(list(prof) + [False] * (min_gap + 1)):
        if v:
            if start is None:
                start = i
            last, gap = i, 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                runs.append((start, last + 1))
                start, gap = None, 0
    pieces = []
    for x0, x1 in runs:
        pieces.append(im.crop((x0, 0, x1, im.height)) if axis == 0 else im.crop((0, x0, im.width, x1)))
    return pieces


def defringe(im, *sides, n=3):
    """The cut edge of a piece is anti-aliased (partly transparent). Pieces that must meet seamlessly (the parts of the
    pause board, the HP bar caps, the scroll track...) get that edge replaced by a copy of the solid pixels just inside it
    - those run parallel to the edge, which is exactly what makes a piece stretchable - so no hairline shows at the join."""
    a = np.asarray(im).copy()
    for side in sides:
        for i in range(n):
            if side == "l":
                a[:, i] = a[:, n]
            elif side == "r":
                a[:, -1 - i] = a[:, -1 - n]
            elif side == "t":
                a[i, :] = a[n, :]
            elif side == "b":
                a[-1 - i, :] = a[-1 - n, :]
    return Image.fromarray(a, "RGBA")


def join_pieces(pieces, axis):
    """Put the pieces back to back with no gap between them (the artist left white gaps so they could be told apart)."""
    first, mid, last = pieces
    if axis == 0:
        first, mid, last = defringe(first, "r"), defringe(mid, "l", "r"), defringe(last, "l")
        out = Image.new("RGBA", (first.width + mid.width + last.width, max(p.height for p in pieces)))
        out.paste(first, (0, 0))
        out.paste(mid, (first.width, 0))
        out.paste(last, (first.width + mid.width, 0))
    else:
        first, mid, last = defringe(first, "b"), defringe(mid, "t", "b"), defringe(last, "t")
        out = Image.new("RGBA", (max(p.width for p in pieces), first.height + mid.height + last.height))
        out.paste(first, (0, 0))
        out.paste(mid, (0, first.height))
        out.paste(last, (0, first.height + mid.height))
    return out


# the wood panel is drawn as three columns (left | middle | right) and the pause board as three rows (top | middle |
# bottom), with a gap between them: join them back into one picture that the game 9-slices
SLICES = {}  # name -> (widths of the columns, heights of the rows) in source px: the 9-slice / 3-slice margins


def runs_of(im, axis, min_gap=6):
    a = np.asarray(im.getchannel("A")) > 10
    prof = a.any(axis=0 if axis == 0 else 1)
    out, start, gap, last = [], None, 0, 0
    for i, v in enumerate(list(prof) + [False] * (min_gap + 1)):
        if v:
            if start is None:
                start = i
            last, gap = i, 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                out.append((start, last + 1))
                start, gap = None, 0
    return out


def join_grid(im):
    """The 3x3 pause board: nine pieces with white gaps between them, put back to back (edges defringed) into one picture."""
    cols, rows = runs_of(im, 0), runs_of(im, 1)
    if len(cols) != 3 or len(rows) != 3:
        print("WARNING: grid: expected 3x3 pieces, found %dx%d" % (len(cols), len(rows)))
        return None, None
    cw = [x1 - x0 for x0, x1 in cols]
    rh = [y1 - y0 for y0, y1 in rows]
    out = Image.new("RGBA", (sum(cw), sum(rh)))
    y = 0
    for r, (y0, y1) in enumerate(rows):
        x = 0
        for c, (x0, x1) in enumerate(cols):
            sides = (["l"] if c > 0 else []) + (["r"] if c < 2 else []) + (["t"] if r > 0 else []) + (["b"] if r < 2 else [])
            out.paste(defringe(im.crop((x0, y0, x1, y1)), *sides), (x, y))
            x += cw[c]
        y += rh[r]
    return out, (cw, rh)


for nm in ("panel_wood_frame", "banner_grimoire_ink", "toast_strip"):  # three columns (left | middle | right)
    if nm in cuts:
        parts = split_runs(cuts[nm], 0)
        if len(parts) == 3:
            SLICES[nm] = ([p.width for p in parts], [parts[0].height])
            cuts[nm] = join_pieces(parts, 0)
        else:
            print("WARNING: %s: expected 3 parts, found %d" % (nm, len(parts)))
if "board_pause_menu" in cuts:  # 3x3
    joined, info = join_grid(cuts["board_pause_menu"])
    if joined is not None:
        cuts["board_pause_menu"], SLICES["board_pause_menu"] = joined, info
# the intent bubble: two end caps and an arrow in the middle (fixed), two stretchy pieces between them
if "intent_bubble" in cuts:
    parts = split_runs(cuts.pop("intent_bubble"), 0, 4)
    names = ["intent_bubble_cap_l", "intent_bubble_stretch_l", "intent_bubble_tail", "intent_bubble_stretch_r", "intent_bubble_cap_r"]
    if len(parts) == 5:
        edges = [("r",), ("l", "r"), ("l", "r"), ("l", "r"), ("l",)]
        cuts.update({n: defringe(p, *e) for n, p, e in zip(names, parts, edges)})
    else:
        print("WARNING: intent bubble: expected 5 parts, found %d" % len(parts))


def slice_demo(im):
    """The demo HP bar body is [HP | Shield | Blank] side by side: give each colour its own stretchable slice."""
    a = np.asarray(im).astype(int)
    mid = a[a.shape[0] // 2]

    def kind(px):
        r, g, b, al = px
        if al < 128:
            return None
        if r > g + 50 and r > b + 50:
            return "hp"
        if b > r + 40:
            return "shield"
        if abs(r - g) < 25 and abs(g - b) < 25 and r > 140:
            return "blank"
        return None

    runs, cur, start = {}, None, 0
    for x in range(len(mid) + 1):
        k = kind(mid[x]) if x < len(mid) else None
        if k != cur:
            if cur is not None and (cur not in runs or x - start > runs[cur][1] - runs[cur][0]):
                runs[cur] = (start, x)
            cur, start = k, x
    out = {}
    for k, (x0, x1) in runs.items():
        q = (x1 - x0) // 4
        out["hp_body_" + k] = im.crop((x0 + q, 0, x1 - q, im.height))
    return out


for nm in list(cuts):  # pieces that butt against others in the game
    if nm.startswith("hp_head_left_"):
        cuts[nm] = defringe(cuts[nm], "r")
    elif nm.startswith("hp_head_right_"):
        cuts[nm] = defringe(cuts[nm], "l")
    elif nm == "scroll_bar_top_head":
        cuts[nm] = defringe(cuts[nm], "b")
    elif nm == "scroll_bar_body":
        cuts[nm] = defringe(cuts[nm], "t", "b")
    elif nm == "scroll_bar_bottom_head":
        cuts[nm] = defringe(cuts[nm], "t")
if "hp_body_demo" in cuts:
    cuts.update(slice_demo(cuts.pop("hp_body_demo")))
    FIT["hp_body_"] = "h:26"  # same scale as the heads


def white_digits(im):
    """The digits are orange: a white copy (same outline) so the game can tint it any colour."""
    a = np.asarray(im).copy()
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    fill = (r > 150) & (r - b > 70) & (a[..., 3] > 0)
    a[fill, 0], a[fill, 1], a[fill, 2] = 255, 250, 238
    return Image.fromarray(a, "RGBA")


for name in [n for n in cuts if n.startswith("num_")]:
    cuts["numw_" + name[4:]] = white_digits(cuts[name])

for name, im in cuts.items():
    ref = name
    for key, base in COMMON.items():
        if name.startswith(key) and base in cuts:
            ref = base
    refn = ref[:-0] if False else ref
    size = target_size("num_" + ref[5:] if ref.startswith("numw_") else ref, cuts[ref].width / 4.0, cuts[ref].height / 4.0)
    im.resize(size, Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print(name, size)
    if name in SLICES:
        kx, ky = size[0] / im.width, size[1] / im.height
        cw, rh = SLICES[name]
        print("   slice margins (px in the saved png): left %d right %d top %d bottom %d" % (round(cw[0] * kx), round(cw[-1] * kx), round(rh[0] * ky), round(rh[-1] * ky)))


# ---------------------------------------------------------------- the Victory / Defeat banners (page 4)
# These are flat vector art: the lettering is simply painted AFTER its ribbon. So the page's content stream is replayed
# with all painting operators except the wanted ones turned into no-ops, which renders each layer on its own.
BANNER_OPS = 27  # paint operators that make up one empty ribbon (checked below)
BANNER_PX_PER_PT = 900 / 270.0


def split_banners():
    d = pymupdf.open(SRC)
    pg = d[4]
    if len(pg.get_contents()) != 1:
        raise RuntimeError("page 4 has more than one content stream")
    xref = pg.get_contents()[0]
    lines = d.xref_stream(xref).decode("latin1").split("\n")
    paint = ("f", "f*", "S", "s", "B", "B*", "b", "b*")
    shade = re.compile(r"/\w+ sh")  # gradient fills ("BX /Sh0 sh EX Q") and form XObjects ("/Fm0 Do") also paint
    xobj = re.compile(r"/\w+ Do")
    ends = [i for i, ln in enumerate(lines) if ln.strip() in paint or shade.search(ln) or xobj.search(ln)]
    is_sh = [bool(shade.search(lines[e])) for e in ends]
    labs = {t: r for t, r in labels(pg)}
    bg_bottom = max(r.y1 for t, r in labs.items() if t.startswith("BG "))
    left = min(r.x0 for t, r in labs.items() if t.endswith("Banner"))
    top = max([r.y1 for t, r in labs.items() if t.startswith("Leaf set")] + [bg_bottom]) + 12  # the leaf set sits between the background and the banners
    area = pymupdf.Rect(0, top, left - 4, 792)

    def render(keep, zoom, clip):
        ln = list(lines)
        for e in ends:
            if e in keep:
                continue
            ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", shade.sub("", ln[e]))
        d.update_stream(xref, "\n".join(ln).encode("latin1"))
        pm = d.load_page(4).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
        return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")

    # where does each operator paint, on its own?
    boxes = {}
    for k in range(len(ends)):
        a = np.asarray(render({ends[k]}, 0.5, area).getchannel("A")) > 0
        ys, xs = np.nonzero(a)
        if len(xs):
            boxes[k] = pymupdf.Rect(xs.min() / 0.5 + area.x0, ys.min() / 0.5 + area.y0, (xs.max() + 1) / 0.5 + area.x0, (ys.max() + 1) / 0.5 + area.y0)
    starts = sorted(k for k, r in boxes.items() if r.width >= 250 and not is_sh[k])  # the three whole-ribbon outlines, in painting order
    if len(starts) != 3:
        print("WARNING: expected 3 ribbons, found", len(starts))
        return {}
    # every letter is: an outline fill, then a gradient (sh), then some highlight forms: a "letter" starts at the fill before a gradient
    letter_starts = [k - 1 for k in range(1, len(ends)) if is_sh[k] and not is_sh[k - 1]]

    def first_letter_after(k0):
        return min(k for k in letter_starts if k > k0)

    order = ["defeat", "victory", "perfect"]  # painting order
    seg, layers = {}, {}
    bounds = starts[1:] + [len(ends)]
    for i, name in enumerate(order):
        lstart = first_letter_after(starts[i])
        seg[name] = {"banner": list(range(starts[i], lstart)), "text": list(range(lstart, bounds[i]))}
    # the word PERFECT is painted right after the VICTORY lettering, but sits above the victory ribbon
    vtop = boxes[starts[1]].y0
    word, rest = [], []
    cur, cur_ks = None, []
    groups = []
    for k in seg["victory"]["text"]:
        if k in letter_starts:
            groups.append(cur_ks)
            cur_ks = []
        cur_ks.append(k)
    groups.append(cur_ks)
    for g in groups:
        if not g:
            continue
        ys = [boxes[k] for k in g if k in boxes]
        cy = (min(r.y0 for r in ys) + max(r.y1 for r in ys)) / 2 if ys else 1e9
        (word if cy < vtop else rest).extend(g)
    seg["victory"]["text"] = rest
    seg["perfect"]["word"] = word
    for name in order:
        parts = seg[name]
        allk = [k for ks in parts.values() for k in ks if k in boxes]
        union = pymupdf.Rect(boxes[allk[0]])
        for k in allk:
            union |= boxes[k]
        union = union + (-3, -3, 3, 3)
        for part, ks in parts.items():
            layers["%s_%s" % (name, part)] = (render({ends[k] for k in ks}, 4, union), union)
    return layers


try:
    layers = split_banners()
except Exception as ex:  # keep the rest of the export usable if the banner page changes shape
    print("WARNING: banners not exported:", ex)
    layers = {}

def clean_layer(im, keep_largest):
    """Drop the stray bits a layer picks up (letter tops cut off by the crop; hidden ghosts): everything touching the
    bottom edge, and for a lettering layer everything but its biggest piece (the word as a whole)."""
    a = np.asarray(im).copy()
    mask = a[..., 3] > 10
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=6))
    areas = {i: int((mask & (lab == i)).sum()) for i in range(1, n + 1)}
    keep = set(areas)
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl[0].stop >= a.shape[0] - 2:
            keep.discard(i)
    if keep_largest and keep:
        keep = {max(keep, key=lambda i: areas[i])}
    a[~np.isin(lab, list(keep))] = 0
    return Image.fromarray(a, "RGBA")


groups = {}
for lname, (im, union) in layers.items():
    groups.setdefault(lname.split("_")[0], []).append((lname, clean_layer(im, not lname.endswith("_banner")), union))
for gname, items in groups.items():
    boxes_px = [im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox() for _n, im, _u in items]
    x0 = min(b[0] for b in boxes_px); y0 = min(b[1] for b in boxes_px); x1 = max(b[2] for b in boxes_px); y1 = max(b[3] for b in boxes_px)
    for lname, im, union in items:  # one shared crop per banner, so its layers line up when laid on top of each other
        im = im.crop((x0, y0, x1, y1))
        size = (round(im.width / 4.0 * BANNER_PX_PER_PT), round(im.height / 4.0 * BANNER_PX_PER_PT))
        im.resize(size, Image.LANCZOS).save(os.path.join(OUT, lname + ".png"))
        print(lname, size)


# ---------------------------------------------------------------- scroll bar track / volume slider track
# The scroll bar art is three pieces (top head, body, bottom head). Stacked they are the vertical track (9-slice it with
# the heads' height); turned on its side the same pieces are the volume slider's track (heads = left / right caps).
def compose_tracks():
    names = ["scroll_bar_top_head", "scroll_bar_body", "scroll_bar_bottom_head"]
    if not all(os.path.exists(os.path.join(OUT, n + ".png")) for n in names):
        return
    top, body, bottom = [Image.open(os.path.join(OUT, n + ".png")).convert("RGBA") for n in names]
    track = Image.new("RGBA", (body.width, top.height + body.height + bottom.height))
    track.paste(top, (0, 0))
    track.paste(body, (0, top.height))
    track.paste(bottom, (0, top.height + body.height))
    track.save(os.path.join(OUT, "scroll_track.png"))
    track.rotate(90, expand=True).save(os.path.join(OUT, "slider_track.png"))  # counter-clockwise: the top head ends up on the left
    print("scroll_track", track.size, "slider_track", track.size[::-1])


compose_tracks()
