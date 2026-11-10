r"""2026-11-10: reads the user's rig layout, assets/Puppet/Enemies/Act2/pianist/Pianist.pdf, and writes what the game needs:
  - the pictures of its pieces (with their transparency) into pianist/back/: body.png, stool.png, leg.png (the hanging leg), user_fore.png (forearm of the idle hand), pdf_point_fore.png (the pointing forearm),
    pdf_upper.png (the upper arm), piano.png, sign.png, and pdf_foot.png (shoe + shin of the left leg; the thigh is leg.png). Page 2 (two rows: foot down / foot raised) gives the foot's x range, tilt, lift and the leg's pivot;
  - back/pdf_layout.json: where every piece goes, in px of the PIANO's picture ("pp"; the piano is 1849 px wide in its own picture, and the PDF's own scale gives pp per point), for each pose of the sign
    sequence (idle, raise, point, touch, out: panels 1, 2, 3, 4, 6 of page 1) and for the five legs (page 2); plus the metrics that put the 12 right-hand frames on the PDF's body.
Each piece is a matrix [a, b, c, d, e, f] sending the unit square of its picture to pp (x = a u + c v + e, y = b u + d v + f).
Panels are found by order: page 1: groups of 8 = leg, sign, piano, sheet, forearm, stool, upper arm, body; page 2: two stray pieces, then groups of 6 = sign, piano, sheet, leg, stool, body.
Run with the python that has pymupdf:  C:/Users/sonvt/AppData/Local/Programs/Python/Python312/python.exe tools/extract_pianist_pdf.py"""
import io
import json
import math
import os
import sys

import numpy as np
import pymupdf
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from alpha_bleed import bleed

D = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
OUT = os.path.join(D, "back")
doc = pymupdf.open(os.path.join(D, "Pianist.pdf"))


def picture(xref):
    info = doc.extract_image(xref)
    im = Image.open(io.BytesIO(info["image"])).convert("RGB")
    if info.get("smask"):
        m = Image.open(io.BytesIO(doc.extract_image(info["smask"])["image"])).convert("L")
        im = im.convert("RGBA")
        im.putalpha(m)
    return im.convert("RGBA")


def save(xref, name):
    im = bleed(picture(xref))  # (colour of the edge pixels = the sprite's own colour: no white outline, see alpha_bleed.py)
    im.save(os.path.join(OUT, name))
    return im


p0 = doc[0].get_image_info(xrefs=True)
groups0 = [p0[i:i + 8] for i in range(0, len(p0), 8)]
S = None
poses = {}
for name, gi in (("idle", 0), ("raise", 1), ("point", 2), ("touch", 3), ("out", 5)):
    g = groups0[gi]
    piano = g[2]["transform"]
    s = g[2]["width"] / piano[0]
    S = S or s
    px, py = piano[4], piano[5]

    def m(img):
        t = img["transform"]
        return [round(t[0] * s, 2), round(t[1] * s, 2), round(t[2] * s, 2), round(t[3] * s, 2), round((t[4] - px) * s, 1), round((t[5] - py) * s, 1)]

    poses[name] = {"up": m(g[6]), "fo": m(g[4]), "pt": name in ("point", "touch", "out"), "body": m(g[7]), "stool": m(g[5]), "leg": m(g[0]), "sign": m(g[1]), "sheet": m(g[3])}
g = groups0[0]
save(g[0]["xref"], "idle_leg.png")  # (2026-11-10: the user drew a leg for the IDLE position: shoe under the coat tails; poses.idle.leg is its matrix)
save(g[1]["xref"], "sign.png")
save(g[2]["xref"], "piano.png")
save(g[4]["xref"], "user_fore.png")
save(g[5]["xref"], "stool.png")
save(g[6]["xref"], "pdf_upper.png")
body = save(g[7]["xref"], "body.png")
save(groups0[2][4]["xref"], "pdf_point_fore.png")
# page 2 (2026-11-10, the user's second version): two rows of 5 panels. Row 1 = the left foot DOWN (pressing a key) at 5 places, row 2 = the same foot RAISED a little (tilted, lifted) so it does not touch the keys.
# Two pieces: FOOT (shoe + shin) and LEG (the thigh): the leg turns only about the RED dot (its pivot), and the foot always hangs on the leg's BLUE joint (blue dot on the foot = its knee).
# Everything is measured here; the game places the foot at any x between the first and the last panel and turns the leg to meet it (PianistBackRig._draw_leg).
p1 = doc[1].get_image_info(xrefs=True)
SIGN, PIANO_X = groups0[0][1]["xref"], groups0[0][2]["xref"]
pianos = sorted([i for i in p1 if i["xref"] == PIANO_X], key=lambda i: (i["transform"][5] > 200, i["transform"][4]))


def _in_piano(i, q):
    t = q["transform"]
    c = (i["transform"][4] + i["transform"][0] / 2, i["transform"][5] + i["transform"][3] / 2)
    return t[4] <= c[0] <= t[4] + t[0] and t[5] <= c[1] <= t[5] + t[3]


# the LEGEND (outside the panels): the leg (thigh, a ball at each end), the foot (shoe + shin) twice, and 3 dots the user drew:
#   RED = the pivot of the leg (it turns only about this point; the hip, behind the body); BLUE on the leg = its other end (the joint); BLUE on the foot = its knee.
# The game keeps the two blue points TOGETHER at all times: the leg only turns about the red one and the foot hangs on its joint.
leg_ratio = lambda i: i["width"] / i["height"]
legend = [i for i in p1 if not any(_in_piano(i, q) for q in pianos) and i["height"] < 1000 and i["width"] < 1000 and 0.3 < i["transform"][1] + 1 and i["bbox"][1] > 240]
leg_l = [i for i in legend if leg_ratio(i) < 1.2][0]
foot_l = [i for i in legend if leg_ratio(i) >= 1.2]
LEG_X, FOOT_X = leg_l["xref"], foot_l[0]["xref"]
save(LEG_X, "leg.png")
dots = [d for d in doc[1].get_drawings() if d.get("fill")]
red = [d for d in dots if d["fill"][0] > 0.8 and d["fill"][1] < 0.3][0]
blues = [d for d in dots if d["fill"][2] > 0.6 and d["fill"][0] < 0.4]


def _c(d):
    r = d["rect"]
    return (r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2


def _uv(img, pt):
    t = img["transform"]
    return (pt[0] - t[4]) / t[0], (pt[1] - t[5]) / t[3]


def _inside(img, pt):
    u, v = _uv(img, pt)
    return 0 <= u <= 1 and 0 <= v <= 1


blue_leg = [d for d in blues if _inside(leg_l, _c(d))][0]
blue_foot = [d for d in blues if d is not blue_leg][0]
foot_img = [f for f in foot_l if _inside(f, _c(blue_foot))][0]
UVP, UVJ, UVK = _uv(leg_l, _c(red)), _uv(leg_l, _c(blue_leg)), _uv(foot_img, _c(blue_foot))


def apply(t, uv):
    return t[0] * uv[0] + t[2] * uv[1] + t[4], t[1] * uv[0] + t[3] * uv[1] + t[5]


rows = {0: [], 1: []}
for n, pi in enumerate(pianos):
    t = pi["transform"]
    s2 = pi["width"] / t[0]

    def inside(i):
        c = apply(i["transform"], (0.5, 0.5))
        return t[4] <= c[0] <= t[4] + t[0] and t[5] <= c[1] <= t[5] + t[3]

    lg = [i for i in p1 if i["xref"] == LEG_X and inside(i)]
    ft = [i for i in p1 if i["xref"] == FOOT_X and inside(i)][0]
    kx, ky = apply(ft["transform"], UVK)
    px_, py_ = apply(lg[0]["transform"], UVP) if lg else (None, None)
    jx, jy = apply(lg[0]["transform"], UVJ) if lg else (None, None)
    rows[n // 5].append({"knee": ((kx - t[4]) * s2, (ky - t[5]) * s2), "tilt": math.degrees(math.atan2(ft["transform"][1], ft["transform"][0])),
                         "pivot": ((px_ - t[4]) * s2, (py_ - t[5]) * s2) if lg else None, "joint": ((jx - t[4]) * s2, (jy - t[5]) * s2) if lg else None,
                         "ft": ft, "lg": lg[0] if lg else None, "piano": t, "s": s2})
for rw in rows:
    for k, r in enumerate(rows[rw]):
        print("panel", rw, k, "knee", [round(v) for v in r["knee"]], "pivot", r["pivot"] and [round(v) for v in r["pivot"]], "joint", r["joint"] and [round(v) for v in r["joint"]])
r0 = rows[0][0]
fm = r0["ft"]["transform"]
lm0 = r0["lg"]["transform"]
pt_ = r0["piano"]


def mat(tr, pt, s2):
    return [round(tr[0] * s2, 2), round(tr[1] * s2, 2), round(tr[2] * s2, 2), round(tr[3] * s2, 2), round((tr[4] - pt[4]) * s2, 1), round((tr[5] - pt[5]) * s2, 1)]


pivots = [r["pivot"] for rw in rows.values() for r in rw if r["pivot"]]
foot = {"leg_m": mat(lm0, pt_, r0["s"]), "foot_m": mat(fm, pt_, r0["s"]), "uv_pivot": [round(UVP[0], 4), round(UVP[1], 4)], "uv_joint": [round(UVJ[0], 4), round(UVJ[1], 4)], "uv_knee": [round(UVK[0], 4), round(UVK[1], 4)],
        "pivot": [round(float(np.mean([p[0] for p in pivots])), 1), round(float(np.mean([p[1] for p in pivots])), 1)],
        "knee_x0": round(min(r["knee"][0] for r in rows[0]), 1), "knee_x1": round(max(r["knee"][0] for r in rows[0]), 1), "knee_y": round(float(np.mean([r["knee"][1] for r in rows[0]])), 1),
        "tilt": round(float(np.mean([r["tilt"] for r in rows[1]])), 2), "lift": round(float(np.mean([r["knee"][1] for r in rows[0]]) - np.mean([r["knee"][1] for r in rows[1]])), 1)}
save(FOOT_X, "pdf_foot.png")
print("foot", foot)
# the 12 frames on the PDF's body: scale from the width of the hat's brim, the place from the hat's centre and top
a = np.array(body)[:, :, 3] > 128
rows = a[: int(a.shape[0] * 0.1)]
bw = rows.sum(1)
brim_row = int(np.argmax(bw))
bxs = np.where(rows[brim_row])[0]
brim_px_body = int(bxs.max() - bxs.min())
bm = poses["idle"]["body"]
pp_per_px = bm[0] / body.size[0]
brim_pp = brim_px_body * pp_per_px
hat_cx_body = (bxs.min() + bxs.max()) / 2 * pp_per_px + bm[4]
hat_top_body = bm[5]
fr = json.load(open(os.path.join(OUT, "rh_frames.json")))
f1 = np.array(Image.open(os.path.join(OUT, "rh_01.png")).convert("RGBA"))[:, :, 3] > 128
top = np.where(f1.any(1))[0].min()
band = f1[top: top + int(f1.shape[0] * 0.1)]
fbw = band.sum(1)
frow = int(np.argmax(fbw))
fxs = np.where(band[frow])[0]
brim_px_frame = int(fxs.max() - fxs.min())
frame_s = brim_pp / brim_px_frame
fig = {"scale": round(frame_s, 4), "hat_x": float((fxs.min() + fxs.max()) / 2), "cx": round(hat_cx_body, 1), "top": round(hat_top_body - top * frame_s, 1)}
print("brim: body %d px = %.1f pp; frame 1 %d px -> scale %.4f; hat centre of the frame %.1f px ->%.1f pp; top row %d" % (brim_px_body, brim_pp, brim_px_frame, frame_s, fig["hat_x"], hat_cx_body, top))
layout = {"S": round(S, 4), "poses": poses, "foot": foot, "fig": fig}
json.dump(layout, open(os.path.join(OUT, "pdf_layout.json"), "w"), indent=1)
print("poses", list(poses))
