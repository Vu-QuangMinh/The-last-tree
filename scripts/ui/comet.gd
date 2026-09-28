class_name Comet
extends Control
## A chant element released at an enemy: it lifts off, arcs up and flies in as a glowing comet, shedding
## dust in its element's colour. `arrived` fires when the head reaches the target; the dust lingers a moment.

signal arrived

var from := Vector2.ZERO
var to := Vector2.ZERO
var col := Color.WHITE
var dur := 0.42
var rise := 140.0  # how high the arc climbs above the straight line
var fizzle := false  # no target: it just rises and bursts
var _t := 0.0
var _done := false
var _dust: Array = []  # [pos, vel, life, size]
var _rng := RandomNumberGenerator.new()


static func launch(parent: Control, p_from: Vector2, p_to: Vector2, p_col: Color, p_fizzle := false) -> Comet:
	var c := Comet.new()
	c.from = p_from
	c.to = p_to
	c.col = p_col
	c.fizzle = p_fizzle
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.z_index = 40
	parent.add_child(c)
	return c


func _ready() -> void:
	_rng.randomize()


func _point(t: float) -> Vector2:
	var ctrl := (from + to) / 2.0 + Vector2(0, -rise)
	return from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)


func _process(d: float) -> void:
	if not _done:
		_t = minf(1.0, _t + d / dur)
		# ease in: slow lift-off, fast arrival
		var head := _point(_t * _t * (3.0 - 2.0 * _t))
		for i in 3:
			var v := Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-20, 50))
			_dust.append([head + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)), v, 1.0, _rng.randf_range(2.0, 5.0)])
		if _t >= 1.0:
			_done = true
			# a little burst of sparks on impact
			for i in 16:
				var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 220)
				_dust.append([to, v, 1.0, _rng.randf_range(2.5, 6.0)])
			arrived.emit()
	for p in _dust:
		p[0] += p[1] * d
		p[1] *= 0.92
		p[2] -= d * 1.8
	_dust = _dust.filter(func(p): return p[2] > 0.0)
	if _done and _dust.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for p in _dust:
		var c := col.lerp(Color.WHITE, 0.25)
		c.a = p[2] * 0.8
		draw_circle(p[0], p[3] * p[2], c)
	if _done:
		return
	var e := _t * _t * (3.0 - 2.0 * _t)
	# tail: samples behind the head, thinner and fainter further back
	var n := 14
	for i in n:
		var tt := maxf(0.0, e - i * 0.018)
		var r := 13.0 * (1.0 - float(i) / n)
		var c := col
		c.a = 0.55 * (1.0 - float(i) / n)
		draw_circle(_point(tt), r, c)
	var head := _point(e)
	draw_circle(head, 20.0, Color(col, 0.25))
	draw_circle(head, 12.0, col.lightened(0.3))
	draw_circle(head, 6.0, Color(1, 1, 1, 0.95))
