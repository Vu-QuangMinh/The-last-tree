class_name BackdropFx
extends Control
## New theme: the little things that drift in front of a painted background. Act 1: a few leaves tumbling gently.
## Act 2: fireflies that wander and flicker. Act 3: round snowflakes sinking slowly. Everything is deterministic from a
## fixed seed (no two runs differ), slow and soft so the cards on top stay easy to read.

var act := 1

var _t := 0.0
var _bits: Array = []  # per particle: a Dictionary of its own constants


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := RandomNumberGenerator.new()
	g.seed = 7000 + act
	var n: int = {1: 14, 2: 24, 3: 70}.get(act, 0)
	for i in n:
		_bits.append({
			"x": g.randf(), "y": g.randf(),
			"speed": g.randf_range(0.6, 1.4),  # how fast it drifts
			"phase": g.randf() * TAU,
			"size": g.randf_range(0.7, 1.3),
			"tone": g.randf(),
		})


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0:
		return
	for b in _bits:
		match act:
			1:
				_leaf(b, w, h)
			2:
				_firefly(b, w, h)
			3:
				_snow(b, w, h)


## A leaf: drifts left to right and slowly down, swaying and turning as it goes.
func _leaf(b: Dictionary, w: float, h: float) -> void:
	var u := fposmod(b.x + _t * 0.018 * b.speed, 1.0)
	var v := fposmod(b.y + _t * 0.012 * b.speed, 1.0)
	var pos := Vector2(u * (w + 80.0) - 40.0 + sin(_t * 0.9 * b.speed + b.phase) * 26.0, v * (h * 0.78) + sin(_t * 1.3 + b.phase) * 10.0)
	var ang: float = sin(_t * 0.8 * b.speed + b.phase) * 0.9 + b.phase
	var s: float = 12.0 * b.size
	var col := Color(0.42, 0.62, 0.22).lerp(Color(0.8, 0.72, 0.25), b.tone)
	var pts := PackedVector2Array()
	for k in 9:  # a pointed oval
		var a := k / 8.0 * PI
		pts.append(Vector2(cos(a) * s, sin(a) * s * 0.42))
	for k in range(7, 0, -1):
		var a := k / 8.0 * PI
		pts.append(Vector2(cos(a) * s, -sin(a) * s * 0.42))
	draw_set_transform(pos, ang, Vector2.ONE)
	draw_colored_polygon(pts, Color(col, 0.9))
	draw_line(Vector2(-s, 0), Vector2(s * 0.8, 0), col.darkened(0.35), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A firefly: a soft warm glow wandering on a slow loop, blinking on and off.
func _firefly(b: Dictionary, w: float, h: float) -> void:
	var pos := Vector2(
		(b.x + sin(_t * 0.11 * b.speed + b.phase) * 0.06) * w,
		(0.28 + b.y * 0.55 + cos(_t * 0.15 * b.speed + b.phase * 2.0) * 0.05) * h)
	var blink := clampf(0.5 + 0.62 * sin(_t * (1.1 + b.speed) + b.phase * 3.0), 0.0, 1.0)
	if blink < 0.03:
		return
	var s: float = b.size
	draw_circle(pos, 17.0 * s, Color(0.85, 1.0, 0.45, 0.07 * blink))
	draw_circle(pos, 9.0 * s, Color(0.9, 1.0, 0.5, 0.16 * blink))
	draw_circle(pos, 3.6 * s, Color(1.0, 1.0, 0.75, 0.95 * blink))


## A snowflake: a plain round dot, sinking slowly and wobbling from side to side.
func _snow(b: Dictionary, w: float, h: float) -> void:
	var v := fposmod(b.y + _t * 0.022 * b.speed, 1.0)
	var pos := Vector2(fposmod(b.x + sin(_t * 0.5 * b.speed + b.phase) * 0.012, 1.0) * w, v * (h + 20.0) - 10.0)
	var s: float = 2.2 + 3.0 * b.size
	draw_circle(pos, s + 1.5, Color(1, 1, 1, 0.12))
	draw_circle(pos, s, Color(0.96, 0.98, 1.0, 0.85))
