class_name SpellCard
extends PanelContainer
## A spell: name, pattern orbs, rules text. Shows ×N when the current chant would fire it,
## and Silenced / Locked / Used states during a fight.

signal clicked(card: SpellCard)

const W := 250.0
## Category colours: Offensive red, Defensive blue, Utility gold.
const KIND_COLORS := {"damage": Color(0.74, 0.22, 0.18), "defense": Color(0.2, 0.42, 0.72), "utility": Color(0.78, 0.58, 0.12)}
const PARCHMENT := Color(0.93, 0.87, 0.72)
const RARITY_COLORS := {"common": Color(0.35, 0.3, 0.25), "rare": Color(0.1, 0.35, 0.75), "legendary": Color(0.75, 0.45, 0.0)}
const INK := Color(0.1, 0.08, 0.06)
const H := 196.0

var spell: Dictionary
var fires := 0  # preview: how many times the current chant would charge it
var charges := 0  # charged after the chant: click to cast (it wobbles, it's alive)
var aiming := false  # its targeting arrow is out
var base_scale := 1.0  # drawn larger on reward screens
var _t := 0.0
var state := ""  # "", "silenced", "locked", "used"
var state_text := ""
var lock_pattern := ""
var selected := false
var compact := false

var _count: Label
var _state: Label
var _lock_row: HBoxContainer
var _box: StyleBoxFlat
var _shade: ColorRect


static func make(p_spell: Dictionary, p_compact := false) -> SpellCard:
	var c := SpellCard.new()
	c.spell = p_spell
	c.compact = p_compact
	return c


func _ready() -> void:
	custom_minimum_size = Vector2(W, 120 if compact else H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var kc: Color = KIND_COLORS[spell.kind]
	_box = StyleBoxFlat.new()
	_box.bg_color = PARCHMENT
	_box.set_corner_radius_all(10)
	_box.content_margin_left = 8
	_box.content_margin_right = 8
	_box.content_margin_top = 7
	_box.content_margin_bottom = 5
	_box.shadow_color = Color(0, 0, 0, 0.45)
	_box.shadow_size = 4
	add_theme_stylebox_override("panel", _box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	# name: centred in a thin box coloured by what the spell does
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var left := Control.new()
	left.custom_minimum_size = Vector2(34, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	var nb := PanelContainer.new()
	var nbs := StyleBoxFlat.new()
	nbs.bg_color = kc
	nbs.border_color = Color(1, 0.85, 0.3) if spell.get("upgraded", false) else kc.darkened(0.45)
	nbs.set_border_width_all(2 if spell.get("upgraded", false) else 1)
	nbs.set_corner_radius_all(4)
	nbs.content_margin_left = 8
	nbs.content_margin_right = 8
	nbs.content_margin_top = 1
	nbs.content_margin_bottom = 1
	nb.add_theme_stylebox_override("panel", nbs)
	nb.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := UiTheme.label(spell.name, 22, Color.WHITE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_constant_override("outline_size", 4)
	name_l.add_theme_color_override("font_outline_color", kc.darkened(0.6))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nb.add_child(name_l)
	top.add_child(nb)
	_count = UiTheme.label("", 28, Color(0.75, 0.45, 0.0))
	_count.custom_minimum_size = Vector2(34, 0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_constant_override("outline_size", 5)
	_count.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75))
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_count)
	# pattern
	var pat := HBoxContainer.new()
	pat.alignment = BoxContainer.ALIGNMENT_CENTER
	pat.add_theme_constant_override("separation", 3)
	pat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in spell.pattern:
		pat.add_child(ElementIcon.make(ch, 40))
	v.add_child(pat)
	if not compact:
		var d := RichTextLabel.new()
		d.bbcode_enabled = true
		d.fit_content = true
		d.scroll_active = false
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(W - 20, 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.add_theme_color_override("default_color", INK)
		# plain sentences; the text shrinks a little when there is more to say
		var rules := SpellText.card_text(spell)
		var fs := 21 if rules.length() <= 45 else (19 if rules.length() <= 80 else 17)
		d.add_theme_font_size_override("normal_font_size", fs)
		d.add_theme_font_size_override("bold_font_size", fs)
		d.text = "[center]" + Keywords.colorize(rules, true) + "[/center]"
		# the rules sit in the middle of the space left, so the card has no empty gap
		var mid := CenterContainer.new()
		mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(d)
		v.add_child(mid)
	var tags := [spell.rarity_name.to_upper(), SpellDB.KIND_NAMES[spell.kind].to_upper()]
	if spell.power:
		tags.append("POWER")
	var tag_l := UiTheme.label(" · ".join(tags), 13, RARITY_COLORS[spell.rarity])
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag_l)
	var pattern_words := " ".join(Array(spell.pattern.split("")).map(func(c): return Elements.NAMES[c]))
	var extra := "[color=#9aa89a]%s %s  ·  chant %s  ·  triggers at most %d× per turn[/color]" % [spell.rarity_name, SpellDB.KIND_NAMES[spell.kind], pattern_words, 1 if spell.power else spell.size]
	if spell.has("flavor"):
		extra += "\n[i][color=#9aa89a]\"%s\"[/color][/i]" % spell.flavor
	tooltip_text = Keywords.tooltip(spell.name, SpellText.describe(spell), extra)
	# overlays
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.02, 0.04, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_state = UiTheme.label("", 20, Color.WHITE)
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state.add_theme_constant_override("outline_size", 6)
	_state.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_state)
	_lock_row = HBoxContainer.new()
	_lock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_row)
	refresh()


func _process(d: float) -> void:
	if charges > 0 and state == "":
		# alive: a little tilt left and right, a slow breathing glow
		pivot_offset = size / 2.0
		_t += d
		rotation = sin(_t * 6.0) * (0.02 if not aiming else 0.0)
		var s := (1.06 if aiming else 1.0 + 0.02 * sin(_t * 3.0)) * base_scale
		scale = Vector2(s, s)
		self_modulate = Color(1, 1, 1).lerp(Color(1.12, 1.08, 0.92), 0.5 + 0.5 * sin(_t * 4.0))
	elif _t != 0.0:
		rotation = 0.0
		scale = Vector2(base_scale, base_scale)
		self_modulate = Color.WHITE
		pivot_offset = Vector2.ZERO
		_t = 0.0


func _make_custom_tooltip(for_text: String) -> Object:
	return Keywords.make_tooltip(for_text)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func refresh() -> void:
	if _count == null:
		return
	var n := charges if charges > 0 else fires
	_count.text = ("×%d" % n) if n > 0 and state == "" else ""
	# the frame is the spell's function colour; gold when the chant matches it or it's alive
	var border: Color = KIND_COLORS[spell.kind].darkened(0.15)
	var bw := 3
	if fires > 0 and state == "":
		border = Color(1, 0.78, 0.2)
		bw = 4
	if charges > 0:
		border = Color(1, 0.85, 0.25)
		bw = 5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if charges > 0 else Control.CURSOR_ARROW
	_box.border_color = border
	_box.set_border_width_all(bw)
	modulate = Color(1, 1, 1, 0.45) if state == "used" else Color.WHITE
	_state.text = state_text
	for ch in _lock_row.get_children():
		ch.queue_free()
	if state == "locked":
		_state.text = "LOCKED\n\n"
		for ch in lock_pattern:
			_lock_row.add_child(ElementIcon.make(ch, 28))
	_state.visible = state != ""
	_shade.visible = state in ["silenced", "locked"]
