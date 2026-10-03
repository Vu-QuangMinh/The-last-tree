class_name SpellCard
extends PanelContainer
## A spell: art, name, category / rarity / special icons, pattern pips, rules text. Shows ×N when the current
## chant would fire it, and Silenced / Locked / Used states during a fight.
## The layout follows docs/Card Template.pdf (coordinates below are in that template's pixels, 250 × 196).

signal clicked(card: SpellCard)

const W := 250.0
const H := 196.0
## The card's background is a radial gradient from CENTER (in the middle) to EDGE (at the border), tinted by what
## the spell does. The three categories share the same lightness and chroma, so no colour shouts over the others.
const ORBIT_COLOR := {"damage": Color(1.0, 0.36, 0.3), "defense": Color(0.4, 0.72, 1.0), "utility": Color(1.0, 0.9, 0.3)}
const EDGE := {"damage": Color("BB3B30"), "defense": Color("0A6DC8"), "utility": Color("BB8F21")}
const CENTER := {"damage": Color("E26958"), "defense": Color("3195EC"), "utility": Color("E5B858")}
const BEIGE := Color(0.885, 0.772, 0.659)
const INK := Color(0.1, 0.08, 0.06)
const CORNER := 8.0

const MAT := Rect2(9.7, 5.0, 87.6, 87.5)  # the art window's frame
const STRIP := Rect2(89.4, 42.6, 137.4, 35.2)  # the icon strip (its left end tucks under the art window)
const ICON_ZONE := Rect2(99.0, 42.6, 127.8, 35.2)  # the part of the strip that shows
const ICON_BOX := Vector2(31.0, 32.7)  # the biggest an icon gets
const TITLE := Rect2(104.6, 6.0, 110.0, 37.0)
const PIPS := Rect2(10.2, 97.8, 230.0, 30.0)  # the pattern row
const VEIL_PX_PER_PT := 4.0  # the status icons (card_overlay_*) are exported at 4 px per card pixel
const PIP_D := 30.0
const PIP_GAP := 3.1
const PIP_SLOTS := 7  # more elements than this and the whole row shrinks to fit the width
const RULES := Rect2(10.2, 133.2, 230.0, 56.5)
const RULES_PAD := Vector2(6.0, 1.5)

const TITLE_FONT := "res://assets/fonts/HamburgerHeaven"  # .ttf / .otf; the theme font is used until it's added
const RULES_FONT := "res://assets/fonts/SVN-Acherus-Italic"

static var _fonts := {}
static var _glow_tex := {}
static var _bold: FontVariation
static var _art_material: ShaderMaterial
static var _art_shader_res: Shader
static var _art_focus_cache := {}
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
var _veil: TextureRect  # New theme: the painted overlay for Silenced / Locked / Used / Charged
var _count_art: HBoxContainer  # New theme: the ×N badge in painted digits
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


func _beige(r: Rect2, radius: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BEIGE
	sb.set_corner_radius_all(_zi(radius))
	p.add_theme_stylebox_override("panel", sb)
	_place(p, r)
	_root.add_child(p)
	return p


func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * zoom
	# the magnified copy must never catch the mouse, or the real card loses its hover and its clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_zoom_copy else Control.MOUSE_FILTER_STOP
	if not is_zoom_copy:
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
	var kind: String = spell.kind
	_box = StyleBoxFlat.new()
	_box.bg_color = EDGE[kind]
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
	_build_glow(kind)
	_beige(STRIP, 4.0)
	_build_icons()
	_build_art()
	_build_title()
	_build_pips()
	_build_rules()
	_count = UiTheme.label("", _zi(24), Color(0.75, 0.45, 0.0))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_count.add_theme_constant_override("outline_size", _zi(5))
	_count.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75))
	_place(_count, Rect2(W - 46.0, 3.0, 40.0, 30.0))
	_root.add_child(_count)
	if UiSkin.tex("num_times") != null:
		_count_art = HBoxContainer.new()
		_count_art.alignment = BoxContainer.ALIGNMENT_END
		_count_art.add_theme_constant_override("separation", _zi(1))
		_place(_count_art, Rect2(W - 90.0, 3.0, 80.0, 28.0))
		_root.add_child(_count_art)
	_fit_text()
	var seals: Array = spell.get("seals", [])
	var pattern_words := "anything (every Essence is sealed: it wakes on every chant)"
	if spell.pattern != "":
		pattern_words = " ".join(Array(spell.pattern.split("")).map(func(c): return "any Essence" if c == "?" else Elements.NAMES.get(c, c)))
	var extra := "[color=#9aa89a]%s %s  ·  chant %s[/color]" % [spell.rarity_name, SpellDB.KIND_NAMES[spell.kind], pattern_words]
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
	# New theme: a status icon (Silenced / Locked / Used / Charged) sits on the art window, at the size it was drawn
	var veil_layer := Control.new()
	veil_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil_layer)
	_veil = TextureRect.new()
	_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_veil.stretch_mode = TextureRect.STRETCH_SCALE
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	veil_layer.add_child(_veil)
	_orbit = OrbitSpark.new()
	_orbit.color = ORBIT_COLOR.get(spell.kind, Color(1.0, 0.9, 0.3))  # the spark takes the card's colour
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

## The background's lighter middle: a radial fade of the CENTER colour to nothing, over the EDGE-coloured card.
## Stretched over the card it is an ellipse a little taller than wide, reaching the border on every side.
func _build_glow(kind: String) -> void:
	if not _glow_tex.has(kind):
		var g := Gradient.new()
		var c: Color = CENTER[kind]
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([c, Color(c, 0.62), Color(c, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.03, 0.5)
		t.width = 128
		t.height = 144
		_glow_tex[kind] = t
	var glow := TextureRect.new()
	glow.texture = _glow_tex[kind]
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(glow)


## Category, rarity and special (Power / Fleeting / Fused) icons, side by side in the strip.
func _build_icons() -> void:
	var icons: Array = []  # [Texture2D or KindGlyph, size in template pixels]
	var kind: String = spell.kind
	var paths := ["kind_%s" % kind, "rarity_%s" % spell.rarity]
	if spell.power:
		paths.append("special_power")
	if spell.get("fleeting", false):
		paths.append("special_fleeting")
	if spell.get("fused", false):
		paths.append("special_fused")
	for p in paths:
		var t: Texture2D = UiSkin.tex(p)  # New theme: the painted icon (assets/ui/new); otherwise / when it has none, the old PNG
		if t == null:
			t = CardPip.tex("res://assets/card/icons/%s.png" % p)
		if t != null:
			var s := minf(ICON_BOX.x / t.get_width(), ICON_BOX.y / t.get_height())
			icons.append([t, Vector2(t.get_width(), t.get_height()) * s])
		elif p.begins_with("kind_"):
			icons.append([KindGlyph.make(kind, Vector2.ONE), Vector2(28.0, 30.0)])
	var gap := 6.0
	var total := gap * (icons.size() - 1)
	for i in icons:
		total += i[1].x
	var shrink := minf(1.0, (ICON_ZONE.size.x - 8.0) / maxf(total, 1.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _zi(gap * shrink))
	_place(row, ICON_ZONE)
	_root.add_child(row)
	for i in icons:
		var px: Vector2 = i[1] * shrink * zoom
		var c: Control
		if i[0] is Texture2D:
			var tr := TextureRect.new()
			tr.texture = i[0]
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			c = tr
		else:
			c = i[0]
		c.custom_minimum_size = px
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c)


## The art: assets/card/art/<spell name>.png (256 px, square), filling the window. A fused spell shows the art of
## its two parents together, split down the middle (see art_window.gdshader); only the drawing is combined, no
## picture is ever made. Until a spell has its art, its first element stands in.
func _build_art() -> void:
	_beige(MAT, 7.0)
	var win := MAT.grow(-2.0)
	var art := _art_rect()
	if art != null:
		_place(art, win)
		_root.add_child(art)
		return
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.17, 0.16)
	sb.set_corner_radius_all(_zi(6))
	bg.add_theme_stylebox_override("panel", sb)
	_place(bg, win)
	_root.add_child(bg)
	for ch in String(spell.get("full_pattern", spell.pattern)):
		if CardPip.ICON.has(ch):
			var ic := TextureRect.new()
			ic.texture = CardPip.tex("res://assets/card/icons/%s.png" % CardPip.ICON[ch])
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ic.self_modulate = Color(1, 1, 1, 0.85)
			_place(ic, win.grow(-20.0))
			_root.add_child(ic)
			break


## The picture for the art window, or null when the spell (or, for a fusion, a parent) has no art yet.
func _art_rect() -> TextureRect:
	var names: Array = [spell.name]
	if spell.get("fused", false) and spell.has("fused_from"):
		names = spell.fused_from
	var texes: Array = []
	for n in names:
		var t := CardPip.tex(_art_path(n))
		if t != null:
			texes.append([n, t])
	if texes.is_empty():
		return null
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.texture = texes[0][1]
	if texes.size() == 2:
		var mat := ShaderMaterial.new()
		mat.shader = _art_shader()
		mat.set_shader_parameter("fused", true)
		mat.set_shader_parameter("tex_b", texes[1][1])
		mat.set_shader_parameter("focus_a", _art_focus(texes[0][0], texes[0][1]))
		mat.set_shader_parameter("focus_b", _art_focus(texes[1][0], texes[1][1]))
		art.material = mat
	else:
		if _art_material == null:
			_art_material = ShaderMaterial.new()
			_art_material.shader = _art_shader()
		art.material = _art_material
	return art


## "Ripple+" (upgraded) has the art of "Ripple".
static func _art_path(spell_name: String) -> String:
	return "res://assets/card/art/%s.png" % spell_name.trim_suffix("+")


static func _art_shader() -> Shader:
	if _art_shader_res == null:
		_art_shader_res = load("res://assets/card/art_window.gdshader")
	return _art_shader_res


## Where across a picture (0..1) its subject sits, for centring a fused card's half-width band on it. The
## pictures are a bright subject on a dark muted background, so each column is weighted by how bright and
## saturated it is; the answer is the weighted middle, kept 0.25..0.75 so the band always stays inside the
## picture. Worked out once per picture (a coarse sample, a few thousand pixels) and remembered.
static func _art_focus(spell_name: String, tex: Texture2D) -> float:
	var key := spell_name.trim_suffix("+")
	if _art_focus_cache.has(key):
		return _art_focus_cache[key]
	var focus := 0.5
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var sum := 0.0
		var wx := 0.0
		for y in range(0, h, 4):
			for x in range(0, w, 4):
				var c := img.get_pixel(x, y)
				var weight := maxf(c.v - 0.3, 0.0) * (0.35 + c.s)
				sum += weight
				wx += weight * float(x) / w
		if sum > 0.0:
			focus = clampf(wx / sum, 0.25, 0.75)
	_art_focus_cache[key] = focus
	return focus


func _build_title() -> void:
	var col := Color(1, 0.9, 0.5) if spell.get("upgraded", false) else Color.WHITE
	_name_l = UiTheme.label(spell.name.to_upper(), _zi(22), col)
	var f := _font(TITLE_FONT)
	if f == null:
		# until the title font is added: the theme's font, made a little bolder
		var fv := FontVariation.new()
		fv.base_font = _name_l.get_theme_default_font()
		fv.variation_embolden = 0.5
		f = fv
	_name_l.add_theme_font_override("font", f)
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# at most two lines; a fused spell's long name ends in "…" (its tooltip has the whole name)
	_name_l.max_lines_visible = 2
	_name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# a thin dark edge: the title font has fine strokes that a heavy outline would clog
	_name_l.add_theme_constant_override("outline_size", _zi(2))
	_name_l.add_theme_color_override("font_outline_color", Color(EDGE[spell.kind].darkened(0.6), 0.85))
	_name_l.add_theme_constant_override("line_spacing", 0)
	_place(_name_l, TITLE)
	_root.add_child(_name_l)


## One pip per element of the pattern, left to right. Up to PIP_SLOTS at full size; more than that (a fused
## spell) and the whole row shrinks to fit its width, the gaps with it.
func _build_pips() -> void:
	_pat = Control.new()
	_place(_pat, PIPS)
	_root.add_child(_pat)
	# Sealed Essence (wax-seal upgrades) are still shown, under a purple seal, so the row keeps the full pattern
	var full: String = spell.get("full_pattern", spell.pattern)
	var seals: Array = spell.get("seals", [])
	var n: int = full.length()
	var d := PIP_D
	if n > PIP_SLOTS:
		d = PIPS.size.x / (n + (PIP_GAP / PIP_D) * (n - 1))
	var gap := d * PIP_GAP / PIP_D
	fit_orb = d
	for i in n:
		# real ElementIcons, so the fight's effects (the chant being sung, fusing) can play on a card's pattern
		var p := ElementIcon.make(full[i], _z(d))
		p.sealed = i in seals
		p.size = Vector2(_z(d), _z(d))
		p.position = Vector2(i * (d + gap), (PIP_D - d) / 2.0) * zoom
		_pat.add_child(p)


func _build_rules() -> void:
	_beige(RULES, 5.0)
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.scroll_active = false
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(_z(RULES.size.x - 2.0 * RULES_PAD.x), 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the game's own text colours: dark ink, keywords in their parchment shades
	d.add_theme_color_override("default_color", INK)
	var rf := UiTheme.cut("oblique")  # the rules are italic: the oblique cut of the chosen font, bold oblique for bold
	var rb := UiTheme.cut("boldoblique")
	if rf != null and rb != null:
		d.add_theme_font_override("normal_font", rf)
		d.add_theme_font_override("italics_font", rf)
		d.add_theme_font_override("bold_font", rb)
		d.add_theme_font_override("bold_italics_font", rb)
	else:
		rf = _font(RULES_FONT)
	if rf != null and rb == null:
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


## The name fits when its longest word is not wider than the space and the wrapped lines are not taller than it.
func _name_fits(font: Font, fs: int) -> bool:
	var text: String = _name_l.text
	for word in text.split(" "):
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, _zi(fs)).x > _z(TITLE.size.x):
			return false
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, _z(TITLE.size.x), _zi(fs)).y <= _z(TITLE.size.y - 2.0)


## The name shrinks (and wraps to a second line) to fit its space; the rules text takes the biggest size
## (21 down to 10) that fits its box, so a wordy card (a fused one) is never cut off and a short one is not tiny.
func _fit_text() -> void:
	var font := _name_l.get_theme_font("font")
	var name_fs := 22
	if fit_from:
		name_fs = fit_name_fs
	else:
		while name_fs > 11 and not _name_fits(font, name_fs):
			name_fs -= 1
	fit_name_fs = name_fs
	_name_l.add_theme_font_size_override("font_size", _zi(name_fs))
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
	if on:
		Audio.play("ui_hover", -8.0)
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
	if _count_art != null:
		_count.text = ""
		if n > 0 and state == "":
			UiSkin.fill_number(_count_art, "×%d" % n, _z(26), false, 0.62, true)  # small ×, bigger number, bottoms level
		else:
			for c in _count_art.get_children():
				c.queue_free()
	# the frame is a darker shade of the spell's function colour; gold when the chant matches it or it's alive
	var border: Color = EDGE[spell.kind].darkened(0.3)
	var bw := 2
	var glow: Color = ORBIT_COLOR.get(spell.kind, Color(1.0, 0.9, 0.3))  # the spark's colour, so frame and spark match
	if fires > 0 and state == "":
		border = glow
		bw = 4
	if charges > 0:
		border = glow.lightened(0.1)
		bw = 5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if charges > 0 else Control.CURSOR_ARROW
	_box.border_color = border
	_box.set_border_width_all(_zi(bw))
	var veil_name := ""
	if state != "":
		veil_name = "card_overlay_" + state
	elif charges > 0:
		veil_name = "card_overlay_charged"
	var veil_tex := UiSkin.tex(veil_name) if veil_name != "" else null
	_veil.texture = veil_tex
	_veil.visible = veil_tex != null
	if veil_tex != null:  # the icons are cut at 4 px per card pixel; centred on the art window
		_veil.size = veil_tex.get_size() / VEIL_PX_PER_PT * zoom
		_veil.position = (MAT.get_center() * zoom) - _veil.size / 2.0
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
