class_name PuppetShatter
extends Node2D
## Puppet Stage: a defeated puppet bursts into about ten pieces of different sizes. The picture is cut along random lines (a power diagram:
## every piece is a convex cell round a random seed, the seeds having different weights); each piece is a flat plank with a dark brown edge
## (the same picture stacked a few times, tinted, behind it). The pieces fly out from the middle of the puppet, fall to the floor, bounce a
## little, lie there a moment and fade away.

const PIECES := 10
const GRAVITY := 2000.0
const EDGE := Color(0.2, 0.11, 0.05)

var _pieces: Array[Dictionary] = []  # {node, v, w, floor, bounces, rest, age}
var _t := 0.0

## Reform (a boss rising for its second phase): the same burst, then the pieces lie still a moment and are pulled back up
## into the puppet along the very paths they fell by (the flight is worked out first and played forward, then backward).
signal reformed
const STEP := 1.0 / 60.0
const HOLD := 0.45  # (seconds the pieces lie on the floor before they fly back)
var _reform := false
var _track: Array = []  # per step: [[position, rotation] per piece]


## Break `creature`'s puppet and pull it back together (see `reformed`). null when it has no cut-out.
static func spawn_reform(host: Node, creature: Creature) -> PuppetShatter:
	var tex := creature.puppet_tex()
	if tex == null or not creature.is_inside_tree():
		return null
	var fx := PuppetShatter.new()
	fx.z_index = 2
	fx._reform = true
	host.add_child(fx)
	fx.setup(tex, creature.puppet_art_rect(), creature.global_position.y + creature.size.y)
	fx._record()
	Audio.play("wooden_ball_colide", 0.0, 0.7)
	return fx


## The flight worked out step by step (the same throw, gravity and bounces as a death), until every piece lies still.
func _record() -> void:
	var sim: Array = []
	for pc in _pieces:
		var n: Node2D = pc.node
		sim.append({"p": n.position, "r": n.rotation, "v": pc.v, "w": pc.w, "floor": pc.floor, "bounces": 0})
	_track = [sim.map(func(s): return [s.p, s.r])]
	for k in 300:  # (5 s at most)
		var still := true
		for s in sim:
			if s.bounces < 0:
				continue
			still = false
			s.v.y += GRAVITY * STEP
			s.p += s.v * STEP
			s.r += s.w * STEP
			if s.p.y >= s.floor and s.v.y > 0.0:
				s.p.y = s.floor
				s.bounces += 1
				if s.bounces >= 3 or absf(s.v.y) < 140.0:
					s.bounces = -1
				else:
					s.v = Vector2(s.v.x * 0.55, -s.v.y * 0.35)
					s.w *= 0.5
		_track.append(sim.map(func(s): return [s.p, s.r]))
		if still:
			break


func _play_reform(d: float) -> void:
	_t += d
	var last := _track.size() - 1
	var dur := last * STEP
	var k: float
	if _t < dur:
		k = _t / STEP  # out: the burst, as it fell
	elif _t < dur + HOLD:
		k = last  # lying on the floor
	elif _t < dur * 1.6 + HOLD:
		var r := (_t - dur - HOLD) / (dur * 0.6)
		k = last * (1.0 - r * r)  # back in along the same paths, slow at first, then sucked in fast
	else:
		reformed.emit()
		queue_free()
		return
	var i := clampi(int(k), 0, last)
	var j := mini(i + 1, last)
	var f := k - i
	for m in _pieces.size():
		var n: Node2D = _pieces[m].node
		var a: Array = _track[i][m]
		var b: Array = _track[j][m]
		n.position = (a[0] as Vector2).lerp(b[0], f)
		n.rotation = lerpf(a[1], b[1], f)


## Break `creature`'s puppet where it stands (does nothing when it has no cut-out).
static func spawn(host: Node, creature: Creature) -> void:
	var tex := creature.puppet_tex()
	if tex == null or not creature.is_inside_tree():
		return
	var fx := PuppetShatter.new()
	fx.z_index = 2  # (over the floor and the enemies' Essence, under the spell cards)
	host.add_child(fx)
	fx.setup(tex, creature.puppet_art_rect(), creature.global_position.y + creature.size.y)
	Audio.play("wooden_ball_colide", 0.0, 0.7)


## Break a picture that is drawn on the screen in `art` (a Handyman arm: it is drawn into a picture of its own for this).
static func spawn_picture(host: Node, tex: Texture2D, art: Rect2, feet_y: float, sound := "wooden_ball_colide") -> void:
	var fx := PuppetShatter.new()
	fx.z_index = 2
	host.add_child(fx)
	fx.setup(tex, art, feet_y)
	Audio.play(sound, 0.0, 0.7 if sound == "wooden_ball_colide" else 1.0)


func setup(tex: Texture2D, art: Rect2, feet_y: float) -> void:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var k := art.size.x / float(img.get_width())
	var box := Rect2(art.position + Vector2(used.position) * k, Vector2(used.size) * k)  # (the painted part, on the screen)
	var centre := box.get_center()
	var cells: Array = []
	for attempt in 8:  # (cells that hold no paint are dropped; try again until there are enough)
		cells = _cells(box, img, art, k)
		if cells.size() >= PIECES - 1:
			break
	for cell in cells:
		_add_piece(cell, tex, art, centre, feet_y)


## Convex cells of a power diagram over `box`, as polygons in screen coordinates; only those with paint in them.
func _cells(box: Rect2, img: Image, art: Rect2, k: float) -> Array:
	var seeds: Array = []
	var weights: Array = []
	var diag2 := box.size.length_squared()
	for i in PIECES + 4:
		seeds.append(box.position + Vector2(randf(), randf()) * box.size)
		weights.append(randf_range(-0.05, 0.12) * diag2)  # (a big weight makes a big cell)
	var out: Array = []
	for i in seeds.size():
		var poly := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		for j in seeds.size():
			if i == j or poly.size() < 3:
				continue
			# the points p with |p - si|^2 - wi <= |p - sj|^2 - wj: the half plane n.p <= c
			var n: Vector2 = seeds[j] - seeds[i]
			var c: float = (seeds[j].length_squared() - seeds[i].length_squared() - float(weights[j]) + float(weights[i])) / 2.0
			poly = _clip(poly, n, c)
		if poly.size() >= 3 and _has_paint(poly, img, art, k):
			out.append(poly)
	out.shuffle()
	return out.slice(0, PIECES)


static func _clip(poly: PackedVector2Array, n: Vector2, c: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := n.dot(a) - c
		var db := n.dot(b) - c
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


func _has_paint(poly: PackedVector2Array, img: Image, art: Rect2, k: float) -> bool:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	var hits := 0
	for i in 40:
		var p := r.position + Vector2(randf(), randf()) * r.size
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var px := Vector2i(((p - art.position) / k).clamp(Vector2.ZERO, Vector2(img.get_size() - Vector2i.ONE)))
		if img.get_pixelv(px).a > 0.4:
			hits += 1
	return hits >= 2


func _add_piece(cell: PackedVector2Array, tex: Texture2D, art: Rect2, centre: Vector2, feet_y: float) -> void:
	var mid := Vector2.ZERO
	for p in cell:
		mid += p
	mid /= cell.size()
	var local := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in cell:
		local.append(p - mid)
		uv.append((p - art.position) / art.size * tex.get_size())
	var holder := Node2D.new()
	holder.position = mid
	for layer in [4, 3, 2, 1, 0]:  # (the edge first, farthest layer at the back; the face last)
		var pg := Polygon2D.new()
		pg.texture = tex
		pg.polygon = local
		pg.uv = uv
		pg.position = Vector2(1.8, 0.9) * layer
		if layer > 0:
			pg.color = EDGE.lightened(0.03 * (4 - layer))
		holder.add_child(pg)
	var dir := (mid - centre)
	dir = dir.normalized() if dir.length() > 4.0 else Vector2.from_angle(randf() * TAU)
	var area := absf(_area(local))
	var speed := randf_range(260.0, 620.0) / (1.0 + area / 14000.0)  # (small pieces fly further)
	add_child(holder)
	_pieces.append({
		"node": holder, "v": dir * speed + Vector2(randf_range(-80.0, 80.0), -randf_range(240.0, 480.0)),
		"w": randf_range(-9.0, 9.0), "floor": feet_y + randf_range(-18.0, 26.0), "bounces": 0,
		"rest": randf_range(0.5, 1.0), "age": 0.0,
	})


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0


func _process(d: float) -> void:
	if _reform:
		_play_reform(d)
		return
	_t += d
	var alive := false
	for pc in _pieces:
		var n: Node2D = pc.node
		if not is_instance_valid(n):
			continue
		if pc.bounces >= 0:  # in the air or bouncing
			pc.v.y += GRAVITY * d
			n.position += pc.v * d
			n.rotation += pc.w * d
			if n.position.y >= pc.floor and pc.v.y > 0.0:
				n.position.y = pc.floor
				pc.bounces += 1
				if pc.bounces >= 3 or absf(pc.v.y) < 140.0:
					pc.bounces = -1  # (lying on the floor)
				else:
					pc.v = Vector2(pc.v.x * 0.55, -pc.v.y * 0.35)
					pc.w *= 0.5
					Audio.play("wooden_ball_colide", -4.0, randf_range(0.6, 0.9))
		else:
			pc.age += d
			if pc.age > pc.rest:
				n.modulate.a = maxf(0.0, 1.0 - (pc.age - pc.rest) / 0.7)
		alive = alive or n.modulate.a > 0.0
	if not alive:
		queue_free()


## Random convex cells that tile `box` (a power diagram round `count` seeds of different weights), in the box's own coordinates.
static func tile(box: Rect2, count: int) -> Array:
	var seeds: Array = []
	var weights: Array = []
	var diag2 := box.size.length_squared()
	for i in count:
		seeds.append(box.position + Vector2(randf(), randf()) * box.size)
		weights.append(randf_range(-0.04, 0.08) * diag2)
	var out: Array = []
	for i in count:
		var poly := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		for j in count:
			if i == j or poly.size() < 3:
				continue
			var n: Vector2 = seeds[j] - seeds[i]
			var c: float = (seeds[j].length_squared() - seeds[i].length_squared() - float(weights[j]) + float(weights[i])) / 2.0
			poly = _clip(poly, n, c)
		if poly.size() >= 3:
			out.append(poly)
	return out
