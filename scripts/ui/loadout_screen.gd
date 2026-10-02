class_name LoadoutScreen
extends Control
## Before each encounter: see who you face (moves shown once they're in your Codex) and pick your active spells.

signal confirmed
signal codex_pressed

var run: RunState
var enemy_ids: Array = []
var _active_row: HFlowContainer
var _book: HFlowContainer
var _count: Label
var _go: Button
## Press and hold an active spell to drag it to another place in the row (a quick click takes it out).
const DRAG_START := 10.0
var _press := {}  # {i, id, at}
var _drag: CardDrag


func setup(p_run: RunState, ids: Array) -> void:
	run = p_run
	enemy_ids = ids


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = run.act
	bd.tree_glow = false
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var root := VBoxContainer.new()
	root.position = Vector2(40, 64)
	root.size = Vector2(1840, 920)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var kind := run.current_kind()
	root.add_child(UiTheme.label({"fight": "An encounter", "elite": "An elite blocks the path", "boss": "The boss of this act"}.get(kind, "Encounter"), 28, Color.WHITE))
	# enemies
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 16)
	root.add_child(er)
	for i in enemy_ids.size():
		er.add_child(_enemy_panel(enemy_ids[i], i))
	# active row
	var ah := HBoxContainer.new()
	root.add_child(ah)
	ah.add_child(UiTheme.heading("Active spells", 24, UiTheme.ACCENT))
	_count = UiTheme.label("", 20, UiTheme.MUTED)
	ah.add_child(_count)
	# many slots wrap onto a second row instead of running off the screen
	_active_row = HFlowContainer.new()
	_active_row.add_theme_constant_override("h_separation", 10)
	_active_row.add_theme_constant_override("v_separation", 10)
	_active_row.custom_minimum_size = Vector2(1840, 170)
	root.add_child(_active_row)
	root.add_child(UiTheme.label("Spellbook: click a spell to add it to or remove it from your active row. Press and hold an active spell to move it along the row. Powers fire once and then leave the row for the rest of the fight.", 16, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1840, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_book = HFlowContainer.new()
	_book.custom_minimum_size = Vector2(1820, 0)
	_book.add_theme_constant_override("h_separation", 10)
	_book.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_book)
	# the buttons are pinned to the bottom-right, whatever happens above them
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 20)
	bh.alignment = BoxContainer.ALIGNMENT_END
	bh.position = Vector2(1300, 996)
	bh.size = Vector2(580, 60)
	add_child(bh)
	bh.add_child(UiTheme.button("Codex", func(): codex_pressed.emit()))
	_go = UiTheme.button("Begin the fight", func(): confirmed.emit(), 24)
	_go.custom_minimum_size = Vector2(300, 56)
	bh.add_child(_go)
	var hud := HudBar.new()
	hud.setup(run)
	hud.codex_pressed.connect(func(): codex_pressed.emit())
	add_child(hud)
	_refresh()


func _enemy_panel(id: String, index: int) -> Control:
	var d := EnemyDefs.get_def(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
	p.custom_minimum_size = Vector2(440, 250)
	var h := HBoxContainer.new()
	p.add_child(h)
	# exactly the Essence it will start the fight with (extra Essence on deeper floors included)
	var hp_now: Array = run.encounter_hp(index) if index < run.encounter.size() and run.encounter[index] == id else Array(d.hp.split(""))
	var e := EnemyState.new()
	e.setup(d, hp_now.slice(d.hp.length()))
	e.dmg_bonus = EnemyDefs.attack_bonus(run.act)
	var cr := Creature.new()
	cr.setup(e)
	cr.custom_minimum_size = Vector2(150, 170)
	h.add_child(cr)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(270, 0)
	h.add_child(v)
	v.add_child(UiTheme.label(d.name, 22, Color.WHITE))
	# HP stays hidden (?) until you have defeated this enemy once
	var hp := HFlowContainer.new()
	var known := SaveManager.in_codex(id)
	for c in hp_now:
		hp.add_child(ElementIcon.make(c if known else "?", 26))
	v.add_child(hp)
	# a light-hearted description; the moves are in the portrait's hover tooltip
	var bio := UiTheme.label(EnemyDefs.BIOS.get(id, d.get("flavor", "")), 17, Color(0.88, 0.9, 0.82))
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size = Vector2(270, 0)
	v.add_child(bio)
	var hint := UiTheme.label("Hover the portrait to see its moves.", 14, UiTheme.MUTED)
	v.add_child(hint)
	return p


func _refresh() -> void:
	for c in _active_row.get_children():
		c.queue_free()
	for c in _book.get_children():
		c.queue_free()
	for i in run.loadout.size():
		var id: String = run.loadout[i]
		var card := SpellCard.make(run.spell(id))
		card.selected = true
		# a press starts a possible drag; let go without moving and it's a click (takes it out of the row)
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _drag == null:
				_press = {"i": i, "id": id, "at": ev.global_position})
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		_active_row.add_child(card)
	for i in run.active_slots() - run.loadout.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
		empty.add_theme_stylebox_override("panel", UiTheme.panel_box(0.3, 10))
		_active_row.add_child(empty)
	for id in run.spellbook:
		if id in run.loadout:
			continue
		var card := SpellCard.make(run.spell(id))
		card.clicked.connect(func(_c): _toggle(id))
		_book.add_child(card)
	_count.text = "   %d / %d" % [run.loadout.size(), run.active_slots()]
	_go.disabled = run.loadout.is_empty()


func _input(ev: InputEvent) -> void:
	if _press.is_empty():
		return
	if ev is InputEventMouseMotion:
		if is_instance_valid(_drag):
			_drag.set_pointer(ev.global_position)
		elif ev.global_position.distance_to(_press.at) > DRAG_START and run.loadout.size() > 1:
			_begin_drag(ev.global_position)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		var p := _press
		_press = {}
		if is_instance_valid(_drag):
			var res: Array = _drag.finish()
			_drag.queue_free()
			_drag = null
			_active_row.modulate.a = 1.0
			if res[0] != res[1]:
				run.move_active(res[0], res[1])
				Audio.play("loadout_swap")
			_refresh()
		else:
			_toggle(p.id)
		get_viewport().set_input_as_handled()


func _begin_drag(pointer: Vector2) -> void:
	var cards := _active_row.get_children().filter(func(c): return c is SpellCard)
	var slot_pos := []
	for c in cards:
		slot_pos.append(c.global_position)
		# no magnified hover copy while dragging, and the hidden row mustn't catch the mouse
		if is_instance_valid(c._zoom):
			c._zoom.queue_free()
			c._zoom = null
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_row.modulate.a = 0.0
	_drag = CardDrag.new()
	add_child(_drag)
	_drag.begin(run.loadout.map(func(id): return run.spell(id)), slot_pos, _press.i, pointer)


func _toggle(id: String) -> void:
	if run.toggle_active(id):
		Audio.play("loadout_swap")
	else:
		Events.toast.emit("Your active row is full. Remove a spell first.", UiTheme.DANGER)
	_refresh.call_deferred()
