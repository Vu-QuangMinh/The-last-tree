class_name BoostLine
extends Control
## Something raised something else (the user, 2026-11-22): a thin streak of light, like a shooting star, arcs (clearly)
## from the source (a carved marble in the chant, a card) to the middle of what it raised (a card, you), shedding a quick
## trail of dust, and flashes there. Red: damage, blue: Shield, green: HP, yellow: anything else. Drawn on the fight
## screen's effects layer; the target's own shake and flash is FightScreen._boost_landed (on_land).

const COLS := {"dmg": Color(1.0, 0.3, 0.22), "shield": Color(0.35, 0.65, 1.0), "hp": Color(0.35, 0.95, 0.45), "other": Color(1.0, 0.84, 0.28)}
const FLY := 0.4  # seconds for the head to reach its target
const TRAIL := 0.32  # the bright streak's length, as a share of the path
const FLASH := 0.3
const SEGS := 26
const DUST_LIFE := 0.45

var a := Vector2.ZERO
var b := Vector2.ZERO
var ctrl := Vector2.ZERO
var col := Color.WHITE
var _t := 0.0
var _landed := false
var _dust: Array = []  # [pos, vel, life left, size]
var _rng := RandomNumberGenerator.new()
var on_land := Callable()  # (called once when the head arrives: the target reacts)


## A streak from `from` to `to` (in `layer`'s coordinates), of kind "dmg", "shield", "hp" or "other".
static func shoot(layer: Control, from: Vector2, to: Vector2, kind: String) -> BoostLine:
	var l := BoostLine.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.z_index = 80
	l.a = from
	l.b = to
	var d := to - from
	var side := d.orthogonal().normalized()
	if side.y > 0.0:
		side = -side  # (it always arcs upwards)
	l.ctrl = from.lerp(to, 0.5) + side * clampf(d.length() * 0.45, 70.0, 300.0)  # (a clear arc)
	l.col = COLS.get(kind, COLS.other)
	l._rng.randomize()
	layer.add_child(l)
	return l


func _process(dt: float) -> void:
	_t += dt
	if _t < FLY:  # (dust shed from the head: it drifts off and fades fast)
		var hp := _pt(_head())
		var dir := (_pt(minf(1.0, _head() + 0.02)) - hp).normalized()
		for k in 3:
			var vel := -dir * _rng.randf_range(20.0, 70.0) + Vector2(_rng.randf_range(-35.0, 35.0), _rng.randf_range(-35.0, 25.0))
			_dust.append([hp + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)), vel, DUST_LIFE * _rng.randf_range(0.5, 1.0), _rng.randf_range(1.0, 2.6)])
	for p in _dust:
		p[0] += p[1] * dt
		p[1] *= 0.9
		p[1].y += 40.0 * dt  # (it settles a little)
		p[2] -= dt
	_dust = _dust.filter(func(p): return p[2] > 0.0)
	if not _landed and _t >= FLY:
		_landed = true
		if on_land.is_valid():
			on_land.call()
	if _t > FLY * (1.0 + TRAIL) + FLASH and _dust.is_empty():
		queue_free()
	queue_redraw()


func _head() -> float:
	var h := clampf(_t / FLY, 0.0, 1.0)
	return 1.0 - (1.0 - h) * (1.0 - h)  # (quick off the mark, easing into its target)


func _pt(u: float) -> Vector2:
	var v := 1.0 - u
	return a * v * v + ctrl * 2.0 * v * u + b * u * u


func _draw() -> void:
	for p in _dust:
		var k: float = p[2] / DUST_LIFE
		draw_circle(p[0], p[3] * (0.6 + 0.4 * k), Color(col.lightened(0.35), 0.85 * k))
	var head := _head()
	var tail := clampf((_t - FLY * TRAIL) / FLY, 0.0, 1.0)
	if head > tail:
		var prev := _pt(tail)
		for k in range(1, SEGS + 1):
			var u := lerpf(tail, head, float(k) / SEGS)
			var p := _pt(u)
			var s := float(k) / SEGS  # 0 at the tail, 1 at the head
			draw_line(prev, p, Color(0.08, 0.03, 0.02, 0.3 * s), 4.0 * s + 1.2, true)  # (a dark edge: it reads on the bright cards too)
			draw_line(prev, p, Color(col, 0.3 * s), 7.0 * s + 1.0, true)  # (soft glow)
			draw_line(prev, p, Color(col.lightened(0.3), s), 2.2 * s + 0.5, true)  # (the thin bright core)
			prev = p
	if _t < FLY:
		var hp := _pt(head)
		draw_circle(hp, 11.0, Color(col, 0.3))
		draw_circle(hp, 5.5, Color(col.lightened(0.3), 1.0))
		draw_circle(hp, 2.8, Color(1, 1, 1, 1))
	else:
		var f := clampf((_t - FLY) / FLASH, 0.0, 1.0)
		draw_circle(b, 10.0 + 30.0 * f, Color(col, 0.4 * (1.0 - f)))
		draw_arc(b, 8.0 + 40.0 * f, 0.0, TAU, 32, Color(col.lightened(0.2), 0.9 * (1.0 - f)), 3.0, true)
		draw_circle(b, 5.0 * (1.0 - f), Color(1, 1, 1, 1.0 - f))
