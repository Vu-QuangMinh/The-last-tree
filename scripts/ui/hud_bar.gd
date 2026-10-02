class_name HudBar
extends PanelContainer
## Run info along the top of the map and loadout screens.

signal codex_pressed

var run: RunState
var _label: Label
var _arts: HBoxContainer
var _heart: TextureRect


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 0))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(1920, 56)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	add_child(h)
	_arts = HBoxContainer.new()
	_arts.add_theme_constant_override("separation", 4)
	h.add_child(_arts)
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
	h.add_child(info)
	h.add_child(UiTheme.button("Codex", func(): codex_pressed.emit()))
	h.add_child(UiTheme.button(UiTheme.hk("Wiki", "F1"), func(): get_tree().root.get_node("Main").open_wiki() if get_tree().root.has_node("Main") else null))
	refresh()


func refresh() -> void:
	var p := run.player
	_label.text = ("" if _heart != null else "♥ ") + "%d / %d     Act %d     ✿ %d Seedlings     %d spells · %d slots" % [p.hp, p.max_hp, run.act, run.seedlings, run.spellbook.size(), run.active_slots()]
	for c in _arts.get_children():
		c.queue_free()
	for id in run.artifacts:
		_arts.add_child(ArtifactBar.ArtifactChip.make(id, id in run.artifacts_plus))
	# your bottles (and empty bottle slots), after the artifacts
	if run.bottle_slots() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0)
		_arts.add_child(gap)
	for i in run.bottle_slots():
		_arts.add_child(BottleChip.make(run.player.bottles[i] if i < run.player.bottles.size() else "", i, false))
