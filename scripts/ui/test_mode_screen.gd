class_name TestModeScreen
extends Control
## Test mode: pick any enemies (1 to 5, from every act) and any active spells, then fight. After the fight you come
## back here with the same picks. You start with the 8 strongest spells (STRONGEST); drag spells from the list (or the random
## spell slot) into your active row, drag them out to take them away, drop one on another to switch them.

signal fight_requested(enemy_ids: Array, spells: Array)
signal event_requested(event_id: String)  # the Events tab: straight into that "?" event
signal custom_requested(test_id: String)  # the Custom tab: one of the hand-made test scenes
signal back

const MAX_ENEMIES := 5
const MAX_SPELLS := 8
const DRAG_START := 10.0
const ZOOM := 0.72  # the cards on this screen are drawn at this size
## The 8 spells a fresh Test mode starts with: the hardest hitters (and one big defence) that can be cast every turn (no Fleeting spell like Annihilate / World's End, no cooldown), so a test fight is about the enemy, not the loadout.
const STRONGEST := ["supernova", "solar_flare", "meteor", "hurricane", "tidal_wave", "deluge", "steam_titan", "elemental_fury"]
const SORTS := ["Rarity", "Type", "Length"]
const RARITY_ORDER := {"common": 0, "rare": 1, "legendary": 2}
const KIND_ORDER := {"damage": 0, "defense": 1, "utility": 2}

## What you picked last time (kept by Main between fights): {enemies: [], spells: [], sort: int, random: ""}.
var state := {}

var _db: SpellDB
var _enemy_row: HBoxContainer  # the enemies you picked
var _active_row: HBoxContainer  # your active spells
var _active_zone: PanelContainer
var _list: HFlowContainer  # every spell
var _random_slot: Control  # the random spell (empty until you roll one)
var _random_id := ""
var _fight_btn: Button
var _press := {}  # {id, at, from: "list" / "random" / "active", card}
var _float: SpellCard
var _grab := Vector2.ZERO


func setup(p_state: Dictionary) -> void:
	state = p_state


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_db = GameData.db
	if not state.has("spells"):
		state.spells = STRONGEST.filter(func(id): return not _db.get_spell(id).is_empty()).slice(0, MAX_SPELLS)
	if not state.has("enemies"):
		state.enemies = []
	if not state.has("sort"):
		state.sort = 0
	_random_id = state.get("random", "")
	var bd := Backdrop.new()
	bd.act = 1
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# three tabs: Fight (pick enemies and spells), Events (go straight into any "?" event), Custom (hand-made test scenes)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(30, 14)
	tabs.add_theme_constant_override("separation", 10)
	add_child(tabs)
	var root := VBoxContainer.new()
	root.position = Vector2(30, 72)
	root.size = Vector2(1860, 990)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	root.add_child(top)
	top.add_child(UiTheme.heading("Test mode", 32, UiTheme.ACCENT))
	top.add_child(UiTheme.label("Pick enemies and spells, then fight. You come back here afterwards.", 18, UiTheme.MUTED))
	# --- enemies: every enemy of the game, by act; click to add (up to 5), click a picked one to take it away
	var ez := _zone(Color(0.9, 0.5, 0.45))
	root.add_child(ez)
	var ev := VBoxContainer.new()
	ez.add_child(ev)
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 12)
	ev.add_child(eh)
	eh.add_child(UiTheme.heading("Enemies", 22, Color(1, 0.8, 0.75)))
	eh.add_child(UiTheme.label("click to add (up to 5) · click a picked one to remove it", 15, UiTheme.MUTED))
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 8)
	_enemy_row.custom_minimum_size = Vector2(0, 40)
	ev.add_child(_enemy_row)
	var escroll := ScrollContainer.new()
	escroll.custom_minimum_size = Vector2(1820, 130)
	escroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ev.add_child(escroll)
	var egrid := VBoxContainer.new()
	egrid.custom_minimum_size = Vector2(1800, 0)
	escroll.add_child(egrid)
	for group in _enemy_groups():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
		row.custom_minimum_size = Vector2(1800, 0)
		var lbl := UiTheme.label(group[0], 15, UiTheme.MUTED)
		lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(lbl)
		for id in group[1]:
			var b := UiTheme.button(EnemyDefs.name_of(id), func(): _add_enemy(id), 14)
			row.add_child(b)
		egrid.add_child(row)
	# --- your active spells
	_active_zone = _zone(Color(1.0, 0.8, 0.35))
	root.add_child(_active_zone)
	var av := VBoxContainer.new()
	_active_zone.add_child(av)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 12)
	av.add_child(ah)
	ah.add_child(UiTheme.heading("Active spells", 22, UiTheme.ACCENT))
	ah.add_child(UiTheme.label("drag spells in · drag them out to remove · drop on a spell to switch · up to 8", 15, UiTheme.MUTED))
	_active_row = HBoxContainer.new()
	_active_row.add_theme_constant_override("separation", 8)
	_active_row.custom_minimum_size = Vector2(0, SpellCard.H * ZOOM)
	av.add_child(_active_row)
	# --- every spell, sorted; and the random spell
	var lz := _zone(Color(0.6, 0.7, 0.6))
	lz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lz)
	var lv := VBoxContainer.new()
	lz.add_child(lv)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 14)
	lv.add_child(lh)
	lh.add_child(UiTheme.heading("All spells", 22, Color(0.85, 0.92, 0.8)))
	lh.add_child(UiTheme.label("Sort by", 16, UiTheme.MUTED))
	var sort := OptionButton.new()
	for k in SORTS.size():
		sort.add_item(SORTS[k], k)
	sort.selected = int(state.sort)
	sort.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort.item_selected.connect(func(k):
		state.sort = k
		_build_list())
	lh.add_child(sort)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(spacer)
	var roll := UiTheme.button("🎲 Random spell", _roll_random, 18)
	roll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(roll)
	_random_slot = PanelContainer.new()
	_random_slot.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * ZOOM
	_random_slot.add_theme_stylebox_override("panel", _slot_box())
	lh.add_child(_random_slot)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1820, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_list = HFlowContainer.new()
	_list.custom_minimum_size = Vector2(1790, 0)
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_list)
	# --- buttons
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 16)
	bh.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bh)
	bh.add_child(UiTheme.button("Main menu", func(): back.emit(), 20))
	_fight_btn = UiTheme.button("Fight!", func(): fight_requested.emit(state.enemies.duplicate(), state.spells.duplicate()), 24)
	_fight_btn.custom_minimum_size = Vector2(240, 54)
	bh.add_child(_fight_btn)
	_refresh()
	_build_list()
	var pages := [root, _events_page(), _custom_page()]
	for k in TABS.size():
		var b := UiTheme.button(TABS[k], func(): _show_tab(k), 22)
		b.custom_minimum_size = Vector2(200, 48)
		b.toggle_mode = true
		tabs.add_child(b)
		_tab_buttons.append(b)
	_pages = pages
	_show_tab(int(state.get("tab", 0)))


const TABS := ["Fight", "Events", "Custom"]
var _pages: Array = []
var _tab_buttons: Array = []


func _show_tab(k: int) -> void:
	state.tab = k
	for i in _pages.size():
		_pages[i].visible = i == k
		_tab_buttons[i].set_pressed_no_signal(i == k)
		_tab_buttons[i].modulate = Color.WHITE if i == k else Color(0.6, 0.6, 0.6)  # (the open tab stands out)


## Events: every "?" event, one button each. You go straight into it (a throwaway run: 999 Leaves, full HP), and come back here.
func _events_page() -> Control:
	var v := VBoxContainer.new()
	v.position = Vector2(30, 72)
	v.size = Vector2(1860, 990)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.heading("Events", 28, UiTheme.ACCENT))
	v.add_child(UiTheme.label("Go straight into a \"?\" event. You get a throwaway run (999 Leaves, full HP) and come back here afterwards.", 18, UiTheme.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.custom_minimum_size = Vector2(1840, 0)
	v.add_child(flow)
	for ev in MapEvents.ALL:
		var id: String = ev.id
		var b := UiTheme.button(ev.title, func(): event_requested.emit(id), 20)
		b.custom_minimum_size = Vector2(420, 56)
		b.tooltip_text = ev.text
		flow.add_child(b)
	v.add_child(_back_row())
	return v


## Custom: hand-made test scenes (more to come).
const CUSTOM := [  # [id, label, what it shows]
	["armadillo_fight", "Anxious Armadillo: the fight", "The whole fight (20 Essence, +2 Thorns a turn, he never attacks), then his ending."],
	["armadillo_end", "Anxious Armadillo: the ending only", "He starts with 1 Essence (Fire): chant one F and his ending plays."],
]


func _custom_page() -> Control:
	var v := VBoxContainer.new()
	v.position = Vector2(30, 72)
	v.size = Vector2(1860, 990)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.heading("Custom", 28, UiTheme.ACCENT))
	if CUSTOM.is_empty():
		v.add_child(UiTheme.label("Nothing here yet.", 20, UiTheme.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.custom_minimum_size = Vector2(1840, 0)
	v.add_child(flow)
	for c in CUSTOM:
		var id: String = c[0]
		var b := UiTheme.button(c[1], func(): custom_requested.emit(id), 20)
		b.custom_minimum_size = Vector2(420, 56)
		b.tooltip_text = c[2]
		flow.add_child(b)
	v.add_child(_back_row())
	return v


func _back_row() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_END
	bh.add_child(UiTheme.button("Main menu", func(): back.emit(), 20))
	box.add_child(bh)
	return box


func _zone(edge: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.02, 0.55)
	sb.border_color = Color(edge, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _slot_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.2)
	sb.border_color = Color(1.0, 0.85, 0.5, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	return sb


## [label, ids] for every act's normal enemies, mini bosses, bosses, and the ones kept in reserve.
func _enemy_groups() -> Array:
	var out := []
	for act in [1, 2, 3]:
		out.append(["Act %d" % act, EnemyDefs.E.keys().filter(func(k): return EnemyDefs.E[k].act == act and not EnemyDefs.E[k].get("elite", false) and not EnemyDefs.E[k].get("boss", false) and not EnemyDefs.E[k].get("member", false))])
		out.append(["Act %d mini bosses" % act, EnemyDefs.E.keys().filter(func(k): return EnemyDefs.E[k].act == act and EnemyDefs.E[k].get("elite", false) and not EnemyDefs.E[k].get("member", false))
			+ EnemyDefs.ELITE_GROUPS.keys().filter(func(k): return EnemyDefs.ELITE_GROUPS[k].act == act)])
		out.append(["Act %d bosses" % act, EnemyDefs.E.keys().filter(func(k): return EnemyDefs.E[k].act == act and EnemyDefs.E[k].get("boss", false) and not EnemyDefs.E[k].get("member", false))])  # (the Handyman brings his own hands)
	out.append(["In reserve", EnemyDefs.E.keys().filter(func(k): return EnemyDefs.E[k].act == 0)])
	return out.filter(func(g): return not g[1].is_empty())


func _add_enemy(id: String) -> void:
	var ids := EnemyDefs.ids_of(id)  # (a group mini boss brings all its members)
	if state.enemies.size() + ids.size() > MAX_ENEMIES:
		Events.toast.emit("Up to 5 enemies.", UiTheme.DANGER)
		return
	state.enemies.append_array(ids)
	_refresh()


func _refresh() -> void:
	for c in _enemy_row.get_children():
		c.queue_free()
	if state.enemies.is_empty():
		_enemy_row.add_child(UiTheme.label("(no enemies yet: click some below)", 16, UiTheme.MUTED))
	for k in state.enemies.size():
		var idx: int = k
		var b := UiTheme.button("✕ " + EnemyDefs.E[state.enemies[k]].name, func():
			state.enemies.remove_at(idx)
			_refresh(), 16)
		_enemy_row.add_child(b)
	for c in _active_row.get_children():
		c.queue_free()
	for id in state.spells:
		_active_row.add_child(_card(id, "active"))
	for k in MAX_SPELLS - state.spells.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * ZOOM
		empty.add_theme_stylebox_override("panel", _slot_box())
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_active_row.add_child(empty)
	for c in _random_slot.get_children():
		c.queue_free()
	if _random_id != "":
		_random_slot.add_child(_card(_random_id, "random"))
	_fight_btn.disabled = state.enemies.is_empty() or state.spells.is_empty()


## Every spell, in the order the sorter says (then by name).
func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var spells: Array = _db.all_spells.duplicate()
	var key := func(s: Dictionary):
		match int(state.sort):
			0:
				return RARITY_ORDER.get(s.rarity, 9)
			1:
				return KIND_ORDER.get(s.kind, 9)
			_:
				return String(s.pattern).length()
	spells.sort_custom(func(a, b):
		var ka = key.call(a)
		var kb = key.call(b)
		return ka < kb or (ka == kb and String(a.name) < String(b.name)))
	for s in spells:
		_list.add_child(_card(s.id, "list"))


func _card(id: String, from: String) -> SpellCard:
	var card := SpellCard.make(_db.get_spell(id))
	card.zoom = ZOOM  # (laid out smaller, so a lot of spells fit on the screen)
	card.selected = from == "active"
	card.set_meta("spell_id", id)
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not is_instance_valid(_float):
			_press = {"id": id, "at": ev.global_position, "from": from, "card": card})
	return card


func _roll_random() -> void:
	var all: Array = _db.all_spells
	var pick: String = all[randi() % all.size()].id
	while all.size() > 1 and pick == _random_id:
		pick = all[randi() % all.size()].id
	_random_id = pick
	state.random = pick
	Audio.play("elem_pickup")
	_refresh()


# ------------------------------------------------------------------ dragging (and clicking)

func _input(ev: InputEvent) -> void:
	if _press.is_empty():
		return
	if ev is InputEventMouseMotion:
		if is_instance_valid(_float):
			_float.position = ev.global_position - _grab - global_position
			_float.rotation = clampf(ev.relative.x * 0.01, -0.25, 0.25)
		elif ev.global_position.distance_to(_press.at) > DRAG_START:
			_begin_drag(ev.global_position)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		var p := _press
		_press = {}
		if is_instance_valid(_float):
			_drop(p, ev.global_position)
		else:
			_click(p)
		get_viewport().set_input_as_handled()


func _begin_drag(pointer: Vector2) -> void:
	var src: SpellCard = _press.card
	if not is_instance_valid(src):
		return
	if is_instance_valid(src._zoom):
		src._zoom.queue_free()
		src._zoom = null
	_grab = (pointer - src.global_position)
	src.modulate.a = 0.35
	_float = SpellCard.make(_db.get_spell(_press.id))
	_float.is_zoom_copy = true
	_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.scale = Vector2(0.85, 0.85)
	_float.z_index = 50
	add_child(_float)
	_float.position = pointer - _grab - global_position
	Audio.play("elem_pickup")


## A quick click: a spell from the list or the random slot goes into the row; an active one leaves it.
func _click(p: Dictionary) -> void:
	if p.from == "active":
		state.spells.erase(p.id)
	elif not (p.id in state.spells):
		if state.spells.size() >= MAX_SPELLS:
			Events.toast.emit("Your active row is full.", UiTheme.DANGER)
			return
		state.spells.append(p.id)
	_refresh()


func _drop(p: Dictionary, at: Vector2) -> void:
	_float.queue_free()
	_float = null
	var over_active := _active_zone.get_global_rect().has_point(at)
	var onto := ""
	for c in _active_row.get_children():
		if c is SpellCard and c.get_global_rect().has_point(at):
			onto = c.get_meta("spell_id")
	if p.from == "active":
		if not over_active:
			state.spells.erase(p.id)  # dragged out: taken away
		elif onto != "" and onto != p.id:
			var a: int = state.spells.find(p.id)
			var b: int = state.spells.find(onto)
			state.spells[a] = onto
			state.spells[b] = p.id
	elif over_active and not (p.id in state.spells):
		if onto != "":
			state.spells[state.spells.find(onto)] = p.id  # it takes that spell's place
		elif state.spells.size() < MAX_SPELLS:
			state.spells.append(p.id)
		else:
			Events.toast.emit("Your active row is full. Drop it on a spell to switch them.", UiTheme.DANGER)
	Audio.play("loadout_swap")
	_refresh()
