class_name RopeEditor
extends Control
## Rope mode (Room Test, F5): hang the enemies from the ceiling. Left click on a puppet fastens a rivet there and a rope that goes straight up behind the
## ceiling; a rivet can be dragged to move it; right click on a rivet takes it and its rope away. The rivets are kept per enemy (EnemyRopes), as points of the
## puppet's picture, so a rope follows its puppet wherever it rocks or moves (the top of the rope stays put, the rope between sags a little and bends).
## "Next set" walks the enemies of this set off and the next four on (the sets are made by RopeSets).

signal next_pressed

const PICK_R := 14.0  # a rivet is grabbed (dragged, taken away) from this far

var fs: FightScreen
var _title := ""
var _drag := {}  # {id, i, creature}: the rivet that is being dragged
var _ui := Control.new()  # (inside a CanvasLayer of its own: the enemy row is a big Container, and a Button under it would never get a click)
var _ui_layer := CanvasLayer.new()
var _rig: RopeRig  # draws the ropes and the rivets


func setup(p_fs: FightScreen, set_index: int, set_count: int, ids: Array, kind: String, act: int) -> void:
	fs = p_fs
	var names: Array = ids.map(func(id): return EnemyDefs.E[RopeSets.real_id(id)].name + (" (black)" if RopeSets.is_black(id) else ""))
	_title = "Rope mode · Act %d %s · set %d of %d: %s" % [act, kind.capitalize(), set_index + 1, set_count, ", ".join(names)]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.layer = 50
	add_child(_ui_layer)
	_ui_layer.add_child(_ui)
	var title := Label.new()
	title.text = _title
	title.position = Vector2(0, 128)
	title.size = Vector2(1920, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(title)
	var hint := Label.new()
	hint.text = "Left click a puppet: rivet + rope  ·  drag a rivet: move it  ·  right click a rivet: remove it  ·  F5: leave"
	hint.position = Vector2(0, 158)
	hint.size = Vector2(1920, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(hint)
	var next := Button.new()
	next.text = "Next set ▶"
	next.focus_mode = Control.FOCUS_NONE
	next.custom_minimum_size = Vector2(190, 44)
	next.size = Vector2(190, 44)
	next.position = Vector2(1920.0 / 2.0 - 95.0, 190)
	next.add_theme_font_size_override("font_size", 20)
	next.pressed.connect(func(): next_pressed.emit())
	_ui.add_child(next)
	_rig = RopeRig.new()
	_rig.fs = fs
	fs.add_child.call_deferred(_rig)  # (the last child of the screen: its rivets are drawn after the puppets, so they never trail a frame behind them)


func _process(_d: float) -> void:
	if is_instance_valid(_rig):
		_rig.drag = _drag


func _exit_tree() -> void:
	if is_instance_valid(_rig):
		_rig.queue_free()


# ------------------------------------------------------------------ picking

## The rivet nearest to a screen point: {id, i, creature}, or {} when none is within reach.
func _rivet_at(pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := PICK_R
	for t in fs.rope_targets():
		var pts := EnemyRopes.points(t[0])
		for i in pts.size():
			var dist: float = t[1].rope_point(pts[i]).distance_to(pos)
			if dist <= best_d:
				best_d = dist
				best = {"id": t[0], "i": i, "creature": t[1]}
	return best


## The puppet under a screen point and the spot of its picture: {id, creature, frac}, or {} when the point is not on a painted part of any.
func _puppet_at(pos: Vector2) -> Dictionary:
	var targets := fs.rope_targets()
	targets.reverse()  # (the one drawn last is on top)
	for t in targets:
		var frac: Vector2 = t[1].rope_frac_at(pos)
		if t[1].rope_alpha(frac) > 0.1:
			return {"id": t[0], "creature": t[1], "frac": frac}
	return {}


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT and not b.pressed and not _drag.is_empty():
			_drag = {}
			get_viewport().set_input_as_handled()
			return
		if not b.pressed or not (b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]):
			return
		if get_viewport().gui_get_hovered_control() is BaseButton:
			return  # (the Next set / Menu / Back buttons keep their clicks)
		var hit := _rivet_at(b.global_position)
		if b.button_index == MOUSE_BUTTON_RIGHT:
			if not hit.is_empty():
				var pts := EnemyRopes.points(hit.id)
				pts.remove_at(hit.i)
				EnemyRopes.set_points(hit.id, pts)
				get_viewport().set_input_as_handled()
			return
		if hit.is_empty():
			var p := _puppet_at(b.global_position)
			if p.is_empty():
				return
			var pts := EnemyRopes.points(p.id)
			pts.append(p.frac)
			EnemyRopes.set_points(p.id, pts)
			hit = {"id": p.id, "i": pts.size() - 1, "creature": p.creature}
		_drag = hit
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and not _drag.is_empty():
		var c: Creature = _drag.creature
		if not is_instance_valid(c):
			_drag = {}
			return
		var pts := EnemyRopes.points(_drag.id)
		if _drag.i >= pts.size():
			_drag = {}
			return
		var f := c.rope_frac_at((ev as InputEventMouseMotion).global_position)
		pts[_drag.i] = Vector2(clampf(f.x, 0.0, 1.0), clampf(f.y, 0.0, 1.0))
		EnemyRopes.set_points(_drag.id, pts)
		get_viewport().set_input_as_handled()
