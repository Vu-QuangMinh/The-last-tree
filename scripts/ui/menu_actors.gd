class_name MenuActors
extends Control
## Puppet Stage main menu: puppets of Act 1 now and then walk onto the stage floor (hopping on their bases), stand a while (rocking a little) and
## walk off again, a few at a time. They keep to the two sides of the floor, so the menu column stays clear in the middle.

const MAX_ACTORS := 4
const SIDE := 250.0  # the picture's square at the middle of the floor, px
const BIG := {"giant_slime": 1.25, "yeti": 1.25, "rolling_bear": 1.2, "enraged_bear": 1.2, "bramble_matron": 1.2, "triplet_fire": 0.8, "triplet_water": 0.8, "triplet_air": 0.8}
const SKIP := ["handyman", "briar_hedge", "yin_yang", "hand_"]
const EDGE := 20.0  # how close their feet may come to the far and near edges of the floor
const MARGIN_X := 90.0

var floor_top := 600.0  # the y of the far edge of the floor and of its near edge (set by the menu from the stage)
var floor_bottom := 860.0
var _actors: Array[Dictionary] = []  # {node, sprite, shadow, state, goal, t, pause, life, phase, speed, side, base}
var _files: Array[String] = []
var _next := 1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for f in DirAccess.get_files_at("res://assets/Puppet/Enemies/Act1"):
		if f.ends_with(".png") and not SKIP.any(func(s: String) -> bool: return f.begins_with(s)):
			_files.append(f.get_basename())


func _y_range() -> Vector2:
	return Vector2(floor_top + EDGE, floor_bottom - EDGE)


## A puppet is a little smaller far back on the floor and bigger near the front.
func _depth(y: float) -> float:
	var r := _y_range()
	return lerpf(0.82, 1.12, clampf((y - r.x) / maxf(1.0, r.y - r.x), 0.0, 1.0))


## Two puppets overlap when their feet are close in depth (DEPTH_GAP px up or down) and their bodies close sideways: they would walk through each other.
const DEPTH_GAP := 80.0


func _sep(pos_a: Vector2, side_a: float, pos_b: Vector2, side_b: float) -> float:
	return maxf(absf(pos_a.y - pos_b.y) / DEPTH_GAP, absf(pos_a.x - pos_b.x) / ((side_a + side_b) * 0.32))


func _overlap(pos_a: Vector2, side_a: float, pos_b: Vector2, side_b: float) -> bool:
	return _sep(pos_a, side_a, pos_b, side_b) < 1.0


## Would a step from `cur` to `next` bring this puppet into another, or deeper into one it is already in? (A puppet that is overlapped may only
## move so that the gap grows.)
func _worse(me: Dictionary, cur: Vector2, next: Vector2) -> bool:
	for o in _actors:
		if o == me:
			continue
		var op: Vector2 = (o.node as Node2D).position
		var s_new := _sep(next, me.side, op, o.side)
		if s_new < 1.0 and s_new < _sep(cur, me.side, op, o.side) - 0.0001:
			return true
	return false


## Is `pos` free of every other puppet and of the places they are walking to?
func _blocked(me: Dictionary, pos: Vector2) -> bool:
	for o in _actors:
		if o == me:
			continue
		if _overlap(pos, me.side, (o.node as Node2D).position, o.side) or _overlap(pos, me.side, o.goal, o.side):
			return true
	return false


func _free_goal(me: Dictionary, from: Vector2) -> Vector2:
	var width := maxf(size.x, 1920.0)
	var r := _y_range()
	for attempt in 14:
		var g := Vector2(randf_range(MARGIN_X, width - MARGIN_X), randf_range(r.x, r.y))
		if not _blocked(me, g):
			return g
	return from  # (no room: it stays where it is)


func _spawn() -> void:
	if _files.is_empty():
		return
	var id: String = _files[randi() % _files.size()]
	var tex := load("res://assets/Puppet/Enemies/Act1/%s.png" % id) as Texture2D
	if tex == null:
		return
	var width := maxf(size.x, 1920.0)
	var side := SIDE * float(BIG.get(id, 1.0))
	var from_left := randf() < 0.5
	var r := _y_range()
	var y := randf_range(r.x, r.y)
	for attempt in 10:  # (the row of a puppet that is already on stage is left free)
		if _actors.all(func(o: Dictionary) -> bool: return absf(float(o.node.position.y) - y) > DEPTH_GAP or absf(float(o.node.position.x) - (-side if from_left else width + side)) > 700.0):
			break
		y = randf_range(r.x, r.y)
	var holder := Node2D.new()
	holder.position = Vector2(-side if from_left else width + side, y)
	var shadow := Polygon2D.new()  # (a flat dark ellipse on the floor)
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2(cos(i * TAU / 24.0) * side * 0.3, sin(i * TAU / 24.0) * side * 0.06))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.32)
	holder.add_child(shadow)
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2.ONE * side / float(tex.get_width())
	sp.position = Vector2(0.0, -side * 0.48)
	holder.add_child(sp)
	add_child(holder)
	var me := {"node": holder, "sprite": sp, "state": "in", "goal": holder.position, "t": 0.0, "pause": 0.0, "prev": "in",
		"life": randf_range(24.0, 45.0), "age": 0.0, "phase": randf() * TAU, "speed": randf_range(110.0, 190.0), "side": side, "from_left": from_left}
	_actors.append(me)
	me.goal = _free_goal(me, holder.position)


func _process(d: float) -> void:
	_t += d
	_next -= d
	if _next <= 0.0:
		_next = randf_range(3.0, 6.0)
		if _actors.size() < MAX_ACTORS:
			_spawn()
	var width := maxf(size.x, 1920.0)
	var r := _y_range()
	for a in _actors.duplicate():
		var n: Node2D = a.node
		a.t += d
		a.age += d
		var moving := false
		if a.state == "pause" or a.state == "wait":
			a.pause -= d
			if a.pause <= 0.0:
				if a.state == "wait":  # it waited for someone to get out of the way
					a.state = a.prev
					if a.state != "out":
						a.goal = _free_goal(a, n.position)
				elif a.age >= a.life:  # it has stayed long enough: it leaves by the nearer side
					a.state = "out"
					a.goal = Vector2(-a.side - 60.0 if n.position.x < width / 2.0 else width + a.side + 60.0, n.position.y)
				else:  # it wanders on to another spot anywhere on the floor
					a.state = "roam"
					a.goal = _free_goal(a, n.position)
		else:
			var to: Vector2 = a.goal - n.position
			var step: float = a.speed * d
			if to.length() <= step:
				n.position = a.goal
				if a.state == "out":
					n.queue_free()
					_actors.erase(a)
					continue
				a.state = "pause"
				a.pause = randf_range(1.5, 4.5)
			else:
				var next: Vector2 = n.position + to.normalized() * step
				if _worse(a, n.position, next):
					a.prev = a.state  # someone is in the way: wait a moment
					a.state = "wait"
					a.pause = randf_range(0.4, 1.2)
				else:
					n.position = next
					moving = true
		var k: float = _depth(n.position.y)
		n.scale = Vector2.ONE * k
		var sp: Sprite2D = a.sprite
		if moving:  # hopping along on its base
			var h: float = a.t * 9.0 + a.phase
			sp.position.y = -a.side * 0.48 - absf(sin(h)) * 14.0
			sp.rotation = sin(h) * 0.07
		else:  # standing: it rocks a little
			sp.position.y = lerpf(sp.position.y, -a.side * 0.48, minf(1.0, d * 8.0))
			sp.rotation = sin(_t * 1.6 + a.phase) * 0.035
	# the nearer one stands in front: the children are kept in the order of their y (no z_index: the menu column stays over them all)
	var ordered := _actors.map(func(a: Dictionary) -> Node2D: return a.node)
	ordered.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y < b.position.y)
	for i in ordered.size():
		move_child(ordered[i], i)
