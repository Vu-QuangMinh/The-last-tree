class_name AimCursor
extends Control
## Replaces the mouse pointer while a spell takes an enemy's Essence:
##   "shoot": a red crosshair (remove spells: you shoot the Essence off);
##   "hand":  an open hand (steal spells); while you drag an Essence it closes into a fist, and a sucking tether
##            stretches from the enemy's row to the Essence in your hand.
## Drawn in screen coordinates on top of everything; the screen hides the real pointer while it shows.

var mode := "shoot"
var holding := ""  # the element in the hand ("" = nothing held)
var tether_from := Vector2.ZERO
var _t := 0.0
var _kick := 0.0  # the crosshair's recoil after a shot
var point := Vector2(-1, -1)  # (for screenshots) draw here instead of at the mouse


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200


func kick() -> void:
	_kick = 1.0


func _process(d: float) -> void:
	_t += d
	_kick = maxf(0.0, _kick - d * 5.0)
	queue_redraw()


func _draw() -> void:
	var m := (point if point.x >= 0.0 else get_global_mouse_position()) - global_position
	if mode == "shoot":
		_draw_crosshair(m)
	else:
		if holding != "":
			_draw_tether(tether_from - global_position, m)
		_draw_hand(m)


func _draw_crosshair(m: Vector2) -> void:
	var r := 20.0 + 3.0 * sin(_t * 6.0) + 10.0 * _kick
	var red := Color(1.0, 0.15, 0.12)
	var dark := Color(0.15, 0.0, 0.0, 0.8)
	for pass_i in 2:
		var col := dark if pass_i == 0 else red
		var w := 5.0 if pass_i == 0 else 2.5
		draw_arc(m, r, 0, TAU, 40, col, w, true)
		for k in 4:
			var d := Vector2.from_angle(k * PI / 2.0)
			draw_line(m + d * (r - 7.0), m + d * (r + 9.0), col, w, true)
	draw_circle(m, 2.5, red)


## The tether: a wobbling, glowing strand from the enemy's row to your hand, with motes flowing towards you.
func _draw_tether(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	var dir := b - a
	var n := dir.orthogonal().normalized()
	for i in steps + 1:
		var u := float(i) / steps
		pts.append(a + dir * u + n * sin(u * PI * 3.0 - _t * 10.0) * 10.0 * sin(u * PI))
	draw_polyline(pts, Color(0.5, 0.85, 1.0, 0.25), 12.0, true)
	draw_polyline(pts, Color(0.6, 0.9, 1.0, 0.8), 4.0, true)
	draw_polyline(pts, Color(1, 1, 1, 0.9), 1.5, true)
	for k in 4:
		var u := fmod(_t * 0.9 + k * 0.25, 1.0)
		var at: Vector2 = pts[int(u * steps)]
		draw_circle(at, 3.5, Color(0.8, 0.95, 1.0, 0.9))


## An open hand (fingers spread), or a fist while it holds an Essence, drawn as a little cartoon glove.
func _draw_hand(m: Vector2) -> void:
	var skin := Color(1.0, 0.86, 0.72)
	var line := Color(0.35, 0.2, 0.12)
	if holding != "":
		# a fist around the Essence: the orb, with knuckles over it
		var orb_col: Color = Elements.COLORS.get(holding, Color.WHITE)
		draw_circle(m, 16.0, orb_col.darkened(0.5))
		draw_circle(m, 13.0, orb_col)
		for k in 4:
			var p := m + Vector2(-13.0 + k * 8.5, -10.0)
			draw_circle(p, 6.0, line)
			draw_circle(p, 4.6, skin)
		return
	var palm := m + Vector2(0, 8)
	# fingers spread like a fan, then the thumb
	for k in 4:
		var ang := -PI / 2.0 + (k - 1.5) * 0.32
		var tip := palm + Vector2.from_angle(ang) * 26.0
		draw_line(palm, tip, line, 9.0, true)
		draw_line(palm, tip, skin, 6.0, true)
		draw_circle(tip, 4.5, line)
		draw_circle(tip, 3.0, skin)
	var thumb := palm + Vector2(-18, -2)
	draw_line(palm, thumb, line, 9.0, true)
	draw_line(palm, thumb, skin, 6.0, true)
	draw_circle(palm, 12.0, line)
	draw_circle(palm, 10.5, skin)
