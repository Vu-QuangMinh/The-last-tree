class_name LoadoutScreen
extends Control
## Before each encounter: see who you face (moves shown once they're in your Codex) and pick your active spells.

signal confirmed
signal codex_pressed

var run: RunState
var enemy_ids: Array = []
var _active_row: HFlowContainer
var _book: HFlowContainer
var _active_zone: PanelContainer  # the active row, framed in gold: these spells come to the fight
var _book_zone: PanelContainer  # the spellbook, framed darker: the rest of your spells
var _count: Label
var _go: Button
## Any card can be dragged: up into the active row to bring it, down into the spellbook to leave it. Dropped on
## another spell, the two switch places. A quick click (no drag) still adds or removes it.
const DRAG_START := 10.0
var _press := {}  # {id, at, card}: the card pressed (a drag starts once the pointer moves far enough)
var _float: SpellCard  # the card in your hand while dragging
var _grab := Vector2.ZERO  # where on the card the pointer took hold
var _hover_target := {}  # {active: bool, id: String} where it would land now (empty: nowhere)


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
	# up to 5 enemies: the panels share the width (440 each when there's room)
	var pw := minf(440.0, (1840.0 - 16.0 * (enemy_ids.size() - 1)) / maxf(1.0, enemy_ids.size()))
	for i in enemy_ids.size():
		er.add_child(_enemy_panel(enemy_ids[i], i, pw))
	# the active row, in its own gold-framed zone
	_active_zone = _zone(Color(1.0, 0.8, 0.35), 0.18)
	root.add_child(_active_zone)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	_active_zone.add_child(av)
	var ah := HBoxContainer.new()
	av.add_child(ah)
	ah.add_child(UiTheme.heading("Active spells", 24, UiTheme.ACCENT))
	_count = UiTheme.label("", 20, UiTheme.MUTED)
	ah.add_child(_count)
	ah.add_child(UiTheme.label("     these come with you into the fight", 17, UiTheme.MUTED))
	# many slots wrap onto a second row instead of running off the screen
	_active_row = HFlowContainer.new()
	_active_row.add_theme_constant_override("h_separation", 10)
	_active_row.add_theme_constant_override("v_separation", 10)
	_active_row.custom_minimum_size = Vector2(1800, SpellCard.H)
	av.add_child(_active_row)
	# between the two: how to move spells
	var hint := UiTheme.label("▲ drag a spell up to bring it   ·   drag it down to leave it ▼   ·   drop it on another spell to switch them   ·   or just click it", 17, Color(0.95, 0.88, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	# the spellbook, in its own darker zone
	_book_zone = _zone(Color(0.6, 0.7, 0.6), 0.32)
	_book_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_book_zone)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	_book_zone.add_child(bv)
	var bh2 := HBoxContainer.new()
	bv.add_child(bh2)
	bh2.add_child(UiTheme.heading("Spellbook", 22, Color(0.85, 0.92, 0.8)))
	bh2.add_child(UiTheme.label("     the rest of your spells. Powers fire once, then leave the row for the rest of the fight.", 16, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1800, SpellCard.H + 6)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bv.add_child(scroll)
	_book = HFlowContainer.new()
	_book.custom_minimum_size = Vector2(1780, 0)
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


func _enemy_panel(id: String, index: int, width := 440.0) -> Control:
	var d := EnemyDefs.get_def(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
	p.custom_minimum_size = Vector2(width, 250)
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
	var text_w := width - 170.0
	v.custom_minimum_size = Vector2(text_w, 0)
	h.add_child(v)
	v.add_child(UiTheme.label(d.name, 22, Color.WHITE))
	# HP stays hidden (?) until you have defeated this enemy once
	var hp := HFlowContainer.new()
	var known := SaveManager.in_codex(id)
	for c in hp_now:
		hp.add_child(ElementIcon.make(c if known else "hidden", 26))
	v.add_child(hp)
	# a light-hearted description; the moves are in the portrait's hover tooltip
	var bio := UiTheme.label(EnemyDefs.BIOS.get(id, d.get("flavor", "")), 17, Color(0.88, 0.9, 0.82))
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size = Vector2(text_w, 0)
	v.add_child(bio)
	var hint := UiTheme.label("Hover the portrait to see its moves.", 14, UiTheme.MUTED)
	v.add_child(hint)
	return p


## A framed zone for a group of cards: a tinted panel with a coloured edge (it glows while a card hovers over it).
func _zone(edge: Color, fill_alpha: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.02, fill_alpha + 0.3)
	sb.border_color = Color(edge, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.set_meta("edge", edge)
	return p


func _refresh() -> void:
	for c in _active_row.get_children():
		c.queue_free()
	for c in _book.get_children():
		c.queue_free()
	for id in run.loadout:
		_active_row.add_child(_card(id, true))
	for i in run.active_slots() - run.loadout.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.2)
		sb.border_color = Color(1.0, 0.85, 0.5, 0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		empty.add_theme_stylebox_override("panel", sb)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_active_row.add_child(empty)
	for id in run.spellbook:
		if not (id in run.loadout):
			_book.add_child(_card(id, false))
	_count.text = "   %d / %d" % [run.loadout.size(), run.active_slots()]
	_go.disabled = run.loadout.is_empty()


## A card in either zone: press it to drag it; let go without moving and it's a click (in or out of the row).
func _card(id: String, active: bool) -> SpellCard:
	var card := SpellCard.make(run.spell(id))
	card.selected = active
	card.set_meta("spell_id", id)
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not is_instance_valid(_float):
			_press = {"id": id, "at": ev.global_position, "card": card})
	return card


func _input(ev: InputEvent) -> void:
	if _press.is_empty():
		return
	if ev is InputEventMouseMotion:
		if is_instance_valid(_float):
			_move_drag(ev.global_position)
		elif ev.global_position.distance_to(_press.at) > DRAG_START:
			_begin_drag(ev.global_position)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		var p := _press
		_press = {}
		if is_instance_valid(_float):
			_drop()
		else:
			_toggle(p.id)
		get_viewport().set_input_as_handled()


## Pick the pressed card up: a copy of it follows the pointer (the card itself stays behind, faded).
func _begin_drag(pointer: Vector2) -> void:
	var src: SpellCard = _press.card
	if not is_instance_valid(src):
		return
	if is_instance_valid(src._zoom):
		src._zoom.queue_free()
		src._zoom = null
	_grab = pointer - src.global_position
	src.modulate.a = 0.3
	_float = SpellCard.make(run.spell(_press.id))
	_float.is_zoom_copy = true  # just a picture of the card: it never takes the mouse
	_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.selected = _press.id in run.loadout
	_float.z_index = 50
	_float.pivot_offset = Vector2(SpellCard.W, SpellCard.H) / 2.0
	add_child(_float)
	Audio.play("elem_pickup")
	_move_drag(pointer)


func _move_drag(pointer: Vector2) -> void:
	if not is_instance_valid(_float):
		return
	var before := _float.position
	_float.position = pointer - _grab - global_position
	_float.scale = Vector2.ONE * 1.08
	_float.rotation = clampf((_float.position.x - before.x) * 0.01, -0.25, 0.25)
	var t := _target_at(pointer)
	if t != _hover_target:
		_hover_target = t
		_show_target()


## Where a card let go here would land: {active: bool, id: the spell it's on ("" = empty space)}; {} = nowhere.
func _target_at(at: Vector2) -> Dictionary:
	for zone in [[_active_zone, _active_row, true], [_book_zone, _book, false]]:
		if not (zone[0] as Control).get_global_rect().has_point(at):
			continue
		for c in (zone[1] as Control).get_children():
			if c is SpellCard and c.get_global_rect().has_point(at) and c.get_meta("spell_id", "") != _press.get("id", ""):
				return {"active": zone[2], "id": c.get_meta("spell_id")}
		return {"active": zone[2], "id": ""}
	return {}


## Light up the zone (and the card) under the card in your hand.
func _show_target() -> void:
	for zone in [_active_zone, _book_zone]:
		var sb: StyleBoxFlat = zone.get_theme_stylebox("panel")
		var edge: Color = zone.get_meta("edge")
		var lit: bool = not _hover_target.is_empty() and _hover_target.active == (zone == _active_zone)
		sb.border_color = Color(edge, 1.0 if lit else 0.55)
		sb.set_border_width_all(5 if lit else 3)
		sb.shadow_color = Color(edge, 0.45 if lit else 0.0)
		sb.shadow_size = 14 if lit else 0
	for row in [_active_row, _book]:
		for c in row.get_children():
			if c is SpellCard and c != _press.get("card"):
				c.modulate = Color(1.25, 1.2, 1.0) if c.get_meta("spell_id", "") == _hover_target.get("id", "#") else Color.WHITE


func _drop() -> void:
	var id: String = _float.spell.id if _float.spell.has("id") else ""
	var t := _hover_target
	_float.queue_free()
	_float = null
	_hover_target = {}
	_show_target()
	if t.is_empty():
		Audio.play("elem_remove", -6.0)  # let go away from both: it goes back
	elif run.drop_spell(id, t.active, t.id):
		Audio.play("loadout_swap")
	else:
		Events.toast.emit("Your active row is full. Drop it on a spell to switch them, or take one out first.", UiTheme.DANGER)
	_refresh.call_deferred()


func _toggle(id: String) -> void:
	if run.toggle_active(id):
		Audio.play("loadout_swap")
	else:
		Events.toast.emit("Your active row is full. Remove a spell first.", UiTheme.DANGER)
	_refresh.call_deferred()
