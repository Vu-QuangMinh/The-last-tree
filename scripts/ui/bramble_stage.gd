class_name BrambleStage
extends Control
## Puppet Stage, the Bramble Matron's fight (the user, 2026-11-27): her two Briar Hedges stand side by side in front,
## touching, and she stands directly behind them, about 20% taller, so her head shows over them. All three are drawn
## twice as big as a usual puppet. The hedges are scenery more than puppets: they rock softly on their base, each on its
## own slow rhythm (Creature.prop_sway), and they have no intent. When she calls them back each is let down from the
## ceiling on a rope in 1 s, then its rope goes back up (lower()).
## Coordinates: x = 0 is this Control's left edge; every EnemyView is VIEW px big and stands on y = VIEW.y (the row's floor).

const VIEW := Vector2(300.0, 470.0)  # (EnemyView.setup's custom_minimum_size)
const CREATURE_H := 230.0  # (the Creature's box in a view: see HandymanStage)
const HEDGE_BIG := 2.0
const MATRON_BIG := 2.36  # (her picture fills 93.5% of its square, a hedge's 92%: 2.36 makes her about 20% taller)
const HEDGE_FILL_W := 0.9375  # (a hedge's picture is this much of its square wide)
const TOUCH := 0.96  # (a hair of overlap: no gap at all between the two hedges)
const BACK := 26.0  # her feet stand this much higher: further back on the stage
const DROP_TIME := 1.0
const DROP_FROM := -1400.0

var _d := 0.0  # distance between the two hedges' middles


func _init() -> void:
	var side := CREATURE_H * 0.88 * HEDGE_BIG
	_d = side * HEDGE_FILL_W * TOUCH
	custom_minimum_size = Vector2(_d + VIEW.x, VIEW.y)
	size = custom_minimum_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_END  # (feet on the same line as the other enemies' views)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Is this the Bramble Matron's fight in the new rules (HP bars), on the Puppet Stage?
static func wanted(enemies: Array) -> bool:
	return UiSkin.is_puppet() and enemies.any(func(e): return e.id == "bramble_matron" and e.has_meta("hp"))


## Put a view in its place: "matron" behind, "left" / "right" the hedges. Back to front: her, then the hedges.
func add_view(v: EnemyView, place: String) -> void:
	add_child(v)
	v.size = VIEW
	var cx := custom_minimum_size.x / 2.0
	match place:
		"matron":
			v.position = Vector2(cx - VIEW.x / 2.0, -BACK)
			v.creature.big = MATRON_BIG
			v.set_meta("layer", 0)
		"left", "right":
			v.position = Vector2(cx + (_d / 2.0 if place == "right" else -_d / 2.0) - VIEW.x / 2.0, 0.0)
			v.creature.big = HEDGE_BIG
			v.creature.prop_sway = true
			v.set_meta("layer", 1)
			if _drops.has(v.enemy):  # (it was being let down when the row was rebuilt: carry on from there)
				var gone := (Time.get_ticks_msec() - int(_drops[v.enemy])) / 1000.0
				if gone < DROP_TIME + 0.8:
					v.modulate.a = 0.0
					lower.call_deferred(v, maxf(gone, 0.001))
				else:
					_drops.erase(v.enemy)
	var views := get_children().filter(func(c): return c is EnemyView)
	views.sort_custom(func(a, b): return int(a.get_meta("layer", 0)) < int(b.get_meta("layer", 0)))
	for i in views.size():
		move_child(views[i], i)


## Hedges being let down right now (EnemyState -> msec it started): the row is rebuilt when the second one arrives, and the
## new view of the first goes on falling from where it was.
static var _drops := {}


## A hedge called back: it is let down from the ceiling on a rope (DROP_TIME), lands with a little bounce, and its rope
## is pulled back up. `from`: seconds already gone (a rebuilt view carrying on).
func lower(v: EnemyView, from := 0.0) -> void:
	if not is_instance_valid(v) or not is_instance_valid(v.creature):
		return
	if from <= 0.0:
		_drops[v.enemy] = Time.get_ticks_msec()
	var cr := v.creature
	var base := Vector2(cr.offset_top, cr.offset_bottom)
	var rope := Line2D.new()
	rope.width = 3.0
	rope.default_color = Color(0.82, 0.72, 0.5)
	add_child(rope)
	move_child(rope, 0)  # (behind the puppets, in front of the stage behind them)
	var top := (get_global_transform().affine_inverse() * Vector2(0.0, RopeRig.TOP_Y)).y
	var tie := func() -> Vector2:  # (the rope is tied to the top of the hedge)
		var side := cr._art_side() if cr.is_inside_tree() else CREATURE_H * 0.88 * HEDGE_BIG
		return v.position + cr.position + Vector2(cr.size.x / 2.0, cr.size.y - side * 0.9)
	var set_off := func(off: float) -> void:
		if is_instance_valid(cr):
			cr.offset_top = base.x + off
			cr.offset_bottom = base.y + off
	v.modulate.a = 1.0
	var u0 := clampf(from / DROP_TIME, 0.0, 1.0)
	if u0 < 1.0:
		set_off.call(DROP_FROM * pow(1.0 - u0, 3.0))
		var down := create_tween()
		down.tween_method(func(u: float) -> void:
			set_off.call(DROP_FROM * pow(1.0 - u, 3.0))  # (fast at first, slowing down as the rope runs out)
			if is_instance_valid(rope):
				var t: Vector2 = tie.call()
				rope.points = PackedVector2Array([Vector2(t.x, top), t]), u0, 1.0, DROP_TIME * (1.0 - u0))
		await down.finished
		if not is_instance_valid(rope):
			return
		Audio.play("enemy_spawn", -6.0)
		var spring := create_tween()  # (it settles on the floor: a little bob)
		spring.tween_method(func(sp: float) -> void:
			set_off.call(-10.0 * exp(-6.0 * sp) * sin(TAU * 2.0 * sp)), 0.0, 0.6, 0.6)
	var t0: Vector2 = tie.call()
	var up := create_tween()  # (the rope is untied and pulled back up behind the ceiling)
	up.tween_method(func(u: float) -> void:
		if is_instance_valid(rope):
			rope.points = PackedVector2Array([Vector2(t0.x, top), Vector2(t0.x, lerpf(t0.y, top, u * u))]), 0.0, 1.0, 0.5).set_delay(0.15)
	await up.finished
	if is_instance_valid(rope):
		rope.queue_free()
	set_off.call(0.0)
	_drops.erase(v.enemy)
