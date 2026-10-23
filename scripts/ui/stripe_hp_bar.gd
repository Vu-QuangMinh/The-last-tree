class_name StripeHpBar
extends HpBar
## Puppet Stage: your HP as the 16 candy stripes of the painted bar (UI/Hp/hp_piece_NN.png, already clipped to the bar's window), so every stripe is
## 1/16 of your maximum HP (a partly lost stripe still stands until all of it is gone). Lose HP and the stripes from the right end break into five
## pieces that fall and bounce, like the puppets, leaving the dark track empty; gain HP and new stripes are set in. The Shield is blue stripes
## (hp_shield_NN.png) laid over the last HP stripes: when it breaks the red / white ones show under it again, when it grows more blue ones are put on.
## All pictures share one canvas (tools/export_hp_bar.py), so each is drawn at the same place.

const COUNT := 16
const GRAVITY := 2200.0
const BLUE := Color(0.28, 0.58, 0.98)
const RED := Color(0.80, 0.17, 0.12)
const TRACK := Color(0.19, 0.11, 0.10)
## The canvas of the pictures in design px (the bar's box on the page); the frame picture is 2 px per pt.
const CANVAS := Vector2(276.0, 57.0)
## The window the stripes lie in (design px on the canvas), for the plain fallback drawing and for where a bolt sticks.
const WINDOW := Rect2(59.4, 13.2, 202.4, 19.5)

static var _used := {}  # picture -> the box that is drawn in it (in canvas px)

var _have: Array[int] = []  # per stripe: 0 none, 1 HP, 2 shield (what stands there now)
var _drop: Array[float] = []  # per stripe: 1 -> 0 while it is being set in (a number above 1 is a wait)
var _pieces: Array[Dictionary] = []  # the broken bits: {poly, uv, pos, v, rot, w, tex, age, floor, bounces, rest}
var _blue_flash := 0.0


func _ready() -> void:
	_have.resize(COUNT)
	_have.fill(0)
	_drop.resize(COUNT)
	_drop.fill(0.0)


## Design px of the canvas -> px of this control.
func _k() -> float:
	return size.x / CANVAS.x


func _painted() -> bool:
	return UiSkin.tex("hp_bar_frame") != null and UiSkin.tex("hp_piece_00") != null


func _piece(k: int, shield: bool) -> Texture2D:
	return UiSkin.tex("hp_%s_%02d" % ["shield" if shield else "piece", k])


## Where in the canvas (design px) a stripe's picture really draws something.
func _box(tex: Texture2D) -> Rect2:
	if not _used.has(tex):
		var r := tex.get_image().get_used_rect()
		var k := CANVAS.x / float(tex.get_width())
		_used[tex] = Rect2(Vector2(r.position) * k, Vector2(r.size) * k)
	return _used[tex]


## The screen point (global) of the bar at a fraction of its window, for a bolt that sticks there.
func point_at(frac: float) -> Vector2:
	var k := _k()
	return get_global_transform() * (Vector2(WINDOW.position.x + WINDOW.size.x * clampf(frac, 0.0, 1.0), WINDOW.position.y + WINDOW.size.y * 0.5) * k)


func _want(p_hp: float, p_max: float, p_shield: float) -> Array[int]:
	var unit := maxf(1.0, p_max) / float(COUNT)
	var n_hp := clampi(ceili(maxf(0.0, p_hp) / unit - 0.001), 0, COUNT)
	var n_sh := mini(n_hp, ceili(maxf(0.0, p_shield) / unit - 0.001))
	var out: Array[int] = []
	out.resize(COUNT)
	out.fill(0)
	for i in n_hp:
		out[i] = 1
	for k in n_sh:
		out[n_hp - 1 - k] = 2  # (the shield sits on the last HP stripes)
	return out


func set_values(p_hp: float, p_max: float, p_shield: float) -> void:
	if _have.size() != COUNT:
		_ready()
	var first := not _shown
	hp = maxf(0.0, p_hp)
	max_hp = maxf(1.0, p_max)
	shield = maxf(0.0, p_shield)
	var want := _want(p_hp, p_max, p_shield)
	if first:
		_shown = true
		_have = want.duplicate()
		return
	var broke := false
	var placed := 0
	var delay := 0.0
	for i in COUNT:
		var old := _have[i]
		var nw := want[i]
		if old == nw:
			continue
		if old > 0 and (nw == 0 or (old == 2 and nw == 1)):
			_shatter(i, old == 2)
			broke = true
		if nw > old and (old == 0 or (old == 1 and nw == 2)):
			_drop[i] = 1.0 + delay / 0.28  # (set in one after the other, left to right; a drop lasts 0.28 s)
			delay += 0.07
			placed += 1
	_have = want
	if broke:
		Audio.play("wooden_ball_colide", 0.0, randf_range(0.85, 1.05))
	if placed > 0:
		Audio.play("wooden_ball_hole", 0.0, randf_range(0.95, 1.1), 0.06)


## Shield took a hit: the blue stripes flash.
func crack() -> void:
	_blue_flash = 1.0


## A stripe breaks into five pieces: its box is cut from a point near its middle to its four corners, and one of the four triangles is cut in two.
## Each piece carries its part of the stripe's own picture.
func _shatter(i: int, blue: bool) -> void:
	var tex := _piece(i, blue) if _painted() else null
	var k := _k()
	var box := _box(tex) if tex != null else Rect2(WINDOW.position + Vector2(WINDOW.size.x * float(i) / COUNT, 0.0), Vector2(WINDOW.size.x / COUNT, WINDOW.size.y))
	var o := box.position * k
	var s := box.size * k
	var c := o + s * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
	var corners := [o, o + Vector2(s.x, 0), o + s, o + Vector2(0, s.y)]
	var polys: Array = []
	var split := randi() % 4
	for n in 4:
		var a: Vector2 = corners[n]
		var d: Vector2 = corners[(n + 1) % 4]
		if n == split:
			var m := a.lerp(d, randf_range(0.35, 0.65))
			polys.append([c, a, m])
			polys.append([c, m, d])
		else:
			polys.append([c, a, d])
	var mid := o + s / 2.0
	for poly in polys:
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= poly.size()
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for p in poly:
			local.append(p - cen)
			uv.append(p / (CANVAS * k))
		var dir: Vector2 = cen - mid
		dir = dir.normalized() if dir.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		_pieces.append({
			"poly": local, "uv": uv, "pos": cen, "v": dir * randf_range(120.0, 330.0) + Vector2(randf_range(-40.0, 40.0), -randf_range(160.0, 330.0)),
			"rot": randf() * TAU, "w": randf_range(-10.0, 10.0), "tex": tex, "col": BLUE if blue else RED, "age": 0.0,
			"floor": size.y + randf_range(-6.0, 30.0), "bounces": 0, "rest": randf_range(0.35, 0.8),
		})


func _process(d: float) -> void:
	_t += d
	_blue_flash = maxf(0.0, _blue_flash - d * 3.0)
	for i in COUNT:
		if _drop[i] != 0.0:
			_drop[i] = maxf(0.0, _drop[i] - d / 0.28) if _drop[i] > 0.0 else 0.0
	var keep: Array[Dictionary] = []
	for pc in _pieces:
		if pc.bounces >= 0:
			pc.v.y += GRAVITY * d
			pc.pos += pc.v * d
			pc.rot += pc.w * d
			if pc.pos.y >= pc.floor and pc.v.y > 0.0:
				pc.pos.y = pc.floor
				pc.bounces += 1
				if pc.bounces >= 3 or absf(pc.v.y) < 120.0:
					pc.bounces = -1
				else:
					pc.v = Vector2(pc.v.x * 0.55, -pc.v.y * 0.35)
					pc.w *= 0.5
		else:
			pc.age += d
		if pc.age < pc.rest + 0.5:
			keep.append(pc)
	_pieces = keep
	queue_redraw()


func _draw() -> void:
	var k := _k()
	var art := _painted()
	if art:
		draw_texture_rect(UiSkin.tex("hp_bar_frame"), Rect2(Vector2.ZERO, CANVAS * k), false)
	else:
		draw_rect(Rect2(WINDOW.position * k, WINDOW.size * k), TRACK)
	# the HP stripes, left to right (each lies a little over the one before it), then the Shield stripes over them. A stripe being set in drops from above.
	for layer in [1, 2]:
		for i in COUNT:
			if _have[i] < layer or (layer == 2 and _have[i] != 2) or _drop[i] > 1.0:
				continue
			var at := Vector2(0.0, -42.0 * _drop[i] * _drop[i])
			var tint := Color.WHITE.lerp(Color(1.6, 1.6, 1.6, 1.0), _blue_flash) if layer == 2 else Color.WHITE
			if art:
				draw_texture_rect(_piece(i, layer == 2), Rect2(at, CANVAS * k), false, tint)
			else:
				var cell := Rect2(WINDOW.position * k + Vector2(WINDOW.size.x * k * float(i) / COUNT, 0.0), Vector2(WINDOW.size.x * k / COUNT, WINDOW.size.y * k)).grow_individual(0, 0, -1, 0)
				draw_rect(Rect2(cell.position + at, cell.size), tint * (BLUE if layer == 2 else RED))
	# the broken bits
	for pc in _pieces:
		var fade := 1.0 if pc.bounces >= 0 else clampf(1.0 - (pc.age - pc.rest) / 0.5, 0.0, 1.0)
		if fade <= 0.0:
			continue
		draw_set_transform(pc.pos, pc.rot, Vector2.ONE)
		if pc.tex != null:
			draw_colored_polygon(pc.poly, Color(1, 1, 1, fade), pc.uv, pc.tex)
		else:
			draw_colored_polygon(pc.poly, Color(pc.col, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

