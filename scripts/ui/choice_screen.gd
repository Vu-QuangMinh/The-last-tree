class_name ChoiceScreen
extends Control
## Pick one of a few spells or artifacts (or skip). Used for rewards, treasure and the starting relic.

signal chosen(index: int)  # -1 = skipped

var title := ""
var subtitle := ""
var spells: Array = []
var artifacts: Array = []
var can_skip := true
var act := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var t := UiTheme.heading(title, 40, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := UiTheme.label(subtitle, 20, UiTheme.MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1800, 290 if spells.size() <= 5 else 640)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(scroll)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(1780, 0)
	row.add_theme_constant_override("h_separation", 24)
	row.add_theme_constant_override("v_separation", 18)
	scroll.add_child(row)
	# reward cards are drawn larger (laid out big, not stretched, so they stay sharp)
	var big := 1.35 if spells.size() <= 5 else 1.0
	for i in spells.size():
		var card := SpellCard.make(spells[i])
		card.zoom = big
		var idx := i
		card.clicked.connect(func(_c): chosen.emit(idx))
		row.add_child(card)
	for i in artifacts.size():
		var card := ArtifactCard.make(artifacts[i])
		var idx := i
		card.clicked.connect(func(): chosen.emit(idx))
		row.add_child(card)
	if can_skip:
		var skip := UiTheme.button("Skip", func(): chosen.emit(-1), 20)
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skip.custom_minimum_size = Vector2(200, 48)
		v.add_child(skip)
	# the scroll area is as tall as its cards need, up to a limit. It follows the cards' size whenever it changes
	# (they can finish laying out a few frames late), and is never shorter than one full card.
	var floor_h := SpellCard.H * big + 12.0 if not spells.is_empty() else 200.0
	var fit := func():
		if is_instance_valid(row) and is_instance_valid(scroll):
			scroll.custom_minimum_size.y = clampf(row.get_combined_minimum_size().y + 12.0, floor_h, 700.0)
	row.minimum_size_changed.connect(fit)
	fit.call()
	await get_tree().process_frame
	fit.call()
