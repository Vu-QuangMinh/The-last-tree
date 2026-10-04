class_name CampfireSparks
extends Control
## Embers that fly off the fire: each one a random drawn spark, spinning as it rises, drifting from side to side, shrinking
## and fading as it cools.

var textures: Array[Texture2D] = []
var origin := Vector2(960, 800)  # where they are born (just above the flame)

const MAX := 26
var _p: Array = []  # {pos, vel, rot, spin, age, life, sc, tex, phase}
var _spawn := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(d: float) -> void:
	_spawn -= d
	while _spawn <= 0.0 and _p.size() < MAX:
		_spawn += randf_range(0.05, 0.22)
		_p.append({
			"pos": origin + Vector2(randf_range(-34.0, 34.0), randf_range(-10.0, 30.0)),
			"vel": Vector2(randf_range(-22.0, 22.0), -randf_range(70.0, 170.0)),
			"rot": randf() * TAU, "spin": randf_range(-6.0, 6.0),
			"age": 0.0, "life": randf_range(1.5, 3.6), "sc": randf_range(0.7, 1.4),
			"tex": randi() % textures.size(), "phase": randf() * TAU,
		})
	if _spawn <= 0.0:
		_spawn = 0.1
	var keep := []
	for q in _p:
		q.age += d
		if q.age >= q.life:
			continue
		q.pos += q.vel * d
		q.pos.x += sin(q.age * 3.2 + q.phase) * 34.0 * d  # drifts from side to side
		q.vel.y *= 1.0 - 0.18 * d  # slows as it cools
		q.rot += q.spin * d
		keep.append(q)
	_p = keep
	queue_redraw()


func _draw() -> void:
	for q in _p:
		var t: float = q.age / q.life
		var a := minf(t * 8.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, t))
		var tex: Texture2D = textures[q.tex]
		var s: float = q.sc * (1.0 - 0.45 * t)
		draw_set_transform(q.pos, q.rot, Vector2(s, s))
		draw_texture(tex, -tex.get_size() / 2.0, Color(1.0, 0.9 - 0.3 * t, 0.7 - 0.45 * t, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
