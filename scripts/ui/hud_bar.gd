class_name HudBar
extends PanelContainer
## Run info along the top of the map and loadout screens.

signal codex_pressed

var run: RunState
var _label: Label
var _arts: HBoxContainer
var _heart: TextureRect
var _resin: HBoxContainer  # purple resin: a lump of resin and how many pieces you carry
var _seals: HBoxContainer  # purple seals (heated resin) ready to apply

const RESIN_TIP := "Purple resin: %d piece%s.\nEvery fusion drips a piece. Heat it at a campfire to turn it into a purple seal."
const SEAL_TIP := "Purple seals: %d ready.\nEach one seals one Essence of a spell's pattern, so that Essence isn't needed any more. Apply them at a campfire (when you heat resin), ask the merchant, or find a Resin Shrine in a ? room."


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
	_resin = _counter(ResinIcon.make(34))
	h.add_child(_resin)
	var seal_icon := ElementIcon.make("F", 34)
	seal_icon.sealed = true
	_seals = _counter(seal_icon)
	h.add_child(_seals)
	h.add_child(UiTheme.button("Codex", func(): codex_pressed.emit()))
	h.add_child(UiTheme.button(UiTheme.hk("Wiki", "F1"), func(): get_tree().root.get_node("Main").open_wiki() if get_tree().root.has_node("Main") else null))
	refresh()


func refresh() -> void:
	var p := run.player
	_label.text = ("" if _heart != null else "♥ ") + "%d / %d     Act %d     ✿ %d Seedlings     %d spells · %d slots" % [p.hp, p.max_hp, run.act, run.seedlings, run.spellbook.size(), run.active_slots()]
	if _resin != null:
		(_resin.get_child(1) as Label).text = "%d resin" % run.resin
		_resin.tooltip_text = RESIN_TIP % [run.resin, "" if run.resin == 1 else "s"]
		_resin.visible = run.resin > 0 or run._fuse_count > 0
		(_seals.get_child(1) as Label).text = "%d seal%s" % [run.purple_seals, "" if run.purple_seals == 1 else "s"]
		_seals.tooltip_text = SEAL_TIP % run.purple_seals
		_seals.visible = run.purple_seals > 0
	for c in _arts.get_children():
		c.queue_free()
	for id in run.artifacts:
		_arts.add_child(ArtifactBar.ArtifactChip.make(id, id in run.artifacts_plus, 56.0))
	# your bottles (and empty bottle slots), after the artifacts
	if run.bottle_slots() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0)
		_arts.add_child(gap)
	for i in run.bottle_slots():
		_arts.add_child(BottleChip.make(run.player.bottles[i] if i < run.player.bottles.size() else "", i, false))


## An icon and a count side by side, with a tooltip (purple resin, purple seals).
func _counter(icon: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(UiTheme.label("", 20, Color(0.88, 0.7, 1.0)))
	return box
