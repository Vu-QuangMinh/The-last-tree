"""The Handyman, as a rig: page 2 of assets/Puppet/Enemies/Act1/handyman/Handyman.pdf -> his body and six two-bone arms.
The page holds six arms laid out apart (each a run of paint operators ending in its two black pivot dots, named by the label beside them:
"Tâm xoay Spear1" = the shoulder, "Spear2" = the elbow), the body, and two black "Điểm gắn Vai trái/phải" dots on the body (the shoulder
sockets). The dots and the labels are NOT art and are never exported.
Each arm is cut at its elbow into an upper arm (the shoulder side) and a lower arm (elbow, hand, tool). Written (px of the art, R px per PDF point):
  assets/Puppet/Enemies/Act1/handyman.png            the body (square canvas, feet on the bottom edge, like every puppet)
  assets/Puppet/Enemies/Act1/handyman/arm_<name>_upper.png / _lower.png
  scripts/ui/handyman_rig.gd                          (HandymanRig) where every pivot, piece and socket is
The page is replayed operator by operator (page.get_drawings() index == paint operator index), so overlapping arms stay clean.
Run: python tools/export_handyman_rig.py   (then Godot --headless --editor --quit once so it imports the new files)"""
import io
import math
import os
import re
import sys

import numpy as np
import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "Enemies", "Act1", "handyman", "Handyman.pdf")
OUT_DIR = os.path.join(AP.PUPPET, "Enemies", "Act1")
ARM_DIR = os.path.join(OUT_DIR, "handyman")
GD = os.path.join(HERE, "..", "scripts", "ui", "handyman_rig.gd")
PAGE = 1
R = 1.2  # px of art per PDF point
SCALE = 0.66  # game px per px of the art (a PDF point is then 0.8 px on the stage)
OVERLAP = 0.0  # pt: how far each piece reaches over the elbow line into the other
DOT = (0.14, 0.12, 0.13)  # the fill of the black marker dots

# arm name -> (enemy id, side (-1 left shoulder, +1 right), layer: 0 lowest ... the body is above them all)
# (the side is checked against page 2 below: a left arm's upper stick points left from its shoulder; 2026-10-20 the user swapped them round:
# left = Spear, Crossbow, Sword; right = Shield, Hammer, Tweezer. The layer is the draw order on its side: the outermost arm at the back)
ARMS = {
    "Spear": ("hand_spear", -1, 0), "Crossbow": ("hand_crossbow", -1, 1), "Sword": ("hand_sword", -1, 2),
    "Shield": ("hand_shield", 1, 0), "Hammer": ("hand_hammer", 1, 1), "Tweezer": ("hand_tweezer", 1, 2),
}

doc = pymupdf.open(SRC)
pg = doc[PAGE]
xref = pg.get_contents()[0]
lines = doc.xref_stream(xref).decode("latin1").split("\n")
intext = False
for i, ln in enumerate(lines):  # the labels (BT ... ET) are not art
    t = ln.strip()
    if t == "BT":
        intext = True
    if intext:
        lines[i] = ""
    if t == "ET":
        intext = False
paint = ("f", "f*", "S", "s", "B", "B*", "b", "b*")
xobj = re.compile(r"/\w+ Do")
ends = [i for i, ln in enumerate(lines) if ln.strip() in paint or xobj.search(ln)]
orig = list(lines)
dr = pg.get_drawings()
assert len(ends) == len(dr), (len(ends), len(dr))


def render(keep, clip, zoom=R):
    ln = list(orig)
    ks = {ends[k] for k in keep}
    for e in ends:
        if e not in ks:
            ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", ln[e])
    doc.update_stream(xref, "\n".join(ln).encode("latin1"))
    pm = doc.load_page(PAGE).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
    return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")


def centre(i):
    r = dr[i]["rect"]
    return pymupdf.Point((r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2)


def bbox(ids):
    r = pymupdf.Rect(dr[ids[0]]["rect"])
    for i in ids:
        r |= dr[i]["rect"]
    return r


def cut(ids, pad=2.0):
    """Render these operators alone, trim them: (Image, (x, y) of its top-left in pt)."""
    r = bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = render(set(ids), clip)
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop(box)
    return im, (clip.x0 + box[0] / R, clip.y0 + box[1] / R)


# ---- the marker dots and which label each one belongs to ------------------------------------------------------------------
dots = [i for i, d in enumerate(dr) if d.get("fill") and all(abs(a - b) < 0.012 for a, b in zip(d["fill"], DOT))
        and abs(d["rect"].width - 8.9) < 0.3 and abs(d["rect"].height - 8.9) < 0.3 and len(d["items"]) == 4]
labels = []  # (name, number, rect)
for w in pg.get_text("words"):
    m = re.fullmatch(r"([A-Z][a-z]+)([12])", w[4])
    if m and m.group(1) in ARMS:
        labels.append((m.group(1), int(m.group(2)), pymupdf.Rect(w[:4])))
sockets = {}  # "L" / "R"
pivots = {}  # (name, n) -> dot operator


def gap(lb, c):  # distance from a label's box to a dot's centre
    return math.hypot(max(lb[2].x0 - c.x, 0, c.x - lb[2].x1), max(lb[2].y0 - c.y, 0, c.y - lb[2].y1))


pairs = sorted(((gap(lb, centre(d)), d, lb) for d in dots for lb in labels), key=lambda t: t[0])
taken = set()
for dist, d, lb in pairs:  # closest first, one label per dot and one dot per label
    if d in pivots.values() or (lb[0], lb[1]) in taken or len(pivots) >= len(labels):
        continue
    pivots[(lb[0], lb[1])] = d
    taken.add((lb[0], lb[1]))
sock_words = [(w[4], pymupdf.Rect(w[:4])) for w in pg.get_text("words") if w[4] in ("trái", "phải")]
for d in dots:  # the two dots with no pivot label: they sit next to "Điểm gắn Vai trái / phải" on the body
    if d in pivots.values():
        continue
    c = centre(d)
    best = min(sock_words, key=lambda sw: math.hypot(sw[1].x0 - c.x, sw[1].y0 - c.y))
    if math.hypot(best[1].x0 - c.x, best[1].y0 - c.y) < 130:
        sockets["L" if best[0] == "trái" else "R"] = d
assert len(pivots) == 12 and len(sockets) == 2, (len(pivots), sockets)
print("pivots:", {k: (round(centre(v).x, 1), round(centre(v).y, 1)) for k, v in sorted(pivots.items())})

# ---- which operators are which arm -------------------------------------------------------------------------------------------
# The paint operators come in contiguous clumps (a stick, a hand with its tool, the body), but the ORDER of the arms in the file is whatever the artist
# last left it as (the two black pivot dots of an arm do not have to follow its paint). So the stream is cut into clumps that touch each other in the
# page, and every clump goes to the arm whose pivots are nearest to it (or to the body, which holds the two shoulder sockets). The clean pieces of page 3
# and the green hand marker are checked against this further down, so a wrong guess stops the export.
GREEN = (0.0, 0.6, 0.3)  # the green circles: where each hand is (its name, Essence and target marker go there)
greens = [i for i, d in enumerate(dr) if d.get("fill") and d["fill"][1] > 0.5 and d["fill"][0] < 0.3 and d["fill"][2] < 0.6
          and abs(d["rect"].width - d["rect"].height) < 2 and d["rect"].width > 6 and len(d["items"]) == 4]
assert len(greens) == 6, len(greens)
hand_of = {}  # arm -> its green circle: the nearest one to its elbow, closest pairs first
for dist, n, g in sorted(((math.hypot(centre(g).x - centre(pivots[(n, 2)]).x, centre(g).y - centre(pivots[(n, 2)]).y), n, g) for n in ARMS for g in greens),
                         key=lambda t: t[0]):
    if n not in hand_of and g not in hand_of.values():
        hand_of[n] = g


def rect_gap(a, b):
    return math.hypot(max(a.x0 - b.x1, b.x0 - a.x1, 0), max(a.y0 - b.y1, b.y0 - a.y1, 0))


clumps = []  # [first op, last op, Rect]
for i, d in enumerate(dr):
    r = pymupdf.Rect(d["rect"])
    if clumps:
        c = clumps[-1]
        near = pymupdf.Rect(c[2].x0 - 120, c[2].y0 - 120, c[2].x1 + 120, c[2].y1 + 120)
        if near.intersects(r) or near.contains(r):
            c[1] = i
            c[2] |= r
            continue
    clumps.append([i, i, pymupdf.Rect(r)])
sock_pts = [centre(d) for d in sockets.values()]
body_clump = max((c for c in clumps if all(c[2].contains(p) for p in sock_pts)), key=lambda c: c[1] - c[0])
arm_pts = {n: [centre(pivots[(n, 1)]), centre(pivots[(n, 2)]), centre(hand_of[n])] for n in ARMS}
runs = {n: [] for n in ARMS}
body_run = []
owner_rect = {}  # arm name or "body" -> the box of its big clumps
owner_of = {}  # clump index -> owner
for k, c in enumerate(clumps):  # big clumps first: the body is the one that holds the sockets, the rest go to the arm whose pivots / hand are nearest
    if c[1] - c[0] < 60 and c is not body_clump:
        continue
    if c is body_clump:
        o = "body"
    else:
        o = min(ARMS, key=lambda n: min(rect_gap(c[2], pymupdf.Rect(p.x, p.y, p.x, p.y)) for p in arm_pts[n]))
    owner_of[k] = o
    owner_rect[o] = pymupdf.Rect(c[2]) if o not in owner_rect else owner_rect[o] | c[2]
for k, c in enumerate(clumps):  # a few stray operators: with whoever owns the big clump next to it in the file and is nearest to it in the page
    if k in owner_of:
        continue
    cands = {owner_of[j] for j in (k - 1, k + 1) if j in owner_of}
    if not cands:  # (neighbours are small too: look further along the file)
        for step in range(2, 8):
            cands |= {owner_of[j] for j in (k - step, k + step) if j in owner_of}
            if cands:
                break
    cands.add("body")
    owner_of[k] = min(cands, key=lambda o: rect_gap(c[2], owner_rect[o]))
for k, c in enumerate(clumps):
    (body_run if owner_of[k] == "body" else runs[owner_of[k]]).extend(range(c[0], c[1] + 1))
for n in ARMS:
    print("arm", n, "clumps ops:", len(runs[n]))
marker = set(pivots.values()) | set(sockets.values()) | set(greens)


def is_stray(i):  # (two white flecks the tracer left far from everything)
    d = dr[i]
    return d.get("fill") == (1.0, 1.0, 1.0) and d["rect"].y1 < 100


body_ids = [i for i in body_run if i not in marker and not is_stray(i)]

# ---- the body -------------------------------------------------------------------------------------------------------------
im, (bx, by) = cut(body_ids)
pad = 0.04
side = int(max(im.size) * (1 + pad * 2))
dx = (side - im.width) // 2
dy = side - im.height - int(side * pad * 0.5)
sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
sq.alpha_composite(im, (dx, dy))
os.makedirs(ARM_DIR, exist_ok=True)
sq.save(os.path.join(OUT_DIR, "handyman.png"))
sock = {}
for k, d in sockets.items():
    c = centre(d)
    sock[k] = ((c.x - bx) * R + dx, (c.y - by) * R + dy)
    sock[k] = (sock[k][0] / side, sock[k][1] / side)
print("body", sq.size, "sockets", sock)

# ---- the arms -------------------------------------------------------------------------------------------------------------
# An arm is cut in two (upper: shoulder -> elbow, lower: elbow -> hand and tool) and each piece is turned so that its stick lies along +x.
# In the game the stick can then be made longer: a slab of it (`slab`, px along x) is stretched, the two ends keep their size. That is how a
# hand reaches the place where its name stands (HandymanStage).
Z = 2 * R  # (rendered twice as big, turned, then shrunk: the turn does not blur the art)


def cut_turned(ids, phi, pts, pad=2.0):
    """Render these operators alone, turn the picture `phi` degrees counter-clockwise, trim it and shrink it to R px per point.
    pts: PDF points to follow. Returns (Image, [their px in the result])."""
    r = bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = render(set(ids), clip, Z)
    w, h = im.size
    turned = im.rotate(phi, resample=Image.BICUBIC, expand=True)
    w2, h2 = turned.size
    c, s = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    box = turned.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    out_pts = []
    for p in pts:
        dx_, dy_ = (p.x - clip.x0) * Z - w / 2.0, (p.y - clip.y0) * Z - h / 2.0
        out_pts.append((w2 / 2.0 + dx_ * c + dy_ * s - box[0], h2 / 2.0 - dx_ * s + dy_ * c - box[1]))
    turned = turned.crop(box)
    small = turned.resize((max(1, round(turned.width / 2)), max(1, round(turned.height / 2))), Image.LANCZOS)
    sx, sy = small.width / turned.width, small.height / turned.height
    return small, [(x * sx, y * sy) for x, y in out_pts]


def cut_turned_ctx(ctx, ids, phi, pts, pad=2.0):
    """Like cut_turned, for the drawings of another page."""
    r = ctx.bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = ctx.render(set(ids), clip, Z)
    w, h = im.size
    turned = im.rotate(phi, resample=Image.BICUBIC, expand=True)
    w2, h2 = turned.size
    c, s_ = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    box = turned.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    out_pts = []
    for p in pts:
        dx_, dy_ = (p.x - clip.x0) * Z - w / 2.0, (p.y - clip.y0) * Z - h / 2.0
        out_pts.append((w2 / 2.0 + dx_ * c + dy_ * s_ - box[0], h2 / 2.0 - dx_ * s_ + dy_ * c - box[1]))
    turned = turned.crop(box)
    small = turned.resize((max(1, round(turned.width / 2)), max(1, round(turned.height / 2))), Image.LANCZOS)
    sx, sy = small.width / turned.width, small.height / turned.height
    return small, [(x * sx, y * sy) for x, y in out_pts]


def find_pin(img, end):
    """The pin hole at one end of a level stick: the centre of the darkest pixels within 34 pt of the tip. (x, y) in px of the picture."""
    a = np.array(img.convert("RGBA")).astype(float)
    solid = a[:, :, 3] > 200
    lum = a[:, :, :3].mean(axis=2)
    xs = np.where(solid.any(axis=0))[0]
    x0, x1 = (xs.min(), xs.min() + int(34 * R)) if end == "left" else (xs.max() - int(34 * R), xs.max())
    mask = np.zeros_like(solid)
    mask[:, max(0, x0):x1 + 1] = True
    mask &= solid
    cut = np.percentile(lum[mask], 2.0)
    ys, xs2 = np.where(mask & (lum <= cut))
    return float(xs2.mean()), float(ys.mean())


def find_slab(img, lo, hi):
    """The widest run of columns between x = lo and hi where the stick is as thin as it gets (nothing but the stick is there): (xa, xb)."""
    a = np.array(img.getchannel("A")) > 8
    ext = np.zeros(a.shape[1])
    for x in range(a.shape[1]):
        ys = np.where(a[:, x])[0]
        ext[x] = (ys.max() - ys.min()) if len(ys) else 0
    lo, hi = max(0, int(lo)), min(a.shape[1] - 1, int(hi))
    win = ext[lo:hi + 1]
    thin = win[win > 0].min()
    ok = win <= thin * 1.3 + 3
    best, cur = (0, 0), 0
    for i in range(len(ok) + 1):
        if i < len(ok) and ok[i]:
            cur += 1
        else:
            if cur > best[1] - best[0]:
                best = (i - cur, i)
            cur = 0
    n = best[1] - best[0]
    xa, xb = lo + best[0] + 0.2 * n, lo + best[1] - 0.2 * n
    assert xb - xa >= 10, ("no straight piece of stick", lo, hi, best)
    return xa, xb


# ---- page 3: the same arms cut into clean pieces -------------------------------------------------------------------------------
# Page 3 of the PDF holds, for every arm, part 1 (the upper stick, whole, with its two ends: the ragged one goes behind the body, the pinned one is
# the elbow) and part 2 (the lower stick with the hand and its tool, whole, pinned at the elbow end). Nothing is cut at the elbow any more, so a
# folded arm does not show the broken ends the cut left. The pieces carry no marker dots: the elbow and the hand marker are taken from page 2 (the
# lower piece is the same drawing, only moved: found by correlating the two pictures), the upper stick's ends from its own shape.
from scipy import ndimage as ndi
from scipy.signal import fftconvolve

PAGE3 = 2
INSET = 12.0  # pt: how far the pins are from the tips of a stick


class PageCtx:
    def __init__(self, index):
        self.index = index
        self.pg = doc[index]
        self.words = self.pg.get_text("words")  # (before the stream is rewritten without its text)
        self.xref = self.pg.get_contents()[0]
        ls = doc.xref_stream(self.xref).decode("latin1").split("\n")
        inside = False
        for i, ln in enumerate(ls):
            t = ln.strip()
            if t == "BT":
                inside = True
            if inside:
                ls[i] = ""
            if t == "ET":
                inside = False
        self.ends = [i for i, ln in enumerate(ls) if ln.strip() in paint or xobj.search(ln)]
        self.orig = list(ls)
        self.dr = self.pg.get_drawings()
        assert len(self.ends) == len(self.dr), (len(self.ends), len(self.dr))

    def render(self, keep, clip, zoom):
        ln = list(self.orig)
        ks = {self.ends[k] for k in keep}
        for e in self.ends:
            if e not in ks:
                ln[e] = "n" if ln[e].strip() in paint else xobj.sub("", ln[e])
        doc.update_stream(self.xref, "\n".join(ln).encode("latin1"))
        pm = doc.load_page(self.index).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
        return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")

    def bbox(self, ids):
        r = pymupdf.Rect(self.dr[ids[0]]["rect"])
        for i in ids:
            r |= self.dr[i]["rect"]
        return r

    def centre(self, i):
        r = self.dr[i]["rect"]
        return pymupdf.Point((r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2)


C3 = PageCtx(PAGE3)
# the pieces: connected blobs of the picture
full = C3.render(set(range(len(C3.dr))), pymupdf.Rect(0, 0, 1920, 1080), 0.5)
blob_map, blob_n = ndi.label(ndi.binary_dilation(np.array(full.getchannel("A")) > 8, iterations=3))
blob_ids = {}
for i, d in enumerate(C3.dr):
    if d.get("fill") and min(d["fill"]) > 0.97:  # (white flecks of the tracing)
        continue
    c = C3.centre(i)
    k = blob_map[min(blob_map.shape[0] - 1, int(c.y * 0.5)), min(blob_map.shape[1] - 1, int(c.x * 0.5))]
    if k:
        blob_ids.setdefault(int(k), []).append(i)
blobs = {k: v for k, v in blob_ids.items() if len(v) > 200}
labels3 = []
for w in C3.words:
    m = re.fullmatch(r"T?([A-Z][a-z]+)([12])", w[4])
    if m and m.group(1) in ARMS:
        labels3.append((m.group(1), int(m.group(2)), pymupdf.Rect(w[:4])))
assert len(blobs) == 12 and len(labels3) == 12, (len(blobs), len(labels3))
pieces3 = {}
pairs3 = []
for k, ids in blobs.items():
    r = C3.bbox(ids)
    for lb in labels3:
        pairs3.append((math.hypot(max(lb[2].x0 - r.x1, r.x0 - lb[2].x1, 0), max(lb[2].y0 - r.y1, r.y0 - lb[2].y1, 0)), k, lb))
pairs3.sort(key=lambda t: t[0])
used_blob = set()
for dist, k, lb in pairs3:  # closest first, one label per piece and one piece per label
    if k in used_blob or (lb[0], lb[1]) in pieces3:
        continue
    pieces3[(lb[0], lb[1])] = blobs[k]
    used_blob.add(k)
assert len(pieces3) == 12, len(pieces3)


def mask3(ctx, ids, zoom=1.0, pad=4.0):
    r = ctx.bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = ctx.render(set(ids), clip, zoom)
    return np.array(im.getchannel("A")) > 40, (clip.x0, clip.y0)


def mask2(ids, zoom=1.0, pad=4.0):
    r = bbox(ids)
    clip = pymupdf.Rect(r.x0 - pad, r.y0 - pad, r.x1 + pad, r.y1 + pad)
    im = render(set(ids), clip, zoom)
    return np.array(im.getchannel("A")) > 40, (clip.x0, clip.y0)


def shift_between(ids2, ids3):
    """Where a page-2 drawing went on page 3 (it was only moved): (dx, dy) in pt, and how well the two pictures agree (0..1)."""
    a, oa = mask2(ids2)
    b, ob = mask3(C3, ids3)
    corr = fftconvolve(b.astype(float), a[::-1, ::-1].astype(float), mode="full")
    py, px = np.unravel_index(np.argmax(corr), corr.shape)
    ox, oy = px - (a.shape[1] - 1), py - (a.shape[0] - 1)  # (b's top left, on a's pixel grid)
    score = corr.max() / max(1.0, min(a.sum(), b.sum()))
    return (ob[0] - (oa[0] + ox), ob[1] - (oa[1] + oy)), score


def stick_ends(ids, side):
    """The tips of a straight stick (the centre of each end): (shoulder tip, elbow tip). The shoulder tip is the ragged one, the elbow tip the
    pinned one, which is the outer one: the left tip of a left arm, the right tip of a right arm. Also the direction shoulder -> elbow."""
    pts = []
    for i in ids:
        r = C3.dr[i]["rect"]
        pts += [(r.x0, r.y0), (r.x1, r.y0), (r.x0, r.y1), (r.x1, r.y1)]
    a = np.array(pts)
    c = a.mean(axis=0)
    ax = np.linalg.svd(a - c)[2][0]
    if ax[0] < 0:
        ax = -ax
    t = (a - c) @ ax
    left = c + ax * t.min()  # (on the axis through the middle of the stick)
    right = c + ax * t.max()
    return (right, left) if side < 0 else (left, right)


# ---- page 4: where each arm ends up when it is knocked out ----------------------------------------------------------------------
# Page 4 shows the folded pose: one picture with the body and all six arms, and every arm again on its own. The arms are the same drawings as on page 3,
# turned and moved. Every path is told by its colour, number of segments and area (they do not change when it is turned), the paths of a page-3
# piece are found again in the arm's own picture, and the turn and the move are fitted to them (Kabsch). The pins then say where the elbow and the hand
# are, and so which way each stick points.
PAGE4 = 3
C4 = PageCtx(PAGE4)


def sig_of(d):
    pts = []
    for it in d["items"]:
        if it[0] == "l":
            pts += [it[1], it[2]] if not pts else [it[2]]
        elif it[0] == "c":
            pts += [it[1], it[4]] if not pts else [it[4]]
    if len(pts) < 3 or not d.get("fill"):
        return None, None
    a = 0.0
    for (p, q) in zip(pts, pts[1:] + pts[:1]):
        a += p.x * q.y - q.x * p.y
    cx = sum(p.x for p in pts) / len(pts)
    cy = sum(p.y for p in pts) / len(pts)
    return (tuple(round(v, 2) for v in d["fill"]), len(d["items"]), round(abs(a) / 2.0, 1)), (cx, cy)


sigs2 = {}  # signature -> [centre] of the drawings of page 2
for _i, _d in enumerate(dr):
    _sg, _cen = sig_of(_d)
    if _sg is not None:
        sigs2.setdefault(_sg, []).append(_cen)


def shift_by_paths(ids3):
    """How far a page-3 piece lies from its drawing on page 2 (it was only moved): ((dx, dy) in pt, number of paths that agree). Every path of the
    piece votes with the shift to each page-2 path that looks like it (same colour, segments, area); the shift most of them agree on wins."""
    votes = {}
    for i in ids3:
        sg, cen = sig_of(C3.dr[i])
        for c2 in sigs2.get(sg, []) if sg is not None else []:
            key = (round(cen[0] - c2[0]), round(cen[1] - c2[1]))
            votes[key] = votes.get(key, 0) + 1
    if not votes:
        return (0.0, 0.0), 0
    best = max(votes, key=lambda k: votes[k] + votes.get((k[0] + 1, k[1]), 0) + votes.get((k[0] - 1, k[1]), 0) + votes.get((k[0], k[1] + 1), 0) + votes.get((k[0], k[1] - 1), 0))
    sx = sy = w = 0.0
    for i in ids3:
        sg, cen = sig_of(C3.dr[i])
        for c2 in sigs2.get(sg, []) if sg is not None else []:
            if abs(cen[0] - c2[0] - best[0]) <= 1.5 and abs(cen[1] - c2[1] - best[1]) <= 1.5:
                sx += cen[0] - c2[0]
                sy += cen[1] - c2[1]
                w += 1
    return ((sx / w, sy / w), int(w)) if w else ((0.0, 0.0), 0)


def skin_centre(ids3, tx, ty):
    """The middle of the skin-coloured (orange) paint of a page-3 piece, on page 2's coordinates (it is the hand)."""
    r = C3.bbox(ids3)
    clip = pymupdf.Rect(r.x0 - 2, r.y0 - 2, r.x1 + 2, r.y1 + 2)
    im = np.array(C3.render(set(ids3), clip, 1.0)).astype(int)
    m = (im[:, :, 3] > 200) & (im[:, :, 0] > 215) & (im[:, :, 1] > 130) & (im[:, :, 1] < 200) & (im[:, :, 2] > 90) & (im[:, :, 2] < 160)
    ys, xs = np.where(m)
    assert len(xs) > 300, "no skin-coloured paint on the piece"
    return pymupdf.Point(clip.x0 + xs.mean() - tx, clip.y0 + ys.mean() - ty)


full4 = C4.render(set(range(len(C4.dr))), pymupdf.Rect(0, 0, 1920, 1080), 0.5)
map4, n4 = ndi.label(ndi.binary_dilation(np.array(full4.getchannel("A")) > 8, iterations=3))
sigs4 = {}  # signature -> [(blob, (x, y))]
blob_size4 = {}
for i, d in enumerate(C4.dr):
    sg, cen = sig_of(d)
    if sg is None:
        continue
    k = int(map4[min(map4.shape[0] - 1, int(cen[1] * 0.5)), min(map4.shape[1] - 1, int(cen[0] * 0.5))])
    if k:
        sigs4.setdefault(sg, []).append((k, cen))
        blob_size4[k] = blob_size4.get(k, 0) + 1
composite = max(blob_size4, key=blob_size4.get)  # (the body with all six arms)


def fit_piece(ids3, blob, sigs=None):
    """Turn + move that carry a page-3 piece onto its copy in `blob` of page 4 (or of the page `sigs` describes): (angle, tx, ty, matched pairs, rms)."""
    sigs = sigs4 if sigs is None else sigs
    mine = {}
    for i in ids3:
        sg, cen = sig_of(C3.dr[i])
        if sg is not None:
            mine.setdefault(sg, []).append(cen)
    P, Q = [], []
    for sg, cs in mine.items():
        if len(cs) != 1:
            continue
        there = [t[1] for t in sigs.get(sg, []) if t[0] == blob]
        if len(there) == 1:
            P.append(cs[0])
            Q.append(there[0])
    if len(P) < 30:
        return None
    P, Q = np.array(P), np.array(Q)
    pm, qm = P.mean(axis=0), Q.mean(axis=0)
    for _ in range(2):  # (twice: the second time without the pairs that do not fit)
        A, B = P - pm, Q - qm
        ang = math.atan2((A[:, 0] * B[:, 1] - A[:, 1] * B[:, 0]).sum(), (A[:, 0] * B[:, 0] + A[:, 1] * B[:, 1]).sum())
        c, s_ = math.cos(ang), math.sin(ang)
        pred = np.stack([A[:, 0] * c - A[:, 1] * s_, A[:, 0] * s_ + A[:, 1] * c], axis=1) + qm
        err = np.linalg.norm(pred - Q, axis=1)
        keep = err < max(2.0, np.median(err) * 3)
        if keep.all() or keep.sum() < 20:
            break
        P, Q = P[keep], Q[keep]
        pm, qm = P.mean(axis=0), Q.mean(axis=0)
    return ang, pm, qm, len(P), float(np.sqrt((err[err < max(2.0, np.median(err) * 3)] ** 2).mean()))


def carry_back(fit, q):
    """Where a page-4 point lies on page 3 (the opposite of carry)."""
    ang, pm, qm = fit[0], fit[1], fit[2]
    c, s_ = math.cos(-ang), math.sin(-ang)
    d = np.array([q[0] - qm[0], q[1] - qm[1]])
    return np.array([d[0] * c - d[1] * s_, d[0] * s_ + d[1] * c]) + pm


def carry(fit, p):
    """Where a page-3 point lands on page 4."""
    ang, pm, qm = fit[0], fit[1], fit[2]
    c, s_ = math.cos(ang), math.sin(ang)
    d = np.array([p[0] - pm[0], p[1] - pm[1]])
    return np.array([d[0] * c - d[1] * s_, d[0] * s_ + d[1] * c]) + qm


def blob_of_arm(ids):
    """Which of page 4's separate arm pictures holds these page-3 drawings (the one with the most of their signatures)."""
    count = {}
    for i in ids:
        sg, cen = sig_of(C3.dr[i])
        for (k, c) in sigs4.get(sg, []) if sg is not None else []:
            if k != composite:
                count[k] = count.get(k, 0) + 1
    return max(count, key=count.get)


# ---- page 1: the idle pose ------------------------------------------------------------------------------------------------------
# Page 1 shows the Handyman with all six arms in the pose they hang in while he stands there (the hands only sway a little about it). The arms are
# the same drawings as on page 3, turned and moved: found again by their paths (as for page 4), one fit per piece. The directions of the two sticks
# there are the arms' rest directions; the hand marker is then where the hand stands at idle.
C1 = PageCtx(0)
sigs1 = {}  # signature -> [(0, centre, paint operator)]
for _i, _d in enumerate(C1.dr):
    _sg, _cen = sig_of(_d)
    if _sg is not None:
        sigs1.setdefault(_sg, []).append((0, _cen, _i))

# the body on page 1: it only moved (found by its paths, like the arms' lower pieces), so the shoulder sockets moved with it
_votes = {}
for _i in body_ids:
    _sg, _cen = sig_of(dr[_i])
    for _t in sigs1.get(_sg, []) if _sg is not None else []:
        _k = (round(_t[1][0] - _cen[0]), round(_t[1][1] - _cen[1]))
        _votes[_k] = _votes.get(_k, 0) + 1
_best = max(_votes, key=_votes.get)
assert _votes[_best] > 100, ("the body of page 1 not found", _best, _votes[_best])
socket_i = {k: (centre(d).x + _best[0], centre(d).y + _best[1]) for k, d in sockets.items()}
print("body moved by", _best, "on page 1 (%d paths agree); sockets there:" % _votes[_best], socket_i)

out = {}
for n, (eid, sd, layer) in ARMS.items():
    sh = centre(pivots[(n, 1)])
    el = centre(pivots[(n, 2)])
    ax, ay = el.x - sh.x, el.y - sh.y
    ln = math.hypot(ax, ay)
    ux, uy = ax / ln, ay / ln
    assert (ux < 0) == (sd < 0), (n, "page 2 shows this arm on the other side than ARMS says", ux)
    # (page 2 only says where the pivots and the hand marker are: the pieces themselves are page 3's. How far page 3's lower piece was moved from
    # page 2 is found from the paths the two pages share, which also does not care how the arms lie on page 2 or in what order they were drawn.)
    p2 = pieces3[(n, 2)]
    (tx, ty), votes = shift_by_paths(p2)
    assert votes >= 30, (n, "too few paths of the lower piece of page 3 found on page 2", votes)
    box3 = pymupdf.Rect(C3.bbox(p2))
    box3 = pymupdf.Rect(box3.x0 - 3, box3.y0 - 3, box3.x1 + 3, box3.y1 + 3)
    hit = [g for g in greens if box3.contains(pymupdf.Point(centre(g).x + tx, centre(g).y + ty))]
    if len(hit) == 1:
        hand = centre(hit[0])
    else:  # (the green circle was left off this hand on page 2: the hand is where the skin-coloured paint of the piece is)
        assert not hit, (n, "more than one hand marker on the lower piece", hit)
        hand = skin_centre(p2, tx, ty)
        print("%-8s no hand marker on its hand on page 2: put it at the middle of the hand, page 2 (%.0f, %.0f)" % (n, hand.x, hand.y))
    upper, lower = [], p2
    th1 = math.degrees(math.atan2(el.y - sh.y, el.x - sh.x))  # (y points down: clockwise on the screen)
    th2 = math.degrees(math.atan2(hand.y - el.y, hand.x - el.x))
    l2 = math.hypot(hand.x - el.x, hand.y - el.y) * R
    # page 3: the upper stick (part 1) whole, the lower arm (part 2) whole. Each piece has its own pin hole at the elbow end: it is found in the
    # picture (the darkest spot near the tip), so the two pins are put on one another in the game whatever the page-2 markers said. The shoulder
    # pin is INSET pt from the ragged tip.
    p1, p2 = pieces3[(n, 1)], pieces3[(n, 2)]
    tip_s, tip_e = stick_ends(p1, sd)
    dir1 = (tip_e - tip_s) / np.linalg.norm(tip_e - tip_s)
    piv_s = tip_s + dir1 * INSET
    el3 = pymupdf.Point(el.x + tx, el.y + ty)
    hand3 = pymupdf.Point(hand.x + tx, hand.y + ty)
    # the upper stick: turn it level, find the pin at its elbow end
    phi1 = math.degrees(math.atan2(dir1[1], dir1[0]))
    iu0, (q_s, q_e) = cut_turned_ctx(C3, p1, phi1, [pymupdf.Point(*piv_s), pymupdf.Point(*(tip_e - dir1 * INSET))])
    pin_u = find_pin(iu0, "right")
    piv_e = piv_s + dir1 * ((pin_u[0] - q_s[0]) / R)  # (on the axis, as far from the shoulder pin as the pin hole is)
    # the lower arm: turn it level along elbow -> hand, find the pin at the elbow end, turn it again along pin -> hand
    il0, (r_e, r_h) = cut_turned_ctx(C3, p2, th2, [el3, hand3])
    pin_l = find_pin(il0, "left")
    c2, s2 = math.cos(math.radians(th2)), math.sin(math.radians(th2))
    off = np.array([(pin_l[0] - r_e[0]) / R, (pin_l[1] - r_e[1]) / R])
    pin_l_pt = np.array([el3.x, el3.y]) + np.array([off[0] * c2 - off[1] * s2, off[0] * s2 + off[1] * c2])
    th2 = math.degrees(math.atan2(hand3.y - pin_l_pt[1], hand3.x - pin_l_pt[0]))
    l2 = math.hypot(hand3.x - pin_l_pt[0], hand3.y - pin_l_pt[1]) * R
    il, (pl_e, pl_h) = cut_turned_ctx(C3, p2, th2, [pymupdf.Point(*pin_l_pt), hand3])
    l1 = float(np.linalg.norm(piv_e - piv_s)) * R
    iu, (pu_s, pu_e) = cut_turned_ctx(C3, p1, phi1, [pymupdf.Point(*piv_s), pymupdf.Point(*piv_e)])
    # the folded pose (page 4): where each piece's pins and the hand marker went
    blob = blob_of_arm(p1 + p2)
    fit1, fit2 = fit_piece(p1, blob), fit_piece(p2, blob)
    assert fit1 and fit2, (n, "the arm of page 4 does not match page 3")
    s4, e4 = carry(fit1, piv_s), carry(fit1, piv_e)
    e4l, h4 = carry(fit2, pin_l_pt), carry(fit2, (hand3.x, hand3.y))
    fold1 = math.atan2(e4[1] - s4[1], e4[0] - s4[0])
    fold2 = math.atan2(h4[1] - e4l[1], h4[0] - e4l[0])
    print("%-8s folded: upper %.0f deg, lower %.0f deg  (pins %.1f pt apart there, fit rms %.2f / %.2f over %d / %d paths; rest th2 %.0f)" % (
        n, math.degrees(fold1), math.degrees(fold2), float(np.linalg.norm(e4 - e4l)), fit1[4], fit2[4], fit1[3], fit2[3], th2))
    # (the lower piece is found on page 1 by its paths; the upper stick's paths are too alike between arms for that, so the upper stick is the line from
    # the arm's shoulder socket, which is on the body, to the elbow pin the lower piece found)
    fit2i = fit_piece(p2, 0, sigs1)
    assert fit2i and fit2i[4] < 1.0, (n, "the lower arm of page 1 (idle) does not match page 3", fit2i)
    sock_i = socket_i["L" if sd < 0 else "R"]
    e_i = carry(fit2i, pin_l_pt)
    h_i = carry(fit2i, (hand3.x, hand3.y))
    th1 = math.degrees(math.atan2(e_i[1] - sock_i[1], e_i[0] - sock_i[0]))  # (the idle directions replace the page-2 ones)
    th2 = math.degrees(math.atan2(h_i[1] - e_i[1], h_i[0] - e_i[0]))
    idx = [t[2] for i in p2 for sg in [sig_of(C3.dr[i])[0]] if sg is not None and len(sigs1.get(sg, [])) == 1 for t in sigs1[sg]]
    order = sum(idx) / len(idx)
    print("%-8s idle: socket page1 (%.0f, %.0f) elbow (%.0f, %.0f): upper %.0f deg, %.0f pt (L1 %.0f pt)  lower %.0f deg  fit rms %.2f  paint order %.0f" % (
        n, sock_i[0], sock_i[1], e_i[0], e_i[1], th1, math.hypot(e_i[0] - sock_i[0], e_i[1] - sock_i[1]), l1 / R, th2, fit2i[4], order))
    iu.save(os.path.join(ARM_DIR, "arm_%s_upper.png" % n.lower()))
    il.save(os.path.join(ARM_DIR, "arm_%s_lower.png" % n.lower()))
    su = find_slab(iu, pu_s[0] + 0.25 * l1, pu_e[0] - 0.25 * l1)
    sl = find_slab(il, pl_e[0] + 0.12 * l2, pl_e[0] + 0.5 * l2)
    out[n] = {"id": eid, "side": sd, "layer": layer, "order": order, "th1": math.radians(th1), "th2": math.radians(th2), "l1": l1, "l2": l2, "fold1": fold1, "fold2": fold2,
              "u_pivot": pu_s, "u_slab": su, "l_pivot": pl_e, "l_slab": sl}
    print("%-8s upper %s lower %s  paths %d/%d  L1 %.0f L2 %.0f  slabs %.0f-%.0f / %.0f-%.0f  (elbow y off %.1f, hand y off %.1f)" % (
        n, iu.size, il.size, len(upper), len(lower), l1, l2, su[0], su[1], sl[0], sl[1], pu_e[1] - pu_s[1], pl_h[1] - pl_e[1]))


for _rank, _n in enumerate(sorted(out, key=lambda k: out[k]["order"])):  # (the draw order of page 1: the arm painted last lies on top)
    out[_n]["layer"] = _rank
print("layers:", {k: v["layer"] for k, v in out.items()})


def v2(p):
    return "Vector2(%.1f, %.1f)" % (p[0], p[1])


with open(GD, "w", encoding="utf-8", newline="\n") as f:
    f.write("class_name HandymanRig\nextends RefCounted\n")
    f.write("## GENERATED by tools/export_handyman_rig.py from Handyman.pdf (page 2): where every piece of the Handyman's rig is. Do not edit by hand.\n")
    f.write("## Arm space: px of the art, the arm's shoulder pivot is (0, 0); angles are radians, y points down (clockwise on the screen). An arm is an\n")
    f.write("## upper stick (shoulder -> elbow, turns about the shoulder) and a lower one (elbow -> hand and tool, turns about the elbow, riding on the\n")
    f.write("## upper). Each piece's picture is turned so that its stick lies along +x: `*_pivot` is the joint it turns about (px in the picture),\n")
    f.write("## `*_slab` the stretch of stick (x range in the picture) that may be made longer or shorter. theta1 / theta2: the rest direction of\n")
    f.write("## shoulder -> elbow and elbow -> hand; l1 / l2: their rest lengths. At rest the hand marker is l1 * dir(theta1) + l2 * dir(theta2) from the shoulder.\n\n")
    f.write("const SCALE := %s  # game px per px of the art\n" % SCALE)
    f.write("const BODY_PX := %d  # the body's square, in px of the art\n" % side)
    f.write("const SOCKET_L := Vector2(%.5f, %.5f)  # the shoulder sockets, as fractions of the body's square\n" % sock["L"])
    f.write("const SOCKET_R := Vector2(%.5f, %.5f)\n\n" % sock["R"])
    f.write("const ARMS := {\n")
    for n, o in out.items():
        f.write('\t"%s": {"name": "%s", "side": %d, "layer": %d, "theta1": %.5f, "theta2": %.5f, "l1": %.1f, "l2": %.1f, "fold1": %.5f, "fold2": %.5f,\n' % (
            o["id"], n.lower(), o["side"], o["layer"], o["th1"], o["th2"], o["l1"], o["l2"], o["fold1"], o["fold2"]))
        f.write('\t\t"upper": "handyman/arm_%s_upper.png", "upper_pivot": %s, "upper_slab": %s,\n' % (n.lower(), v2(o["u_pivot"]), v2(o["u_slab"])))
        f.write('\t\t"lower": "handyman/arm_%s_lower.png", "lower_pivot": %s, "lower_slab": %s},\n' % (n.lower(), v2(o["l_pivot"]), v2(o["l_slab"])))
    f.write("}\n")
print("wrote", os.path.normpath(GD))
