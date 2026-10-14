class_name HandymanStage
extends Control
## Puppet Stage, the Handyman fight: his body stands in the middle of the floor and his hands hang on his two shoulders (the sockets cut out of
## Handyman.pdf, see HandymanRig). A hand is still an enemy with its own EnemyView, Essence and intent: the view of each hand is placed so that
## the hand's own picture (a two-bone arm drawn by its Creature) meets the body at the shoulder. In layers, from the back: spear and crossbow,
## sword and hammer, tweezer and shield, the body (drawn in that order: the views are kept sorted by layer, none of them has a z_index of its
## own, so the spell cards, one level up, stay over the tip of a long arm). While he has not shown himself yet (no `handyman` enemy in the fight) his body is a plain
## picture drawn here; once he steps out his own view stands exactly where that picture was.
## Coordinates: x = 0 is the middle of the enemy row, y = 0 its top; an EnemyView is VIEW px big and stands on y = VIEW.y.

const VIEW := Vector2(300.0, 470.0)  # EnemyView.setup's custom_minimum_size
const CREATURE_H := 230.0  # the Creature's box in a view (EnemyView: the holder 230 - PUPPET_TOP, and the model's box reaches PUPPET_TOP above it)

var _body: Creature  # the picture of his body while he has not shown himself
var _real := false  # his own EnemyView stands there now
var _ghosts := {}  # hand id -> the folded arm of a hand that is not summoned yet
## The hands that come later, and the phase of the fight they come in.
const LATER := {"hand_hammer": 2, "hand_crossbow": 2, "hand_spear": 3, "hand_shield": 3}


func _init() -> void:
	custom_minimum_size = Vector2(1.0, VIEW.y)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_END  # (feet on the same line as the other enemies' views)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Is there art for this fight? (Without it the hands keep standing in a row.)
static func available() -> bool:
	if not UiSkin.is_puppet() or Creature.enemy_path("handyman.png", 1) == "":
		return false
	for id in HandymanRig.ARMS:
		var a: Dictionary = HandymanRig.ARMS[id]
		if Creature.enemy_path(a.upper, 1) == "" or Creature.enemy_path(a.lower, 1) == "":
			return false
	return true


func setup() -> void:
	var st := EnemyState.new()
	st.setup(EnemyDefs.get_def("handyman"))
	_body = Creature.new()
	_body.setup(st)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.tooltip_text = ""
	_body.size = Vector2(VIEW.x, CREATURE_H)
	_body.position = Vector2(-VIEW.x / 2.0, VIEW.y - CREATURE_H)
	add_child(_body)


## The body's square (the picture's canvas), on this layer.
func body_square() -> Rect2:
	var s := HandymanRig.BODY_PX * HandymanRig.SCALE
	return Rect2(Vector2(-s / 2.0, VIEW.y - s), Vector2(s, s))


## Where a hand's shoulder socket is on the body.
func socket(side: int) -> Vector2:
	var sq := body_square()
	var f: Vector2 = HandymanRig.SOCKET_R if side > 0 else HandymanRig.SOCKET_L
	return sq.position + f * sq.size


## The six places where the hands' names stand, in one row (x from the middle of the row, three on each side, evenly spaced; y of the
## hand marker: the name is just above it, the Essence just under it, so the names are level and so are the Essence). The sticks of each arm are
## stretched until its hand marker is there. Outermost slot = the highest arm of its side, so the arms do not cross.
const SLOT_X := {"hand_spear": -690.0, "hand_sword": -460.0, "hand_tweezer": -230.0, "hand_shield": 230.0, "hand_hammer": 460.0, "hand_crossbow": 690.0}
const SLOT_Y := 430.0


func slot_of(id: String) -> Vector2:
	return Vector2(SLOT_X[id], SLOT_Y)


## How long the arm's two sticks must be (px of the art) for its hand marker to reach `slot_of(id)`, and the direction of its lower stick:
## (upper length, lower length, lower angle). With the rest directions it is two equations in two lengths; when that asks for a stick
## shorter than it can be made (the hand is too near), the upper stick stays as short as it goes and the lower one turns to meet the slot.
func reach_of(id: String) -> Vector3:
	var arm: Dictionary = HandymanRig.ARMS[id]
	var t := (slot_of(id) - socket(arm.side)) / HandymanRig.SCALE
	var u1 := Vector2.from_angle(arm.theta1)
	var slab_u: Vector2 = arm.upper_slab
	var slab_l: Vector2 = arm.lower_slab
	var lo_a: float = float(arm.l1) - 0.8 * (slab_u.y - slab_u.x)
	var lo_b: float = float(arm.l2) - 0.8 * (slab_l.y - slab_l.x)
	var best := Vector3(lo_a, lo_b, arm.theta2)
	var best_cost := INF
	var far := 0.0
	var a := lo_a
	while a <= lo_a + 900.0:  # (the upper length that leaves the lower stick closest to its rest direction)
		var f := t - u1 * a
		var len := f.length()
		far = maxf(far, len)
		if len >= lo_b:
			var cost := absf(angle_difference(f.angle(), arm.theta2))
			if cost < best_cost:
				best_cost = cost
				best = Vector3(a, len, f.angle())
		a += 2.0
	if best_cost == INF:
		push_warning("HandymanStage: %s cannot reach its slot (the lower stick would be %.0f, the shortest is %.0f)" % [id, far, lo_b])
	return best


## Where the top left corner of a hand's view goes: the middle of its Creature's box on its slot.
func view_position(id: String) -> Vector2:
	return slot_of(id) - Vector2(VIEW.x / 2.0, VIEW.y - CREATURE_H / 2.0)


func add_hand(e: EnemyState, v: EnemyView, reach: bool) -> void:
	var arm: Dictionary = HandymanRig.ARMS[e.id]
	drop_ghost(e.id)
	add_child(v)
	v.size = VIEW
	v.position = view_position(e.id)
	var r := reach_of(e.id)
	v.creature.reach = Vector2(r.x, r.y)
	v.creature.reach_angle = r.z
	v.set_meta("layer", arm.layer)
	_sort_layers()
	if e.knocked:
		v.creature._fold_t = 1.0  # (still folded: the view was rebuilt)
	elif reach:  # a hand that joins mid-fight unfolds from where it lay, behind him
		v.creature._fold_t = 1.0


## The hands that are not in the fight yet lie folded behind him from the start (for them to unfold when their turn comes).
func sync_ghosts(live_ids: Array, phase: int, fight: Fight) -> void:
	for id in LATER:
		var wanted: bool = phase < int(LATER[id]) and not (id in live_ids)
		if not wanted:
			drop_ghost(id)
		elif not _ghosts.has(id):
			var st := EnemyState.new()
			st.setup(EnemyDefs.get_def(id))
			st.knocked = true
			var v := EnemyView.new()
			v.setup(st, fight)
			v.make_ghost()
			add_child(v)
			v.size = VIEW
			v.position = view_position(id)
			var r := reach_of(id)
			v.creature.reach = Vector2(r.x, r.y)
			v.creature.reach_angle = r.z
			v.creature._fold_t = 1.0
			v.set_meta("layer", HandymanRig.ARMS[id].layer)
			_ghosts[id] = v
	_sort_layers()


func drop_ghost(id: String) -> void:
	if _ghosts.has(id):
		var g: EnemyView = _ghosts[id]
		if is_instance_valid(g):
			g.get_parent().remove_child(g)
			g.queue_free()
		_ghosts.erase(id)


## The Handyman himself steps out (an enemy now): his view takes the place of the picture.
func add_body(v: EnemyView) -> void:
	add_child(v)
	v.size = VIEW
	v.position = Vector2(-VIEW.x / 2.0, 0.0)
	v.creature.sad_forever = true  # (all his hands are down: the crying face for good)
	v.set_meta("layer", 9)
	_sort_layers()


## Back to front: the views by layer (the spear and crossbow first), his body's picture on top of them.
func _sort_layers() -> void:
	var views := get_children().filter(func(c): return c is EnemyView)
	views.sort_custom(func(a, b): return int(a.get_meta("layer", 0)) < int(b.get_meta("layer", 0)))
	for i in views.size():
		move_child(views[i], i)
	if _body != null:
		move_child(_body, views.size())


func set_real(real: bool) -> void:
	_real = real
	if _body != null:
		_body.visible = not real


func body_feet() -> Variant:
	if _body == null or _real:
		return null
	return _body.global_position + Vector2(_body.size.x / 2.0, _body.size.y)
