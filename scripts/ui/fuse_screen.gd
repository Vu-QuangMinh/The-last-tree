class_name FuseScreen
extends Control
## Campfire: fuse two spells into one. Drag two cards onto the fuse slots (or click them); the forged spell is shown
## before you commit. A card dropped on a full slot pushes the old card back down to the list; a card dragged out of a
## slot (or clicked there) runs back down too.

signal fused(new_spell: Dictionary)
signal back

const RULES := "Fuse melts two of your spells into ONE spell that does everything both of them did.\n• Its pattern: the first spell you pick, then the whole of the second. Nothing is lost.\n• Both spells are used up, and the new one takes a single slot in your active row.\n• Fused spells can't be fused again, and Powers can't be fused."

var run: RunState
var _slots: Array = ["", ""]  # ids in the two fuse slots: the first one's pattern goes first
var _preview: Dictionary = {}
var _grid: HFlowContainer
var _slot_box: Array = []  # the two drop targets
var _result_box: HBoxContainer
var _drag := {}  # the card being dragged: {id, from} (from = slot index, or -1 for the list)
var _fly: Array = []  # [{id, from: Vector2}] cards that run from a slot back down to the list
var _status: RichTextLabel
var _fuse_btn: Button


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = run.act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(50, 70)
	v.size = Vector2(1820, 1000)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.heading("🔥 Fuse two spells", 38, Color(1, 0.8, 0.6)))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.custom_minimum_size = Vector2(1100, 0)
	rules.add_theme_font_size_override("normal_font_size", 18)
	rules.add_theme_font_size_override("bold_font_size", 18)
	rules.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	rules.text = Keywords.colorize(RULES)
	v.add_child(rules)
	# the two fuse slots, then the result
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	v.add_child(mid)
	for k in 2:
		var slot := _make_slot(k)
		_slot_box.append(slot)
		mid.add_child(slot)
		if k == 0:
			mid.add_child(UiTheme.label("+", 48, Color.WHITE))
	mid.add_child(UiTheme.label("→", 48, Color(1, 0.8, 0.4)))
	_result_box = HBoxContainer.new()
	_result_box.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
	mid.add_child(_result_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	mid.add_child(side)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(420, 0)
	_status.add_theme_font_size_override("normal_font_size", 19)
	_status.add_theme_font_size_override("bold_font_size", 19)
	_status.add_theme_color_override("default_color", Color(1, 0.9, 0.75))
	side.add_child(_status)
	_fuse_btn = UiTheme.button("Fuse them!", _commit, 24)
	_fuse_btn.custom_minimum_size = Vector2(260, 56)
	side.add_child(_fuse_btn)
	v.add_child(UiTheme.label("Your spells (drag two onto the slots, or click them):", 18, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1820, 300)
	scroll.set_drag_forwarding(Callable(), _can_drop_list, _drop_list)  # drop a slot's card here: it goes back down
	v.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.custom_minimum_size = Vector2(1800, 0)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var bh := HBoxContainer.new()
	bh.position = Vector2(1500, 1000)
	add_child(bh)
	var back_btn := UiTheme.button("Back to the campfire", func(): back.emit(), 20)
	back_btn.custom_minimum_size = Vector2(300, 52)
	bh.add_child(back_btn)
	_refresh()


func _make_slot(k: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = Color(1, 0.8, 0.5, 0.6)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.set_drag_forwarding(Callable(), func(_at, d): return _can_drop_slot(d), func(_at, d): _drop_slot(k, d))
	return p


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for id in run.spellbook:
		if id in _slots:
			continue  # it sits in a fuse slot
		var s := run.spell(id)
		var card := SpellCard.make(s)
		var ok := run.can_fuse(id)
		if not ok:
			card.state = "used"
			card.state_text = "Can't fuse" if not s.get("fused", false) else "Already fused"
		# the rules again, right where the player is deciding
		card.set_meta("fuse_tip", "\n\n" + ("Fuse: drag this onto a slot (or click it) to melt it with another spell." if ok else ("Powers can't be fused." if s.get("power", false) else "Fused spells can't be fused again.")))
		card.set_meta("fuse_id", id)
		card.clicked.connect(func(_c): _click_list(id))
		if ok:
			card.set_drag_forwarding(func(_at): return _begin_drag(card, id, -1), Callable(), Callable())
		_grid.add_child(card)
	for k in 2:  # the slots
		var box: PanelContainer = _slot_box[k]
		for c in box.get_children():
			c.queue_free()
		var id: String = _slots[k]
		if id == "":
			var hint := UiTheme.label("1st spell\nits pattern goes first" if k == 0 else "2nd spell\nits pattern goes after", 20, Color(1, 0.9, 0.75, 0.7))
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(hint)
		else:
			var card := SpellCard.make(run.spell(id))
			var slot := k
			card.clicked.connect(func(_c): _unslot(slot))
			card.set_drag_forwarding(func(_at): return _begin_drag(card, id, slot), Callable(), Callable())
			box.add_child(card)
	for c in _result_box.get_children():
		c.queue_free()
	_fuse_btn.disabled = _slots[0] == "" or _slots[1] == ""
	if _slots[0] != "" and _slots[1] != "":
		_preview = run.fuse_preview(_slots[0], _slots[1])
		_result_box.add_child(SpellCard.make(_preview))
		_status.text = ""
	else:
		_preview = {}
		_status.text = Keywords.colorize("Drag the first spell onto the left slot: its pattern goes first." if _slots[0] == "" and _slots[1] == "" else "Now the other spell: drag it onto the empty slot.")
	if not _fly.is_empty():
		_run_fly.call_deferred()


## A card runs from where it was (a slot) down to its place in the spell list.
func _run_fly() -> void:
	await get_tree().process_frame
	var jobs := _fly.duplicate()
	_fly.clear()
	for j in jobs:
		for c in _grid.get_children():
			if c.get_meta("fuse_id", "") != j.id or c.is_queued_for_deletion():
				continue
			var ghost := SpellCard.make(run.spell(j.id))
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.z_index = 50
			add_child(ghost)
			ghost.global_position = j.from
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(ghost, "global_position", c.global_position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func():
				if is_instance_valid(c):
					c.modulate.a = 1.0
				ghost.queue_free())
			break


func _begin_drag(card: SpellCard, id: String, from: int) -> Variant:
	_drag = {"id": id, "from": from}
	var pv := Control.new()
	var c := SpellCard.make(run.spell(id))
	c.zoom = 0.7
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = -Vector2(SpellCard.W, SpellCard.H) * 0.35
	pv.add_child(c)
	card.set_drag_preview(pv)
	return {"fuse": id, "from": from}


func _can_drop_slot(d: Variant) -> bool:
	return d is Dictionary and d.has("fuse")


func _drop_slot(k: int, d: Variant) -> void:
	var id: String = d.fuse
	var from: int = d.from
	if from == k:
		return
	var old: String = _slots[k]
	if from >= 0:
		_slots[from] = old  # slot to slot: the two swap
	elif old != "":
		_push_back(k)  # the card that was there runs back down
	_slots[k] = id
	_drag = {}
	_refresh.call_deferred()


func _can_drop_list(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and d.has("fuse") and d.from >= 0


func _drop_list(_at: Vector2, d: Variant) -> void:
	_unslot(d.from)
	_drag = {}


## Take the card out of slot k: it runs down to the list.
func _unslot(k: int) -> void:
	if _slots[k] == "":
		return
	_push_back(k)
	_slots[k] = ""
	_refresh.call_deferred()


func _push_back(k: int) -> void:
	var box: PanelContainer = _slot_box[k]
	_fly.append({"id": _slots[k], "from": box.global_position})


func _click_list(id: String) -> void:
	if not run.can_fuse(id):
		return
	var k := 0 if _slots[0] == "" else 1  # the first empty slot; both full: the second one gives way
	if _slots[k] != "":
		_push_back(k)
	_slots[k] = id
	_refresh.call_deferred()


## A card dragged out of a slot and let go anywhere that isn't a slot leaves it too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not _drag.is_empty() and _drag.from >= 0 and not get_viewport().gui_is_drag_successful():
			_unslot(_drag.from)
		_drag = {}


func _commit() -> void:
	if _slots[0] == "" or _slots[1] == "" or _preview.is_empty():
		return
	run.fuse_commit(_preview, _slots[0], _slots[1])
	fused.emit(_preview)
