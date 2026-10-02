class_name SpellCard
extends PanelContainer
## A spell: name, pattern, rules text, and its category / rarity / special symbols. Shows ×N when the current
## chant would fire it, and Silenced / Locked / Used states during a fight.
## A parchment card: the name in a box of the spell's category colour, the pattern orbs under it, the rules in
## the middle and the symbols along the bottom (coordinates below are in card pixels, 250 × 196).

signal clicked(card: SpellCard)

const W := 250.0
const H := 196.0
## Category colours (the name box and the frame): Offensive red, Defensive blue, Utility gold.
const EDGE := {"damage": Color("BB3B30"), "defense": Color("0A6DC8"), "utility": Color("BB8F21")}
const PARCHMENT := Color(0.93, 0.87, 0.72)
const INK := Color(0.1, 0.08, 0.06)
const RARITY_COLORS := {"common": Color(0.35, 0.3, 0.25), "rare": Color(0.1, 0.35, 0.75), "legendary": Color(0.75, 0.45, 0.0)}
const CORNER := 10.0

const TITLE := Rect2(10.0, 6.0, 230.0, 32.0)  # the name box's row (the box hugs the name, centred)
const PIPS := Rect2(10.0, 44.0, 230.0, 36.0)  # the pattern row, centred
const PIP_D := 36.0
const PIP_GAP := 4.0
const PIP_SLOTS := 6  # more elements than this and the whole row shrinks to fit the width
const RULES := Rect2(8.0, 86.0, 234.0, 82.0)
const RULES_PAD := Vector2(4.0, 1.5)
const ICONS := Rect2(10.0, 170.0, 230.0, 20.0)  # rarity · category along the bottom

const TITLE_FONT := "res://assets/fonts/HamburgerHeaven"  # .ttf / .otf; the theme font is used until it's added
const RULES_FONT := "res://assets/fonts/SVN-Acherus-Italic"

static var _fonts := {}
static var _bold: FontVariation
static var _layer: CanvasLayer

var spell: Dictionary
var fires := 0  # preview: how many times the current chant would charge it
var charges := 0  # charged after the chant: click to cast (it wobbles, it's alive)
var aiming := false  # its targeting arrow is out
var base_scale := 1.0  # drawn larger on reward screens, smaller in a crowded spell row
var _hover := false
var _t := 0.0
var state := ""  # "", "silenced", "locked", "used"
var state_text := ""
var lock_pattern := ""
var selected := false
## Drawn this many times bigger: fonts, pips and margins are all laid out at the larger size (not stretched),
## so the text stays sharp. Used for reward cards and the hover magnifier.
var zoom := 1.0

var _root: Control
var _count: Label
var _rules: RichTextLabel
var _name_l: Label
var _name_box: Panel
var _pat: Control
## Sizes picked by _fit_text, in unzoomed units. The hover copy reuses them (fit_from) so it is an exact
## enlargement of the card, wrapping its text the same way.
var fit_name_fs := 0
var fit_fs := 0
var fit_orb := 0.0
var fit_from := false
var _state: Label
var _lock_row: HBoxContainer
var _box: StyleBoxFlat
var _shade: Panel
var _orbit: OrbitSpark  # pending: the chant you're building will wake this spell


func _z(x: float) -> float:
	return x * zoom


func _zi(x: float) -> int:
	return int(round(x * zoom))


static func make(p_spell: Dictionary) -> SpellCard:
	var c := SpellCard.new()
	c.spell = p_spell
	return c


## A font file from assets/fonts (.ttf or .otf), loaded once; null when it isn't there.
static func _font(base: String) -> Font:
	if not _fonts.has(base):
		_fonts[base] = null
		for ext in ["ttf", "otf"]:
			if ResourceLoader.exists("%s.%s" % [base, ext]):
				_fonts[base] = load("%s.%s" % [base, ext])
				break
	return _fonts[base]


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position * zoom
	c.size = r.size * zoom
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * zoom
	# the magnified copy must never catch the mouse, or the real card loses its hover and its clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_zoom_copy else Control.MOUSE_FILTER_STOP
	if not is_zoom_copy:
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
	var kind: String = spell.kind
	_box = StyleBoxFlat.new()
	_box.bg_color = PARCHMENT
	_box.set_corner_radius_all(_zi(CORNER))
	_box.content_margin_left = 0
	_box.content_margin_right = 0
	_box.content_margin_top = 0
	_box.content_margin_bottom = 0
	_box.shadow_color = Color(0, 0, 0, 0.45)
	_box.shadow_size = _zi(4)
	add_theme_stylebox_override("panel", _box)
	# everything sits in one plain Control, so it can be placed freely (a PanelContainer would stretch each child)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_title()
	_build_pips()
	_build_rules()
	_build_icons()
	_count = UiTheme.label("", _zi(24), Color(0.75, 0.45, 0.0))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_count.add_theme_constant_override("outline_size", _zi(5))
	_count.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75))
	_place(_count, Rect2(W - 46.0, 3.0, 40.0, 30.0))
	_root.add_child(_count)
	_fit_text()
	var pattern_words := "anything (every Essence is sealed: it wakes on every chant)"
	if spell.pattern != "":
		pattern_words = " ".join(Array(spell.pattern.split("")).map(func(c): return "any Essence" if c == "?" else Elements.NAMES.get(c, c)))
	var extra := "[color=#9aa89a]%s %s  ·  chant %s[/color]" % [spell.rarity_name, SpellDB.KIND_NAMES[spell.kind], pattern_words]
	var seals: Array = spell.get("seals", [])
	if not seals.is_empty():
		extra += "\n[color=#c79be0]Sealed: %d Essence of its pattern %s no longer needed.[/color]" % [seals.size(), "is" if seals.size() == 1 else "are"]
	if spell.has("flavor"):
		extra += "\n[i][color=#9aa89a]\"%s\"[/color][/i]" % spell.flavor
	tooltip_text = Keywords.tooltip(spell.name, SpellText.describe(spell), extra)
	# overlays
	_shade = Panel.new()
	var shade_box := StyleBoxFlat.new()
	shade_box.bg_color = Color(0.02, 0.02, 0.04, 0.78)
	shade_box.set_corner_radius_all(_zi(CORNER))
	_shade.add_theme_stylebox_override("panel", shade_box)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_orbit = OrbitSpark.new()
	_orbit.zoom = zoom
	_orbit.margins = [0.0, 0.0, 0.0, 0.0]
	_orbit.visible = false
	add_child(_orbit)
	_state = UiTheme.label("", _zi(20), Color.WHITE)
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state.add_theme_constant_override("outline_size", _zi(6))
	_state.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_state)
	_lock_row = HBoxContainer.new()
	_lock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_row)
	refresh()


# ------------------------------------------------------------------ building

## Rarity and category in small capitals along the bottom (plus POWER / FLEETING / FUSED), in the rarity's colour.
func _build_icons() -> void:
	var tags := [spell.rarity_name.to_upper(), SpellDB.KIND_NAMES[spell.kind].to_upper()]
	if spell.power:
		tags.append("POWER")
	if spell.get("fleeting", false):
		tags.append("FLEETING")
	if spell.get("fused", false):
		tags.append("FUSED")
	var l := UiTheme.label(" · ".join(tags), _zi(13), RARITY_COLORS.get(spell.rarity, INK))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(l, ICONS)
	_root.add_child(l)


## The name, centred in a small box of the spell's category colour (sized in _fit_text).
func _build_title() -> void:
	_name_box = Panel.new()
	var nbs := StyleBoxFlat.new()
	nbs.bg_color = EDGE[spell.kind]
	nbs.border_color = EDGE[spell.kind].darkened(0.45)
	nbs.set_border_width_all(_zi(1))
	nbs.set_corner_radius_all(_zi(5))
	_name_box.add_theme_stylebox_override("panel", nbs)
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name_box)
	# the name uses the game's own font (easy to read); only the rules text uses the card font
	_name_l = UiTheme.label(spell.name, _zi(22), Color.WHITE)
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_l.add_theme_constant_override("outline_size", _zi(4))
	_name_l.add_theme_color_override("font_outline_color", Color(EDGE[spell.kind].darkened(0.6), 0.9))
	_place(_name_l, TITLE)
	_root.add_child(_name_l)


## One pip per Essence of the pattern, left to right. Up to PIP_SLOTS at full size; more than that (a fused
## spell) and the whole row shrinks to fit its width, the gaps with it. Sealed Essence (upgrades) keep their
## pip, under a purple wax seal.
func _build_pips() -> void:
	_pat = Control.new()
	_place(_pat, PIPS)
	_root.add_child(_pat)
	var full: String = spell.get("full_pattern", spell.pattern)
	var seals: Array = spell.get("seals", [])
	var n: int = full.length()
	var d := PIP_D
	if n > PIP_SLOTS:
		d = PIPS.size.x / (n + (PIP_GAP / PIP_D) * (n - 1))
	var gap := d * PIP_GAP / PIP_D
	fit_orb = d
	var x0 := (PIPS.size.x - (n * d + (n - 1) * gap)) / 2.0
	for i in n:
		# real ElementIcons, so the fight's effects (the chant being sung, fusing) can play on a card's pattern
		var p := ElementIcon.make(full[i], _z(d))
		p.sealed = i in seals
		p.size = Vector2(_z(d), _z(d))
		p.position = Vector2(x0 + i * (d + gap), (PIP_D - d) / 2.0) * zoom
		_pat.add_child(p)


func _build_rules() -> void:
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.scroll_active = false
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(_z(RULES.size.x - 2.0 * RULES_PAD.x), 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the game's own text colours: dark ink, keywords in their parchment shades
	d.add_theme_color_override("default_color", INK)
	var rf := _font(RULES_FONT)
	if rf != null:
		if _bold == null:
			_bold = FontVariation.new()
			_bold.base_font = rf
			_bold.variation_embolden = 0.6
		d.add_theme_font_override("normal_font", rf)
		d.add_theme_font_override("italics_font", rf)
		d.add_theme_font_override("bold_font", _bold)
		d.add_theme_font_override("bold_italics_font", _bold)
	d.text = "[center]" + Keywords.colorize(SpellText.card_text(spell), true) + "[/center]"
	_rules = d
	# the rules sit in the middle of the box, whatever their size
	var mid := CenterContainer.new()
	_place(mid, RULES)
	mid.add_child(d)
	_root.add_child(mid)


## The name shrinks to fit its row on one line; its coloured box then hugs it. The rules text takes the biggest
## size (21 down to 10) that fits its space, so a wordy card (a fused one) is never cut off and a short one is
## not tiny.
func _fit_text() -> void:
	var font := _name_l.get_theme_font("font")
	var name_fs := 22
	var max_w := TITLE.size.x - 24.0
	if fit_from:
		name_fs = fit_name_fs
	else:
		while name_fs > 11 and font.get_string_size(_name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _zi(name_fs)).x > _z(max_w):
			name_fs -= 1
	fit_name_fs = name_fs
	_name_l.add_theme_font_size_override("font_size", _zi(name_fs))
	var tw := minf(font.get_string_size(_name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _zi(name_fs)).x / zoom, max_w)
	var bw := tw + 18.0
	_place(_name_box, Rect2(TITLE.position.x + (TITLE.size.x - bw) / 2.0, TITLE.position.y + 2.0, bw, TITLE.size.y - 4.0))
	var room := _z(RULES.size.y - 2.0 * RULES_PAD.y)
	# measured on the real text box (coloured keywords and line spacing included), at the box's text width
	_rules.size = Vector2(_z(RULES.size.x - 2.0 * RULES_PAD.x), 0)
	var fs := fit_fs if fit_from else 21
	while true:
		_rules.add_theme_font_size_override("normal_font_size", _zi(fs))
		_rules.add_theme_font_size_override("bold_font_size", _zi(fs))
		_rules.add_theme_font_size_override("italics_font_size", _zi(fs))
		_rules.add_theme_font_size_override("bold_italics_font_size", _zi(fs))
		# the rules font has generous line spacing; tightening it lets the text be a size or two bigger
		_rules.add_theme_constant_override("line_separation", -_zi(fs * 0.17))
		if fit_from or fs <= 10 or _rules.get_content_height() <= room:
			break
		fs -= 1
	fit_fs = fs


# ------------------------------------------------------------------ hover magnifier

## Hovering a card shows a magnified copy of it on a layer above everything else, so it's never clipped by a
## scroll area or hidden behind other cards. The copy ignores the mouse, so the real card keeps its hover.
var _zoom: SpellCard
var is_zoom_copy := false


func _on_hover(on: bool) -> void:
	if is_zoom_copy or on == _hover:
		return
	# only let go when the mouse has really left the card (not when something flickers on top of it)
	if not on and is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position()):
		return
	_hover = on
	if is_instance_valid(_zoom):
		_zoom.queue_free()
		_zoom = null
		refresh()  # shows the real card again
	if not on or not is_inside_tree():
		return
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 25
		get_tree().root.add_child(_layer)
	# how big the real card looks now, and how big the copy should be
	var real_scale := get_global_transform().get_scale().x
	var shown := real_scale * zoom
	var target := shown * 1.2 if shown >= 1.0 else 1.12
	var z := SpellCard.make(spell)
	z.is_zoom_copy = true
	z.zoom = target  # laid out at the big size, so it's crisp
	z.fit_from = true  # same text sizes as this card, so it wraps exactly the same
	z.fit_name_fs = fit_name_fs
	z.fit_fs = fit_fs
	z.fit_orb = fit_orb
	# its layer is outside every screen, so it must be given the game's theme (font) itself, or it falls back
	# to Godot's default font: heavier, wider, and the text wraps differently from the real card
	z.theme = UiTheme.get_theme()
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# same shape as the real card (it may have been stretched by its row), just bigger
	var zsize := size / zoom * target
	z.custom_minimum_size = zsize
	_layer.add_child(z)
	_zoom = z
	_sync_zoom()
	_ignore_mouse(z)
	z.size = zsize
	# sits where the real card is and grows upwards from its bottom edge (a quick pop, then crisp at scale 1)
	var bottom_mid := global_position + Vector2(size.x * real_scale / 2.0, size.y * real_scale)
	z.pivot_offset = Vector2(zsize.x / 2.0, zsize.y)
	z.position = bottom_mid - Vector2(zsize.x / 2.0, zsize.y)
	if z.position.y < 8.0:
		z.position.y = 8.0
	z.scale = Vector2.ONE * (shown / target)
	z.create_tween().tween_property(z, "scale", Vector2.ONE, 0.1)
	modulate.a = 0.0


func _sync_zoom() -> void:
	var z := _zoom
	z.fires = fires
	z.charges = charges
	z.state = state
	z.state_text = state_text
	z.lock_pattern = lock_pattern
	z.selected = selected
	z.refresh()


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children(true):  # include internal ones, like a text box's hidden scrollbar
		_ignore_mouse(c)


func _exit_tree() -> void:
	if is_instance_valid(_zoom):
		_zoom.queue_free()


func _process(d: float) -> void:
	if _hover and not (is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())):
		_on_hover(false)
	if charges > 0 and state == "" and z_index == 0:
		# alive: a little tilt left and right, a slow breathing glow (shrunk cards pivot at their corner so they
		# stay inside their slot)
		pivot_offset = size / 2.0 if base_scale >= 0.999 else Vector2.ZERO
		_t += d
		rotation = sin(_t * 6.0) * (0.02 if not aiming else 0.0)
		var s := (1.06 if aiming else 1.0 + 0.02 * sin(_t * 3.0)) * base_scale
		scale = Vector2(s, s)
		self_modulate = Color(1, 1, 1).lerp(Color(1.18, 1.12, 0.9), 0.5 + 0.5 * sin(_t * 4.0))
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		_box.shadow_color = Color(1.0, 0.82, 0.2, 0.55 + 0.35 * glow)
		_box.shadow_size = _zi(10 + 8 * glow)
	elif _t != 0.0:
		rotation = 0.0
		scale = Vector2(base_scale, base_scale)
		self_modulate = Color.WHITE
		pivot_offset = Vector2.ZERO
		_t = 0.0
		_box.shadow_color = Color(0, 0, 0, 0.45)
		_box.shadow_size = _zi(4)


## The pattern orbs still needed (not sealed), left to right: the ones a matching chant lights up.
func live_orbs() -> Array:
	if _pat == null:
		return []
	return _pat.get_children().filter(func(o): return o is ElementIcon and not o.sealed)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
	return Keywords.make_tooltip(for_text + Keywords.colorize(get_meta("fuse_tip", "")))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func refresh() -> void:
	if _count == null:
		return
	var n := charges if charges > 0 else fires
	_count.text = ("×%d" % n) if n > 0 and state == "" else ""
	# the frame is the spell's category colour; gold when the chant matches it or it's alive
	var border: Color = EDGE[spell.kind].darkened(0.15)
	var bw := 3
	if fires > 0 and state == "":
		border = Color(1, 0.78, 0.2)
		bw = 4
	if charges > 0:
		border = Color(1, 0.85, 0.25)
		bw = 5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if charges > 0 else Control.CURSOR_ARROW
	_box.border_color = border
	_box.set_border_width_all(_zi(bw))
	modulate = Color(1, 1, 1, 0.45) if state == "used" else Color.WHITE
	if is_instance_valid(_zoom):
		modulate.a = 0.0  # its magnified copy is showing instead
		_sync_zoom()
	_state.text = state_text
	for ch in _lock_row.get_children():
		ch.queue_free()
	if state == "locked":
		_state.text = "LOCKED\n\n"
		for ch in lock_pattern:
			_lock_row.add_child(ElementIcon.make(ch, _z(28)))
	_state.visible = state != ""
	_shade.visible = state in ["silenced", "locked"]
	_orbit.visible = fires > 0 and charges == 0 and state == ""
