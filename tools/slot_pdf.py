"""Helpers to take the pieces of assets/Puppet/_Source/Slot_machine.pdf apart (used by export_slot_machine.py).
The page is 1920 x 1080 pt = the game's screen, so a piece's place on the page is its place on the screen.
Every painted path of the page (page.get_drawings()[i]) is matched to its paint operator in the content stream (`mapping`); a piece is rendered by
turning every OTHER paint operator into a no-op (n) and dropping the shadings (`sh`: the lamps' glow, the lever knob) and images (`Do`) that are not wanted.
Needs pymupdf, pillow."""
import io
import math
import os
import sys

import pymupdf
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
PAINT = {"f", "f*", "S", "s", "B", "B*", "b", "b*"}


def _mul(a, b):
    return (a[0] * b[0] + a[1] * b[2], a[0] * b[1] + a[1] * b[3], a[2] * b[0] + a[3] * b[2], a[2] * b[1] + a[3] * b[3],
            a[4] * b[0] + a[5] * b[2] + b[4], a[4] * b[1] + a[5] * b[3] + b[5])


class Slot:
    def __init__(self, path):
        self.doc = pymupdf.open(path)
        self.page = self.doc[0]
        self.H = self.page.rect.height
        self.xref = self.page.get_contents()[0]
        self.stream = self.doc.xref_stream(self.xref).decode("latin1")
        self.dr = self.page.get_drawings()
        self._parse()

    # ------------------------------------------------------------------ parsing
    def _parse(self):
        H = self.H
        toks = self.stream.split()
        self.toks = toks
        ctm = (1, 0, 0, 1, 0, 0)
        stack = []
        pts = []
        operands = []
        paint = []  # (token index, bbox)
        self.shadings = []  # (token index, x, y) in page coordinates (y down)
        self.images = []  # (token index, bbox)
        self.text = []  # token indexes of BT / ET
        for ti, t in enumerate(toks):
            try:
                operands.append(float(t))
                continue
            except ValueError:
                pass
            op = t
            if op == "q":
                stack.append(ctm)
            elif op == "Q":
                ctm = stack.pop() if stack else ctm
            elif op == "cm":
                ctm = _mul(tuple(operands[-6:]), ctm)
            elif op in ("m", "l"):
                pts.append(tuple(operands[-2:]))
            elif op == "c":
                o = operands[-6:]
                pts += [tuple(o[0:2]), tuple(o[2:4]), tuple(o[4:6])]
            elif op in ("v", "y"):
                o = operands[-4:]
                pts += [tuple(o[0:2]), tuple(o[2:4])]
            elif op == "re":
                x, y, w, h = operands[-4:]
                pts += [(x, y), (x + w, y + h)]
            elif op in PAINT:
                if pts:
                    xs, ys = [], []
                    for x, y in pts:
                        xs.append(ctm[0] * x + ctm[2] * y + ctm[4])
                        ys.append(H - (ctm[1] * x + ctm[3] * y + ctm[5]))
                    paint.append((ti, min(xs), min(ys), max(xs), max(ys)))
                else:
                    paint.append((ti, None, None, None, None))
                pts = []
            elif op == "n":
                pts = []
            elif op == "sh":
                self.shadings.append((ti, ctm[4], H - ctm[5]))
            elif op == "Do":
                # the unit square through the CTM
                x0, y0 = ctm[4], ctm[5]
                x1, y1 = ctm[0] + ctm[2] + ctm[4], ctm[1] + ctm[3] + ctm[5]
                self.images.append((ti, min(x0, x1), H - max(y0, y1), max(x0, x1), H - min(y0, y1)))
            elif op in ("BT", "ET"):
                self.text.append(ti)
            operands = []
        # match the painted paths (get_drawings) to the paint operators, in order
        def close(ev, r, tol=4.0):
            return ev[1] is not None and abs(ev[1] - r.x0) < tol and abs(ev[2] - r.y0) < tol and abs(ev[3] - r.x1) < tol and abs(ev[4] - r.y1) < tol

        self.mapping = [None] * len(self.dr)
        e = 0
        for k, d in enumerate(self.dr):
            for off in range(60):
                if e + off < len(paint) and close(paint[e + off], d["rect"]):
                    self.mapping[k] = paint[e + off][0]
                    e += off + 1
                    break
        self.paint_tokens = [p[0] for p in paint]

    # ------------------------------------------------------------------ rendering
    def render(self, draw_idx, clip, zoom=2.0, shadings=(), images=()):
        """The page with only these painted paths (indexes of get_drawings), shadings (token indexes) and images (token indexes), cropped to `clip`."""
        keep = {self.mapping[i] for i in draw_idx if self.mapping[i] is not None}
        keep_sh = set(shadings)
        keep_do = set(images)
        toks = list(self.toks)
        drop_text = False
        for ti in self.paint_tokens:
            if ti not in keep:
                toks[ti] = "n"
        for ti, x, y in self.shadings:
            if ti not in keep_sh:
                toks[ti] = ""
                toks[ti - 1] = ""
        for ti, *_ in self.images:
            if ti not in keep_do:
                toks[ti] = ""
                toks[ti - 1] = ""
        for a, b in zip(self.text[0::2], self.text[1::2]):  # (the labels are not art)
            for k in range(a, b + 1):
                toks[k] = ""
        self.doc.update_stream(self.xref, " ".join(toks).encode("latin1"))
        pm = self.doc.load_page(0).get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip, alpha=True)
        return Image.open(io.BytesIO(pm.tobytes("png"))).convert("RGBA")

    def shadings_in(self, rect, margin=12.0):
        return [ti for ti, x, y in self.shadings if rect.x0 - margin <= x <= rect.x1 + margin and rect.y0 - margin <= y <= rect.y1 + margin]

    def images_in(self, rect):
        out = []
        for ti, x0, y0, x1, y1 in self.images:
            if x0 >= rect.x0 - 2 and y0 >= rect.y0 - 2 and x1 <= rect.x1 + 2 and y1 <= rect.y1 + 2:
                out.append(ti)
        return out

    def box(self, idx):
        r = pymupdf.Rect(self.dr[idx[0]]["rect"])
        for i in idx:
            r |= self.dr[i]["rect"]
        return r

    @staticmethod
    def trim(im, zoom=2.0, origin=(0.0, 0.0)):
        """Crop to the painted part; returns (image, (x, y) of its top-left on the page in pt)."""
        box = im.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
        if box is None:
            return None, origin
        return im.crop(box), (origin[0] + box[0] / zoom, origin[1] + box[1] / zoom)
