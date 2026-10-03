class_name ArtifactCard
extends PanelContainer
## An artifact on offer (keepsake, treasure, relic): its symbol big in a medallion ringed in its tier colour,
## the name large in that colour, a small faded type line, and the description with hoverable keywords.

signal clicked

const TIER_COL := {"common": Color(0.93, 0.9, 0.78), "rare": Color(0.5, 0.78, 1.0), "legendary": Color(1.0, 0.78, 0.3)}
const CURSED_COL := Color(1.0, 0.45, 0.4)
const W := 360.0

var artifact: Dictionary
var _box: StyleBoxFlat
var _col: Color
var _medal: Control
var _hover := false
var _t := 0.0
var _frame: StyleBoxTexture  # New theme: the painted treasure frame (and its hover twin)
var _frame_hover: StyleBoxTexture
var _ring: Texture2D  # New theme: the medal ring of this artifact's tier


static func make(a: Dictionary) -> ArtifactCard:
	var c := ArtifactCard.new()
	c.artifact = a
	return c


func _ready() -> void:
	var a := artifact
	var cursed: bool = a.get("aspect", "") == "Cursed"
	_col = CURSED_COL if cursed else TIER_COL.get(a.get("tier", "common"), Color.WHITE)
	custom_minimum_size = Vector2(W, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_box = StyleBoxFlat.new()
	_box.bg_color = Color(0.07, 0.08, 0.07, 0.94)
	_box.border_color = _col.darkened(0.35)
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(14)
	_box.content_margin_left = 22
	_box.content_margin_right = 22
	_box.content_margin_top = 18
	_box.content_margin_bottom = 20
	_box.shadow_color = Color(0, 0, 0, 0.5)
	_box.shadow_size = 6
	_frame = UiSkin.box("treasure_card_frame", [12, 12, 12, 12], [26, 22, 26, 24])
	if _frame != null:
		_frame_hover = UiSkin.box("treasure_card_frame_hover", [12, 12, 12, 12], [26, 22, 26, 24])
		_ring = UiSkin.tex("medal_ring_cursed" if cursed else "medal_ring_" + str(a.get("tier", "common")))
		add_theme_stylebox_override("panel", _frame)
	else:
		add_theme_stylebox_override("panel", _box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	# the symbol, big, in a medallion
	_medal = Control.new()
	_medal.custom_minimum_size = Vector2(0, 118)
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medal.draw.connect(_draw_medal)
	v.add_child(_medal)
	var icon: Control = UiSkin.artifact_icon(str(a.get("id", "")), 76)
	if icon != null:
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.offset_left = -38
		icon.offset_right = 38
		icon.offset_top = -38
		icon.offset_bottom = 38
	else:
		icon = UiTheme.label(a.get("icon", "◆"), 60, Color.WHITE)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medal.add_child(icon)
	# name: big and in its tier colour
	var name_l := UiTheme.heading(a.name, 30, _col)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_constant_override("outline_size", 6)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	# type: small and faded
	var tier: String = Artifacts.TIER_NAMES.get(a.get("tier", "common"), "")
	var kind := "%s artifact  ·  %s" % [tier, a.get("aspect", "")]
	var type_l := UiTheme.label(kind, 15, Color(0.62, 0.66, 0.6))
	type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(type_l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	# the description, keywords coloured and hoverable
	var desc := KeywordText.make(a.desc, 20)
	desc.custom_minimum_size = Vector2(W - 44, 0)
	desc.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	v.add_child(desc)
	# the text catches the mouse (for its keyword tooltips), so a click on it still picks the artifact
	desc.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: clicked.emit())


func _process(d: float) -> void:
	_t += d
	_hover = is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())
	# hovered: the frame lights up in its colour and the medallion glows
	if _frame != null:
		add_theme_stylebox_override("panel", _frame_hover if _hover else _frame)
		_medal.queue_redraw()
		return
	var target := _col if _hover else _col.darkened(0.35)
	_box.border_color = _box.border_color.lerp(target, minf(1.0, d * 12.0))
	_box.set_border_width_all(3 if _hover else 2)
	_medal.queue_redraw()


func _draw_medal() -> void:
	var c := _medal.size / 2.0
	var r := 52.0
	if _ring != null:  # New theme: a dark disc behind the artifact, the painted ring around it
		var s := 112.0 / maxf(_ring.get_width(), _ring.get_height())
		var sz := Vector2(_ring.get_width(), _ring.get_height()) * s
		_medal.draw_circle(c, 46.0, Color(0.2, 0.13, 0.1))
		_medal.draw_texture_rect(_ring, Rect2(c - sz / 2.0, sz), false)
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	var glow := 0.18 + (0.22 if _hover else 0.08) * pulse
	for k in 4:
		_medal.draw_circle(c, r + 6.0 + k * 5.0, Color(_col, glow * (1.0 - k * 0.24)))
	_medal.draw_circle(c, r, Color(0.13, 0.14, 0.12))
	_medal.draw_circle(c, r - 6.0, Color(0.18, 0.19, 0.16))
	_medal.draw_arc(c, r, 0, TAU, 48, _col, 3.0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
