class_name HudBar
extends PanelContainer
## Run info along the top of the map and loadout screens.

signal codex_pressed

var run: RunState
var _label: Label
var _seed_icon: TextureRect  # New theme: the painted Seedling replaces the ✿ in the line
var _label2: Label  # ...and the rest of the line, after it
var _arts: HBoxContainer  # the artifacts, then the bottles: each in its own row with its own frame
var _art_row: HBoxContainer
var _bottle_row: HBoxContainer
var _heart: TextureRect
var _on_stage := false  # laid over the Puppet stage: a small block in the top left corner



func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	if UiSkin.is_puppet():  # (no long bar behind: only its parts, the frames of the artifacts and the bottles, the numbers, the buttons)
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 0))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(1920, 56)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	add_child(h)
	_arts = HBoxContainer.new()
	_arts.add_theme_constant_override("separation", 12)  # (between the artifacts' frame and the bottles')
	h.add_child(_arts)
	_art_row = HBoxContainer.new()
	_art_row.add_theme_constant_override("separation", 4)
	_arts.add_child(_art_row)
	_bottle_row = HBoxContainer.new()
	_bottle_row.add_theme_constant_override("separation", 4)
	_arts.add_child(_bottle_row)
	UiSkin.frame_behind(_art_row, Vector2(16, 6), "slot_strip_brass")  # (Puppet: the artifacts' frame has a brass rim, the bottles' is plain wood)
	UiSkin.frame_behind(_bottle_row, Vector2(16, 6), "slot_strip_wood")
	if UiSkin.is_puppet() and not get_tree().get_nodes_in_group("fight_screen").is_empty():
		_art_row.visible = false  # (laid over the stage: the stage's own frames, top left, show the artifacts and the bottles: two frames on top of each other looked wrong)
		_bottle_row.visible = false
		_on_stage = true  # (the top frame of the fight screen shows Act, HP, bottles and artifacts: only the Seedlings line and the Codex / Wiki buttons are left here)
	_label = UiTheme.label("", 20, Color.WHITE)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heart = UiSkin.icon("icon_heart", 28)
	if _heart != null:  # New theme: the painted heart instead of the ♥ character
		_heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(_heart)
	info.add_child(_label)
	_seed_icon = UiSkin.icon("icon_seedling", 30)
	if _seed_icon != null:
		_seed_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(_seed_icon)
		_label2 = UiTheme.label("", 20, Color.WHITE)
		info.add_child(_label2)
	var codex := UiTheme.button("Codex", func(): codex_pressed.emit())
	var wiki := UiTheme.button(UiTheme.hk("Wiki", "F1"), func(): get_tree().root.get_node("Main").open_wiki() if get_tree().root.has_node("Main") else null)
	if _on_stage:
		h.queue_free()  # (a two-line block in the corner, clear of the top frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 8)
		btns.add_child(codex)
		btns.add_child(wiki)
		box.add_child(btns)
		info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(info)
		var pad := MarginContainer.new()  # (top left corner)
		pad.add_theme_constant_override("margin_left", 20)
		pad.add_theme_constant_override("margin_top", 26)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(box)
		add_child(pad)
		custom_minimum_size = Vector2(1920, 56)
	else:
		h.add_child(info)
		h.add_child(codex)
		h.add_child(wiki)
	refresh()


func refresh() -> void:
	var p := run.player
	if _on_stage:  # (HP and Act are in the top frame)
		if _heart != null:
			_heart.visible = false
		_label.text = ""
		if _label2 != null:
			_label2.text = "%d Seedlings · %d spells · %d slots" % [run.seedlings, run.spellbook.size(), run.active_slots()]
		else:
			_label.text = "✿ %d Seedlings · %d spells · %d slots" % [run.seedlings, run.spellbook.size(), run.active_slots()]
	elif _label2 != null:
		_label.text = ("" if _heart != null else "♥ ") + "%d / %d     Act %d    " % [p.hp, p.max_hp, run.act]
		_label2.text = "%d Seedlings     %d spells · %d slots" % [run.seedlings, run.spellbook.size(), run.active_slots()]
	else:
		_label.text = ("" if _heart != null else "♥ ") + "%d / %d     Act %d     ✿ %d Seedlings     %d spells · %d slots" % [p.hp, p.max_hp, run.act, run.seedlings, run.spellbook.size(), run.active_slots()]
	for c in _art_row.get_children() + _bottle_row.get_children():
		c.queue_free()
	if _on_stage:
		return
	for id in run.artifacts:
		_art_row.add_child(ArtifactBar.ArtifactChip.make(id, id in run.artifacts_plus, 56.0))
	# your bottles (and empty bottle slots), after the artifacts
	for i in run.player.bottles.size() if UiSkin.is_new() else run.bottle_slots():  # (painted themes: only the bottles you carry)
		_bottle_row.add_child(BottleChip.make(run.player.bottles[i] if i < run.player.bottles.size() else "", i, false, 56.0))
