class_name BlockHpBar
extends HpBar
## Puppet Stage: your HP as 20 square blocks in a wooden tray, two rows of ten, each block 5% of your maximum HP (a partly lost block still
## stands until all of it is gone). Lose HP and the blocks from the end break into five pieces that fall and bounce, like the puppets; gain
## HP and new blocks are set in. The Shield is blue blocks set on top of the last red ones: when it breaks the red blocks show under it
## again, when it grows more blue blocks are put on.

const COLS := 10
const ROWS := 2
const COUNT := COLS * ROWS
const PAD := 8.0
const GAP := 2.0
const GRAVITY := 2200.0
const RED := Color(0.80, 0.17, 0.12)
const BLUE := Color(0.28, 0.58, 0.98)
const TRAY := Color(0.17, 0.10, 0.06)
const TRAY_EDGE := Color(0.42, 0.26, 0.13)
const CELL := Color(0.09, 0.05, 0.03)

## The painted tray (UI/Hp/hp_tray.png, 2712 x 575): its 20 cells are 226 px squares, 267 px apart, 41 px from the edge (measured on the picture).
const ART_W := 2712.0
const ART_H := 575.0
const ART_PAD := 41.0
const ART_CELL := 226.0
const ART_PITCH := 267.0

var _have: Array[int] = []  # per block: 0 none, 1 red, 2 blue (what stands there now)
var _drop: Array[float] = []  # per block: 1 -> 0 while its top piece is being set in (a negative number is a wait)
var _pieces: Array[Dictionary] = []  # the broken bits: {poly, pos, v, rot, w, col, age, floor, bounces}
var _blue_flash := 0.0


func _ready() -> void:
	_have.resize(COUNT)
	_have.fill(0)
	_drop.resize(COUNT)
	_drop.fill(0.0)


## The block size that fits the control's width.
func _block() -> float:
	if _painted():
		return ART_CELL * size.x / ART_W
	return (size.x - 2.0 * PAD - (COLS - 1) * GAP) / COLS


func _cell_pos(i: int) -> Vector2:
	if _painted():
		var k := size.x / ART_W
		return Vector2(ART_PAD + (i % COLS) * ART_PITCH, ART_PAD + (i / COLS) * ART_PITCH) * k
	var b := _block()
	return Vector2(PAD + (i % COLS) * (b + GAP), PAD + (i / COLS) * (b + GAP))


## True when the painted tray and blocks are there (Puppet theme art); otherwise everything is drawn in code.
func _painted() -> bool:
	return UiSkin.tex("hp_tray") != null and UiSkin.tex("hp_block_red") != null


## The picture of a block (red / blue) or of one of its two shards.
func _pic(col: Color, shard := "") -> Texture2D:
	return UiSkin.tex("hp_%s_%s%s" % ["shard" if shard != "" else "block", "blue" if col == BLUE else "red", "_" + shard if shard != "" else ""])


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
		out[n_hp - 1 - k] = 2  # (the shield sits on the last HP blocks)
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
			_shatter(i, BLUE if old == 2 else RED)
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


## Shield took a hit: the blue blocks flash.
func crack() -> void:
	_blue_flash = 1.0


## A block breaks into five pieces: the square is cut from a point near its middle to its four corners, and one of the four triangles is cut in two.
func _shatter(i: int, col: Color) -> void:
	var b := _block()
	var o := _cell_pos(i)
	var c := Vector2(b, b) * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.65))
	var corners := [Vector2(0, 0), Vector2(b, 0), Vector2(b, b), Vector2(0, b)]
	var polys: Array = []
	var split := randi() % 4
	for k in 4:
		var a: Vector2 = corners[k]
		var d: Vector2 = corners[(k + 1) % 4]
		if k == split:
			var m := a.lerp(d, randf_range(0.35, 0.65))
			polys.append([c, a, m])
			polys.append([c, m, d])
		else:
			polys.append([c, a, d])
	var mid := o + Vector2(b, b) / 2.0
	var art := _painted()
	for poly in polys:
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= poly.size()
		var local := PackedVector2Array()
		for p in poly:
			local.append(p - cen)
		var world := o + cen
		var dir := (world - mid)
		dir = dir.normalized() if dir.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		_pieces.append({
			"poly": local, "pos": world, "v": dir * randf_range(120.0, 330.0) + Vector2(randf_range(-40.0, 40.0), -randf_range(160.0, 330.0)),
			"rot": randf() * TAU, "w": randf_range(-10.0, 10.0), "col": col.lerp(Color.WHITE, randf_range(0.0, 0.12)),
			"tex": _pic(col, "a" if randf() < 0.5 else "b") if art else null, "age": 0.0, "floor": size.y + randf_range(-6.0, 30.0), "bounces": 0, "rest": randf_range(0.35, 0.8),
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


func _face(col: Color, flash: float) -> Color:
	return col.lerp(Color(1, 1, 1), clampf(flash, 0.0, 1.0) * 0.6)


## One block: a bevelled square (light top edge, dark bottom edge).
func _draw_block(at: Vector2, b: float, col: Color, flash := 0.0, scale_y := 1.0) -> void:
	var r := Rect2(at, Vector2(b, b * scale_y))
	draw_rect(r, _face(col.darkened(0.45), flash))
	var inner := r.grow(-2.0)
	draw_rect(inner, _face(col, flash))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 3.0)), _face(col.lightened(0.35), flash))  # (the lit top edge)
	draw_rect(Rect2(inner.position, Vector2(3.0, inner.size.y)), _face(col.lightened(0.18), flash))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 3.0), Vector2(inner.size.x, 3.0)), _face(col.darkened(0.3), flash))
	draw_rect(Rect2(inner.position + Vector2(inner.size.x - 3.0, 0), Vector2(3.0, inner.size.y)), _face(col.darkened(0.2), flash))


func _draw() -> void:
	var b := _block()
	if _painted():
		_draw_painted(b)
		return
	# the tray: dark wood, a lighter rim, and a dark cell for every block
	draw_rect(Rect2(Vector2.ZERO, size), TRAY_EDGE)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-3.0), TRAY)
	for i in COUNT:
		var o := _cell_pos(i)
		draw_rect(Rect2(o - Vector2(1, 1), Vector2(b + 2, b + 2)), CELL)
	for c in range(1, COLS):  # the dividers between the cells: thin wooden slats
		var x := PAD + c * (b + GAP) - GAP / 2.0
		draw_line(Vector2(x, 3.0), Vector2(x, size.y - 3.0), TRAY_EDGE, 2.0)
	draw_line(Vector2(3.0, PAD + b + GAP / 2.0), Vector2(size.x - 3.0, PAD + b + GAP / 2.0), TRAY_EDGE, 2.0)
	# the blocks (a block being set in drops from above: it falls, squashes a little and settles)
	for i in COUNT:
		var st := _have[i]
		if st == 0:
			continue
		var o := _cell_pos(i)
		var dp := _drop[i]
		if st == 2:
			# the red block stays under the blue one, which may be on its way down
			_draw_block(o, b, RED, 0.0)
			if dp > 1.0:
				continue  # (still waiting for its turn)
			_draw_block(o + Vector2(0, -42.0 * dp * dp), b, BLUE, _blue_flash)
		else:
			if dp > 1.0:
				continue
			_draw_block(o + Vector2(0, -42.0 * dp * dp), b, RED, 0.0)
	# the broken bits
	for pc in _pieces:
		var fade := 1.0 if pc.bounces >= 0 else clampf(1.0 - (pc.age - pc.rest) / 0.5, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var pts := PackedVector2Array()
		var xf := Transform2D(pc.rot, pc.pos)
		for p in pc.poly:
			pts.append(xf * p)
		var col: Color = pc.col
		draw_colored_polygon(pts, Color(col, fade))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, Color(col.darkened(0.55), fade), 1.6)


## The painted version of _draw: the tray picture, the wooden blocks (blue ones on the red ones) and the real shards of a broken block.
func _draw_painted(b: float) -> void:
	draw_texture_rect(UiSkin.tex("hp_tray"), Rect2(Vector2.ZERO, Vector2(size.x, size.x * ART_H / ART_W)), false)
	for i in COUNT:
		var st := _have[i]
		if st == 0:
			continue
		var o := _cell_pos(i)
		var dp := _drop[i]
		if st == 2:
			draw_texture_rect(_pic(RED), Rect2(o, Vector2(b, b)), false)
			if dp > 1.0:
				continue
			var flash := Color(1, 1, 1, 1).lerp(Color(1.6, 1.6, 1.6, 1), _blue_flash)
			draw_texture_rect(_pic(BLUE), Rect2(o + Vector2(0, -42.0 * dp * dp), Vector2(b, b)), false, flash)
		else:
			if dp > 1.0:
				continue
			draw_texture_rect(_pic(RED), Rect2(o + Vector2(0, -42.0 * dp * dp), Vector2(b, b)), false)
	for pc in _pieces:
		var tex: Texture2D = pc.get("tex")
		if tex == null:
			continue
		var fade := 1.0 if pc.bounces >= 0 else clampf(1.0 - (pc.age - pc.rest) / 0.5, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var half := b * 0.3  # (a shard is about 60% of a block)
		draw_set_transform(pc.pos, pc.rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(Vector2(-half, -half), Vector2(half, half) * 2.0), false, Color(1, 1, 1, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
