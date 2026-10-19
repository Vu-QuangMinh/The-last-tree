class_name Creature
extends Control
## Procedural enemy portrait: body shape picked from the enemy id, tinted by its HP elements.

var enemy_id := ""
var tint := Color(0.6, 0.6, 0.6)
var accent := Color(1, 1, 1)
var big := 1.0
var flash := 0.0
var bob := 0.0
## Getting hit: it jolts (shake, decaying), blinks white a few times, and pulls a pained face for a moment.
var hurt := 0.0  # seconds of the pained face left
var _shake := 0.0  # pixels of jolt, decaying
var _blink := 0.0  # seconds of white blinking left
const HURT_TIME := 1.75  # long enough for the player to see the reaction
var shape := 0
var crown := false
var spikes := false
var dead := false
var _enemy: EnemyState = null  # for drawn art: how much Essence it has left picks the face
var _max_hp := 1  # Essence it started with (or the most it has had since)
var _yin_rot := 0.0  # the Yin Yang Beast's symbol: turned upside down (PI) when it is black
var _yin_target := 0.0
var _yin_last := ""
var _orbit_t := 0.0
var _orbs: Array = []  # the Invoker's words so far: their Essence orbit him for the rest of the fight
var _art_tip := 0.0  # the tilt the picture was last drawn with, and how far the jolt of a hit moved it sideways (for the rope mode's rivets)
var _art_shake_x := 0.0
var _floaters: Array = []  # [texture, centre fraction, phase] of the loose pieces hovering by the puppet (FLOATERS)
var _art := {}  # face name -> Texture2D, for enemies with drawn art (empty: drawn procedurally)

## Enemies with drawn art (New theme): one picture per face (angry: half its Essence or more; normal: low, under half; hurt: just hit).
## They live in New/Enemies/Act<n>/ (the file name has a %s for the face).
const ART := {"ashling": "ashling_%s.webp", "triplet_fire": "ashling_%s.webp"}
const ART_FACES := ["angry", "normal", "hurt"]
## Drawn art with two forms (the Yin Yang Beast and its Cubs): form 1 in its starting colour, form 2 once it has
## flipped (a black Cub is form 2 from the start). Each form has the three faces: path % [face, form].
const ART_FORMS := {"yin_yang_beast": "res://assets/enemies/yin_yang_%s_%d.webp", "yin_yang_clone": "res://assets/enemies/yin_yang_%s_%d.webp"}

## Puppet Stage: every enemy that has a cut-out in Puppet/Enemies/Act1..3/ (named after its id, or the PUPPET_FILES entry) is drawn from that
## one picture instead of its procedural body; it rocks on its base instead of bobbing, and tips back when hit.
const ENEMY_ACTS := [1, 2, 3]
const PUPPET_FILES := {"triplet_fire": "triplet_fire", "triplet_water": "triplet_water", "triplet_air": "triplet_air",
	"forge_spirit_b": "forge_spirit"}  # (the Wizard's second Forge Spirit: the same puppet)
## Loose pieces that hover next to a puppet instead of being painted on it: [file in Enemies/Act<n>/, centre as a fraction of the picture's square, phase].
## The Invoker's three orbs float above his open palm (cut off his hand by tools/import_act1_fix.py), each bobbing on its own beat.
const FLOATERS := {"invoker": [["invoker/orb_fire", Vector2(0.7274, 0.4508), 0.0], ["invoker/orb_water", Vector2(0.7640, 0.3995), 2.1], ["invoker/orb_wind", Vector2(0.7953, 0.4555), 4.2]]}

const SHAPES := {
	# act 1 (the Verdant Circle)
	"iceling": 1, "zephling": 1, "triplet_fire": 1, "triplet_water": 1, "triplet_air": 1, "purple_slime": 0, "green_slime": 0, "yellow_slime": 0, "giant_slime": 0,
	"bramble_back": 4, "winged_tortoise": 3, "yeti": 4, "rolling_bear": 4, "enraged_bear": 4, "mirror_fairy": 2, "tomato_knight": 2, "greenseer": 5,
	"puddle_slime": 0, "splitter_ooze": 0, "tide_colossus": 0, "blightmother": 0, "last_gasp_spore": 0,
	"gale_sprite": 1, "mirror_wisp": 1, "storm_imp": 1, "hush_moth": 1, "leech_bat": 1, "echo_wraith": 1, "storm_rider": 1,
	"stone_knight": 2, "warded_golem": 2, "lockwarden": 2, "woodcutter": 2, "invoker": 2, "forge_spirit": 1, "yin_yang_beast": 4, "yin_yang_clone": 4, "inverter": 2, "mimic_chest": 3,
	"cinder_hound": 4, "blinding_beetle": 4, "bramble_matron": 5, "mirror_knight": 2, "void_archon": 1, "pickpocket_imp": 4, "overgrowth_vine": 5, "shrine_maiden": 5,
	"tidecaller": 5, "hexer": 5, "toll_keeper": 5, "frost_hex": 5, "ashling": 1, "last_winter": 1,
}


const THICKNESS := Color(0.2, 0.11, 0.05)  # (Puppet Stage: the colour of a plank's edge)
var _puppet := false  # Puppet Stage cut-out in use
## A Handyman hand in the Puppet Stage is not a picture but a two-bone wooden arm (HandymanRig.ARMS): it turns a little about its shoulder and
## its elbow all the time, swings hard when it attacks, and goes limp when it is knocked out. Its shoulder hangs on the Handyman's body (HandymanStage).
var _rig := {}  # the arm's entry of HandymanRig.ARMS ({} for everything else)
var _rig_tex: Array = []  # [upper, lower]
var swing := 0.0  # the attack, set by the fight screen: -0.4 wound up ... 1 struck
## A hand that reaches for something on the screen (the Tweezer Hand stealing Essence): `poke` 0 = hanging as usual ... 1 = the tip of its tool is on
## `poke_target` (a screen point), the sticks stretched to get there (see _poke_pose). Only the arms in POKE_TIP can do it.
var poke := 0.0
var poke_target := Vector2.ZERO
var _arm_tip := Vector2.ZERO  # where the tip of the tool was drawn last, in this Control's own coordinates
## The tip of the tool of an arm, in px of the arm's lower piece (the Tweezer: where the two prongs close).
const POKE_TIP := {"hand_tweezer": Vector2(432.5, 25.5)}
var intro := 0.0  # 1 -> 0: the arm reaches out from the body when it first appears
var _fold_t := 0.0  # 0 -> 1 while the hand is knocked out (it folds away behind the Handyman's back), 1 -> 0 when it comes back
var _gear_t := 0.0  # the clock of the arm's jammed machinery (a knocked-out arm)
var _drive := 1.0  # 0..1: how much the broken gears pull right now (0 = stuck, it only trembles)
var _rig_phase := 0.0


## The picture of an enemy in the chosen theme's Enemies folder: its own act's folder first, then the others (null when there is none).
static func enemy_path(file: String, act := 1) -> String:
	var order: Array = [act] + ENEMY_ACTS.filter(func(a): return a != act)
	for a in order:
		var path: String = UiSkin.theme_dir() + "Enemies/Act%d/%s" % [a, file]
		if ResourceLoader.exists(path):
			return path
	return ""


static func _puppet_tex(file: String, act := 1) -> Texture2D:
	var path := enemy_path(file + ".png", act)
	return load(path) as Texture2D if path != "" else null


func setup(e: EnemyState) -> void:
	enemy_id = e.id
	_enemy = e
	_max_hp = maxi(1, maxi(e.size(), str(e.def.get("hp", "")).length()))
	_art.clear()
	if ART_FORMS.has(e.id):
		for form in [1, 2]:
			for face in ART_FACES:
				var fpath: String = ART_FORMS[e.id] % [face, form]
				if ResourceLoader.exists(fpath):
					_art["%s_%d" % [face, form]] = load(fpath)
	elif ART.has(e.id):
		for face in ART_FACES:
			var path := enemy_path(ART[e.id] % face, int(e.def.get("act", 1)))
			if path != "":
				_art[face] = load(path)
	_puppet = false
	if UiSkin.is_puppet():
		var file: String = PUPPET_FILES.get(e.id, e.id)
		if e.id in ["yin_yang_clone", "yin_yang_beast"]:  # (one picture per colour; _draw_art picks by its current colour)
			for c in ["white", "black"]:
				var tc := _puppet_tex(e.id + "_" + c, int(e.def.get("act", 1)))
				if tc != null:
					_art["yin_" + c] = tc
		var t := _puppet_tex(file, int(e.def.get("act", 1)))
		if t != null:
			_art = {"angry": t, "normal": t, "hurt": t}
		if e.id == "anxious_armadillo":
			_sad_tex = _puppet_tex("anxious_armadillo_sad", 2)
		if e.id == "handyman":  # (his two faces: the smiling body above, and the crying one when a hand of his takes damage)
			_sad_tex = _puppet_tex("handyman_sad", 1)
			add_to_group("handyman_body")
		_puppet = not _art.is_empty()
		_floaters = []
		if _puppet and FLOATERS.has(e.id):
			for f in FLOATERS[e.id]:
				var ft := _puppet_tex(f[0], int(e.def.get("act", 1)))
				if ft != null:
					_floaters.append([ft, f[1], f[2]])
		_rig = {}
		_rig_tex = []
		if HandymanRig.ARMS.has(e.id):
			var arm: Dictionary = HandymanRig.ARMS[e.id]
			var up := enemy_path(arm.upper, 1)
			var lo := enemy_path(arm.lower, 1)
			if up != "" and lo != "":
				_rig = arm
				_rig_tex = [load(up), load(lo)]
				_rig_phase = float(hash(e.id) % 628) / 100.0
	shape = SHAPES.get(e.id, hash(e.id) % 6)
	var counts := {"F": 0, "W": 0, "A": 0}
	for c in e.def.hp:
		counts[c] += 1
	var col := Color(0, 0, 0)
	var total := 0.0
	for k in counts:
		col += Elements.COLORS[k] * counts[k]
		total += counts[k]
	tint = (col / total).darkened(0.25)
	if e.def.has("tint"):
		tint = e.def.tint  # (a look of its own: the Enraged Rolling Bear's red fur)
	tint.a = 1.0
	accent = Elements.COLORS[e.def.hp[0]]
	big = 1.2 if e.is_boss else (1.1 if e.is_elite or e.id == "giant_slime" else 1.0)
	big = e.def.get("size", big)
	crown = e.is_boss and not e.has_passive("hand")
	spikes = e.is_elite
	bob = randf() * TAU
	# hovering the portrait shows the enemy's moves (clicks still reach whatever holds it)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = EnemyInfo.moves_tooltip(e.id, e.dmg_bonus)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
	return Keywords.make_tooltip(for_text)


## Hit for `strength` (1 = a full hit, less for a single Essence knocked off).
## The Handyman's face cries for a moment (one of his hands was hurt).
func cry(sec: float) -> void:
	_sad_t = maxf(_sad_t, sec)


func hit(strength := 1.0) -> void:
	if not _rig.is_empty() and is_inside_tree():  # (a hand of the Handyman took damage: his body cries)
		get_tree().call_group("handyman_body", "cry", 1.4)
	hurt = HURT_TIME
	_shake = maxf(_shake, 7.0 * strength + 3.0)
	_blink = maxf(_blink, 0.18 + 0.22 * strength)


func _process(d: float) -> void:
	if _enemy != null and _orbs.size() < _enemy.stripped.size():
		# he said a word: its Essence appears and joins the orbit (it stays)
		var orb := ElementIcon.make(_enemy.stripped[_orbs.size()], 34)
		orb.size = Vector2(34, 34)
		orb.pivot_offset = orb.size / 2.0
		orb.highlight = true
		orb.scale = Vector2.ZERO
		add_child(orb)
		orb.create_tween().tween_property(orb, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_orbs.append(orb)
	if not _orbs.is_empty():
		_orbit_t += d
		var c := Vector2(size.x / 2.0, size.y * 0.5)
		var s := minf(size.x, size.y) * 0.34 * big
		for k in _orbs.size():
			# each on its own ring, tilted 60 degrees from the last (the atom picture), going round fast
			var a := _orbit_t * 3.4 + TAU * k / 3.0
			var tilt := PI * k / 3.0
			var p := Vector2(cos(a) * s * 1.45, sin(a) * s * 0.42).rotated(tilt)
			var orb: ElementIcon = _orbs[k]
			orb.position = c + p - orb.size / 2.0
			orb.show_behind_parent = sin(a) < 0  # (behind him on the far half of its ring)
			orb.z_index = 2 if sin(a) >= 0 else 0  # (the near half: in front of his spell cards too)
		queue_redraw()
	if _enemy != null and _enemy.yin != "":
		if _yin_last == "":
			_yin_rot = 0.0 if _enemy.yin == "white" else PI
			_yin_target = _yin_rot
		elif _enemy.yin != _yin_last:
			_yin_target += PI  # it inverted: the symbol spins half a turn
		_yin_last = _enemy.yin
		_yin_rot = move_toward(_yin_rot, _yin_target, d * TAU)
	bob += d * 2.0
	_spider_tick(d)
	if not _rig.is_empty():
		var folded := _enemy != null and _enemy.knocked
		_gear_t += d
		# knocked out: the arm creeps away behind the Handyman, but the gears inside are broken: it moves a little, jams, trembles, moves again
		_drive = clampf(sin(_gear_t * 2.1) + 0.6 * sin(_gear_t * 3.4 + 1.3) + 0.25, 0.0, 1.0)
		if folded:
			_fold_t = move_toward(_fold_t, 1.0, d * 0.5 * _drive)
		else:
			_fold_t = move_toward(_fold_t, 0.0, d * 1.8)  # (it reaches out again, smoothly)
	flash = maxf(0.0, flash - d * 3.0)
	hurt = maxf(0.0, hurt - d)
	_sad_t = maxf(0.0, _sad_t - d)
	_shake = maxf(0.0, _shake - d * 30.0)
	_blink = maxf(0.0, _blink - d)
	queue_redraw()


func _draw() -> void:
	_draw_rings()  # (the Invoker's rings: drawn first, so he stands in front of them)
	var c := Vector2(size.x / 2.0, size.y * 0.58 + sin(bob) * 4.0)
	if _enemy != null and _enemy.yin != "":
		tint = Color(0.92, 0.91, 0.88) if _enemy.yin == "white" else Color(0.13, 0.13, 0.15)  # black and white only
		accent = Color(0.5, 0.5, 0.5)
	if _shake > 0.0:  # the jolt of a hit
		c += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	var s := minf(size.x, size.y) * 0.34 * big
	# white blinks while hit: on and off a few times (and the older soft flash)
	var blink_on := _blink > 0.0 and fmod(_blink, 0.12) > 0.05
	var body := tint.lerp(Color.WHITE, maxf(flash, 0.85 if blink_on else 0.0))
	if dead:
		body = Color(0.2, 0.2, 0.2, 0.4)
	# shadow (the New theme stands it on a painted stump instead)
	if UiSkin.tex("enemy_stand") == null and not UiSkin.is_puppet():
		draw_set_transform(Vector2(c.x, size.y * 0.93), 0, Vector2(1, 0.25))
		draw_circle(Vector2.ZERO, s * 0.9, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
	if not _rig.is_empty():
		_draw_arm(blink_on)
		return
	if not _art.is_empty():
		_draw_art(blink_on)
		if not ART_FORMS.has(enemy_id):
			_draw_yinyang(c, s)  # (two-form art paints its own yin-yang)
		return
	if enemy_id == "veiled_eyes":
		_draw_veiled(c, s, body, blink_on)
		return
	if enemy_id.begins_with("spiderling"):
		_draw_spiderling(c, s * 0.75, body)
		return
	if enemy_id == "spider_cocoon":
		_draw_cocoon(c, s * 0.8)
		return
	var eye_y := -s * 0.15
	match shape:
		0:  # blob
			var pts := PackedVector2Array()
			for i in 33:
				var t := i / 32.0 * TAU
				var r := s * (1.0 + 0.06 * sin(t * 5.0 + bob))
				pts.append(c + Vector2(cos(t) * r * 1.1, sin(t) * r * (0.8 if sin(t) < 0 else 0.55)))
			draw_colored_polygon(pts, body)
		1:  # floating wisp with wings
			for side in [-1, 1]:
				var w := PackedVector2Array([c, c + Vector2(side * s * 1.5, -s * 0.9 + sin(bob * 2.0) * 8), c + Vector2(side * s * 1.2, s * 0.2)])
				draw_colored_polygon(w, Color(accent, 0.45))
			draw_circle(c, s * 0.75, body)
			var tail := PackedVector2Array([c + Vector2(-s * 0.5, s * 0.3), c + Vector2(s * 0.5, s * 0.3), c + Vector2(sin(bob) * s * 0.3, s * 1.3)])
			draw_colored_polygon(tail, body)
		2:  # armoured knight / golem
			var r := Rect2(c - Vector2(s * 0.75, s * 0.9), Vector2(s * 1.5, s * 1.8))
			draw_rect(r, body)
			draw_rect(Rect2(c - Vector2(s * 0.55, s * 1.35), Vector2(s * 1.1, s * 0.6)), body.darkened(0.2))
			draw_rect(Rect2(c + Vector2(-s * 1.05, -s * 0.6), Vector2(s * 0.3, s * 1.1)), body.darkened(0.3))
			draw_rect(Rect2(c + Vector2(s * 0.75, -s * 0.6), Vector2(s * 0.3, s * 1.1)), body.darkened(0.3))
			eye_y = -s * 1.05
		3:  # chest
			draw_rect(Rect2(c - Vector2(s, s * 0.5), Vector2(s * 2, s * 1.1)), body.darkened(0.2))
			var lid := PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(s, -s * 0.5), c + Vector2(s * 0.9, -s * 1.1 - sin(bob) * 6), c + Vector2(-s * 0.9, -s * 1.1 - sin(bob) * 6)])
			draw_colored_polygon(lid, body)
			for i in 6:
				var x := -s * 0.8 + i * s * 0.32
				draw_colored_polygon(PackedVector2Array([c + Vector2(x, -s * 0.5), c + Vector2(x + s * 0.16, -s * 0.5), c + Vector2(x + s * 0.08, -s * 0.25)]), Color.WHITE)
			eye_y = -s * 0.85
		4:  # beast on legs
			draw_set_transform(c, 0, Vector2(1.3, 0.8))
			draw_circle(Vector2.ZERO, s * 0.8, body)
			draw_set_transform(Vector2.ZERO)
			for i in 4:
				var x := -s * 0.8 + i * s * 0.53
				draw_line(c + Vector2(x, s * 0.4), c + Vector2(x + sin(bob + i) * 5, s * 1.1), body.darkened(0.3), 6.0)
			draw_circle(c + Vector2(s * 0.95, -s * 0.35), s * 0.45, body)
			eye_y = -s * 0.4
			c.x += s * 0.95
		5:  # robed caster
			var robe := PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.9, s * 1.0), c + Vector2(-s * 0.9, s * 1.0)])
			draw_colored_polygon(robe, body.darkened(0.15))
			draw_circle(c + Vector2(0, -s * 0.6), s * 0.45, body)
			draw_circle(c + Vector2(s * 1.0, -s * 0.2 + sin(bob) * 5), s * 0.18, Color(accent, 0.9))
			draw_line(c + Vector2(s * 1.0, -s * 0.05), c + Vector2(s * 0.95, s * 1.0), Color(0.45, 0.3, 0.2), 4.0)
			eye_y = -s * 0.65
	if spikes:
		for i in 5:
			var x := -s * 0.6 + i * s * 0.3
			draw_colored_polygon(PackedVector2Array([c + Vector2(x - 8, eye_y - s * 0.45), c + Vector2(x + 8, eye_y - s * 0.45), c + Vector2(x, eye_y - s * 0.85)]), accent.darkened(0.2))
	if crown:
		var cy := eye_y - s * 0.6
		var pts := PackedVector2Array([c + Vector2(-s * 0.45, cy), c + Vector2(-s * 0.45, cy - s * 0.35), c + Vector2(-s * 0.22, cy - s * 0.15),
			c + Vector2(0, cy - s * 0.45), c + Vector2(s * 0.22, cy - s * 0.15), c + Vector2(s * 0.45, cy - s * 0.35), c + Vector2(s * 0.45, cy)])
		draw_colored_polygon(pts, Color(1, 0.82, 0.3))
	if not dead and hurt > 0.0:
		_draw_pained_face(c, s, eye_y)
	elif not dead:
		for side in [-1, 1]:
			var ep := c + Vector2(side * s * 0.25, eye_y)
			draw_circle(ep, s * 0.13, Color(1, 1, 0.9))
			draw_circle(ep + Vector2(side * 2, 2), s * 0.06, Color(0.1, 0.05, 0.05))


## Ouch: eyes squeezed shut into "> <", brows pulled up in the middle, a small round "o" of a mouth, and a bead of
## sweat. It fades back to the normal face as `hurt` runs out.
	_draw_yinyang(c, s)


## The Yin Yang Beast's symbol on its head: the white half up while it is white; it spins round each time it inverts.
## The Invoker's rings: faint ellipses his orbiting Essence travel along.
func _draw_rings() -> void:
	if _orbs.is_empty():
		return
	var c := Vector2(size.x / 2.0, size.y * 0.5)
	var s := minf(size.x, size.y) * 0.34 * big
	for k in _orbs.size():
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * s * 1.45, sin(a) * s * 0.42).rotated(PI * k / 3.0))
		var col: Color = Elements.COLORS.get((_orbs[k] as ElementIcon).el, Color.WHITE)
		draw_polyline(pts, Color(col, 0.35), 2.0, true)


func _draw_yinyang(c: Vector2, s: float) -> void:
	if _enemy == null or _enemy.yin == "":
		return
	var r := s * 0.32
	var at := c + Vector2(0, -s * 1.05)
	var white := Color(0.97, 0.96, 0.92)
	var black := Color(0.08, 0.08, 0.1)
	draw_set_transform(at, _yin_rot)
	draw_circle(Vector2.ZERO, r + 2.0, Color(0.45, 0.45, 0.45))
	draw_circle(Vector2.ZERO, r, black)
	var top := PackedVector2Array()
	for k in 25:
		var t := PI + k / 24.0 * PI
		top.append(Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(top, white)
	draw_circle(Vector2(-r / 2.0, 0), r / 2.0, white)
	draw_circle(Vector2(r / 2.0, 0), r / 2.0, black)
	draw_circle(Vector2(-r / 2.0, 0), r / 6.0, black)
	draw_circle(Vector2(r / 2.0, 0), r / 6.0, white)
	draw_set_transform(Vector2.ZERO)


func _draw_pained_face(c: Vector2, s: float, eye_y: float) -> void:
	var ink := Color(0.1, 0.05, 0.05)
	var w := maxf(2.0, s * 0.07)
	for side in [-1, 1]:
		var ep := c + Vector2(side * s * 0.25, eye_y)
		var r := s * 0.12
		# a ">" on the left, a "<" on the right: both point at the nose
		draw_polyline(PackedVector2Array([ep + Vector2(-side * r, -r * 0.8), ep + Vector2(side * r * 0.6, 0), ep + Vector2(-side * r, r * 0.8)]), ink, w, true)
		# brows tilted up towards the middle
		draw_line(ep + Vector2(-side * r * 1.1, -r * 1.6), ep + Vector2(side * r * 0.9, -r * 2.3), ink, w * 0.8, true)
	var mouth := c + Vector2(0, eye_y + s * 0.32)
	draw_circle(mouth, s * 0.09, ink)
	draw_circle(mouth + Vector2(0, s * 0.02), s * 0.05, Color(0.75, 0.25, 0.3))
	# a sweat drop on the side of the head
	var sd := c + Vector2(s * 0.55, eye_y - s * 0.1)
	draw_circle(sd, s * 0.07, Color(0.6, 0.85, 1.0, 0.9))
	draw_colored_polygon(PackedVector2Array([sd + Vector2(-s * 0.06, -s * 0.02), sd + Vector2(0, -s * 0.16), sd + Vector2(s * 0.06, -s * 0.02)]), Color(0.6, 0.85, 1.0, 0.9))


## Puppet Stage: the side of the square the puppet's picture is drawn in. The Handyman's body is drawn at the size his arms were cut for.
func _art_side() -> float:
	if enemy_id == "handyman" and _puppet:
		return HandymanRig.BODY_PX * HandymanRig.SCALE
	return minf(size.x, size.y) * 0.88 * big


func has_rig() -> bool:
	return not _rig.is_empty()


## The two sticks of a hand's arm are drawn longer or shorter than they were cut: `reach` = (upper, lower) length in px of the art. HandymanStage
## sets it so that the hand lands where its name stands. (0, 0) = as cut.
var reach := Vector2.ZERO
var sad_forever := false  # the Handyman's body, once every hand is down: he keeps the crying face (Face.pdf)
var _sad_tex: Texture2D
var _sad_t := 0.0  # seconds of crying left (a hand of his was hurt)
var calm := false  # a folded arm that was never hurt (a hand not summoned yet): it lies still, no creaking
var reach_angle := INF  # the lower stick's direction when it is not the rest one (INF: the rest one)


## The hand marker, from the shoulder, in px of the art, with the sticks at `r` (upper, lower) length.
static func arm_hand(arm: Dictionary, r: Vector2, th2: float) -> Vector2:
	return Vector2.from_angle(arm.theta1) * r.x + Vector2.from_angle(th2) * r.y


## Draw one stick of an arm (its picture lies along +x, the joint it turns about at `pivot`): the stretch `slab` is made `extra` px longer.
func _draw_stick(tex: Texture2D, pivot: Vector2, slab: Vector2, extra: float, mod: Color) -> void:
	var h := float(tex.get_height())
	var w := float(tex.get_width())
	extra = maxf(extra, -(slab.y - slab.x) * 0.9)
	draw_texture_rect_region(tex, Rect2(-pivot.x, -pivot.y, slab.x + 1.0, h), Rect2(0.0, 0.0, slab.x + 1.0, h), mod)
	draw_texture_rect_region(tex, Rect2(slab.y - pivot.x + extra - 1.0, -pivot.y, w - slab.y + 1.0, h), Rect2(slab.y - 1.0, 0.0, w - slab.y + 1.0, h), mod)
	draw_texture_rect_region(tex, Rect2(slab.x - pivot.x - 0.5, -pivot.y, slab.y - slab.x + extra + 1.0, h), Rect2(slab.x, 0.0, slab.y - slab.x, h), mod)


## The pose of a knocked-out arm at `f` (0 = as it hangs, 1 = away): {u: upper direction, l: lower direction, len: stick lengths, px of the art}.
## First half: the arm is lifted and pulled in behind the Handyman's back (written for a LEFT arm, angles clockwise from +x with y down; a right arm
## is its mirror image): the upper stick points inward, the lower one is doubled back along it. Second half: it goes to the pose drawn on page 4 of
## Handyman.pdf for that arm (rig: fold1 / fold2, the sticks at their cut length), turning the way that does not sweep past the ground.
const FOLD_TUCK_UPPER := deg_to_rad(345.0)
const FOLD_TUCK_LOWER := deg_to_rad(165.0)


## The signed turn from `from` to `to` that does not go through "pointing down".
static func _sweep(from: float, to: float) -> float:
	var d := angle_difference(from, to)
	for way in 2:
		var ok := true
		for i in 9:
			if absf(angle_difference(from + d * i / 8.0, PI / 2.0)) < 0.5:
				ok = false
		if ok:
			return d
		d -= signf(d) * TAU
	return angle_difference(from, to)


func _fold_pose(f: float, th1: float, th2: float, sd: float, rest: Vector2) -> Dictionary:
	var mirror := sd > 0.0
	var p1 := fposmod(PI - th1 if mirror else th1, TAU)
	var p2 := fposmod(PI - th2 if mirror else th2, TAU)
	var tuck_len := rest * 0.55
	if f < 0.5:
		var s := smoothstep(0.0, 1.0, f / 0.5)
		var u := lerpf(p1, FOLD_TUCK_UPPER, s)
		var l := lerpf(p2, FOLD_TUCK_LOWER, s)
		return {"u": PI - u if mirror else u, "l": PI - l if mirror else l, "len": rest.lerp(tuck_len, s)}
	var s := smoothstep(0.0, 1.0, (f - 0.5) / 0.5)
	var tu: float = PI - FOLD_TUCK_UPPER if mirror else FOLD_TUCK_UPPER
	var tl: float = PI - FOLD_TUCK_LOWER if mirror else FOLD_TUCK_LOWER
	var fu: float = _rig.fold1
	var fl: float = _rig.fold2
	return {"u": tu + _sweep(tu, fu) * s, "l": tl + _sweep(tl, fl) * s, "len": tuck_len.lerp(Vector2(_rig.l1, _rig.l2), s)}


## A Handyman hand: the upper arm turns about the shoulder, the lower arm (elbow, hand, tool) about the elbow, riding on the upper one. All the
## motion is angles, taken DOWN for a left arm with a negative turn and for a right arm with a positive one (`sd` carries that sign).
func _draw_arm(blink_on: bool) -> void:
	var sc: float = HandymanRig.SCALE
	var sd: float = _rig.side
	var h := 0.0 if dead else minf(hurt / 0.4, 1.0)  # (a hit throws it back up)
	# knocked out: see _fold_pose. The broken gears: while the arm is stuck it trembles a little, and a folded arm creaks
	var folding := _enemy != null and _enemy.knocked
	var th2: float = _rig.theta2 if is_inf(reach_angle) else reach_angle
	var a1 := sin(bob * 0.45 + _rig_phase) * 0.045  # idle: it hangs and drifts a little
	var a2 := sin(bob * 0.62 + _rig_phase * 1.7) * 0.075
	a1 += sd * (swing * 0.14 - h * 0.15 - intro * 1.1)
	a2 += sd * (swing * 0.26 - h * 0.25 - intro * 0.6)
	var rest := reach if reach != Vector2.ZERO else Vector2(_rig.l1, _rig.l2)
	var r := rest
	var poked := poke > 0.0 and _enemy != null and POKE_TIP.has(_enemy.id)
	if _fold_t > 0.0:
		var pose := _fold_pose(_fold_t, float(_rig.theta1), th2, sd, rest)
		var fold1 := angle_difference(float(_rig.theta1), pose.u)
		a1 = a1 * (1.0 - _fold_t) + fold1
		a2 = a2 * (1.0 - _fold_t) + angle_difference(th2 + fold1, pose.l)
		r = pose.len  # (the sticks pull in as it folds)
		if folding:
			if not calm:  # (a hurt arm: its broken gears tremble while it is stuck)
				var stuck := 1.0 - _drive
				a1 += sin(_gear_t * 47.0) * 0.012 * stuck
				a2 += sin(_gear_t * 41.0 + 1.0) * 0.02 * stuck
			# a folded arm always drifts a little, slowly (a calm one, never hurt, only this: no trembling)
			a1 += sin(_gear_t * 0.9 + _rig_phase) * 0.012 * _fold_t
			a2 += sin(_gear_t * 1.3) * 0.03 * _fold_t
	if poked:  # (reaching for a point of the screen: both sticks turn and stretch to put the tip of its tool there)
		var pk := _poke_pose(size / 2.0 - arm_hand(_rig, rest, th2) * sc, rest, th2, sc)
		a1 += angle_difference(a1, pk.a1) * poke
		a2 += angle_difference(a2, pk.a2) * poke
		r = r.lerp(pk.r, poke)
	# a stick cannot be shorter than its stretch allows: the elbow pin of the upper stick and the lower stick's must stay on one another
	var slab_u: Vector2 = _rig.upper_slab
	var slab_l: Vector2 = _rig.lower_slab
	r = Vector2(maxf(r.x, float(_rig.l1) - 0.9 * (slab_u.y - slab_u.x)), maxf(r.y, float(_rig.l2) - 0.9 * (slab_l.y - slab_l.x)))
	var elbow := Vector2.from_angle(_rig.theta1) * r.x
	var origin := size / 2.0 - arm_hand(_rig, rest, th2) * sc  # (the shoulder: the middle of the box is the hand marker at rest)
	if _shake > 0.0:
		origin += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	var mod := Color.WHITE
	if dead:
		mod = Color(0.05, 0.05, 0.05, 0.4)
	elif blink_on or flash > 0.0:
		var b := 1.0 + 0.9 * maxf(flash, 1.0 if blink_on else 0.0)
		mod = Color(b, b, b)
	mod.a *= 1.0 - 0.6 * intro
	var m1 := Transform2D(a1, origin) * Transform2D(Vector2(sc, 0.0), Vector2(0.0, sc), Vector2.ZERO)
	var m2 := m1 * Transform2D(a2, elbow)
	draw_set_transform_matrix(m1 * Transform2D(_rig.theta1, Vector2.ZERO))
	_draw_stick(_rig_tex[0], _rig.upper_pivot, _rig.upper_slab, r.x - float(_rig.l1), mod)
	draw_set_transform_matrix(m2 * Transform2D(th2, Vector2.ZERO))
	_draw_stick(_rig_tex[1], _rig.lower_pivot, _rig.lower_slab, r.y - float(_rig.l2), mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _enemy != null and POKE_TIP.has(_enemy.id):
		var tt: Vector2 = POKE_TIP[_enemy.id]
		var piv: Vector2 = _rig.lower_pivot
		_arm_tip = (m2 * Transform2D(th2, Vector2.ZERO)) * Vector2(tt.x - piv.x + (r.y - float(_rig.l2)), tt.y - piv.y)


## Where the tip of the arm's tool is on the screen.
func tool_tip() -> Vector2:
	return get_global_transform() * _arm_tip


## The pose that puts the tip of the tool on `poke_target`: the hand has to be where the tip would leave it (the tool sticks out of the hand at a fixed
## angle to the lower stick), and the upper stick turns most of the way toward it, so the arm bends a little at the elbow. Returns the turn of the
## upper stick (a1) and of the lower one (a2) from their rest, and the two lengths (px of the art). `s`: the shoulder, in this Control's coordinates.
func _poke_pose(s: Vector2, rest: Vector2, th2: float, sc: float) -> Dictionary:
	var tt: Vector2 = POKE_TIP[_enemy.id]
	var piv: Vector2 = _rig.lower_pivot
	var off := Vector2(tt.x - (piv.x + float(_rig.l2)), tt.y - piv.y) * sc  # (tip relative to the hand marker, with the lower stick along +x)
	var t := get_global_transform().affine_inverse() * poke_target
	var th := (t - s).angle()
	var u := float(_rig.theta1)
	var h := t
	var e := s
	var l1 := rest.x * sc
	for k in 6:
		h = t - off.rotated(th)
		var d := h - s
		u = lerp_angle(float(_rig.theta1), d.angle(), 0.7)
		l1 = maxf(d.length() * 0.5, rest.x * sc)
		e = s + Vector2.from_angle(u) * l1
		th = (h - e).angle()
	var a1p := angle_difference(float(_rig.theta1), u)
	return {"a1": a1p, "a2": wrapf(th - a1p - th2, -PI, PI), "r": Vector2(l1 / sc, (h - e).length() / sc)}


## Drawn art instead of the procedural body: hurt for a moment after a hit, angry while it has at least half its
## Essence, the normal (worn-out) face below half. It bobs and jolts like the procedural ones and blinks bright when hit.
func _draw_art(blink_on: bool) -> void:
	var face := "angry"
	if _enemy != null:
		_max_hp = maxi(_max_hp, _enemy.size())
		if _enemy.size() * 2 < _max_hp:
			face = "normal"
	if hurt > 0.0 and not dead:
		face = "hurt"
	if ART_FORMS.has(enemy_id):
		# form 1 in its starting colour, form 2 once it has flipped to the other one
		var start: String = _enemy.def.get("yin", "white") if _enemy != null else "white"
		face += "_1" if _enemy == null or _enemy.yin == "" or _enemy.yin == start else "_2"
	var tex: Texture2D = _art.get(face, _art.values()[0])
	if _puppet and _enemy != null and _enemy.yin != "" and _art.has("yin_" + _enemy.yin):
		tex = _art["yin_" + _enemy.yin]
	if _sad_tex != null and (sad_forever or _sad_t > 0.0):
		tex = _sad_tex
	var side := _art_side()
	var c := Vector2(size.x / 2.0, size.y - side * 0.5 + sin(bob) * 4.0)
	if _shake > 0.0:
		c += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	_art_shake_x = c.x - size.x / 2.0
	if _puppet and not dead:
		_draw_puppet_shadow(tex, Vector2(c.x, size.y), side)
	if _puppet:  # a puppet doesn't bob: it rocks on its base, and tips back when it is hit
		var tip := 0.0 if dead else (0.0 if enemy_id == "handyman" else sin(bob * 0.5) * 0.04) - 0.16 * minf(hurt / 0.4, 1.0)  # (the Handyman's body does not rock: six arms hang on its shoulders)
		draw_set_transform(Vector2(c.x, size.y), tip)
		_art_tip = tip
		c = Vector2(0, -side * 0.5)
	var mod := Color.WHITE
	if dead:
		mod = Color(0.05, 0.05, 0.05, 0.4)  # an unknown silhouette (codex), like the procedural grey
	elif blink_on or flash > 0.0:
		var b := 1.0 + 0.9 * maxf(flash, 1.0 if blink_on else 0.0)
		mod = Color(b, b, b)
	draw_texture_rect(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, mod)
	if _puppet and not dead:
		for fl in _floaters:  # (they hover: a slow drift up and down and a little sideways, each on its own beat)
			var ft: Texture2D = fl[0]
			var k := side / float(tex.get_width())
			var ph: float = fl[2]
			var at: Vector2 = c + (fl[1] - Vector2(0.5, 0.5)) * side + Vector2(sin(bob * 0.7 + ph) * side * 0.006, sin(bob * 1.1 + ph) * side * 0.014)
			draw_texture_rect(ft, Rect2(at - ft.get_size() * k * 0.5, ft.get_size() * k), false, mod)
	if _puppet:
		draw_set_transform(Vector2.ZERO)


## Puppet Stage: the shadow the spotlight throws on the floor: its own silhouette lying flat BEHIND the puppet (up the screen from its
## feet, squashed, leaning right), dark at the feet and fading away from them, with a soft edge (a few passes, each a little wider and fainter).
func _draw_puppet_shadow(tex: Texture2D, feet: Vector2, side: float) -> void:
	var depth := side * 0.5
	var lean := side * 0.5
	var passes := [[0.0, 0.62], [0.06, 0.38], [0.13, 0.2]]
	for p in passes:
		var grow: float = p[0]
		var w := side * (1.0 + grow)
		var d := depth * (1.0 + grow)
		var near := Color(0, 0, 0, p[1])  # (at the feet)
		var far := Color(0, 0, 0, p[1] * 0.3)  # (at the head)
		var pts := PackedVector2Array([
			feet + Vector2(-w / 2.0 + lean, -d), feet + Vector2(w / 2.0 + lean, -d),  # the head's two corners, on the floor behind
			feet + Vector2(w / 2.0, 0.0), feet + Vector2(-w / 2.0, 0.0)])  # the feet
		draw_polygon(pts, PackedColorArray([far, far, near, near]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)


## Puppet Stage: the whole square the picture is drawn in, on the screen, and the picture itself (for the pieces it breaks into).
func puppet_art_rect() -> Rect2:
	var side := _art_side()
	return Rect2(global_position + Vector2(size.x / 2.0 - side / 2.0, size.y - side), Vector2(side, side))


func puppet_tex() -> Texture2D:
	if not _puppet or _art.is_empty():
		return null
	if _enemy != null and _enemy.yin != "" and _art.has("yin_" + _enemy.yin):
		return _art["yin_" + _enemy.yin]
	return _art.values()[0]


## ---- Rope mode (RopeEditor): points on the puppet's picture, given as fractions of its square (0..1 from the top left) --------------------------
## Only a plain Puppet Stage cut-out takes ropes (a Handyman hand is a rig and a dead puppet is a silhouette).
func rope_ok() -> bool:
	return _puppet and _rig.is_empty() and not dead and not _art.is_empty()


## Where a point of the picture is on the screen. `rest`: where it is while the puppet stands still (no rocking, no jolt): the top of its rope hangs over that.
func rope_point(frac: Vector2, rest := false) -> Vector2:
	var side := _art_side()
	var local := Vector2(0.0, -side * 0.5) + (frac - Vector2(0.5, 0.5)) * side
	var org := Vector2(size.x / 2.0 + (0.0 if rest else _art_shake_x), size.y)
	return get_global_transform() * (org + local.rotated(0.0 if rest else _art_tip))


## The point of the picture under a screen point (the inverse of rope_point; outside the square when the point is off the picture).
func rope_frac_at(g: Vector2) -> Vector2:
	var side := _art_side()
	var l := get_global_transform().affine_inverse() * g
	l = (l - Vector2(size.x / 2.0 + _art_shake_x, size.y)).rotated(-_art_tip)
	return (l - Vector2(0.0, -side * 0.5)) / side + Vector2(0.5, 0.5)


static var _alpha_cache := {}  # texture path -> a small copy of its picture (only the opaque parts matter)


## How opaque the picture is at a point of it (0 outside the square or on a see-through part).
func rope_alpha(frac: Vector2) -> float:
	var tex := puppet_tex()
	if tex == null or frac.x < 0.0 or frac.y < 0.0 or frac.x >= 1.0 or frac.y >= 1.0:
		return 0.0
	var key := tex.resource_path
	if not _alpha_cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		_alpha_cache[key] = img
	var img: Image = _alpha_cache[key]
	return img.get_pixel(int(frac.x * img.get_width()), int(frac.y * img.get_height())).a


static var _bounds_cache := {}  # texture path -> Rect2 (the painted part of the picture, as fractions of its square)


## Puppet Stage: where the painted part of the puppet is, in this control's own coordinates (the picture is a square, its feet at the
## bottom edge: see _draw_art). Empty when it is not drawn as a puppet.
func puppet_bounds() -> Rect2:
	if not _rig.is_empty():  # (a hand: a small box on the hand marker of the art, the name stands right over it and the Essence right under it;)
		return Rect2(size / 2.0 + Vector2(0.0, 50.0) - Vector2(60.0, 6.0), Vector2(120.0, 12.0))  # (50 px lower than the hand: over the spell cards)
	if not _puppet or _art.is_empty():
		return Rect2()
	var tex: Texture2D = _art.values()[0]
	var key := tex.resource_path
	if not _bounds_cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var r := img.get_used_rect()
		_bounds_cache[key] = Rect2(Vector2(r.position) / Vector2(img.get_size()), Vector2(r.size) / Vector2(img.get_size()))
	var f: Rect2 = _bounds_cache[key]
	var side := _art_side()
	var origin := Vector2(size.x / 2.0 - side / 2.0, size.y - side)
	var r := Rect2(origin + f.position * side, f.size * side)
	if _enemy != null and _enemy.yin != "":  # (the Yin Yang Beast carries its symbol over its head: it counts as its head)
		var sym_top := size.y * 0.58 - minf(size.x, size.y) * 0.34 * big * 1.37 - 2.0
		if sym_top < r.position.y:
			r = Rect2(r.position.x, sym_top, r.size.x, r.end.y - sym_top)
	return r


# ------------------------------------------------------------------ the Veiled Eyes (drawn until it has art)

const VIOLET := Color(0.66, 0.32, 1.0)
const SILK := Color(0.95, 0.94, 0.9)
var _veil_drop := 0.0  # 0: the veil is on; 1: it has fallen away (it slides off when phase 2 starts)
var _hypno := 0.0  # seconds left of the human eyes' bright hypnotizing glow (the fight's opening)
var _look := Vector2.ZERO  # where the human eyes look, -1..1 (phase 2: they glance around)
var _look_to := Vector2.ZERO
var _look_t := 0.0


## The fight's opening: the human eyes shine brightly for a moment.
func hypnotize(sec := 2.2) -> void:
	_hypno = sec


func _spider_tick(d: float) -> void:
	if enemy_id != "veiled_eyes" or _enemy == null:
		return
	if _enemy.phase >= 2:
		_veil_drop = move_toward(_veil_drop, 1.0, d * 0.7)
	_hypno = maxf(0.0, _hypno - d)
	_look_t -= d
	if _look_t <= 0.0:
		_look_t = randf_range(0.9, 2.2)  # (every so often they glance somewhere else)
		_look_to = Vector2(randf_range(-1, 1), randf_range(-0.7, 0.7))
	_look = _look.lerp(_look_to, minf(1.0, d * 6.0))
	queue_redraw()


## What its eyes say: phase 1 "both" / "left" / "right"; phase 2 how many dots (0..4) are lit.
func _eyes_cue() -> Variant:
	if _enemy == null or _enemy.intent.is_empty():
		return null
	return _enemy.intent.get("eyes", null)


func _draw_veiled(c: Vector2, s: float, body: Color, blink_on: bool) -> void:
	var phase2 := _enemy != null and _enemy.phase >= 2
	var top := Vector2(c.x, 0.0)
	if not phase2:
		var ball := c + Vector2(0, -s * 0.05)
		var r := s * 0.95
		draw_line(top, ball + Vector2(0, -r), SILK, 2.0, true)
		draw_circle(ball, r * 1.04, Color(0, 0, 0, 0.5))
		draw_circle(ball, r, body)
		draw_circle(ball + Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.08))  # (a dull sheen)
		var cue: Variant = _eyes_cue()
		var lit_l: bool = _hypno > 0.0 or cue == "both" or cue == "left"
		var lit_r: bool = _hypno > 0.0 or cue == "both" or cue == "right"
		for side in [-1, 1]:
			_human_eye(ball + Vector2(side * r * 0.4, -r * 0.12), r * 0.3, Vector2.ZERO, false, blink_on)
		_draw_veil(ball, r, 0.0)
		for side in [-1, 1]:  # a lit eye pierces right through the veil
			if lit_l if side < 0 else lit_r:
				_human_eye(ball + Vector2(side * r * 0.4, -r * 0.12), r * 0.3, Vector2.ZERO, true, blink_on)
		return
	# phase 2: the spider, hanging head-down on its thread
	var ab := c + Vector2(0, -s * 0.25)  # its back (the abdomen), where the human eyes are
	var head := c + Vector2(0, s * 0.55)
	draw_line(top, ab + Vector2(0, -s * 0.7), SILK, 2.0, true)
	var leg := Color(body.darkened(0.3), 1.0)
	for side in [-1, 1]:
		for k in 4:
			var root := c + Vector2(side * s * 0.35, -s * 0.15 + k * s * 0.24)
			var knee := root + Vector2(side * s * (0.7 + 0.08 * k), (-0.6 + k * 0.26) * s)
			var foot := knee + Vector2(side * s * 0.2, (0.45 + k * 0.05) * s)
			draw_polyline(PackedVector2Array([root, knee, foot]), Color(0, 0, 0, 0.6), s * 0.16, true)
			draw_polyline(PackedVector2Array([root, knee, foot]), leg, s * 0.11, true)
	draw_circle(ab, s * 0.72, Color(0, 0, 0, 0.5))
	draw_circle(ab, s * 0.68, body)
	draw_circle(head, s * 0.42, Color(0, 0, 0, 0.5))
	draw_circle(head, s * 0.38, body.lightened(0.05))
	for side in [-1, 1]:  # fangs
		draw_colored_polygon(PackedVector2Array([head + Vector2(side * s * 0.12, s * 0.28), head + Vector2(side * s * 0.2, s * 0.32),
			head + Vector2(side * s * 0.1, s * 0.58)]), SILK.darkened(0.2))
	# the human eyes on its back: they look around; before the laser they glow and stare straight at you
	var cue: Variant = _eyes_cue()
	var stare: bool = cue != null and typeof(cue) != TYPE_STRING and int(cue) == 0
	for side in [-1, 1]:
		var at := ab + Vector2(side * s * 0.3, -s * 0.12)
		_human_eye(at, s * 0.24, Vector2(0, 0.35) if stare else _look, stare or _hypno > 0.0, blink_on)
	# the 4 spider-eye dots on its head: as many light up as its count says
	var n_lit: int = int(cue) if cue != null and typeof(cue) != TYPE_STRING else 0
	var dots := [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(-0.16, 0.1), Vector2(0.16, 0.1)]
	for k in 4:
		var p: Vector2 = head + dots[k] * s
		if k < n_lit:
			draw_circle(p, s * 0.13, Color(VIOLET, 0.35))
			draw_circle(p, s * 0.075, Color(1.0, 0.55, 1.0))
			draw_circle(p, s * 0.035, Color(1, 1, 1))
		else:
			draw_circle(p, s * 0.06, Color(0.03, 0.02, 0.04))
			draw_circle(p + Vector2(-s * 0.015, -s * 0.015), s * 0.015, Color(1, 1, 1, 0.5))
	if _veil_drop < 1.0:
		_draw_veil(ab + Vector2(0, -s * 0.2), s * 0.95, _veil_drop)  # (falling away)


## A human eye: an almond of white with a violet iris; lit, it glows through anything over it.
func _human_eye(at: Vector2, w: float, look: Vector2, lit: bool, blink_on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := k / 23.0 * TAU
		pts.append(at + Vector2(cos(t) * w, sin(t) * w * 0.48 * (1.0 if sin(t) > 0 else 0.9)))
	if lit:
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
		draw_circle(at, w * 1.9, Color(VIOLET, 0.16 * pulse))
		draw_circle(at, w * 1.3, Color(VIOLET, 0.28 * pulse))
	draw_colored_polygon(pts, Color(0.97, 0.95, 0.98) if not blink_on else Color.WHITE)
	var iris := at + Vector2(look.x * w * 0.35, look.y * w * 0.15)
	draw_circle(iris, w * 0.36, VIOLET.lightened(0.25) if lit else VIOLET)
	draw_circle(iris, w * 0.17, Color(0.05, 0.02, 0.08))
	draw_circle(iris + Vector2(-w * 0.1, -w * 0.1), w * 0.07, Color(1, 1, 1, 0.9))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.05, 0.03, 0.06), maxf(1.5, w * 0.1), true)


## The thin black veil over its eyes (drop 0: on; up to 1: it slides down and fades away).
func _draw_veil(at: Vector2, r: float, drop: float) -> void:
	var a := 0.72 * (1.0 - drop)
	if a <= 0.01:
		return
	var off := Vector2(drop * r * 0.15, drop * r * 2.4)
	var pts := PackedVector2Array()
	for k in 13:
		var t := PI + k / 12.0 * PI  # the top half of the ball
		pts.append(at + off + Vector2(cos(t), sin(t)) * r * 1.03)
	for k in 13:  # a wavy hem, under the eyes
		var u := 1.0 - k / 12.0
		var x := lerpf(-r * 1.03, r * 1.03, u)
		pts.append(at + off + Vector2(x, r * (0.18 + 0.07 * sin(u * 18.0 + bob * 0.6))))
	draw_colored_polygon(pts, Color(0.02, 0.01, 0.03, a))


func _draw_spiderling(c: Vector2, s: float, body: Color) -> void:
	draw_line(Vector2(c.x, 0), c + Vector2(0, -s * 0.5), Color(SILK, 0.8), 1.5, true)
	var leg := body.darkened(0.3)
	for side in [-1, 1]:
		for k in 4:
			var root := c + Vector2(side * s * 0.25, -s * 0.1 + k * s * 0.13)
			var knee := root + Vector2(side * s * 0.55, (-0.4 + k * 0.22) * s)
			var foot := knee + Vector2(side * s * 0.2, (0.45 + k * 0.08) * s)
			draw_polyline(PackedVector2Array([root, knee, foot]), leg, s * 0.09, true)
	draw_circle(c, s * 0.48, body)
	draw_circle(c + Vector2(0, s * 0.5), s * 0.28, body.lightened(0.05))
	for side in [-1, 1]:
		draw_circle(c + Vector2(side * s * 0.1, s * 0.48), s * 0.07, Color(1.0, 0.45, 0.9))


func _draw_cocoon(c: Vector2, s: float) -> void:
	var sway := sin(bob * 0.7) * 0.08
	var at := c + Vector2(0, -s * 0.05)
	draw_line(Vector2(c.x, 0), at + Vector2(0, -s * 0.9), SILK, 2.0, true)
	draw_set_transform(at, sway, Vector2.ONE)
	var pts := PackedVector2Array()
	for k in 28:
		var t := k / 27.0 * TAU
		pts.append(Vector2(cos(t) * s * 0.55, sin(t) * s * 0.9))
	draw_colored_polygon(pts, SILK)
	for k in 7:  # silk wound round and round
		var y := -s * 0.75 + k * s * 0.25
		var half := s * 0.55 * sqrt(maxf(0.0, 1.0 - pow(y / (s * 0.9), 2)))
		draw_line(Vector2(-half, y - s * 0.05), Vector2(half, y + s * 0.07), SILK.darkened(0.15), 2.0, true)
	draw_rect(Rect2(Vector2(-s * 0.2, -s * 0.28), Vector2(s * 0.4, s * 0.56)), Color(0.55, 0.4, 0.75, 0.18))  # (a card, faintly, inside)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
