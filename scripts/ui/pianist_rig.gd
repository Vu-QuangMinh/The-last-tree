class_name PianistRig
extends RefCounted
## The Pianist, put together from the pieces in Enemies/Act2/pianist/ (made by tools/gen_boss_art.py + tools/import_boss_art.py):
## the body (a tall thin bust, one sleeve empty), the piano with its keyboard slot, the keys, the music stand, the sign, and a
## two-bone arm and a two-bone leg. The hand rides the highest note sounding, the foot the lowest (PianistSong.hands_at), each
## limb a stretched piece turned about its brass pegs (two-bone IK). Everything is measured in `u` (Creature's `s`), `c` = the middle of the stage.
## Draw order: sign, body, piano, keys, stand, page, leg, arm.

const FILES := {"body": "pianist_body", "arm_upper": "pianist_arm_upper", "arm_lower": "pianist_arm_lower", "thigh": "pianist_thigh",
	"shin": "pianist_shin", "piano": "pianist_piano", "keys": "pianist_keys", "stand": "pianist_music_stand", "sign": "pianist_sign"}
## where the pegs are, in fractions of each piece's own picture (measured once on the pictures)
const SHOULDER := Vector2(0.88, 0.557)  # the body's socket for the playing arm (his right shoulder: the left of the picture holds the empty sleeve)
const ARM_UP := [Vector2(0.112, 0.49), Vector2(0.911, 0.51)]  # shoulder peg, elbow peg
const ARM_LOW := [Vector2(0.095, 0.5), Vector2(0.985, 0.47)]  # elbow peg, the tip of the middle finger
const LEG_UP := [Vector2(0.084, 0.498), Vector2(0.928, 0.501)]  # hip peg, knee peg
const LEG_LOW := [Vector2(0.126, 0.31), Vector2(0.93, 0.99)]  # knee peg, the sole of the shoe
const SLOT := Rect2(0.126, 0.078, 0.751, 0.23)  # the piano's keyboard slot (fractions of the piano picture)
const SIGN_BOARD := Rect2(0.08, 0.138, 0.837, 0.4)  # the sign's empty board
const STAND_PAPER := Rect2(0.21, 0.07, 0.58, 0.42)  # the music stand's sheet of paper
## the layout, in u
const PIANO_W := 2.2
const BODY_H := 1.95
const ARM_L := Vector2(0.72, 0.78)  # upper arm, forearm (peg to fingertip)
const ARM_T := Vector2(0.2, 0.17)  # their thickness
const LEG_L := Vector2(0.62, 0.62)
const LEG_T := Vector2(0.17, 0.17)

var tex := {}


static func load_rig() -> PianistRig:
	var r := PianistRig.new()
	for k in FILES:
		var path := Creature.enemy_path("pianist/%s.png" % FILES[k], 2)
		if path == "":
			if k == "stand":
				continue  # (the stand has a drawn stand to fall back on)
			return null
		r.tex[k] = load(path)
	return r


## Everything drawn on `ci` (the Creature). st: hand (0..1 along the keys), foot (0..1, low notes), press (0..1: a key is going down), page (-1 or 0..1: turning), left (0..1 of the piece still to play), t (seconds), dead.
func draw(ci: CanvasItem, c: Vector2, u: float, st: Dictionary, mod: Color) -> void:
	var piano: Texture2D = tex.piano
	var pw := PIANO_W * u
	var ph := pw * piano.get_height() / piano.get_width()
	var p0 := Vector2(c.x - pw * 0.5, c.y - 0.3 * u)  # the piano's top left corner
	var slot := Rect2(p0 + SLOT.position * Vector2(pw, ph), SLOT.size * Vector2(pw, ph))
	var bt: Texture2D = tex.body
	var bh := BODY_H * u
	var bw := bh * bt.get_width() / bt.get_height()
	var b0 := Vector2(c.x - bw * 0.5, c.y + 0.3 * u - bh)  # the body's top left
	var shoulder := b0 + SHOULDER * Vector2(bw, bh)
	var ground := p0.y + ph
	# the sign, to the right of the piano
	var sg: Texture2D = tex.sign
	var sh := 0.78 * u
	var sw := sh * sg.get_width() / sg.get_height()
	var s0 := Vector2(c.x + pw * 0.5 + 0.12 * u, ground - sh)
	_place(ci, sg, Rect2(s0, Vector2(sw, sh)), mod)
	var board := Rect2(s0 + SIGN_BOARD.position * Vector2(sw, sh), SIGN_BOARD.size * Vector2(sw, sh))
	var font := ThemeDB.fallback_font
	var px := int(maxf(9.0, board.size.y * 0.3))
	for k in 2:
		var txt: String = ["SILENCE,", "PLEASE"][k]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		ci.draw_string(font, Vector2(board.get_center().x - w / 2.0, board.position.y + board.size.y * (0.42 + 0.4 * k)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.3, 0.08, 0.06) * mod)
	_place(ci, bt, Rect2(b0, Vector2(bw, bh)), mod)
	_place(ci, piano, Rect2(p0, Vector2(pw, ph)), mod)
	_place(ci, tex.keys, slot.grow_individual(-slot.size.x * 0.01, -slot.size.y * 0.02, -slot.size.x * 0.01, 0.0), mod)
	# the keys going down under the hand and the foot
	var hand_x := slot.position.x + slot.size.x * (0.04 + 0.92 * float(st.hand))
	var foot_x := slot.position.x + slot.size.x * (0.04 + 0.42 * float(st.foot))
	if not st.dead and float(st.press) > 0.0:
		ci.draw_rect(Rect2(hand_x - slot.size.x * 0.012, slot.position.y + slot.size.y * 0.1, slot.size.x * 0.024, slot.size.y * 0.8), Color(0.0, 0.0, 0.0, 0.28 * float(st.press)))
		ci.draw_rect(Rect2(foot_x - slot.size.x * 0.012, slot.position.y + slot.size.y * 0.1, slot.size.x * 0.024, slot.size.y * 0.8), Color(0.0, 0.0, 0.0, 0.2 * float(st.press)))
	# the music stand, on the piano in front of his chest
	var stand := Rect2(Vector2(c.x - 0.2 * u, p0.y + 0.04 * u - 0.66 * u), Vector2(0.43 * u, 0.66 * u))
	var paper := Rect2(stand.position + STAND_PAPER.position * stand.size, STAND_PAPER.size * stand.size)
	if tex.has("stand"):
		_place(ci, tex.stand, stand, mod)
	else:
		ci.draw_rect(paper, Color(0.93, 0.9, 0.82) * mod)
		for k in 3:
			var y := paper.position.y + paper.size.y * (0.2 + 0.25 * k)
			ci.draw_line(Vector2(paper.position.x + u * 0.04, y), Vector2(paper.end.x - u * 0.04, y), Color(0.3, 0.3, 0.3), 1.0)
	var page := float(st.page)
	if page >= 0.0:
		# the page swings over from right to left (it narrows to an edge in the middle, then opens on the other side)
		var k := absf(cos(page * PI))
		var pwid := paper.size.x * 0.5 * k
		var px0 := paper.get_center().x if page < 0.5 else paper.get_center().x - pwid
		var rr := Rect2(px0, paper.position.y - u * 0.02 * (1.0 - k), pwid, paper.size.y)
		ci.draw_rect(rr, Color(1.0, 0.98, 0.92) * mod)
		ci.draw_rect(rr, Color(0.4, 0.35, 0.3) * mod, false, 1.0)
	else:
		# a thin bar on the stand: how much of the piece is left
		var bar := Rect2(paper.position + Vector2(paper.size.x * 0.08, paper.size.y * 0.78), Vector2(paper.size.x * 0.84, maxf(2.0, u * 0.035)))
		ci.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.25))
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - float(st.left)), bar.size.y)), Color(0.55, 0.08, 0.1))
	# the leg: out of his waist, the foot up on the low keys
	var hip := Vector2(c.x - 0.1 * u, p0.y - 0.1 * u)
	var foot := Vector2(foot_x, slot.position.y + slot.size.y * 0.55 + (u * 0.02 * float(st.press)))
	var knee := _elbow(hip, foot, LEG_L.x * u, LEG_L.y * u, 1.0)
	foot = hip + (foot - hip).limit_length((LEG_L.x + LEG_L.y) * u * 0.995)
	_bone(ci, tex.thigh, LEG_UP[0], LEG_UP[1], hip, knee, LEG_T.x * u, mod)
	_bone(ci, tex.shin, LEG_LOW[0], LEG_LOW[1], knee, foot, LEG_T.y * u, mod)
	# the arm: the hand on the keys, or on the page while he turns it
	var hand := Vector2(hand_x, slot.position.y + slot.size.y * 0.5 + (u * 0.03 * float(st.press)))
	if page >= 0.0:
		hand = Vector2(paper.get_center().x + paper.size.x * 0.5 * cos(page * PI), paper.position.y + paper.size.y * 0.4)
	hand = shoulder + (hand - shoulder).limit_length((ARM_L.x + ARM_L.y) * u * 0.995)
	var elbow := _elbow(shoulder, hand, ARM_L.x * u, ARM_L.y * u, -1.0)
	_bone(ci, tex.arm_upper, ARM_UP[0], ARM_UP[1], shoulder, elbow, ARM_T.x * u, mod)
	_bone(ci, tex.arm_lower, ARM_LOW[0], ARM_LOW[1], elbow, hand, ARM_T.y * u, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _place(ci: CanvasItem, t: Texture2D, r: Rect2, mod: Color) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ci.draw_texture_rect(t, r, false, mod)


## The middle joint of a two-bone limb from `a` to `t`: the bend goes the way `side` says.
static func _elbow(a: Vector2, t: Vector2, l1: float, l2: float, side: float) -> Vector2:
	var d := t - a
	var dist := clampf(d.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	return a + d.normalized().rotated(side * acos(cos_a)) * l1


## A piece laid on the line `from` -> `to`: its peg `pa` at `from`, its peg/tip `pb` at `to`, stretched along the bone and `thick` tall.
func _bone(ci: CanvasItem, t: Texture2D, pa: Vector2, pb: Vector2, from: Vector2, to: Vector2, thick: float, mod: Color) -> void:
	var size := Vector2(t.get_width(), t.get_height())
	var v := (pb - pa) * size
	var d := to - from
	var xf := Transform2D(d.angle() - v.angle(), from) * Transform2D.IDENTITY.scaled(Vector2(d.length() / v.length(), thick / size.y)) * Transform2D(0.0, -pa * size)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture(t, Vector2.ZERO, mod)
