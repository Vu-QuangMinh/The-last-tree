class_name PianistBackRig
extends RefCounted
## The Pianist seen from BEHIND, built from the user's Pianist.pdf and his own cuts in Enemies/Act2/pianist/back/. WHERE everything goes is read from back/pdf_layout.json, which
## tools/extract_pianist_pdf.py makes from the PDF itself (so after the user changes the PDF: run that tool, nothing here is edited by hand):
##  - rh_01..12.png: the whole seated figure (head, hat, torso, tails, stool, right arm) in 12 poses of the right hand, from the hand near the body (1) out to the far right (12). They were
##    registered on the stool, cleaned and cropped to one common box by tools/import_pianist_frames.py, so they lie exactly on each other: the right hand picks the frame by where the pitch of
##    the right hand's last note lies between the lowest and the highest note of the right hand in the piece (PianistSong.hand_at), and the frames are crossfaded while it moves;
##  - the LEFT leg = two pieces from page 2 of the PDF: leg.png (the thigh, turns about the red dot under the coat tails) and pdf_foot.png (shoe + shin, only moves sideways). Row 1 of the PDF = the foot DOWN on a key,
##    row 2 = RAISED (a little higher and tilted, not touching the keys): the foot goes to ANY x between the first and the last panel, the thigh turns so that its free end always meets the foot's knee (_draw_leg);
##  - the pieces of the IDLE position and of the sign sequence (the PDF's own: body, stool, upper arm, forearms): the Pianist waits in the idle position until the music starts, and points at the sign
##    with them (SEQ); leg.png is a hanging leg (two of them, behind the figure; the left one fades out while the foot is up).
## Layout in px of the piano's picture ("pp", 1849 wide); `u` scales it to the stage. NOTHING here moves by itself: the cluster stands still.
## Draw order, back to front: sign, piano, sheet, hanging legs, left leg, figure (the frames, or the pieces).

const FRAMES := 12
const FILES := {"pbody": "body", "pstool": "stool", "pupper": "pdf_upper", "pfore": "user_fore", "pforep": "pdf_point_fore", "leg": "leg", "piano": "piano", "sign": "sign",
	"sheet0": "sheet_1", "sheet1": "sheet_2", "sheet2": "sheet_3", "sheet3": "sheet_4",
	"foot": "pdf_foot", "idleleg": "idle_leg"}
const HAND_LIFT_PX := 10.0  # (the user, 2026-11-10: the whole figure, body and hands, 10 px of its own pictures higher than the PDF puts it, so the hands meet the keys)
const PIVOT_SHIFT := Vector2(36.0, 0.0)  # (pp: the thigh's pivot (red dot) moved right so that it hides behind the body instead of showing at its left edge)
const LAYOUT := "pianist/back/pdf_layout.json"
## The sign sequence (the user's Pianist.pdf, page 1): idle -> raise the arm -> the hand sprite changes to the pointing one -> touches the sign (a knock on the wood) -> the hand comes out a little ->
## touches again (knock) -> out -> touches a third time (knock) -> lowers the arm -> the sprite changes back -> idle. [time s, pose, swap]: swap = the forearm sprite changes at that time (the arm
## holds the pose before it).
const SEQ := [[0.0, "idle", false], [0.30, "idle", false], [0.85, "raise", false], [1.10, "point", true], [1.60, "touch", false], [1.90, "out", false], [2.20, "touch", false],
	[2.50, "out", false], [2.80, "touch", false], [3.30, "point", false], [3.55, "raise", true], [4.05, "idle", false], [4.25, "idle", false]]
const KNOCKS := [1.60, 2.20, 2.80]  # (when the finger touches the wood: the sound)
const SEQ_FIGURE := 0.25  # (the figure has come to the picture the sequence starts from: it changes into the pieces from here)
const SEQ_TIME := 4.25

var tex := {}
var frames: Array = []
var poses: Dictionary = {}  # idle / raise / point / touch / out: {up, fo, pt, body, stool, leg, sign, sheet} (matrices in pp)
var foot: Dictionary = {}  # the left leg's geometry from page 2 of the PDF (see tools/extract_pianist_pdf.py)
var frame_s := 2.075  # the figure's frames: pp per px of the sprite, the hat's centre x in the sprite, where that hat stands (pp), and where the top of the sprite is
var hat_x := 155.0
var fig_cx := 913.0
var fig_top := 151.0


static func load_rig() -> PianistBackRig:
	var r := PianistBackRig.new()
	for k in FILES:
		var path := Creature.enemy_path("%s.png" % ("pianist/back/" + FILES[k]), 2)
		if path == "":
			return null
		r.tex[k] = load(path)
	for k in FRAMES:
		var fp := Creature.enemy_path("pianist/back/rh_%02d.png" % (k + 1), 2)
		if fp == "":
			return null
		r.frames.append(load(fp))
	var jp := UiSkin.theme_dir() + "Enemies/Act2/" + LAYOUT
	if not FileAccess.file_exists(jp):
		return null
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
	r.poses = lay.poses
	r.foot = lay.foot
	r.frame_s = float(lay.fig.scale)
	r.hat_x = float(lay.fig.hat_x)
	r.fig_cx = float(lay.fig.cx)
	r.fig_top = float(lay.fig.top)
	return r


## st: rh (0..11, a float: the frame of the right hand), foot_x (0..1: the left foot along the keys, 0 = the lowest note of the left hand), foot_up (0..1: 1 = the foot is raised, 0 = it is down on the key), foot_on (0..1),
## page (-1, or 0..1 while he turns it), sheet (0..3, which music), slam (0..1: the last chord), left (0..1 of the piece played), pt (seconds into the sign sequence, -1 = none),
## idle (0..1: how much of the idle position of the PDF is shown instead of the frames: 1 until the music starts).
func draw(ci: CanvasItem, c: Vector2, u: float, st: Dictionary, mod: Color) -> void:
	var k := u / 900.0
	var base := Transform2D(0.0, Vector2(k, k), 0.0, Vector2(c.x - 924.0 * k, c.y - 1.62 * u))
	var slam := float(st.slam)
	var idle: Dictionary = poses.idle
	_piece(ci, base, tex.sign, idle.sign, Vector2.ZERO, mod)
	_piece(ci, base, tex.piano, [1849.0, 0.0, 0.0, 1841.0, 0.0, 0.0], Vector2.ZERO, mod)
	# the sheet music on the desk (the PDF's place: its width and its bottom edge; the four sheets differ in height)
	var sh: Texture2D = tex["sheet%d" % clampi(int(st.sheet), 0, 3)]
	var sm: Array = idle.sheet
	var sw := float(sm[0])
	var sheet := Rect2(Vector2(float(sm[4]), float(sm[5]) + float(sm[3]) - sw * sh.get_height() / sh.get_width()), Vector2(sw, sw * sh.get_height() / sh.get_width()))
	_place(ci, base, sh, sheet.position, sw / sh.get_width(), mod)
	var page := float(st.page)
	if page >= 0.0:
		# the right-hand page swings over to the left: it narrows to an edge in the middle, then opens on the other side
		var half := sheet.size.x * 0.46
		var kk := absf(cos(page * PI))
		var pw := half * kk
		var px0 := sheet.get_center().x if page < 0.5 else sheet.get_center().x - pw
		ci.draw_set_transform_matrix(base)
		var leaf := Rect2(px0, sheet.position.y + sheet.size.y * 0.06 - 24.0 * (1.0 - kk), pw, sheet.size.y * 0.72)
		ci.draw_rect(leaf, Color(0.96, 0.92, 0.8) * mod)
		ci.draw_rect(leaf, Color(0.35, 0.3, 0.25) * mod, false, 3.0)
	else:
		# a thin bar along the bottom of the music: how much of the piece is left
		ci.draw_set_transform_matrix(base)
		var bar := Rect2(sheet.position + Vector2(sheet.size.x * 0.1, sheet.size.y * 0.86), Vector2(sheet.size.x * 0.8, 14.0))
		ci.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.3))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - float(st.left)), bar.size.y)), Color(0.55, 0.08, 0.1))
	# the two legs hang straight down from under the coat tails (the left one while he does not play with it): the PDF's leg, and the same mirrored about the body
	var foot_on := float(st.foot_on)
	var dive := Vector2(0.0, 46.0 * slam)  # (the last chord: the whole figure dives forward)
	# the IDLE leg (the user drew it into the PDF's idle position, page 1: shoe under the coat tails, behind the body) shows whenever he is not playing: before Engage, the sign sequence, the page turn;
	# while he plays, the leg is the one on the keys (a hard switch, never a fade)
	if foot_on < 0.5:
		_piece(ci, base, tex.idleleg, idle.leg, dive + Vector2(0.0, -HAND_LIFT_PX * frame_s), mod)
	# the left leg, on the keys: the foot slides sideways (raised while it travels), goes down on the key as the note sounds, and the thigh turns to follow it
	if foot_on >= 0.5:
		_draw_leg(ci, base, float(st.foot_x), float(st.foot_up), dive, mod)
	# what is shown of the figure: ONE picture, never two at once (no fades, no cross-fades: they made the figure ghostly): the idle position of the PDF until the music starts, the sign
	# sequence while he points at the sign, otherwise the frame of the right hand nearest to `rh` (the frames lie exactly on each other, so the change between them does not jump)
	var pt := float(st.pt)
	var fdive := dive + Vector2(0.0, -HAND_LIFT_PX * frame_s)  # (the figure only; the legs keep `dive`)
	var pos := Vector2(fig_cx - hat_x * frame_s, fig_top) + fdive
	if pt >= 0.0 and pt >= SEQ_FIGURE and pt < SEQ_TIME - 0.03:
		_draw_sequence(ci, base, pt, fdive, mod)
	elif float(st.idle) > 0.5:
		_composite(ci, base, idle.up, idle.fo, false, fdive, mod)
	else:
		_place(ci, base, frames[clampi(roundi(float(st.rh)), 0, FRAMES - 1)], pos, frame_s, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The left leg: the user's rule (2026-11-10): the LEG turns only about its pivot (the red dot, the hip behind the body) and the FOOT hangs on the leg's joint: the leg's blue point and the foot's
## blue point (its knee) are always the same point, so nothing stretches and nothing comes apart. x (0..1 between the first and the last place of the PDF's row 1) and `up` (0 down on the key ...
## 1 raised: lifted, and the foot tilted about the knee) say where the knee WANTS to be; the leg is turned to point at that place, and the joint (which can only lie on its circle about the pivot) is where
## the knee really goes, the foot follows it.
func _draw_leg(ci: CanvasItem, base: Transform2D, x: float, up: float, dive: Vector2, mod: Color) -> void:
	var f := foot
	var lm: Array = f.leg_m
	var lT := Transform2D(Vector2(lm[0], lm[1]), Vector2(lm[2], lm[3]), Vector2(lm[4], lm[5]))
	var pivot := Vector2(float(f.pivot[0]), float(f.pivot[1])) + PIVOT_SHIFT  # (the whole leg is moved right a little so that the pivot hides behind the body)
	lT = Transform2D(0.0, PIVOT_SHIFT) * lT
	var uvj: Array = f.uv_joint
	var joint0: Vector2 = lT * Vector2(uvj[0], uvj[1])
	var want := Vector2(lerpf(float(f.knee_x0), float(f.knee_x1), clampf(x, 0.0, 1.0)) + PIVOT_SHIFT.x, float(f.knee_y) - float(f.lift) * up)
	var rot := (want - pivot).angle() - (joint0 - pivot).angle()
	var leg_t := Transform2D(0.0, pivot) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -pivot) * lT
	var joint: Vector2 = leg_t * Vector2(uvj[0], uvj[1])
	var fm: Array = f.foot_m
	var fT := Transform2D(Vector2(fm[0], fm[1]), Vector2(fm[2], fm[3]), Vector2(fm[4], fm[5]))
	var uvk: Array = f.uv_knee
	var knee0: Vector2 = fT * Vector2(uvk[0], uvk[1])
	var tilt := Transform2D(deg_to_rad(float(f.tilt)) * up, Vector2.ZERO)
	var foot_t: Transform2D = Transform2D(0.0, joint) * tilt * Transform2D(0.0, -joint) * Transform2D(0.0, joint - knee0) * fT
	_piece(ci, base, tex.leg, _arr(leg_t), dive, mod)
	_piece(ci, base, tex.foot, _arr(foot_t), dive, mod)


static func _arr(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]


func _place(ci: CanvasItem, base: Transform2D, t: Texture2D, pos: Vector2, s: float, mod: Color) -> void:
	ci.draw_set_transform_matrix(base)
	ci.draw_texture_rect(t, Rect2(pos, t.get_size() * s), false, mod)


## The pieces of the PDF at time `pt` of the sequence.
func _draw_sequence(ci: CanvasItem, base: Transform2D, pt: float, dive: Vector2, mod: Color) -> void:
	var a: Array = SEQ[0]
	var b: Array = SEQ[SEQ.size() - 1]
	for i in SEQ.size() - 1:
		if pt >= float(SEQ[i][0]) and pt <= float(SEQ[i + 1][0]):
			a = SEQ[i]
			b = SEQ[i + 1]
			break
	var ka: Dictionary = poses[a[1]]
	var kb: Dictionary = poses[b[1]]
	var span := maxf(0.001, float(b[0]) - float(a[0]))
	var k := smoothstep(0.0, 1.0, clampf((pt - float(a[0])) / span, 0.0, 1.0))
	var point_sprite: bool = bool(ka.pt)
	var up: Array = _lerp6(ka.up, kb.up, k)
	var fo: Array = _lerp6(ka.fo, kb.fo, k)
	if bool(b[2]):  # (the sprite changes at the next key: until then the arm holds)
		up = ka.up
		fo = ka.fo
		if pt >= float(b[0]):
			point_sprite = bool(kb.pt)
	_composite(ci, base, up, fo, point_sprite, dive, mod)


## The forearm, the stool, the upper arm, the body: the arm is BEHIND the body.
func _composite(ci: CanvasItem, base: Transform2D, up: Array, fo: Array, point_sprite: bool, dive: Vector2, mod: Color) -> void:
	_piece(ci, base, tex.pforep if point_sprite else tex.pfore, fo, dive, mod)
	_piece(ci, base, tex.pstool, poses.idle.stool, dive, mod)
	_piece(ci, base, tex.pupper, up, dive, mod)
	_piece(ci, base, tex.pbody, poses.idle.body, dive, mod)


static func _lerp6(a: Array, b: Array, k: float) -> Array:
	var out: Array = []
	for i in 6:
		out.append(lerpf(float(a[i]), float(b[i]), k))
	return out


## A piece laid where the PDF puts it: m = [a, b, c, d, e, f] sends the unit square of the picture to pp.
func _piece(ci: CanvasItem, base: Transform2D, t: Texture2D, m: Array, dive: Vector2, mod: Color) -> void:
	var w := float(t.get_width())
	var h := float(t.get_height())
	ci.draw_set_transform_matrix(base * Transform2D(Vector2(float(m[0]) / w, float(m[1]) / w), Vector2(float(m[2]) / h, float(m[3]) / h), Vector2(float(m[4]), float(m[5])) + dive))
	ci.draw_texture(t, Vector2.ZERO, mod)
