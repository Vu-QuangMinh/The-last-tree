r"""2026-11-10: reads the user's rig layout, assets/Puppet/Enemies/Act2/pianist/Pianist.pdf, and writes what the game needs:
  - the pictures of its pieces (with their transparency) into pianist/back/: body.png, stool.png, leg.png (the hanging leg), user_fore.png (forearm of the idle hand), pdf_point_fore.png (the pointing forearm),
    pdf_upper.png (the upper arm), piano.png, sign.png, and user_leg_1..5.png (the raised left leg, 1 = the lowest note ... 5 = the highest, in the order of the labels on page 2);
  - back/pdf_layout.json: where every piece goes, in px of the PIANO's picture ("pp"; the piano is 1849 px wide in its own picture, and the PDF's own scale gives pp per point), for each pose of the sign
    sequence (idle, raise, point, touch, out: panels 1, 2, 3, 4, 6 of page 1) and for the five legs (page 2); plus the metrics that put the 12 right-hand frames on the PDF's body.
Each piece is a matrix [a, b, c, d, e, f] sending the unit square of its picture to pp (x = a u + c v + e, y = b u + d v + f).
Panels are found by order: page 1: groups of 8 = leg, sign, piano, sheet, forearm, stool, upper arm, body; page 2: two stray pieces, then groups of 6 = sign, piano, sheet, leg, stool, body.
Run with the python that has pymupdf:  C:/Users/sonvt/AppData/Local/Programs/Python/Python312/python.exe tools/extract_pianist_pdf.py"""
import io
import json
import os

import numpy as np
import pymupdf
from PIL import Image

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
    im = picture(xref)
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
save(g[0]["xref"], "leg.png")
save(g[1]["xref"], "sign.png")
save(g[2]["xref"], "piano.png")
save(g[4]["xref"], "user_fore.png")
save(g[5]["xref"], "stool.png")
save(g[6]["xref"], "pdf_upper.png")
body = save(g[7]["xref"], "body.png")
save(groups0[2][4]["xref"], "pdf_point_fore.png")
# page 2: the legs
p1 = doc[1].get_image_info(xrefs=True)[2:]
panels = [p1[i:i + 6] for i in range(0, len(p1), 6)]
known = {i["xref"] for i in groups0[0]}  # (the pieces of page 1 that are not legs: the leg of a panel is the one picture that is none of them)
info = []
for pn in panels:
    leg_img = [i for i in pn if i["xref"] not in known][0]
    piano_img = [i for i in pn if i["xref"] == groups0[0][2]["xref"]][0]
    pn = [pn[0], piano_img, pn[2], leg_img]  # (only [1] = the piano and [3] = the leg are used below)
    piano = piano_img["transform"]
    info.append((piano[5] > 150, piano[4], pn))  # (bottom row?, x, group)
info.sort(key=lambda t: (t[0], t[1]))  # labels: 1, 2, 3 = top row left to right, 4, 5 = bottom row
legs = []
for n, (_, _, pn) in enumerate(info, 1):
    piano = pn[1]["transform"]
    s = pn[1]["width"] / piano[0]
    t = pn[3]["transform"]
    legs.append([round(t[0] * s, 2), round(t[1] * s, 2), round(t[2] * s, 2), round(t[3] * s, 2), round((t[4] - piano[4]) * s, 1), round((t[5] - piano[5]) * s, 1)])
    save(pn[3]["xref"], "user_leg_%d.png" % n)
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
layout = {"S": round(S, 4), "poses": poses, "legs": legs, "fig": fig}
json.dump(layout, open(os.path.join(OUT, "pdf_layout.json"), "w"), indent=1)
print("poses", list(poses), "legs", len(legs))
for k, m in enumerate(legs, 1):
    print(" leg", k, m)
