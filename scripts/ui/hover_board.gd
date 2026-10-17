class_name HoverBoard
extends RefCounted
## The hover board of the Puppet Stage (the painted 9-slice board of the Chant UI PDF): the thing's picture in proportion, 100 px tall, on the left, all the words on the
## right. The board is only as wide as its words need. Used by the artifacts, the bottles and the debuffs.


static func available() -> bool:
	return UiSkin.is_puppet() and UiSkin.tex("artifact_hover_board") != null


## A Theme whose tooltip box is empty: set on a control that shows a board, so the game's own tooltip box does not sit behind the painted one.
static func bare_theme() -> Theme:
	var th := Theme.new()
	th.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	return th


## `tex`: the picture (null: words only); `bbcode`: the tooltip text (Keywords.tooltip).
static func make(tex: Texture2D, bbcode: String, left_of: Control = null) -> Control:
	var panel := PanelContainer.new()
	var m: Array = PuppetTopHud.HOVER_MARGINS
	var sb := UiSkin.box("artifact_hover_board", [int(m[0]), int(m[1]), int(m[2]), int(m[3])], [int(m[0]) + 8, int(m[1]) + 6, int(m[2]) + 8, int(m[3]) + 6])
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("bare", true)  # (a pinned copy is not put in the game's tooltip box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		var h := 100.0
		var w := h * tex.get_width() / float(tex.get_height())
		if w > 140.0:  # (a very wide picture is held to 140 px: its height follows, so it is never squeezed)
			h = h * 140.0 / w
			w = 140.0
		r.custom_minimum_size = Vector2(w, h)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	var label := Keywords.make_tooltip(bbcode)
	label.custom_minimum_size = Vector2(Keywords.natural_width(bbcode, 200.0, 440.0), 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	if left_of != null:  # the tooltip window is put to the left of the control, level with it (the game puts it under the mouse by itself)
		panel.resized.connect(func() -> void: _place_left.call_deferred(panel, left_of))
	return panel


static func _place_left(panel: Control, anchor: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree() or not is_instance_valid(anchor):
		return
	var w := panel.get_window()
	if w == null or w == panel.get_tree().root:
		return
	var r := anchor.get_global_rect()
	var sz := Vector2(w.size)
	var screen := panel.get_tree().root.get_visible_rect().size
	var pos := Vector2(r.position.x - sz.x - 10.0, r.get_center().y - sz.y / 2.0)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, screen.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, screen.y - sz.y))
	w.position = Vector2i(pos)
