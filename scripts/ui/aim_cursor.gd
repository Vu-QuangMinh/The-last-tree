class_name AimCursor
extends Control
## Replaces the mouse pointer while a spell takes an enemy's Essence:
##   "shoot": a red crosshair (remove spells: you shoot the Essence off);
##   "hand":  an open hand (steal spells); while you drag an Essence it closes into a fist, and a sucking tether
##            stretches from the enemy's row to the Essence in your hand.
##   "brush": a paint brush dipped in rainbow paint (Expose: you paint an Essence into an Any Essence); its tip
##            is the hotspot, and it presses down when you paint.
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


## The rainbow the brush's paint cycles through (also the colours of the splash it leaves).
const RAINBOW := [Color(1.0, 0.3, 0.35), Color(1.0, 0.62, 0.2), Color(1.0, 0.9, 0.3), Color(0.35, 0.9, 0.45),
	Color(0.3, 0.7, 1.0), Color(0.7, 0.45, 1.0)]


static func rainbow(u: float) -> Color:
	u = fposmod(u, 1.0) * RAINBOW.size()
	var k := int(u)
	return (RAINBOW[k] as Color).lerp(RAINBOW[(k + 1) % RAINBOW.size()], u - k)


func _process(d: float) -> void:
	_t += d
	_kick = maxf(0.0, _kick - d * 5.0)
	queue_redraw()


func _draw() -> void:
	var m := (point if point.x >= 0.0 else get_global_mouse_position()) - global_position
	if mode == "shoot":
		_draw_crosshair(m)
	elif mode == "brush":
		_draw_brush(m)
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


const BRUSH_SCALE := 1.8


## A round paint brush, handle up and to the right, its bristles loaded with paint that shifts through the rainbow.
## m is the very tip. After a dab (kick) the brush presses in and springs back.
func _draw_brush(at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * BRUSH_SCALE)
	var m := Vector2.ZERO
	var press := _kick * 6.0
	var dir := Vector2(1, -1.25).normalized()  # from the tip up the handle
	var side := dir.orthogonal()
	var tip := m + dir * press * 0.3
	var line := Color(0.22, 0.13, 0.08)
	# bristles: a teardrop of paint from the tip to the ferrule, splaying wider while pressed
	var b0 := tip + dir * 26.0
	var wide := 8.0 + press * 0.7
	var tuft := PackedVector2Array([tip, tip + dir * 9.0 + side * wide, b0 + side * 6.0, b0 - side * 6.0, tip + dir * 9.0 - side * wide])
	draw_colored_polygon(tuft, line)
	var inner := PackedVector2Array()
	var c := (tip + b0) / 2.0
	for p in tuft:
		inner.append(c + (p - c) * 0.8)
	draw_colored_polygon(inner, Color(0.95, 0.88, 0.7))
	# the paint on the bristles: bands of rainbow sliding along
	for k in 4:
		var u := float(k) / 4.0
		var col := rainbow(u + _t * 0.35)
		var a := tip.lerp(b0, u * 0.62)
		var w := 3.0 + 4.5 * sin(PI * (0.2 + u * 0.6))
		draw_line(a, tip.lerp(b0, u * 0.62 + 0.16), col, w * 2.0, true)
	draw_circle(tip + dir * 3.0, 3.5, rainbow(_t * 0.35))
	# a drip hanging off the tip
	var drip := fmod(_t * 0.8, 1.0)
	draw_circle(tip + Vector2(0, 4.0 + drip * 10.0), 2.6 * (1.0 - drip * 0.6), Color(rainbow(_t * 0.35), 1.0 - drip))
	# the ferrule: silver, with two crimp lines
	var f1 := b0 + dir * 12.0
	draw_line(b0, f1, line, 15.0)
	draw_line(b0, f1, Color(0.78, 0.8, 0.86), 12.0)
	draw_line(b0 + dir * 4.0 - side * 6.0, b0 + dir * 4.0 + side * 6.0, Color(0.5, 0.52, 0.58), 1.5)
	draw_line(b0 + dir * 8.0 - side * 6.0, b0 + dir * 8.0 + side * 6.0, Color(0.5, 0.52, 0.58), 1.5)
	# the wooden handle, tapering, with a red-painted end
	var h1 := f1 + dir * 34.0
	draw_colored_polygon(PackedVector2Array([f1 + side * 6.5, h1 + side * 4.0, h1 - side * 4.0, f1 - side * 6.5]), line)
	draw_colored_polygon(PackedVector2Array([f1 + side * 5.0, h1 + side * 2.6, h1 - side * 2.6, f1 - side * 5.0]), Color(0.78, 0.55, 0.3))
	draw_circle(h1, 4.5, line)
	draw_circle(h1, 3.2, Color(0.85, 0.25, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
