class_name EnemyView
extends VBoxContainer
## An enemy on the fight screen: intent symbols on top (always drawn above the model), portrait, name,
## HP orbs (with preview ghosts), statuses. In move mode its HP orbs are clickable.

signal clicked(view: EnemyView)
signal hp_clicked(view: EnemyView, index: int)  # index == size() means "the end"

var enemy: EnemyState
var fight: Fight
var creature: Creature
var _intent_slot: Control
var _name: Label
var _hp_row: HFlowContainer
var _status: RichTextLabel
var _skull: Label
var _ring: Panel
var targetable := false
var targeted := false
var move_mode := false
var move_pick := -1  # the element picked up in move mode
var pick_mode := false  # choosing an element to remove (Pluck)
var pick_i := -1
var _hp_icons: Array = []  # the orbs currently shown, left to right


func setup(e: EnemyState, f: Fight) -> void:
	enemy = e
	fight = f
	custom_minimum_size = Vector2(300, 470)
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_slot = CenterContainer.new()
	_intent_slot.custom_minimum_size = Vector2(300, 46)
	_intent_slot.z_index = 10  # never hidden behind a model
	_intent_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intent_slot)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	add_child(gap)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 230)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.clip_contents = false
	add_child(holder)
	_ring = Panel.new()
	var rb := StyleBoxFlat.new()
	rb.draw_center = false
	rb.border_color = Color(1, 0.9, 0.4)
	rb.set_border_width_all(3)
	rb.set_corner_radius_all(16)
	_ring.add_theme_stylebox_override("panel", rb)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_ring)
	creature = Creature.new()
	creature.setup(e)
	creature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creature.offset_top = 22  # models stay below the intent row
	holder.add_child(creature)
	_skull = UiTheme.label("☠", 64, Color(1, 0.35, 0.3))
	_skull.position = Vector2(112, 20)
	_skull.add_theme_constant_override("outline_size", 8)
	_skull.add_theme_color_override("font_outline_color", Color.BLACK)
	holder.add_child(_skull)
	_name = UiTheme.label(e.name, 20, Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_hp_row = HFlowContainer.new()
	_hp_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_hp_row.add_theme_constant_override("h_separation", 2)
	_hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_row)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(290, 40)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("normal_font_size", 14)
	_status.add_theme_font_size_override("bold_font_size", 14)
	_status.add_theme_color_override("default_color", Color(0.85, 0.8, 1))
	add_child(_status)
	refresh({})


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


## Where the arrow should point / start for this enemy (global coordinates).
func anchor_point() -> Vector2:
	return global_position + Vector2(size.x / 2.0, 170)


## preview: the dict from Fight.preview (or {} for none).
func refresh(preview: Dictionary) -> void:
	var e := enemy
	for c in _intent_slot.get_children():
		c.queue_free()
	if not e.intent.is_empty():
		_intent_slot.add_child(IntentChip.make(e))
	for ch in _hp_row.get_children():
		ch.queue_free()
	_hp_icons.clear()
	var k: int = preview.get("removed", {}).get(e, 0)
	var ghosts := {}
	var seen := 0
	for i in e.size():
		if seen >= k:
			break
		if not e.armor[i]:
			ghosts[i] = true
		seen += 1
	if k > 0 and e.is_exposed():
		for i in range(e.size() - 1, -1, -1):
			if not ghosts.has(i) and not e.armor[i]:
				ghosts[i] = true
				break
	var mask := fight.hidden_mask(e)
	var px := 38.0 if e.size() <= 7 else 30.0
	if move_mode or pick_mode:
		px = 48.0 if e.size() <= 6 else 40.0
	for i in e.size():
		var hidden: bool = mask.size() > i and mask[i]
		var icon := ElementIcon.make("?" if hidden else e.elements[i], px)
		icon.armored = e.armor[i]
		icon.ghost = ghosts.has(i)
		if move_mode:
			icon.highlight = i == move_pick
			icon.dim = move_pick >= 0 and i != move_pick
			_make_clickable(icon, i)
		elif pick_mode:
			icon.highlight = i == pick_i
			icon.dim = e.armor[i]
			if not e.armor[i]:
				_make_clickable(icon, i)
		_hp_row.add_child(icon)
		_hp_icons.append(icon)
	if move_mode and move_pick >= 0:
		var end := UiTheme.label("▸", 30, Color(1, 0.9, 0.4))
		end.tooltip_text = "Put it at the end"
		_make_clickable(end, e.size() - 1)
		_hp_row.add_child(end)
	_skull.visible = e in preview.get("dies", [])
	var st := e.describe_statuses()
	for p in e.def.get("passives", []):
		st.append(EnemyDefs.PASSIVE_TEXT[p].get_slice(":", 0))
	_status.text = "[center]" + Keywords.colorize(" · ".join(st.map(func(s): return s.get_slice(" (", 0)))) + "[/center]"
	tooltip_text = _tooltip()
	_ring.visible = targetable or move_mode or pick_mode
	_ring.modulate = Color(1, 1, 1, 1.0 if targeted or move_mode or pick_mode else 0.35)
	_name.add_theme_color_override("font_color", Color(1, 0.9, 0.4) if targeted else Color.WHITE)


func _make_clickable(c: Control, index: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hp_clicked.emit(self, index)
			c.accept_event())


func _tooltip() -> String:
	var e := enemy
	var title := e.name + (" (Boss)" if e.is_boss else (" (Elite)" if e.is_elite else ""))
	var lines := []
	lines.append("HP: %d elements" % e.size())
	for s in e.describe_statuses():
		lines.append("• " + s)
	for p in e.def.get("passives", []):
		lines.append("• " + EnemyDefs.PASSIVE_TEXT[p])
	lines.append("Hover its portrait to see its moves.")
	var flavor := "[i][color=#9aa89a]\"%s\"[/color][/i]" % e.def.get("flavor", "")
	return Keywords.tooltip(title, "\n".join(lines), flavor)


func _make_custom_tooltip(for_text: String) -> Object:
	return Keywords.make_tooltip(for_text)


## Where HP element j sits on screen (comets fly here).
func hp_point(j: int) -> Vector2:
	if j >= 0 and j < _hp_icons.size():
		var ic: Control = _hp_icons[j]
		return ic.global_position + ic.size / 2.0
	return global_position + Vector2(size.x / 2.0, 330)


## The chant reaches HP element j: it bursts (armoured ones just clang).
func pop(j: int) -> void:
	if j < 0 or j >= _hp_icons.size():
		return
	var icon: ElementIcon = _hp_icons[j]
	icon.pivot_offset = icon.size / 2.0
	var tw := icon.create_tween()
	if icon.armored:
		tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.06)
		tw.tween_property(icon, "modulate", Color.WHITE, 0.12)
		return
	tw.tween_property(icon, "scale", Vector2(1.5, 1.5), 0.07)
	tw.parallel().tween_property(icon, "modulate", Color(2.2, 2.0, 1.6), 0.07)
	tw.tween_property(icon, "scale", Vector2(0.1, 0.1), 0.12)
	tw.parallel().tween_property(icon, "modulate:a", 0.0, 0.12)
	creature.flash = 0.6


func hit_flash() -> void:
	creature.flash = 1.0
