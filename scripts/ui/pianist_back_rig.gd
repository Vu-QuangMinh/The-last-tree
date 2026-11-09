class_name PianistBackRig
extends RefCounted
## The Pianist seen from BEHIND, built from the user's Pianist.pdf and his own cuts in Enemies/Act2/pianist/back/. WHERE everything goes is read from back/pdf_layout.json, which
## tools/extract_pianist_pdf.py makes from the PDF itself (so after the user changes the PDF: run that tool, nothing here is edited by hand):
##  - rh_01..12.png: the whole seated figure (head, hat, torso, tails, stool, right arm) in 12 poses of the right hand, from the hand near the body (1) out to the far right (12). They were
##    registered on the stool, cleaned and cropped to one common box by tools/import_pianist_frames.py, so they lie exactly on each other: the right hand picks the frame by where the pitch of
##    the right hand's last note lies between the lowest and the highest note of the right hand in the piece (PianistSong.hand_at), and the frames are crossfaded while it moves;
##  - user_leg_1..5.png: the raised LEFT leg in 5 poses, picture 1 for the lowest note of the left hand (shoe farthest left on the keys) ... 5 for the highest (nearest the middle);
##  - the pieces of the IDLE position and of the sign sequence (the PDF's own: body, stool, upper arm, forearms): the Pianist waits in the idle position until the music starts, and points at the sign
##    with them (SEQ); leg.png is a hanging leg (two of them, behind the figure; the left one fades out while the foot is up).
## Layout in px of the piano's picture ("pp", 1849 wide); `u` scales it to the stage. NOTHING here moves by itself: the cluster stands still.
## Draw order, back to front: sign, piano, sheet, hanging legs, left leg, figure (the frames, or the pieces).

const FRAMES := 12
const FILES := {"pbody": "body", "pstool": "stool", "pupper": "pdf_upper", "pfore": "user_fore", "pforep": "pdf_point_fore", "leg": "leg", "piano": "piano", "sign": "sign",
	"sheet0": "sheet_1", "sheet1": "sheet_2", "sheet2": "sheet_3", "sheet3": "sheet_4",
	"foot1": "user_leg_1", "foot2": "user_leg_2", "foot3": "user_leg_3", "foot4": "user_leg_4", "foot5": "user_leg_5"}
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
var legs: Array = []  # the five matrices of the raised left leg
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
	r.legs = lay.legs
	r.frame_s = float(lay.fig.scale)
	r.hat_x = float(lay.fig.hat_x)
	r.fig_cx = float(lay.fig.cx)
	r.fig_top = float(lay.fig.top)
	return r


## st: rh (0..11, a float: the frame of the right hand; between two frames they are crossfaded), foot_frame (0..4), foot_on (0..1), tap_f (0..1: a low note was just struck),
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
	var lm: Array = idle.leg
	_piece(ci, base, tex.leg, lm, dive, mod)
	if foot_on < 0.5:  # (a hard switch, never a fade: a half-transparent wooden leg shows the piano through it)
		var lm2: Array = [-float(lm[0]), float(lm[1]), -float(lm[2]), float(lm[3]), 2.0 * fig_cx - float(lm[4]), float(lm[5])]
		_piece(ci, base, tex.leg, lm2, dive, mod)
	# the left leg, up on the keys: the picture of the pitch of the left hand's last note, where the PDF puts it, kicking a little as each note is struck
	if foot_on >= 0.5:
		var fi := clampi(int(st.foot_frame), 0, legs.size() - 1)
		_piece(ci, base, tex["foot%d" % (fi + 1)], legs[fi], dive + Vector2(0.0, -10.0 * float(st.tap_f)), mod)
	# what is shown of the figure: ONE picture, never two at once (no fades, no cross-fades: they made the figure ghostly): the idle position of the PDF until the music starts, the sign
	# sequence while he points at the sign, otherwise the frame of the right hand nearest to `rh` (the frames lie exactly on each other, so the change between them does not jump)
	var pt := float(st.pt)
	var pos := Vector2(fig_cx - hat_x * frame_s, fig_top) + dive
	if pt >= 0.0 and pt >= SEQ_FIGURE and pt < SEQ_TIME - 0.03:
		_draw_sequence(ci, base, pt, dive, mod)
	elif float(st.idle) > 0.5:
		_composite(ci, base, idle.up, idle.fo, false, dive, mod)
	else:
		_place(ci, base, frames[clampi(roundi(float(st.rh)), 0, FRAMES - 1)], pos, frame_s, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


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
