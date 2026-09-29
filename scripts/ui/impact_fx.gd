class_name ImpactFx
extends Control
## An enemy's hit landing on you: three slash marks tear across, sparks burst out, then everything fades.
## Blue when your Shield took it, red when it hurt.

var at := Vector2.ZERO
var col := Color(1, 0.3, 0.25)
var _t := 0.0
var _sparks: Array = []  # [pos, vel, life]
var _rng := RandomNumberGenerator.new()

const LIFE := 0.55


static func burst(parent: Control, p_at: Vector2, blocked: bool) -> ImpactFx:
	var fx := ImpactFx.new()
	fx.at = p_at
	fx.col = Color(0.55, 0.85, 1.0) if blocked else Color(1, 0.3, 0.25)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.z_index = 45
	parent.add_child(fx)
	return fx


func _ready() -> void:
	_rng.randomize()
	for i in 22:
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(120, 420)
		_sparks.append([at, v, 1.0])


func _process(d: float) -> void:
	_t += d
	for s in _sparks:
		s[0] += s[1] * d
		s[1] *= 0.9
		s[2] -= d * 2.2
	queue_redraw()
	if _t > LIFE + 0.3:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / 0.12, 0, 1)  # slashes grow in fast
	var fade := clampf(1.0 - (_t - 0.15) / LIFE, 0, 1)
	for i in 3:
		var off := Vector2((i - 1) * 34.0, (i - 1) * -8.0)
		var a := at + off + Vector2(-70, -60)
		var b := at + off + Vector2(70, 60)
		var e := a.lerp(b, k)
		draw_line(a, e, Color(col, fade * 0.35), 16.0)
		draw_line(a, e, Color(col.lightened(0.3), fade), 6.0)
		draw_line(a, e, Color(1, 1, 1, fade), 2.0)
	draw_circle(at, 46.0 * (1.0 - fade * 0.5), Color(col, 0.25 * fade))
	for s in _sparks:
		if s[2] > 0.0:
			draw_circle(s[0], 3.5 * s[2], Color(col.lightened(0.4), s[2]))
