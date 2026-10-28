"""The Samurai and his Retainer (2026-10-29), from the user's Act2/samurai/animation.pdf (ONE huge page, 23 distinct pictures placed again and again).
The Samurai is drawn as separate pieces (body, back, two thighs, two shins, two feet, two upper arms and four forearm-with-sword pieces) placed again and again
with their own matrices: the idle pose, a two-frame idle sway and the three stances (In no kamae 9 frames, Ko gasumi 4, Hybrid 3x3 = Sha no kamae 13).
An ARM is a chain: the upper arm turns about its shoulder (a point of the body), the forearm turns about the elbow (the ball of the upper arm, which sits in
the forearm's socket). The shoulder, the elbows and the sockets are SOLVED from the PDF (the point that stays put in every frame), and every frame stores the
two angles and scales, so the arm in between two frames is still joined at the shoulder and the elbow (see SamuraiRig).
The Retainer is the same: his body (the picture of 401 x 1403) is fixed; his front arm turns about the shoulder and carries the bottle / the fan (and the sliver,
his thumb) at the hand. Bottle (idle), lower (the hand lowered before the throw), fan 1 / fan 2 are those; the gong poses and the kneeling pose are finished pictures.
Pictures are found by SIZE (the PDF was saved again and the xref numbers changed once already).
Output (never into samurai/: that folder is the user's own):
  assets/Puppet/Enemies/Act2/samurai_rig/<piece>.png        the Samurai's pieces, full size
  assets/Puppet/Enemies/Act2/samurai_retainer_rig/<piece>.png   the Retainer's pieces
  assets/Puppet/Enemies/Act2/samurai.png                     the idle pose assembled (codex / menus / shadow)
  assets/Puppet/Enemies/Act2/samurai_retainer*.png           idle (the bottle in his hand), gong, gong2, yield: finished pictures, square canvases
  assets/Puppet/Enemies/Act2/samurai_bottle.png              the bottle he throws (and the Bottle intent's icon)
  scripts/ui/samurai_layout.gd, scripts/ui/retainer_layout.gd   generated
Run with a python that has pymupdf, numpy and Pillow:  C:/Users/sonvt/AppData/Local/Programs/Python/Python312/python.exe tools/export_samurai_rig.py
(then Godot --headless --editor --quit once)."""
import itertools
import math
import os

import numpy as np
import pymupdf
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ACT2 = os.path.join(HERE, "..", "assets", "Puppet", "Enemies", "Act2")
PDF = os.path.join(ACT2, "samurai", "animation.pdf")
OUT = os.path.join(ACT2, "samurai_rig")
OUT_R = os.path.join(ACT2, "samurai_retainer_rig")
LAYOUT = os.path.join(HERE, "..", "scripts", "ui", "samurai_layout.gd")
LAYOUT_R = os.path.join(HERE, "..", "scripts", "ui", "retainer_layout.gd")

# size of the picture -> piece
SAMURAI_BY_SIZE = {(533, 881): "body", (228, 147): "back", (248, 390): "thigh_l", (247, 392): "thigh_r", (226, 105): "foot_l", (225, 104): "foot_r",
	(238, 141): "arm_l", (239, 141): "arm_r", (313, 651): "sword_long_a", (309, 652): "sword_long_b", (312, 408): "sword_short_a", (309, 416): "sword_short_b"}
SHIN = (134, 252)  # two pictures of the same size: the one that stands further left in the idle pose is the left shin
RETAINER_BY_SIZE = {(401, 1403): "body", (417, 558): "arm_back", (68, 46): "sliver", (530, 668): "bottle", (603, 198): "arm_front", (368, 536): "fan",
	(1234, 1047): "mallet_arm", (720, 566): "gong", (668, 1318): "yield"}
FORES = ["sword_long_a", "sword_long_b", "sword_short_a", "sword_short_b"]
PREVIEW = 1.0 / 4.149  # page points -> pixels of the 2000 px wide preview in which the rows were read
CANVAS = 1500  # the Retainer's finished pictures: square, in page pixels
BODY_X = 760  # ... with the middle of his body this far from the left edge
GROUND_PAD = 40


def row_of(y: float) -> str:
	return "top" if y < 150 else ("idle_ab" if y < 330 else ("sha" if y < 500 else ("ko" if y < 700 else "in")))


def frame_name(y: float, order: int) -> str:
	r = row_of(y)
	if r == "top":
		return "idle"
	if r == "idle_ab":
		return "idle_%s" % "ab"[order]
	return "%s_%d" % (r, order)


def pixel_matrix(info: dict) -> list:
	"""[a b c d e f] mapping a pixel of the picture to the page: x' = a x + c y + e, y' = b x + d y + f"""
	a, b, c, d, e, f = info["transform"]
	w, h = info["width"], info["height"]
	return [a / w, b / w, c / h, d / h, e, f]


def mat(m) -> np.ndarray:
	a, b, c, d, e, f = m
	return np.array([[a, c, e], [b, d, f], [0, 0, 1.0]])


def compose(placements: list, box: tuple, images: dict) -> Image.Image:
	"""Draw the pictures in paint order on a transparent canvas covering the page rectangle box = (x0, y0, w, h)."""
	x0, y0, w, h = box
	canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	for key, m in placements:
		a, b, c, d, e, f = m
		e -= x0
		f -= y0
		det = a * d - b * c
		ia, ib = d / det, -c / det
		ic, id_ = -b / det, a / det
		ie = -(ia * e + ib * f)
		if_ = -(ic * e + id_ * f)
		layer = images[key].transform((w, h), Image.AFFINE, (ia, ib, ie, ic, id_, if_), resample=Image.BICUBIC)
		canvas = Image.alpha_composite(canvas, layer)
	return canvas


def solve_pin(pairs: list):
	"""pairs = [(P, C)] matrices (3x3) of a parent and a child that are pinned together: find the point p of the parent's picture and the point c of the
	child's picture that coincide in every pair:  P p = C c.  Returns (p, c, rms residual)."""
	rows, rhs = [], []
	for P, C in pairs:
		rows.append(np.hstack([P[:2, :2], -C[:2, :2]]))
		rhs.append(C[:2, 2] - P[:2, 2])
	A, y = np.vstack(rows), np.concatenate(rhs)
	sol = np.linalg.lstsq(A, y, rcond=None)[0]
	r = A @ sol - y
	return sol[:2], sol[2:], float(np.sqrt((r ** 2).mean()))


def decompose(L: np.ndarray):
	"""linear part -> (angle, sx, sy) for  R(angle) * diag(sx, sy)  (the pictures are only turned and scaled)"""
	x, y = L[:2, 0], L[:2, 1]
	return math.atan2(x[1], x[0]), float(np.linalg.norm(x)), float(np.linalg.norm(y))


def vec(v) -> str:
	return "Vector2(%.3f, %.3f)" % (v[0], v[1])


def tf(m: list) -> str:
	return "Transform2D(Vector2(%.5f, %.5f), Vector2(%.5f, %.5f), Vector2(%.3f, %.3f))" % tuple(m)


def load_images(doc, infos) -> dict:
	images = {}
	for x in {i["xref"] for i in infos}:
		pix = pymupdf.Pixmap(doc, x)
		smask = doc.extract_image(x).get("smask", 0)
		if smask:
			pix = pymupdf.Pixmap(pix, pymupdf.Pixmap(doc, smask))
		if pix.n - pix.alpha != 3:
			pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
		images[x] = Image.frombytes("RGBA" if pix.alpha else "RGB", (pix.width, pix.height), pix.samples).convert("RGBA")
	return images


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(OUT_R, exist_ok=True)
	doc = pymupdf.open(PDF)
	page = doc[0]
	infos = page.get_image_info(xrefs=True)
	images = load_images(doc, infos)
	size_of = {x: im.size for x, im in images.items()}

	# ---- which xref is which piece -------------------------------------------------------------------------
	names = {}
	for x, sz in size_of.items():
		if sz in SAMURAI_BY_SIZE:
			names[x] = SAMURAI_BY_SIZE[sz]
		elif sz in RETAINER_BY_SIZE:
			names[x] = "R_" + RETAINER_BY_SIZE[sz]
	idle_shins = [i for i in infos if size_of[i["xref"]] == SHIN and i["bbox"][1] * PREVIEW < 200 and i["bbox"][0] * PREVIEW < 300]  # (the idle pose at the top left)
	two = sorted({i["xref"]: i for i in idle_shins}.values(), key=lambda i: i["bbox"][0])
	names[two[0]["xref"]] = "shin_l"
	names[two[1]["xref"]] = "shin_r"
	pieces = {x: n for x, n in names.items() if not n.startswith("R_")}
	assert len(pieces) == 14, names
	for x, n in pieces.items():
		images[x].save(os.path.join(OUT, n + ".png"))
	for x, n in names.items():
		if n.startswith("R_"):
			images[x].save(os.path.join(OUT_R, n[2:] + ".png"))

	# ---- the Samurai's frames -------------------------------------------------------------------------------
	sam = [(k, i) for k, i in enumerate(infos) if i["xref"] in pieces]

	def centre(i):
		b = i["bbox"]
		return ((b[0] + b[2]) / 2 * PREVIEW, (b[1] + b[3]) / 2 * PREVIEW)

	def skip(i):  # the row of loose pieces (Than, Than sau, Chan phai ...) and the spare swords at the top
		cx, cy = centre(i)
		return cy < 200 and cx > 330

	body_x = next(x for x, n in pieces.items() if n == "body")
	bodies = [(k, i) for k, i in sam if i["xref"] == body_x and not skip(i)]
	rows = {}
	for k, i in bodies:
		cx, cy = centre(i)
		rows.setdefault(row_of(cy), []).append((cx, k, i))
	fname = {}
	for row in rows.values():
		row.sort()
		for n, (cx, k, i) in enumerate(row):
			fname[k] = frame_name(centre(i)[1], n)
	groups = {k: [] for k in fname}
	for k, i in sam:
		if skip(i):
			continue
		cx, cy = centre(i)
		best = min(fname, key=lambda bk: (centre(infos[bk])[0] - cx) ** 2 + (centre(infos[bk])[1] - cy) ** 2)
		groups[best].append((k, i))
	raw = {}  # frame -> {piece: (3x3 matrix, z)}
	for bk, items in groups.items():
		mats = {pieces[i["xref"]]: i for k, i in items}
		assert len(items) == len(mats) == 12, (fname[bk], [pieces[i["xref"]] for k, i in items])
		body = infos[bk]
		foot = mats["foot_l"]
		ax = body["transform"][4] + body["transform"][0] / 2.0
		ay = foot["transform"][5] + foot["transform"][3]
		d = {}
		for z, (k, i) in enumerate(sorted(items)):  # paint order = the page's order
			m = pixel_matrix(i)
			d[pieces[i["xref"]]] = (mat([m[0], m[1], m[2], m[3], m[4] - ax, m[5] - ay]), z)
		raw[fname[bk]] = d
	print("frames:", {n: len(v) for n, v in sorted(raw.items())})

	# the shoulders (a point of the body = a point of the upper arm) ...
	shoulder, root = {}, {}
	for side in "lr":
		pairs = [(d["body"][0], d["arm_" + side][0]) for d in raw.values()]
		shoulder[side], root[side], rms = solve_pin(pairs)
		print("shoulder", side, shoulder[side].round(1), "root", root[side].round(1), "rms %.2f" % rms)
	# ... and the elbows (a point of the upper arm = a point of the forearm's socket); which forearm is on which arm: the one that fits best
	elbow = {"l": np.array([35.0, 84.0]), "r": np.array([210.0, 83.0])}
	socket = {}
	idle = raw["idle"]
	for fp, side in [("sword_short_a", "r"), ("sword_long_b", "l")]:
		socket[fp] = (np.linalg.inv(idle[fp][0]) @ idle["arm_" + side][0] @ np.append(elbow[side], 1))[:2]
	for fp in FORES:
		socket.setdefault(fp, socket["sword_short_a"] if "short" in fp else socket["sword_long_b"])

	def world(M, p):
		return (M @ np.append(p, 1))[:2]

	pairing = {}
	for it in range(10):
		for n, d in raw.items():
			fores = [p for p in d if p in FORES]
			best = None
			for perm in itertools.permutations("lr", len(fores)):
				cost = sum(np.linalg.norm(world(d[f][0], socket[f]) - world(d["arm_" + a][0], elbow[a])) for f, a in zip(fores, perm))
				if best is None or cost < best[0]:
					best = (cost, dict(zip(fores, perm)))
			pairing[n] = best[1]
		idx = {"l": 0, "r": 2}
		for i, f in enumerate(FORES):
			idx[f] = 4 + 2 * i
		rows_a, rhs = [], []
		for n, d in raw.items():
			for f, a in pairing[n].items():
				U, F = d["arm_" + a][0], d[f][0]
				A = np.zeros((2, 12))
				A[:, idx[a]:idx[a] + 2] = U[:2, :2]
				A[:, idx[f]:idx[f] + 2] = -F[:2, :2]
				rows_a.append(A)
				rhs.append(F[:2, 2] - U[:2, 2])
		A, y = np.vstack(rows_a), np.concatenate(rhs)
		sol = np.linalg.lstsq(A, y, rcond=None)[0]
		for k in idx:
			v = sol[idx[k]:idx[k] + 2]
			if k in "lr":
				elbow[k] = v
			else:
				socket[k] = v
	r = A @ sol - y
	print("elbows rms %.2f max %.1f" % (np.sqrt((r ** 2).mean()), np.abs(r).max()), {k: v.round(1) for k, v in elbow.items() if k in "lr"})
	assert len({(f, a) for p in pairing.values() for f, a in p.items()}) == 4

	frames = {}
	jumps = []
	for n, d in raw.items():
		fr = {"parts": [], "arms": {}}
		for piece in ["body", "back", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
			M, z = d[piece]
			fr["parts"].append((piece, [M[0, 0], M[1, 0], M[0, 1], M[1, 1], M[0, 2], M[1, 2]], z))
		for side in "lr":
			U, zu = d["arm_" + side]
			fore = next(f for f, a in pairing[n].items() if a == side)
			F, zf = d[fore]
			ang, sx, sy = decompose(U[:2, :2])
			rel = np.linalg.inv(U[:2, :2]) @ F[:2, :2]
			fang, fsx, fsy = decompose(rel)
			fr["arms"][side] = (ang, sx, sy, fore, fang, fsx, fsy, zu, zf)
		frames[n] = fr
	for seq in ["idle_a", "idle_b"] + ["in_%d" % i for i in range(9)] + ["ko_%d" % i for i in range(4)] + ["sha_%d" % i for i in range(13)]:
		assert seq in frames, seq
	for pre in ["in", "ko", "sha"]:
		k = 0
		while "%s_%d" % (pre, k + 1) in frames:
			for side in "lr":
				a, b = frames["%s_%d" % (pre, k)]["arms"][side], frames["%s_%d" % (pre, k + 1)]["arms"][side]
				for what, i in [("upper", 0), ("fore", 4)]:
					if what == "fore" and a[3] != b[3]:
						continue  # (another piece: they are not compared)
					dlt = (b[i] - a[i] + math.pi) % (2 * math.pi) - math.pi
					if abs(dlt) > 2.0:
						jumps.append("%s_%d->%d %s %s %.0f deg" % (pre, k, k + 1, side, what, math.degrees(dlt)))
			k += 1
	print("big turns (the shortest way is taken):", jumps)

	# ---- the assembled idle pose -----------------------------------------------------------------------------
	idle_k = next(k for k, n in fname.items() if n == "idle")
	place = [(i["xref"], pixel_matrix(i)) for k, i in groups[idle_k]]
	boxes = [i["bbox"] for k, i in groups[idle_k]]
	x0, y0 = int(min(b[0] for b in boxes)) - 10, int(min(b[1] for b in boxes)) - 10
	x1, y1 = int(max(b[2] for b in boxes)) + 10, int(max(b[3] for b in boxes)) + 10
	side_px = max(x1 - x0, y1 - y0)
	img = compose(place, ((x0 + x1) // 2 - side_px // 2, y1 - side_px, side_px, side_px), images)
	img.save(os.path.join(ACT2, "samurai.png"))

	# ---- the Retainer ------------------------------------------------------------------------------------------
	rname = {x: n[2:] for x, n in names.items() if n.startswith("R_")}
	rb_x = next(x for x, n in rname.items() if n == "body")
	rbodies = sorted([(k, i) for k, i in enumerate(infos) if i["xref"] == rb_x], key=lambda t: t[1]["bbox"][0])
	assert len(rbodies) == 6, len(rbodies)
	pose_names = ["bottle", "lower", "fan1", "fan2", "gong", "gong2"]
	rfr = {}
	rplace = {}
	# the pictures of a frame are consecutive in the page's order; a frame starts with his back arm (or the mallet arm of the gong poses)
	run = [(k, i) for k, i in enumerate(infos) if i["xref"] in rname and i["bbox"][1] > 4200 and rname[i["xref"]] != "yield"]
	runs = []
	for k, i in run:
		if rname[i["xref"]] in ("arm_back", "mallet_arm") or not runs:
			runs.append([])
		runs[-1].append((k, i))
	assert len(runs) == 6, [len(r) for r in runs]
	for n, mine in enumerate(runs):
		bk, bi = next((k, i) for k, i in mine if i["xref"] == rb_x)
		mine.sort(key=lambda t: t[0])
		ax = bi["transform"][4] + bi["transform"][0] / 2.0
		ay = bi["transform"][5] + bi["transform"][3]
		d = {}
		for z, (k, i) in enumerate(mine):
			m = pixel_matrix(i)
			d[rname[i["xref"]]] = (mat([m[0], m[1], m[2], m[3], m[4] - ax, m[5] - ay]), z)
		rfr[pose_names[n]] = d
		rplace[pose_names[n]] = (bi, mine)
		print("retainer", pose_names[n], sorted(d))
	arm_poses = ["bottle", "lower", "fan1", "fan2"]
	r_shoulder, r_root, rms = solve_pin([(rfr[p]["body"][0], rfr[p]["arm_front"][0]) for p in arm_poses])
	print("retainer shoulder", r_shoulder.round(1), "root", r_root.round(1), "rms %.2f" % rms)
	hands = {}
	for kid, poses in [("bottle", ["bottle", "lower"]), ("sliver", ["bottle", "lower"]), ("fan", ["fan1", "fan2"])]:
		pairs = [(rfr[p]["arm_front"][0], rfr[p][kid][0]) for p in poses]
		turn = abs(decompose(np.linalg.inv(pairs[0][0][:2, :2]) @ pairs[0][1][:2, :2])[0] - decompose(np.linalg.inv(pairs[1][0][:2, :2]) @ pairs[1][1][:2, :2])[0])
		if turn < 0.05:  # (it does not turn on the hand: carried as it is; any point of it will do for a pin, so the middle of its picture)
			hc = np.array(size_of[next(x for x, n in rname.items() if n == kid)], float) / 2.0
			hp = (np.linalg.inv(pairs[0][0]) @ pairs[0][1] @ np.append(hc, 1))[:2]
			rms = 0.0
		else:
			hp, hc, rms = solve_pin(pairs)
		hands[kid] = (hp, hc)
		print("retainer hand", kid, hp.round(1), hc.round(1), "rms %.2f" % rms)

	# finished pictures: idle (the bottle in his hand), gong, gong2, yield
	def baked(pose):
		bi, mine = rplace[pose]
		bx = (bi["bbox"][0] + bi["bbox"][2]) / 2
		ground = bi["bbox"][3]
		place = [(i["xref"], pixel_matrix(i)) for k, i in mine]
		return compose(place, (int(bx - BODY_X), int(ground + GROUND_PAD - CANVAS), CANVAS, CANVAS), images)

	baked("bottle").save(os.path.join(ACT2, "samurai_retainer.png"))
	baked("gong").save(os.path.join(ACT2, "samurai_retainer_gong.png"))
	baked("gong2").save(os.path.join(ACT2, "samurai_retainer_gong2.png"))
	yi = next(i for i in infos if rname.get(i["xref"]) == "yield")
	yx = (yi["bbox"][0] + yi["bbox"][2]) / 2
	compose([(yi["xref"], pixel_matrix(yi))], (int(yx - BODY_X), int(yi["bbox"][3] + GROUND_PAD - CANVAS), CANVAS, CANVAS), images).save(os.path.join(ACT2, "samurai_retainer_yield.png"))
	images[next(x for x, n in rname.items() if n == "bottle")].save(os.path.join(ACT2, "samurai_bottle.png"))
	for stale in ["samurai_retainer_bottle.png", "samurai_retainer_fan.png", "samurai_retainer_fan2.png"]:
		for ext in ["", ".import"]:
			f = os.path.join(ACT2, stale + ext)
			if os.path.exists(f):
				os.remove(f)

	# ---- the layout files -------------------------------------------------------------------------------------
	out = ["# Generated by tools/export_samurai_rig.py from Act2/samurai/animation.pdf: do not edit by hand.", "class_name SamuraiLayout", "extends RefCounted",
		"## Pixels of the page's pictures; origin = the middle of the frame's feet line. A part is [piece, matrix, z]: the matrix maps a pixel of the piece's own picture",
		"## (origin top left) to the frame. An arm is [upper angle, upper scale x, y, forearm piece, forearm angle (to the upper arm), scale x, y, upper z, forearm z]:",
		"## the upper arm turns about SHOULDER (a point of the body) = ROOT (a point of its picture), the forearm about ELBOW (a point of the upper arm's picture) = SOCKET.", ""]
	out.append("const SIZE := {")
	for x, n in pieces.items():
		out.append('\t"%s": Vector2(%d, %d),' % (n, images[x].width, images[x].height))
	out.append("}")
	out.append("const SHOULDER := {\"l\": %s, \"r\": %s}" % (vec(shoulder["l"]), vec(shoulder["r"])))
	out.append("const ROOT := {\"l\": %s, \"r\": %s}" % (vec(root["l"]), vec(root["r"])))
	out.append("const ELBOW := {\"l\": %s, \"r\": %s}" % (vec(elbow["l"]), vec(elbow["r"])))
	out.append("const SOCKET := {")
	for f in FORES:
		out.append('\t"%s": %s,' % (f, vec(socket[f])))
	out.append("}")
	out.append("const FRAMES := {")
	for n in sorted(frames):
		fr = frames[n]
		out.append('\t"%s": {' % n)
		out.append('\t\t"parts": [')
		for piece, m, z in fr["parts"]:
			out.append('\t\t\t["%s", %s, %d],' % (piece, tf(m), z))
		out.append("\t\t],")
		for side in "lr":
			a = fr["arms"][side]
			out.append('\t\t"%s": [%.5f, %.5f, %.5f, "%s", %.5f, %.5f, %.5f, %d, %d],' % (side, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]))
		out.append("\t},")
	out.append("}")
	with open(LAYOUT, "w", encoding="utf-8", newline="\n") as fh:
		fh.write("\n".join(out) + "\n")

	rl = ["# Generated by tools/export_samurai_rig.py from Act2/samurai/animation.pdf: do not edit by hand.", "class_name RetainerLayout", "extends RefCounted",
		"## The Retainer, in pixels of the page's pictures; origin = the middle of his body's foot line. His body stands still; his front arm turns about SHOULDER (a point of",
		"## the body) = ROOT (a point of the arm's picture) and carries the bottle / the sliver (his thumb) / the fan at HAND [point of the arm, point of the thing].",
		"## A pose is {static: [[piece, matrix, z]], arm: [angle, scale x, y, z], kids: {piece: [angle (to the arm), scale x, y, z]}}.", ""]
	rl.append("const SIZE := {")
	for x, n in rname.items():
		if n not in ("mallet_arm", "gong", "yield"):
			rl.append('\t"%s": Vector2(%d, %d),' % (n, images[x].width, images[x].height))
	rl.append("}")
	rl.append("const SHOULDER := %s" % vec(r_shoulder))
	rl.append("const ROOT := %s" % vec(r_root))
	rl.append("const HAND := {")
	for kid, (hp, hc) in hands.items():
		rl.append('\t"%s": [%s, %s],' % (kid, vec(hp), vec(hc)))
	rl.append("}")
	rl.append("const POSES := {")
	for p in arm_poses:
		d = rfr[p]
		ang, sx, sy = decompose(d["arm_front"][0][:2, :2])
		rl.append('\t"%s": {' % p)
		rl.append('\t\t"static": [')
		for piece in ["body", "arm_back"]:
			M, z = d[piece]
			rl.append('\t\t\t["%s", %s, %d],' % (piece, tf([M[0, 0], M[1, 0], M[0, 1], M[1, 1], M[0, 2], M[1, 2]]), z))
		rl.append("\t\t],")
		rl.append('\t\t"arm": [%.5f, %.5f, %.5f, %d],' % (ang, sx, sy, d["arm_front"][1]))
		rl.append('\t\t"kids": {')
		for kid in ["bottle", "sliver", "fan"]:
			if kid in d:
				rel = np.linalg.inv(d["arm_front"][0][:2, :2]) @ d[kid][0][:2, :2]
				ka, ksx, ksy = decompose(rel)
				rl.append('\t\t\t"%s": [%.5f, %.5f, %.5f, %d],' % (kid, ka, ksx, ksy, d[kid][1]))
		rl.append("\t\t},")
		rl.append("\t},")
	rl.append("}")
	with open(LAYOUT_R, "w", encoding="utf-8", newline="\n") as fh:
		fh.write("\n".join(rl) + "\n")
	print("wrote", LAYOUT, LAYOUT_R)


if __name__ == "__main__":
	main()
