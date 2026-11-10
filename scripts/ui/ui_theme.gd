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
	_fonts.clear()
	_fallbacks = []  # (a new array: the fonts already out there keep the one they hold)
	_single_bold.clear()
	_title_font = null
	_title_font_looked = false


static var _fonts := {}
const GLOBAL_FONTS := "res://assets/Global/Fonts/"


## A font file (with its extension): the chosen theme's own Fonts folder first, then Global/Fonts. "" when there is none.
static func font_path(file: String) -> String:
	for dir in [UiSkin.theme_dir() + "Fonts/", GLOBAL_FONTS]:
		if ResourceLoader.exists(dir + file):
			return dir + file
	return ""


## One cut of the game's font family (SFU Futura, in a Fonts folder); null when the file isn't there.
static func family(file: String) -> Font:
	if not _fonts.has(file):
		var path := font_path(file + ".TTF")
		_fonts[file] = with_fallbacks(load(path)) if path != "" else null
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
			var path := font_path(file)
			if path != "":
				_fallbacks.append(load(path))
	f.fallbacks = _fallbacks
	return f


## Settings → Look → Show Hotkey: whether button texts carry their key, like "Chant  (Enter)".
static func show_hotkeys() -> bool:
	return SaveManager.setting("show_hotkeys", true)


## "Chant" + "Enter" -> "Chant  (Enter)", or just "Chant" when hotkeys are hidden.
static func hk(text: String, key: String) -> String:
	return "%s  (%s)" % [text, key] if show_hotkeys() else text


## The display font on a control that must stand out (the Chant / Clear / Pass / Menu buttons); New theme only. Settings > Header styles ("button") restyles it.
static func use_heading_font(c: Control) -> void:
	var f := title_font()
	if f != null:
		c.add_theme_font_override("font", f)
	apply_header(c, "button", c.get_theme_font_size("font_size"))


static var _title_font: Font
static var _title_font_looked := false


## The display font for headings ("iCiel Cadena": any file with "ciel" in its name, in the theme's Fonts folder or Global/Fonts).
## Null while the font file isn't there: headings then use the normal font.
static func title_font() -> Font:
	if not _title_font_looked:
		_title_font_looked = true
		for dir in [UiSkin.theme_dir() + "Fonts/", GLOBAL_FONTS]:
			for f in DirAccess.get_files_at(dir):
				var name := f.trim_suffix(".import")
				if "ciel" in name.to_lower() and ResourceLoader.exists(dir + name):
					_title_font = with_fallbacks(load(dir + name))
					break
			if _title_font != null:
				break
	return _title_font


## A label for a heading or anything that must stand out (panel titles, names): the display font when there is one. `group` is its Settings > Header styles group
## ("title" for a big one, "section" for a small one, "card" for a card's name, when not given).
static func heading(text: String, size := 18, color := TEXT, group := "") -> Label:
	var l := Label.new()  # (not label(): a heading follows its own group's size, not the body size)
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := title_font()
	if f != null:
		l.add_theme_font_override("font", f)
	apply_header(l, group if group != "" else ("title" if size >= 30 else "section"), size)
	return l


## ---- Settings > Font Edit (and F7, the text inspector): each group of text has its own font, size, gap between the letters, colour and stroke colour ----
## "body" is every ordinary label and button made by UiTheme.label / UiTheme.button; the others are the headers.
const HEADER_GROUPS := ["body", "title", "section", "card", "event", "button"]
const HEADER_LABELS := ["Body text", "Screen titles", "Section headers", "Card names", "Event titles", "Buttons (Chant, Clear, Menu...)"]
## font "default": the group's own font; colour "": the one the code gave; stroke with alpha 0: none.
const HEADER_DEFAULT := {"font": "default", "scale": 100.0, "spacing": 0.0, "color": "", "stroke": "00000000"}


## What the player set for a group (anything not set is the default).
static func header_style(group: String) -> Dictionary:
	var out := HEADER_DEFAULT.duplicate()
	var all = SaveManager.setting("header_styles", {})
	if all is Dictionary and all.has(group) and all[group] is Dictionary:
		for k in all[group]:
			out[k] = all[group][k]
	return out


static func set_header_style(group: String, style: Dictionary) -> void:
	var all = SaveManager.setting("header_styles", {})
	if not (all is Dictionary):
		all = {}
	all[group] = style
	SaveManager.set_setting("header_styles", all)


## The font of a group: its own default (the headers: the display font; "event" and "body": none, so the game's font stays), or a family of FONT_OPTIONS, with the gap between letters.
static func header_font(group: String, style: Dictionary) -> Font:
	var base: Font = null
	var choice := String(style.get("font", "default"))
	if choice == "default":
		if group != "event" and group != "body":
			base = title_font()
	else:
		base = font_for_option(choice, "regular")
	var gap := float(style.get("spacing", 0.0))
	if gap == 0.0:
		return base
	if base == null:
		base = cut("regular")
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = int(round(gap))
	return fv


## Dress a Label (or Button) in its group's style (or in `style`, an unsaved one); `size` is the size the code asked for (the group's size is a percentage of it).
## The control remembers its group and size (so the F7 inspector and Font Edit can restyle it later) and what it looked like before (so a style taken away puts that back).
static func apply_header(c: Control, group: String, size: int, style := {}) -> void:
	if style.is_empty():
		apply_text_edit(c)
	var st: Dictionary = style if not style.is_empty() else header_style(group)
	var ts := text_style(c) if style.is_empty() else {}  # (a style kept for this one text by the F7 inspector: it wins over the group's)
	if not ts.is_empty():
		st = st.duplicate()
		st.font = ts.font
		st.spacing = ts.spacing
		if String(ts.get("color", "")) != "":
			st.color = ts.color
	if not c.has_meta("hg_orig"):
		c.set_meta("hg_orig", {"color": c.get_theme_color("font_color"), "outline": c.get_theme_constant("outline_size"), "ocolor": c.get_theme_color("font_outline_color"), "font": c.get_theme_font_size("font_size")})
	c.set_meta("hg", group)
	c.set_meta("hg_size", size)
	var orig: Dictionary = c.get_meta("hg_orig")
	var f := header_font(group, st)
	if f != null:
		c.add_theme_font_override("font", f)
		c.set_meta("hg_font", true)
	elif c.has_meta("hg_font"):  # (only a font this function set is taken away: the code sets its own on some labels)
		c.remove_theme_font_override("font")
		c.remove_meta("hg_font")
	var scale := float(st.scale) / 100.0
	if not ts.is_empty() and int(ts.get("px", 0)) > 0:
		c.add_theme_font_size_override("font_size", int(ts.px))
		scale = float(ts.px) / maxf(float(size), 1.0)
	elif size > 0 and scale != 1.0:
		c.add_theme_font_size_override("font_size", maxi(6, roundi(float(size) * scale)))
	elif size > 0:
		c.add_theme_font_size_override("font_size", size)
	var col := String(st.get("color", ""))
	c.add_theme_color_override("font_color", Color.html(col) if col != "" else orig.color)
	var stroke := Color.html(String(st.stroke))
	if stroke.a > 0.0:
		c.add_theme_constant_override("outline_size", maxi(2, roundi(float(size) * scale * 0.12)))
		c.add_theme_color_override("font_outline_color", stroke)
	else:
		c.add_theme_constant_override("outline_size", int(orig.outline))
		c.add_theme_color_override("font_outline_color", orig.ocolor)
	if c is Button:  # (a button's other states carry their own colours)
		for k in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
			if col != "":
				c.add_theme_color_override(k, Color.html(col))
	set_offset(c, Vector2(float(ts.get("dx", 0)), float(ts.get("dy", 0))) if not ts.is_empty() else Vector2.ZERO)
	if style.is_empty() and (c is Label or c is Button):
		c.set_meta("hg_key", text_key(c))
		if not c.has_meta("hg_watch"):
			c.set_meta("hg_watch", true)
			# (words given to the text after it was made: its saved style and place are looked for again)
			c.minimum_size_changed.connect(func() -> void:
				if is_instance_valid(c) and text_key(c) != String(c.get_meta("hg_key", "")) and c.has_meta("hg"):
					apply_header(c, String(c.get_meta("hg")), int(c.get_meta("hg_size"))))


## The style the F7 inspector kept for one text (found by its words): {"font", "px", "spacing", "color"}, or {} when there is none.
static func text_key(c: Control) -> String:
	if c.has_meta("orig_text"):
		return String(c.get_meta("orig_text"))  # (a text the inspector reworded keeps its first words as its key)
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	elif c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	return t.strip_edges().substr(0, 120)


## The F7 inspector's reworded texts: Settings "text_edits" {first words: new words}. A Label or Button takes them when it is made (and back again when the edit is taken away).
static func apply_text_edit(c: Control) -> void:
	if not (c is Label or c is Button):
		return
	var key := text_key(c)
	if key == "":
		return
	var all = SaveManager.setting("text_edits", {})
	var now: String = (c as Label).text if c is Label else (c as Button).text
	var want := key
	if all is Dictionary and all.has(key):
		want = String(all[key])
	if now == want:
		return
	if c is Label:
		(c as Label).text = want
	else:
		(c as Button).text = want
	if want == key:
		c.remove_meta("orig_text")
	else:
		c.set_meta("orig_text", key)


static func text_style(c: Control) -> Dictionary:
	var all = SaveManager.setting("text_styles", {})
	var key := text_key(c)
	if key != "" and all is Dictionary and all.has(key) and all[key] is Dictionary:
		var out := {"font": "default", "px": 0, "spacing": 0.0, "color": "", "dx": 0, "dy": 0}
		for k in all[key]:
			out[k] = all[key][k]
		return out
	return {}


## Move a text by `off` pixels from where its container (or its code) puts it (the F7 inspector's arrows). A container puts its children back at every layout, so the offset is
## added again after each one (Container.sort_children); a text that is not in a container is moved once, when it enters the tree.
static func set_offset(c: Control, off: Vector2) -> void:
	var had: Vector2 = c.get_meta("off") if c.has_meta("off") else Vector2.ZERO
	if off == had and c.has_meta("off_hooked"):
		return
	if off == Vector2.ZERO and not c.has_meta("off_hooked"):
		return
	c.set_meta("off", off)
	if not c.has_meta("off_hooked"):
		c.set_meta("off_hooked", true)
		c.set_meta("off_applied", Vector2.ZERO)
		var hook := func() -> void:
			if not is_instance_valid(c):
				return
			var p := c.get_parent()
			if p is Container:
				(p as Container).sort_children.connect(func() -> void: _resort(c))  # (a lambda of its own: two texts of one container with the same bound call would count as one connection)
				_shift(c)
			else:
				_shift.bind(c).call_deferred()  # (a screen that places its children itself does it right after add_child: the offset goes on top of that)
		if c.is_inside_tree():
			hook.call()
		else:
			c.tree_entered.connect(hook, CONNECT_ONE_SHOT)
	elif c.is_inside_tree():
		_shift(c)


static func _resort(c: Control) -> void:
	if is_instance_valid(c):
		c.set_meta("off_applied", Vector2.ZERO)  # (the container just put it back in its place)
		_shift(c)


static func _shift(c: Control) -> void:
	var want: Vector2 = c.get_meta("off")
	var applied: Vector2 = c.get_meta("off_applied")
	c.position += want - applied
	c.set_meta("off_applied", want)


## Restyle every text of the tree that belongs to a group (after a group's style changed).
static func reapply_all(root: Node) -> void:
	for n in root.get_children():
		if n.has_meta("hg_skip"):
			continue  # (the F7 inspector's own window)
		if n is Control and n.has_meta("hg"):
			apply_header(n, String(n.get_meta("hg")), int(n.get_meta("hg_size")))
		reapply_all(n)


const FONT_OPTIONS := ["futura", "acherus", "ba_le", "thanh_pho", "tungsten", "desire"]
const FONT_LABELS := ["Futura", "Acherus", "UVN Ba Le", "UVN Thanh Pho", "SVN Tungsten Book", "SVN Desire"]
## The families that are one file (plus, where there is one, a file for the bold): font option -> [regular file, bold file]. A family with no bold file is emboldened.
const SINGLE_FONTS := {
	"acherus": ["SVN-Acherus-Italic.otf", ""],
	"ba_le": ["UVNBaLe.TTF", ""],
	"thanh_pho": ["UVNThanhPho_R.TTF", "UVNThanhPho.TTF"],
	"tungsten": ["SVN-Tungsten Book.ttf", ""],
	"desire": ["SVN-Desire.otf", ""],
}
static var _single_bold := {}


## Settings → Look → Font: which family the whole game is set in (one of FONT_OPTIONS).
static func font_choice() -> String:
	return SaveManager.setting("font", "futura")


## One cut of the chosen family: "regular", "bold", "oblique" or "boldoblique". Futura has all four as files; the single-file families (Acherus is italic itself,
## the others upright) use their file for the regular and the oblique, and their bold file for the bold, or the regular emboldened when they have none.
## Null when the files aren't there (the caller keeps its font).
static func cut(kind: String) -> Font:
	return font_for_option(font_choice(), kind)


## A cut of any family of FONT_OPTIONS (the chosen one, or the one a header group asks for).
static func font_for_option(choice: String, kind: String) -> Font:
	if SINGLE_FONTS.has(choice):
		var files: Array = SINGLE_FONTS[choice]
		var path := font_path(files[0])
		var base: Font = with_fallbacks(load(path)) if path != "" else null
		if base == null or kind == "regular" or kind == "oblique":
			return base
		if files[1] != "" and font_path(files[1]) != "":
			return with_fallbacks(load(font_path(files[1])))
		if not _single_bold.has(choice):
			var fv := FontVariation.new()
			fv.base_font = base
			fv.variation_embolden = 0.6
			_single_bold[choice] = fv
		return _single_bold[choice]
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
	t.default_font_size = px(18)
	for fs in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(fs, "RichTextLabel", px(18))
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
	var tip_art := UiSkin.frame("bubble_dark", 16, [20, 14, 20, 14])  # (the painted dark plaque, when it is there)
	t.set_stylebox("panel", "TooltipPanel", tip_art if tip_art != null else tip)
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
	var fam := family_box("default", state)
	if fam != null:
		return fam
	var key := state
	return UiSkin.box("button_small_" + key, [12, 12, 12, 14], [12, 2, 12, 9])


## The button family (btn_<kind>.png, cut from the ImageSet plaques by tools/cut_dialogue_panel.py): one carved walnut plaque with a brass line, painted a colour for what the
## button does. Buttons that do the same thing look the same everywhere:
##   primary (ochre gold)  go on / start / confirm: Continue, Next, Begin the fight, Engage!, the choices of an event
##   default (oiled walnut) any other action: tabs, Codex, Wiki, Talk ... (and every plain Button the theme dresses)
##   back (cream)           leave a screen without doing anything: Back, Close, Skip, Cancel, Menu, Goodbye
##   danger (wine red)      destroys or gives up: Yes (to a warning), Quit, removing things
##   buy (moss green)       spends something to get something: Buy, Take, Unlock
const FAMILY_TEXT := {"primary": Color(0.22, 0.07, 0.05), "back": Color(0.22, 0.07, 0.05)}  # (the rest: cream words on the dark plaque)
const FAMILY_WORDS := {
	"primary": ["continue", "next", "go on", "begin", "engage", "fuse", "done", "play", "new run", "fight", "chant", "leave the shop"],
	"back": ["back", "close", "skip", "cancel", "menu", "main menu", "goodbye", "keep the ink", "clear"],
	"danger": ["yes", "quit", "abandon", "✕", "give up", "delete"],
	"buy": ["buy", "take ·", "unlock", "sold"],
}


## The kind of a button from its words ("default" when nothing fits).
static func kind_for(text: String) -> String:
	var t := text.strip_edges().to_lower().trim_prefix("☰ ")
	for kind in ["buy", "danger", "back", "primary"]:
		for w: String in FAMILY_WORDS[kind]:
			if t.begins_with(w):
				return kind
	return "default"


static func family_box(kind: String, state: String) -> StyleBox:
	if state == "focus":
		return StyleBoxEmpty.new() if UiSkin.tex("btn_" + kind) != null else null
	var b := UiSkin.box("btn_" + kind, [20, 14, 20, 14], [16, 3, 16, 5])
	if b == null:
		return null
	match state:
		"hover":
			b.modulate_color = Color(1.14, 1.12, 1.05)
		"pressed":
			b.modulate_color = Color(0.78, 0.74, 0.68)
		"disabled":
			b.modulate_color = Color(0.55, 0.55, 0.55)
	return b


## Dress a Button as one of the family (the theme's own art when the family is missing, e.g. in the Classic theme).
static func skin_button(b: Button, kind: String, size := 0) -> void:
	if not UiSkin.is_new() or UiSkin.tex("btn_" + kind) == null:
		return
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, family_box(kind, state))
	var ink: Color = FAMILY_TEXT.get(kind, Color(0.98, 0.93, 0.8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", ink.darkened(0.3) if kind in FAMILY_TEXT else Color(0.7, 0.66, 0.6))
	var dark := kind in FAMILY_TEXT
	b.add_theme_constant_override("outline_size", 0 if dark else 3)
	if not dark:
		b.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	if size > 0:
		b.add_theme_font_size_override("font_size", size)


## The wooden Menu button's look (normal / hover / pressed): New theme only; empty in Default.
static func menu_button_styles() -> Dictionary:
	if not UiSkin.is_new():
		return {}
	var out := {}
	if UiSkin.tex("btn_back") != null:
		for state in ["normal", "hover", "pressed", "disabled"]:
			out[state] = family_box("back", state)
		return out
	for state in ["normal", "hover", "pressed"]:
		if UiSkin.is_puppet() and UiSkin.path_of("button_menu_" + state).contains("/Puppet/"):  # (its own plate: 131 x 46)
			out[state] = UiSkin.box("button_menu_" + state, [20, 16, 20, 20], [16, 2, 16, 8])
		else:
			out[state] = UiSkin.box("button_menu_" + state, [14, 14, 14, 15], [14, 3, 14, 9])
	out["disabled"] = out["normal"]
	return out


## Give a Button the wooden Menu look (New theme only).
static func use_menu_style(b: Button) -> void:
	if UiSkin.tex("btn_back") != null:
		skin_button(b, "back")
		return
	var st := menu_button_styles()
	for k in st:
		b.add_theme_stylebox_override(k, st[k])


## The Play button on the main menu: a normal button, turning orange (Button Play Hover) when hovered (New theme only).
static func use_play_style(b: Button, always := false) -> void:
	if not UiSkin.is_new():
		return
	if UiSkin.tex("btn_primary") != null:
		skin_button(b, "primary")  # (the gold plaque of the family: Play, Continue, Leave the shop)
		return
	var orange := UiSkin.box("button_play_hover", [20, 16, 20, 18], [20, 6, 20, 12])
	b.add_theme_stylebox_override("hover", orange)
	if always and orange != null:  # (the orange plank is the button's face all the time, not only under the mouse)
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, orange)
		b.add_theme_color_override("font_color", Color(0.2, 0.1, 0.04))
		b.add_theme_color_override("font_hover_color", Color(0.1, 0.05, 0.02))
		b.add_theme_color_override("font_pressed_color", Color(0.1, 0.05, 0.02))


## Puppet Stage: the wooden button of the Chant strip (kind "chant", "clear" or "pass"; Undo uses "clear"), blank: the word is the button's text.
static func puppet_button_styles(kind: String, art := true) -> Dictionary:
	var out := {}
	if art and UiSkin.is_minhhud() and kind != "clear":  # (MinhHUD: the round Chant / Pass button is one picture drawn by Hud2Layout; these Buttons only take the clicks)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			out[state] = StyleBoxEmpty.new()
		return out
	if art and (UiSkin.is_hud2() or UiSkin.is_minhhud()) and UiSkin.tex("hud2_btn_" + kind) != null:  # (Puppet HUD ver 2: the user's own painted buttons from the PDF, the word is in the picture; hover = the same picture lit, pressed = its own pressed picture)
		var pressed := "hud2_btn_%s_pressed" % kind
		for state in ["normal", "hover", "pressed", "disabled"]:
			var b := UiSkin.box(pressed if state == "pressed" and UiSkin.tex(pressed) != null else "hud2_btn_" + kind)
			b.modulate_color = Hud2Layout.tint_of(state)
			out[state] = b
		out["focus"] = StyleBoxEmpty.new()
		return out
	var m := [14, 12, 14, 12] if kind == "chant" else [10, 8, 10, 8]
	if UiSkin.is_newui2():
		m = [0, 0, 0, 0]  # (NewUI Ver2: the pictures are full size and not cut in nine: the whole picture is stretched to the button, they have its shape)
	for state in ["normal", "hover", "pressed", "disabled"]:
		out[state] = UiSkin.box("button_%s_%s" % [kind, state], m, [4, 2, 4, 4])
	return out


## Puppet Stage: dress a button as one of those wooden buttons, its word stamped in the art's orange.
static func style_puppet_button(b: Button, kind: String, size: int, art := true) -> void:
	var st := puppet_button_styles(kind, art)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	if art and (UiSkin.is_hud2() or UiSkin.is_minhhud() or UiSkin.is_newui2()):
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # (the painted pictures are big and drawn small: mipmaps keep them smooth)
	b.add_theme_font_size_override("font_size", size)
	var ink := Color(1.0, 0.93, 0.78) if (UiSkin.is_hud2() or UiSkin.is_minhhud()) and art else Color(0.96, 0.72, 0.42)  # (HUD ver 2: cream words on the lighter wood)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.55, 0.48))
	b.add_theme_color_override("font_outline_color", Color(0.17, 0.09, 0.05))
	b.add_theme_constant_override("outline_size", 3)


## A big amber button (the Chant / Release button): New theme only; null in Default.
static func chant_button_styles() -> Dictionary:
	if not UiSkin.is_new():
		return {}
	var out := {}
	if UiSkin.is_puppet() and UiSkin.tex("button_chant_normal") != null and UiSkin.path_of("button_chant_normal").contains("/Puppet/"):
		return puppet_button_styles("chant")
	for state in ["normal", "hover", "pressed", "disabled"]:
		# only the amber face, as the user asked: the art's dark 3D base strip is left out. The face is its own image
		# (button_chant_*_face.png: rows 0-47 of the art, the pressed one 2-49), not a window onto the full art: scaled to a
		# smaller window, a window's edge picked up the strip's top row, a pale line under the button.
		out[state] = UiSkin.box("button_chant_%s_face" % state, [20, 16, 20, 12], [20, 6, 20, 6])
	return out


static func panel_box(alpha := 0.88, radius := 12) -> StyleBox:
	var art := UiSkin.box("panel_wood_frame", [34, 34, 34, 34] if UiSkin.is_puppet() else [30, 30, 30, 30], [26, 22, 26, 22] if UiSkin.is_puppet() else [18, 14, 18, 14])  # (the Puppet panel has a carved rim and corner pieces)
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


## Settings > Font Edit > Body text > Size %: how big the ordinary text is, as a percentage of what the screens ask for (labels, buttons, the theme's default sizes, the words of an event).
static func body_scale() -> float:
	return float(header_style("body").scale) / 100.0


## A size the code asked for, in the player's body size.
static func px(size: int) -> int:
	var k := body_scale()
	return size if k == 1.0 else maxi(6, roundi(float(size) * k))


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	apply_header(l, "body", size)
	return l


static func button(text: String, cb: Callable, size := 18, kind := "") -> Button:
	var b := Button.new()
	b.text = text
	skin_button(b, kind if kind != "" else kind_for(text), size)
	b.add_theme_font_size_override("font_size", size)
	apply_header(b, "body", size)
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	b.mouse_entered.connect(func(): Audio.play("ui_hover", -6.0))
	b.focus_mode = Control.FOCUS_NONE
	return b
