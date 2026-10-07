"""Cuts assets/ui/Room Background.pdf (one page per room; so far the Wandering Apothecary) into
assets/ui/new/room/<room>_<layer>.png and writes scripts/ui/<room>_layout.gd (generated: do not edit by hand).

Same idea as the campfire in export_fight_ui.py: the big picture on the page shows where each object goes and in what order
(z = the drawing's paint order). The loose objects on the right are found again inside it by lining up their drawings (same
fill / outline / number of segments, in the same order) with the picture's: that works whatever the artist did to the copy in
the picture (moved, scaled, turned a little). Each object is then cut by replaying the page's own content stream with only
its drawings switched on, so the cut is the object exactly as it stands in the picture. What the picture draws that no loose
object owns (sky, ground, the log...) is replayed the same way as background layers. Written at 1 px per game pixel for a
1080 px tall stage.

Run:  python tools/export_room_background.py     (needs pymupdf, pillow, numpy)
"""
import collections
import difflib
import io
import os
import re
import statistics
import sys
import unicodedata

import numpy as np
import pymupdf
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "Room Background.pdf")
OUT = os.path.join(HERE, "..", "assets", "ui", "new", "room")
os.makedirs(OUT, exist_ok=True)

PAINT = ("f", "f*", "S", "s", "B", "B*", "b", "b*")
SHADE = re.compile(r"/\w+ sh")
XOBJ = re.compile(r"/\w+ Do")
SH, XO = SHADE, XOBJ

# page 0: the Wandering Apothecary. label (lower case, accents kept) -> object id
ROOM = "apothecary"
LABELS = {"xe hàng": "cart", "đèn sáng lập lòe": "lantern", "legend plate": "plate", "mysterious merchant": "merchant",
          "thỏi crystal phát sáng": "crystal", "walk on": "sign", "rừng cây đung đưa trong gió": "forest"}
CHILD = {"lantern": "cart", "crystal": "merchant"}  # a loose object that is also a part of a bigger one: a light source, not a layer
ORDER = ["cart", "merchant", "sign", "plate", "forest"]
MAIN = pymupdf.Rect(0, 0, 405, 278)  # the big picture (points); the loose forest sits below it, the rest to the right


def key(dr):
    f = tuple(round(c, 2) for c in dr["fill"]) if dr.get("fill") else None
    c = tuple(round(c, 2) for c in dr["color"]) if dr.get("color") else None
    return (f, c, len(dr["items"]))


def sig(dr):  # exact geometry (for finding a child inside its parent: both are loose, same scale)
    r = dr["rect"]
    pts = []
    for it in dr["items"]:
        for q in it[1:]:
            if hasattr(q, "x"):
                pts.append((round(q.x - r.x0, 1), round(q.y - r.y0, 1)))
            elif hasattr(q, "x0"):
                pts.append((round(q.x0 - r.x0, 1), round(q.y0 - r.y0, 1), round(q.x1 - r.x0, 1), round(q.y1 - r.y0, 1)))
    return (key(dr), tuple(pts[:6]), len(pts))


def stream_ops(lines, page_h):
    """Walk the content stream: for every paint operator, its line number and the bounding box of its path (y down, like get_drawings)."""
    out=[]
    ctm=[1,0,0,1,0,0]; stack=[]
    pts=[]
    def apply(m,x,y): return (m[0]*x+m[2]*y+m[4], m[1]*x+m[3]*y+m[5])
    def mul(a,b):  # a then b  (new = a * b in PDF row-vector convention: cm matrix applied first)
        return [a[0]*b[0]+a[1]*b[2], a[0]*b[1]+a[1]*b[3], a[2]*b[0]+a[3]*b[2], a[2]*b[1]+a[3]*b[3], a[4]*b[0]+a[5]*b[2]+b[4], a[4]*b[1]+a[5]*b[3]+b[5]]
    cur=None
    for n,l in enumerate(lines):
        t=l.strip()
        if not t: continue
        if t=="q": stack.append(list(ctm)); continue
        if t.startswith("q "):
            stack.append(list(ctm)); t=t[2:]
        if t=="Q":
            if stack: ctm=stack.pop()
            continue
        w=t.split(' ')
        op=w[-1]
        try:
            if op=="cm":
                ctm=mul([float(v) for v in w[:6]], ctm)
            elif op=="m":
                cur=apply(ctm,float(w[0]),float(w[1])); pts.append(cur)
            elif op=="l":
                cur=apply(ctm,float(w[0]),float(w[1])); pts.append(cur)
            elif op=="c":
                for k in (0,2,4): pts.append(apply(ctm,float(w[k]),float(w[k+1])))
            elif op in ("v","y"):
                for k in (0,2): pts.append(apply(ctm,float(w[k]),float(w[k+1])))
            elif op=="re":
                x,y,ww,hh=[float(v) for v in w[:4]]
                for a,b in ((x,y),(x+ww,y),(x+ww,y+hh),(x,y+hh)): pts.append(apply(ctm,a,b))
        except ValueError:
            pass
        if t in ("n", "W n", "W* n"):
            pts = []  # a clip path: not painted
            continue
        if t in PAINT or SH.search(l) or XO.search(l):
            if pts:
                xs=[p[0] for p in pts]; ys=[page_h-p[1] for p in pts]
                out.append((n,(min(xs),min(ys),max(xs),max(ys))))
            else:
                out.append((n,None))
            pts=[]
    return out

def align(ops, draws):
    """drawing index -> line number of its paint operator (a couple of operators draw nothing the page reports)."""
    mp=[]; i=0
    def close(a,b):
        if a is None: return False
        tol=2.5 + 0.02*max(b.width,b.height)
        return abs(a[0]-b.x0)<=tol and abs(a[1]-b.y0)<=tol and abs(a[2]-b.x1)<=tol and abs(a[3]-b.y1)<=tol
    for j,d in enumerate(draws):
        k=0
        while i+k<len(ops) and not close(ops[i+k][1], d["rect"]) and k<8: k+=1
        if i+k>=len(ops) or not close(ops[i+k][1], d["rect"]):
            print("align: no match for drawing", j, [round(v) for v in d["rect"]], "at op", i); k=0
        if i+k>=len(ops): break
        mp.append(ops[i+k][0]); i+=k+1
    return mp


def centre(r):
    return pymupdf.Point((r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2)


def union(rects):
    r = pymupdf.Rect(rects[0])
    for q in rects[1:]:
        r |= q
    return r


def main():
    doc = pymupdf.open(SRC)
    page = doc[0]
    draws = page.get_drawings()
    words = page.get_text("words")
    labels = {}
    line_words = collections.defaultdict(list)
    for w in words:
        line_words[(w[5], w[6])].append(w)
    for _k, ws in line_words.items():
        text = unicodedata.normalize("NFKC", " ".join(w[4] for w in ws)).strip().lower()
        r = pymupdf.Rect(min(w[0] for w in ws), min(w[1] for w in ws), max(w[2] for w in ws), max(w[3] for w in ws))
        if text in LABELS and not (text == "walk on" and ws[0][4] == "WALK"):  # (the sign's own lettering is in capitals: not the label)
            labels[LABELS[text]] = r
    print("labels:", {k: [round(v) for v in r] for k, r in labels.items()})
    main_idx = [i for i, d in enumerate(draws) if MAIN.contains(centre(d["rect"]))]
    main_set = set(main_idx)
    loose_idx = [i for i in range(len(draws)) if i not in main_set]
    # the loose objects: right column = bands between labels; the forest = below the picture on the left
    objs = {}
    right = sorted([(k, r) for k, r in labels.items() if k != "forest"], key=lambda kv: kv[1].y0)
    top = 0.0
    for k, r in right:
        objs[k] = [i for i in loose_idx if draws[i]["rect"].x0 > 400 and top - 2 <= centre(draws[i]["rect"]).y <= r.y0 + 2]
        top = r.y1
    objs["forest"] = [i for i in loose_idx if draws[i]["rect"].x1 < 420 and centre(draws[i]["rect"]).y < labels["forest"].y0 + 2]
    for k, v in objs.items():
        print("object", k, len(v))

    # --- line each loose object's drawings up with the picture's (in paint order), parents before children
    mkeys = [key(draws[i]) for i in main_idx]
    taken = {}  # main drawing index -> object
    pairs = {}  # object -> {loose index: main index}
    for k in ORDER:
        lj = objs[k]
        keys = [key(draws[j]) for j in lj]
        avail = [(("used", n) if main_idx[n] in taken else mkeys[n]) for n in range(len(main_idx))]
        sm = difflib.SequenceMatcher(None, avail, keys, autojunk=False)
        cand = {}
        for a, b, size in sm.get_matching_blocks():
            for t in range(size):
                cand[lj[b + t]] = main_idx[a + t]
        # the copy in the picture may be scaled: keep the pairs whose size agrees with the typical ratio
        ratios = [draws[i]["rect"].width / draws[j]["rect"].width for j, i in cand.items() if draws[j]["rect"].width > 4]
        s = statistics.median(ratios) if ratios else 1.0
        good = {j: i for j, i in cand.items() if draws[j]["rect"].width < 4 or abs(draws[i]["rect"].width / draws[j]["rect"].width / s - 1) < 0.1}
        # an object is painted as one run: drop pairs that only coincide with something painted far away
        runs, cur = [], []
        for j, i in sorted(good.items(), key=lambda t: t[1]):
            if cur and i - cur[-1][1] > 60:
                runs.append(cur)
                cur = []
            cur.append((j, i))
        runs.append(cur)
        good = dict(max(runs, key=len)) if good else {}
        pairs[k] = good
        for i in good.values():
            taken[i] = k
        print("object", k, "found", len(good), "of", len(lj), "scale %.3f" % s)
    owned = {k: sorted(v.values()) for k, v in pairs.items()}
    # --- the child objects (lantern, crystal) sit inside their parent's loose picture: where they are in the picture
    child_rect = {}
    for child, parent in CHILD.items():
        want = {sig(draws[j]) for j in objs[child]}
        hit = [j for j in objs[parent] if sig(draws[j]) in want and j in pairs[parent]]
        if not hit:
            print("child not found in parent:", child)
            continue
        child_rect[child] = union([draws[pairs[parent][j]]["rect"] for j in hit])
        print("child", child, "at", [round(v) for v in child_rect[child]], "in", parent, "(%d drawings)" % len(hit))

    # --- the picture frame
    # (the artwork runs past the picture's clip: the frame is what actually shows, found by rendering the picture's area)
    pm = pymupdf.open(SRC)[0].get_pixmap(matrix=pymupdf.Matrix(4, 4), clip=MAIN, alpha=True)
    alpha = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA").getchannel("A").point(lambda v: 255 if v > 200 else 0)
    fb = alpha.getbbox()
    frame = pymupdf.Rect(MAIN.x0 + fb[0] / 4.0, MAIN.y0 + fb[1] / 4.0, MAIN.x0 + fb[2] / 4.0, MAIN.y0 + fb[3] / 4.0)
    K = 1080.0 / frame.height  # px per point
    W = round(frame.width * K)
    print("frame", frame, "scene px", W, "x 1080")

    # --- pieces painted inside an object's own run of drawings and lying within its outline belong to it (the lantern's
    # body, the plate's middle): the loose picture has them too
    absorbed = collections.defaultdict(set)
    for k in ("cart", "merchant", "sign", "plate"):
        mine = owned[k]
        box = union([draws[i]["rect"] for i in mine]) + (-2, -2, 2, 2)
        for i in range(min(mine), max(mine) + (40 if k == "plate" else 1)):  # (the plate's stretched middle is painted after its two ends)
            if i in main_set and i not in taken and box.contains(draws[i]["rect"]):
                absorbed[k].add(i)
    in_object = {i for k in absorbed for i in absorbed[k]} | set(taken)

    # --- the page stream, cut by switching drawings on and off
    d2 = pymupdf.open(SRC)
    x0 = d2[0].get_contents()[0]
    lines = d2.xref_stream(x0).decode("latin1").split("\n")
    ops = stream_ops(lines, doc[0].rect.height)  # (a couple more paint operators than drawings: line each drawing up with its operator)
    op_line = align(ops, draws)
    all_ops = [n for n, _bb in ops]
    print("paint operators", len(ops), "drawings", len(draws))
    # (all lettering goes: the plate's text is drawn by the game; only the sign's "WALK ON" is art and stays)
    no_text = [("" if re.search(r"\bT[jJ]\b", ln) else ln) for ln in lines]
    sign_text = [("" if re.search(r"\bT[jJ]\b", ln) and "ON)" not in ln else ln) for ln in lines]

    def render(idxs, clip, with_text=False):
        ln = list(sign_text if with_text else no_text)
        keep = {op_line[i] for i in idxs}
        for e in all_ops:
            if e not in keep:
                ln[e] = "n" if ln[e].strip() in PAINT else XOBJ.sub("", SHADE.sub("", ln[e]))
        d2.update_stream(x0, "\n".join(ln).encode("latin1"))
        pm = d2.load_page(0).get_pixmap(matrix=pymupdf.Matrix(K, K), clip=clip, alpha=True)
        im = Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")
        box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        if box is None:
            return None, None
        return im.crop(box), box

    layout = []
    z_of = {}
    for k in ["forest", "cart", "merchant", "sign"]:
        idxs = owned[k] + sorted(absorbed[k])
        clip = union([draws[i]["rect"] for i in idxs]) + (-4, -4, 4, 4)
        clip = pymupdf.Rect(max(clip.x0, frame.x0), max(clip.y0, frame.y0), min(clip.x1, frame.x1), min(clip.y1, frame.y1))
        part, box = render(idxs, clip, with_text=(k == "sign"))
        part.save(os.path.join(OUT, "%s_%s.png" % (ROOM, k)))
        x = (clip.x0 - frame.x0) * K + box[0]
        y = (clip.y0 - frame.y0) * K + box[1]
        z = statistics.median(owned[k])
        z_of[k] = z
        layout.append({"id": k, "file": "%s_%s" % (ROOM, k), "x": round(x), "y": round(y), "z": z, "w": part.width, "h": part.height})
        print("layer", k, part.size, round(x), round(y), "z", z)
    z_of["plate"] = statistics.median(owned["plate"])
    idxs = owned["plate"] + sorted(absorbed["plate"])  # (the plate is cut like the rest, without its text: the game writes that)
    clip = union([draws[i]["rect"] for i in idxs]) + (-4, -4, 4, 4)
    part, box = render(idxs, clip)
    part.save(os.path.join(OUT, "%s_plate.png" % ROOM))
    plate = {"x": round((clip.x0 - frame.x0) * K + box[0]), "y": round((clip.y0 - frame.y0) * K + box[1]), "w": part.width, "h": part.height, "z": z_of["plate"]}
    layout.append({"id": "plate", "file": "%s_plate" % ROOM, "x": plate["x"], "y": plate["y"], "z": plate["z"], "w": part.width, "h": part.height})
    print("plate", plate)

    # --- backgrounds: what the picture draws that no loose object owns, in the gaps between the objects
    zs = sorted((z_of[k], k) for k in z_of)  # (the plate too: the picture paints it last, in front of the log)
    first = min(z_of.values())
    groups = collections.defaultdict(list)
    for i in main_idx:
        if i in in_object:
            continue
        before = [k for z, k in zs if z <= i]
        groups["bg" if i < first else "decor_" + (before[-1] if before else "forest")].append(i)
    for name, ks in groups.items():
        part, box = render(ks, frame)
        if part is None:
            continue
        part.save(os.path.join(OUT, "%s_%s.png" % (ROOM, name)))
        z = 0 if name == "bg" else z_of[name[6:]] + 0.5
        layout.append({"id": name, "file": "%s_%s" % (ROOM, name), "x": box[0], "y": box[1], "z": z, "w": part.width, "h": part.height})
        print("layer", name, part.size, box[:2], "z", z, "ops", len(ks))
    layout.sort(key=lambda e: e["z"])

    # --- the light sources: where, and the colour sampled from the object itself
    lights = {}
    p2 = pymupdf.open(SRC)[0]
    for w in p2.get_text("words"):
        p2.add_redact_annot(pymupdf.Rect(w[:4]))
    p2.apply_redactions(images=pymupdf.PDF_REDACT_IMAGE_NONE, graphics=pymupdf.PDF_REDACT_LINE_ART_NONE)
    for child in CHILD:
        if child not in child_rect:
            continue
        r = child_rect[child]
        src = union([draws[j]["rect"] for j in objs[child]])
        pm = p2.get_pixmap(matrix=pymupdf.Matrix(4, 4), clip=src + (-2, -2, 2, 2), alpha=True)
        a = np.asarray(Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")).astype(float)
        rgb = a[..., :3][a[..., 3] > 200] / 255.0
        v = rgb.max(axis=1)
        s = (v - rgb.min(axis=1)) / np.maximum(v, 1e-3)
        score = v * (0.4 + s)
        col = rgb[score >= np.quantile(score, 0.75)].mean(axis=0)
        lights[child] = {"x": round(((r.x0 + r.x1) / 2 - frame.x0) * K), "y": round(((r.y0 + r.y1) / 2 - frame.y0) * K),
                         "r": round(max(r.width, r.height) * K), "color": tuple(round(float(c), 3) for c in col)}
        print("light", child, lights[child])

    # --- the layout file
    out = ["class_name ApothecaryLayout", "extends RefCounted",
           "## GENERATED by tools/export_room_background.py from Room Background.pdf: do not edit by hand.",
           "## Every layer: its picture (assets/ui/new/room/<file>.png), its top-left in the scene (%d x 1080 px, centred on the 1920 stage) and its z." % W, "",
           "const SCENE_W := %d" % W, "const LAYERS := ["]
    for e in layout:
        out.append('\t{"id": "%s", "file": "%s", "x": %d, "y": %d, "z": %s, "w": %d, "h": %d},' % (e["id"], e["file"], e["x"], e["y"], e["z"], e["w"], e["h"]))
    out.append("]")
    out.append('const PLATE := {"x": %d, "y": %d, "w": %d, "h": %d, "z": %s}' % (plate["x"], plate["y"], plate["w"], plate["h"], plate["z"]))
    out.append("const LIGHTS := {")
    for k, v in lights.items():
        out.append('\t"%s": {"x": %d, "y": %d, "r": %d, "color": Color(%.3f, %.3f, %.3f)},' % (k, v["x"], v["y"], v["r"], *v["color"]))
    out.append("}")
    with open(os.path.join(HERE, "..", "scripts", "ui", "%s_layout.gd" % ROOM), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("done")


if __name__ == "__main__":
    sys.exit(main())
