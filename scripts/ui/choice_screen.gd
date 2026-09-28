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
	var t := UiTheme.label(title, 40, Color.WHITE)
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
	# reward cards are shown larger: each sits scaled inside a holder of the scaled size
	var big := 1.35 if spells.size() <= 5 else 1.0
	for i in spells.size():
		var card := SpellCard.make(spells[i])
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * big
		card.position = Vector2.ZERO
		card.size = Vector2(SpellCard.W, SpellCard.H)
		card.scale = Vector2(big, big)
		card.base_scale = big
		holder.add_child(card)
		var idx := i
		card.clicked.connect(func(_c): chosen.emit(idx))
		row.add_child(holder)
	for i in artifacts.size():
		var a: Dictionary = artifacts[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 180)
		var cursed: bool = a.get("pool", "") == "curse"
		b.text = "%s %s\n%s\n\n%s" % ["☠" if cursed else "◆", a.name, "CURSED" if cursed else a.get("aspect", ""), a.desc]
		if cursed:
			b.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
			b.add_theme_color_override("font_hover_color", Color(1, 0.7, 0.65))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func(): chosen.emit(idx))
		row.add_child(b)
	if can_skip:
		var skip := UiTheme.button("Skip", func(): chosen.emit(-1), 20)
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skip.custom_minimum_size = Vector2(200, 48)
		v.add_child(skip)
