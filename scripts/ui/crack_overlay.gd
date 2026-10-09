class_name CrackOverlay
extends Control
## Glass-like cracks over a spell card the Hammer Hand has hit: level 1, a few cracks out from the impact; level 2,
## cracks all over. Each crack is a jagged line (a dark core with a pale edge beside it, like broken glass), branching
## as it goes, with a few rings joining the rays near the impact. The pattern is fixed per card (seeded by its id).

var level := 0
var seed_key := ""
var margins := [6.0, 7.0, 6.0, 5.0]  # the card's content margins: the cracks reach the frame
var zoom := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_level(n: int, key: String) -> void:
	if n == level and key == seed_key:
		return
	level = n
	seed_key = key
	visible = n > 0
	queue_redraw()


func _draw() -> void:
	if level <= 0:
		return
	var r := Rect2(Vector2(-margins[0], -margins[1]), size + Vector2(margins[0] + margins[2], margins[1] + margins[3]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var hits := [r.position + r.size * Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.6))]
	if level >= 2:
		hits.append(r.position + r.size * Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.8)))
	for k in hits.size():
		var at: Vector2 = hits[k]
		var rays := 5 if level == 1 else 9
		var reach := (0.35 if level == 1 else 1.0) * r.size.length()
		var ends := []
		for i in rays:
			var ang := TAU * i / rays + rng.randf_range(-0.3, 0.3)
			var pts := _jagged(rng, at, ang, reach * rng.randf_range(0.5, 1.0), r)
			_crack(pts)
			ends.append(pts)
			# a branch or two
			if level >= 2 or rng.randf() < 0.4:
				var j := rng.randi_range(1, maxi(1, pts.size() - 2))
				_crack(_jagged(rng, pts[j], ang + rng.randf_range(-0.9, 0.9), reach * 0.35, r))
		# rings joining the rays near the impact (the spider-web look)
		for ring in (1 if level == 1 else 2):
			var t := 0.18 + 0.2 * ring
			for i in ends.size():
				var a: PackedVector2Array = ends[i]
				var b: PackedVector2Array = ends[(i + 1) % ends.size()]
				var ia := mini(a.size() - 1, int(a.size() * t) + 1)
				var ib := mini(b.size() - 1, int(b.size() * t) + 1)
				if rng.randf() < 0.75:
					_crack(PackedVector2Array([a[ia], (a[ia] + b[ib]) / 2.0 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) * zoom, b[ib]]))
		# the impact itself: a small crushed star
		draw_circle(at, 3.0 * zoom, Color(1, 1, 1, 0.55))


func _jagged(rng: RandomNumberGenerator, from: Vector2, ang: float, length: float, r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var p := from
	var step := 9.0 * zoom
	var travelled := 0.0
	while travelled < length:
		ang += rng.randf_range(-0.35, 0.35)
		p += Vector2(cos(ang), sin(ang)) * step
		travelled += step
		if not r.has_point(p):
			p = p.clamp(r.position, r.end)
			pts.append(p)
			break
		pts.append(p)
	return pts


func _crack(pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(1, 1, 1, 0.55), 2.6 * zoom, true)  # the pale chipped edge
	draw_polyline(pts, Color(0.12, 0.1, 0.1, 0.85), 1.3 * zoom, true)  # the crack
