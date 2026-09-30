class_name ShardBurst
extends Control
## A shattering orb: jagged shards in its element's colour fly outwards, spinning and fading, with a quick flash.

var at := Vector2.ZERO
var col := Color.WHITE
var size_px := 40.0
var _shards: Array = []  # [pos, vel, angle, spin, size, life]
var _flash := 1.0


static func burst(parent: Control, p_at: Vector2, p_col: Color, p_size := 40.0) -> ShardBurst:
	var b := ShardBurst.new()
	b.at = p_at
	b.col = p_col
	b.size_px = p_size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.z_index = 45
	parent.add_child(b)
	return b


func _ready() -> void:
	var n := 10 + int(size_px / 8.0)
	for i in n:
		var dir := Vector2.from_angle(randf() * TAU)
		var speed := randf_range(120.0, 320.0) * (size_px / 40.0)
		_shards.append([at + dir * size_px * 0.2, dir * speed, randf() * TAU, randf_range(-9.0, 9.0), randf_range(0.18, 0.34) * size_px, 1.0])


func _process(d: float) -> void:
	_flash = maxf(0.0, _flash - d * 5.0)
	for s in _shards:
		s[0] += s[1] * d
		s[1] = s[1] * 0.9 + Vector2(0, 380.0 * d)  # slow down, then fall a little
		s[2] += s[3] * d
		s[5] -= d * 1.6
	_shards = _shards.filter(func(s): return s[5] > 0.0)
	if _shards.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _flash > 0.0:
		draw_circle(at, size_px * (0.6 + (1.0 - _flash) * 0.6), Color(1, 1, 0.9, 0.55 * _flash))
	for s in _shards:
		var p: Vector2 = s[0]
		var r: float = s[4]
		var a: float = s[2]
		# a jagged triangle shard
		var pts := PackedVector2Array([p + Vector2.from_angle(a) * r, p + Vector2.from_angle(a + 2.3) * r * 0.55, p + Vector2.from_angle(a + 3.9) * r * 0.8])
		draw_colored_polygon(pts, Color(col.lightened(0.15), s[5]))
		pts.append(pts[0])
		draw_polyline(pts, Color(col.darkened(0.5), s[5]), 1.5)
