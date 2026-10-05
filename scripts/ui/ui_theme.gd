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


## Forget the cached Theme (the Theme setting changed): the next screen builds it again.
static func reset() -> void:
	_theme = null
	_title_font = null
	_title_font_looked = false


static var _fonts := {}


## One cut of the game's font family (SFU Futura, in assets/fonts); null when the file isn't there.
static func family(file: String) -> Font:
	if not _fonts.has(file):
		var path := "res://assets/fonts/%s.TTF" % file
		_fonts[file] = with_fallbacks(load(path)) if ResourceLoader.exists(path) else null
	return _fonts[file]


const FALLBACK_FONTS := ["NotoColorEmoji.ttf", "NotoSansSymbols2-Regular.ttf", "DejaVuSans.ttf"]
static var _fallbacks: Array[Font] = []


## Gives a font the bundled emoji / symbol fonts as fallbacks, so characters like 🔥 ⌫ ✿ → draw everywhere.
## The web build can't reach system fonts, so without these they show as hex-code boxes.
static func with_fallbacks(f: Font) -> Font:
	if f == null or not f.fallbacks.is_empty():
		return f
	if _fallbacks.is_empty():
		for file in FALLBACK_FONTS:
			var path: String = "res://assets/fonts/" + file
			if ResourceLoader.exists(path):
				_fallbacks.append(load(path))
	f.fallbacks = _fallbacks
	return f


## Settings → Look → Show Hotkey: whether button texts carry their key, like "Chant  (Enter)".
static func show_hotkeys() -> bool:
	return SaveManager.setting("show_hotkeys", true)


## "Chant" + "Enter" -> "Chant  (Enter)", or just "Chant" when hotkeys are hidden.
static func hk(text: String, key: String) -> String:
	return "%s  (%s)" % [text, key] if show_hotkeys() else text


## The display font on a control that must stand out (the Chant / Clear / Pass / Menu buttons); New theme only.
static func use_heading_font(c: Control) -> void:
	var f := title_font()
	if f != null:
		c.add_theme_font_override("font", f)


static var _title_font: Font
static var _title_font_looked := false


## New theme: the display font for headings ("iCiel Cadena": any file in assets/fonts with "ciel" in its name).
## Null in Default, or while the font file isn't there: headings then use the normal font.
static func title_font() -> Font:
	if not UiSkin.is_new():
		return null
	if not _title_font_looked:
		_title_font_looked = true
		for f in DirAccess.get_files_at("res://assets/fonts"):
			var path := "res://assets/fonts/" + f.trim_suffix(".import")
			if "ciel" in f.to_lower() and ResourceLoader.exists(path):
				_title_font = with_fallbacks(load(path))
				break
	return _title_font


## A label for a heading or anything that must stand out (panel titles, names): the display font when there is one.
static func heading(text: String, size := 18, color := TEXT) -> Label:
	var l := label(text, size, color)
	var f := title_font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l


const FONT_OPTIONS := ["futura", "acherus"]
const FONT_LABELS := ["Futura", "Acherus"]
static var _acherus_bold: FontVariation


## Settings → Look → Font: which family the whole game is set in ("futura" or "acherus").
static func font_choice() -> String:
	return SaveManager.setting("font", "futura")


## One cut of the chosen family: "regular", "bold", "oblique" or "boldoblique". Futura has all four as files; Acherus is a
## single italic face, so its bold is that face emboldened. Null when the files aren't there (the caller keeps its font).
static func cut(kind: String) -> Font:
	if font_choice() == "acherus":
		var base: Font = with_fallbacks(load("res://assets/fonts/SVN-Acherus-Italic.otf")) if ResourceLoader.exists("res://assets/fonts/SVN-Acherus-Italic.otf") else null
		if base == null or kind == "regular" or kind == "oblique":
			return base
		if _acherus_bold == null:
			_acherus_bold = FontVariation.new()
			_acherus_bold.base_font = base
			_acherus_bold.variation_embolden = 0.6
		return _acherus_bold
	return family({"regular": "SFUFuturaRegular", "bold": "SFUFuturaBold", "oblique": "SFUFuturaObliqueTTF", "boldoblique": "SFUFuturaBoldOblique"}.get(kind, "SFUFuturaRegular"))


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	with_fallbacks(ThemeDB.fallback_font)  # Godot's own font, used by any control that has no theme
	var font: Font = cut("regular")
	if font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "Noto Sans"])
		font = with_fallbacks(sys)
	t.default_font = font
	t.default_font_size = 18
	# the same family for rich text: bold / italic / bold italic stay what they were, in their Futura cuts
	for pair in [["normal_font", "regular"], ["bold_font", "bold"], ["italics_font", "oblique"], ["bold_italics_font", "boldoblique"]]:
		var f: Font = cut(pair[1])
		if f != null:
			t.set_font(pair[0], "RichTextLabel", f)
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var art := _button_art(state)
		if art != null:
			t.set_stylebox(state, "Button", art)
			continue
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
	if UiSkin.is_new():
		t.set_color("font_color", "Button", Color.WHITE)
		t.set_color("font_outline_color", "Button", Color(0.18, 0.1, 0.07))
		t.set_constant("outline_size", "Button", 5)
	# tooltips: fully opaque so they read clearly over the board
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.08, 0.1, 0.08, 1.0)
	tip.border_color = ACCENT.darkened(0.2)
	tip.set_border_width_all(2)
	tip.set_corner_radius_all(8)
	tip.content_margin_left = 18
	tip.content_margin_right = 18
	tip.content_margin_top = 14
	tip.content_margin_bottom = 14
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 21)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.48, 0.45))
	if UiSkin.is_new():
		t.set_color("font_disabled_color", "Button", Color(0.62, 0.6, 0.57))
	if UiSkin.is_new():
		_skin_scrollbars(t)
	_theme = t
	return t


## New theme: the wooden scroll bar (track + grabber) and the volume slider (the same track on its side + a round knob).
static func _skin_scrollbars(t: Theme) -> void:
	var track := UiSkin.box("scroll_track", [0, 10, 0, 10], [10, 10, 10, 10])
	if track != null and UiSkin.tex("scroll_bar_grabber") != null:
		t.set_stylebox("scroll", "VScrollBar", track)
		for g in ["grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(g, "VScrollBar", StyleBoxEmpty.new())  # the painted thumb is a ScrollThumb on top of the bar (it never stretches)
	var slider_track := UiSkin.box("slider_track", [10, 0, 10, 0], [10, 10, 10, 10])
	var knob := UiSkin.tex("volume_bar_grabber")
	if slider_track != null and knob != null:
		t.set_stylebox("slider", "HSlider", slider_track)
		t.set_stylebox("grabber_area", "HSlider", StyleBoxEmpty.new())
		t.set_stylebox("grabber_area_highlight", "HSlider", StyleBoxEmpty.new())
		for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
			t.set_icon(ic, "HSlider", knob)


## The art for a Button state in the New theme (the small green button); null in Default.
static func _button_art(state: String) -> StyleBox:
	if not UiSkin.is_new():
		return null
	if state == "focus":
		return StyleBoxEmpty.new()  # no focus ring
	var key := state
	return UiSkin.box("button_small_" + key, [12, 12, 12, 14], [12, 2, 12, 9])


## The wooden Menu button's look (normal / hover / pressed): New theme only; empty in Default.
static func menu_button_styles() -> Dictionary:
	if not UiSkin.is_new():
		return {}
	var out := {}
	for state in ["normal", "hover", "pressed"]:
		out[state] = UiSkin.box("button_menu_" + state, [14, 14, 14, 15], [14, 3, 14, 9])
	out["disabled"] = out["normal"]
	return out


## Give a Button the wooden Menu look (New theme only).
static func use_menu_style(b: Button) -> void:
	var st := menu_button_styles()
	for k in st:
		b.add_theme_stylebox_override(k, st[k])


## The Play button on the main menu: a normal button, turning orange (Button Play Hover) when hovered (New theme only).
static func use_play_style(b: Button) -> void:
	if not UiSkin.is_new():
		return
	b.add_theme_stylebox_override("hover", UiSkin.box("button_play_hover", [20, 16, 20, 18], [20, 6, 20, 12]))


## A big amber button (the Chant / Release button): New theme only; null in Default.
static func chant_button_styles() -> Dictionary:
	if not UiSkin.is_new():
		return {}
	var out := {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		# the whole picture: amber face AND its dark 3D base strip (the bottom 14 px stay unstretched)
		var b := UiSkin.box("button_chant_" + state, [20, 16, 20, 14], [20, 4, 20, 16])
		out[state] = b
	return out


static func panel_box(alpha := 0.88, radius := 12) -> StyleBox:
	var art := UiSkin.box("panel_wood_frame", [30, 30, 30, 30], [18, 14, 18, 14])
	if art != null:
		art.modulate_color = Color(1, 1, 1, clampf(alpha + 0.1, 0.0, 1.0))
		return art
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
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	b.mouse_entered.connect(func(): Audio.play("ui_hover", -6.0))
	b.focus_mode = Control.FOCUS_NONE
	return b
