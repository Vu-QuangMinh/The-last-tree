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

const SHAPES := {
	"puddle_slime": 0, "splitter_ooze": 0, "tide_colossus": 0, "blightmother": 0, "last_gasp_spore": 0,
	"gale_sprite": 1, "mirror_wisp": 1, "storm_imp": 1, "hush_moth": 1, "leech_bat": 1, "echo_wraith": 1, "storm_rider": 1,
	"stone_knight": 2, "warded_golem": 2, "lockwarden": 2, "woodcutter": 2, "gem_king": 2, "inverter": 2, "mimic_chest": 3,
	"cinder_hound": 4, "blinding_beetle": 4, "hollow_stag": 4, "bramble_matron": 5, "mirror_knight": 2, "void_archon": 1, "pickpocket_imp": 4, "overgrowth_vine": 5, "shrine_maiden": 5,
	"tidecaller": 5, "hexer": 5, "toll_keeper": 5, "frost_hex": 5, "ashling": 1, "last_winter": 1,
}


func setup(e: EnemyState) -> void:
	enemy_id = e.id
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
	tint.a = 1.0
	accent = Elements.COLORS[e.def.hp[0]]
	big = 1.2 if e.is_boss else (1.1 if e.is_elite else 1.0)
	crown = e.is_boss or e.id == "gem_king"
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
func hit(strength := 1.0) -> void:
	hurt = HURT_TIME
	_shake = maxf(_shake, 7.0 * strength + 3.0)
	_blink = maxf(_blink, 0.18 + 0.22 * strength)


func _process(d: float) -> void:
	bob += d * 2.0
	flash = maxf(0.0, flash - d * 3.0)
	hurt = maxf(0.0, hurt - d)
	_shake = maxf(0.0, _shake - d * 30.0)
	_blink = maxf(0.0, _blink - d)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.58 + sin(bob) * 4.0)
	if _shake > 0.0:  # the jolt of a hit
		c += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	var s := minf(size.x, size.y) * 0.34 * big
	# white blinks while hit: on and off a few times (and the older soft flash)
	var blink_on := _blink > 0.0 and fmod(_blink, 0.12) > 0.05
	var body := tint.lerp(Color.WHITE, maxf(flash, 0.85 if blink_on else 0.0))
	if dead:
		body = Color(0.2, 0.2, 0.2, 0.4)
	# shadow (the New theme stands it on a painted stump instead)
	if UiSkin.tex("enemy_stand") == null:
		draw_set_transform(Vector2(c.x, size.y * 0.93), 0, Vector2(1, 0.25))
		draw_circle(Vector2.ZERO, s * 0.9, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
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
