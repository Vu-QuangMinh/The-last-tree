class_name UiTheme
extends RefCounted
## Shared look for all UI: dark translucent panels, soft green accents.

const BG := Color(0.05, 0.07, 0.06, 0.88)
const BORDER := Color(0.28, 0.38, 0.28)
const TEXT := Color(0.9, 0.92, 0.86)
const MUTED := Color(0.6, 0.66, 0.6)
const ACCENT := Color(0.55, 0.85, 0.45)
const DANGER := Color(0.95, 0.35, 0.3)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "Noto Sans"])
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(8)
		b.content_margin_left = 14
		b.content_margin_right = 14
		b.content_margin_top = 6
		b.content_margin_bottom = 6
		match state:
			"normal":
				b.bg_color = Color(0.13, 0.18, 0.13)
				b.border_color = BORDER
				b.set_border_width_all(1)
			"hover":
				b.bg_color = Color(0.18, 0.26, 0.17)
				b.border_color = ACCENT
				b.set_border_width_all(1)
			"pressed":
				b.bg_color = Color(0.1, 0.14, 0.1)
				b.border_color = ACCENT
				b.set_border_width_all(2)
			"disabled":
				b.bg_color = Color(0.09, 0.1, 0.09)
				b.border_color = Color(0.2, 0.22, 0.2)
				b.set_border_width_all(1)
			"focus":
				b.bg_color = Color(0, 0, 0, 0)
				b.draw_center = false
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", TEXT)
	# tooltips: fully opaque so they read clearly over the board
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.08, 0.1, 0.08, 1.0)
	tip.border_color = ACCENT.darkened(0.2)
	tip.set_border_width_all(2)
	tip.set_corner_radius_all(8)
	tip.content_margin_left = 12
	tip.content_margin_right = 12
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.48, 0.45))
	_theme = t
	return t


static func panel_box(alpha := 0.88, radius := 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(BG, alpha)
	b.border_color = BORDER
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b
