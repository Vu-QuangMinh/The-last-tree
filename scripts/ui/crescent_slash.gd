class_name CrescentSlash
extends Node2D
## The Samurai's air slash: a pale crescent that flies out of his sword and cuts a chant Essence out of the air
## (his Deflect). `arrived` fires when it reaches the Essence; then it flares and fades.

signal arrived

const R := 34.0  # the crescent's radius
var from := Vector2.ZERO
var to := Vector2.ZERO
var dur := 0.42
var _t := 0.0
var _fade := 1.0
var _done := false


static func launch(parent: Node, p_from: Vector2, p_to: Vector2, p_dur := 0.42) -> CrescentSlash:
	var c := CrescentSlash.new()
	c.from = p_from
	c.to = p_to
	c.dur = p_dur
	c.position = p_from
	c.rotation = (p_to - p_from).angle()
	c.z_index = 41  # (just over the comets)
	parent.add_child(c)
	return c


func _process(d: float) -> void:
	if not _done:
		_t = minf(1.0, _t + d / dur)
		var e := 1.0 - pow(1.0 - _t, 2.0)  # (out of the sword fast, then it slows a little)
		position = from.lerp(to, e)
		scale = Vector2.ONE * lerpf(0.5, 1.15, e)
		if _t >= 1.0:
			_done = true
			arrived.emit()
	else:
		_fade -= d / 0.18
		scale *= 1.0 + d * 2.5
		if _fade <= 0.0:
			queue_free()
			return
	queue_redraw()


## The crescent: an outer arc facing where it flies, and an inner one set back, so the middle is thick and the
## horns are sharp. A soft wider copy behind it is its glow.
func _shape(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var a := lerpf(-1.25, 1.25, float(i) / n)
		pts.append(Vector2.from_angle(a) * r)
	for i in n + 1:
		var a := lerpf(1.25, -1.25, float(i) / n)
		pts.append(Vector2(-r * 0.42, 0) + Vector2.from_angle(a) * r * 1.02)
	return pts


func _draw() -> void:
	var a := clampf(_fade, 0.0, 1.0)
	draw_colored_polygon(_shape(R * 1.35), Color(0.75, 0.95, 1.0, 0.22 * a))
	draw_colored_polygon(_shape(R), Color(0.92, 1.0, 1.0, 0.95 * a))
