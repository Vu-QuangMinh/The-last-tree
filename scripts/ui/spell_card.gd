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
var base_scale := 1.0  # drawn larger on reward screens, smaller in a crowded spell row
var _hover := false
var _t := 0.0
var state := ""  # "", "silenced", "locked", "used"
var state_text := ""
var lock_pattern := ""
var ignited := false  # wrapped in a thin line of flame: casting it burns you (the Ember Sprite)
var selected := false
var compact := false
## Drawn this many times bigger: fonts, orbs and margins are all laid out at the larger size (not stretched),
## so the text stays sharp. Used for reward cards and the hover magnifier.
var zoom := 1.0

var _count: Label
var _rules: RichTextLabel
var _name_l: Label
var _pat: HBoxContainer
var _tag_l: Label
## Sizes picked by _fit_text, in unzoomed units. The hover copy reuses them (fit_from) so it is an exact
## enlargement of the card, wrapping its text the same way.
var fit_name_fs := 0
var fit_fs := 0
var fit_orb := 0.0
var fit_from := false
var _state: Label
var _lock_row: HBoxContainer
var _box: StyleBoxFlat
var _shade: ColorRect
var _orbit: OrbitSpark  # pending: the chant you're building will wake this spell
var _flame: FlameOutline


func _z(x: float) -> float:
	return x * zoom


func _zi(x: float) -> int:
	return int(round(x * zoom))


static func make(p_spell: Dictionary, p_compact := false) -> SpellCard:
	var c := SpellCard.new()
	c.spell = p_spell
	c.compact = p_compact
	return c


func _ready() -> void:
	custom_minimum_size = Vector2(W, 120 if compact else H) * zoom
	# the magnified copy must never catch the mouse, or the real card loses its hover and its clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_zoom_copy else Control.MOUSE_FILTER_STOP
	if not is_zoom_copy:
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
	var kc: Color = KIND_COLORS[spell.kind]
	_box = StyleBoxFlat.new()
	_box.bg_color = PARCHMENT
	_box.set_corner_radius_all(_zi(10))
	_box.content_margin_left = _z(6)
	_box.content_margin_right = _z(6)
	_box.content_margin_top = _z(7)
	_box.content_margin_bottom = _z(5)
	_box.shadow_color = Color(0, 0, 0, 0.45)
	_box.shadow_size = _zi(4)
	add_theme_stylebox_override("panel", _box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _zi(SEP))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	# name: centred in a thin box coloured by what the spell does
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var nb := PanelContainer.new()
	var nbs := StyleBoxFlat.new()
	nbs.bg_color = kc
	nbs.border_color = Color(1, 0.85, 0.3) if spell.get("upgraded", false) else kc.darkened(0.45)
	nbs.set_border_width_all(_zi(2 if spell.get("upgraded", false) else 1))
	nbs.set_corner_radius_all(_zi(4))
	nbs.content_margin_left = _z(8)
	nbs.content_margin_right = _z(8)
	nbs.content_margin_top = _z(1)
	nbs.content_margin_bottom = _z(1)
	nb.add_theme_stylebox_override("panel", nbs)
	nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := UiTheme.label(spell.name, _zi(22), Color.WHITE)
	_name_l = name_l
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_constant_override("outline_size", _zi(4))
	name_l.add_theme_color_override("font_outline_color", kc.darkened(0.6))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nb.add_child(name_l)
	top.add_child(nb)
	_count = UiTheme.label("", _zi(28), Color(0.75, 0.45, 0.0))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_count.add_theme_constant_override("outline_size", _zi(5))
	_count.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.75))
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# pinned to the card's top-right corner (a plain Label would be centred in the card)
	_count.size_flags_horizontal = Control.SIZE_SHRINK_END
	_count.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(_count)
	# pattern
	var pat := HBoxContainer.new()
	pat.alignment = BoxContainer.ALIGNMENT_CENTER
	pat.add_theme_constant_override("separation", _zi(3))
	pat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# long (fused) patterns get smaller orbs so they fit the card's width. Sealed Essence (upgrades) are still
	# shown, under a purple wax seal.
	var full: String = spell.get("full_pattern", spell.pattern)
	var seals: Array = spell.get("seals", [])
	var alts: Array = spell.get("patterns", [])  # a fused anti-spell: one row per pattern (either one breaks it)
	var count := full.length()
	if alts.size() > 1:
		count = 0
		for a in alts:
			count = maxi(count, String(a).length())
	var orb := minf(40.0 if alts.size() <= 1 else 32.0, (RULES_W - 3.0 * (count - 1)) / maxf(1.0, count))
	if alts.size() > 1:
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", _zi(3))
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for a in alts:
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", _zi(3))
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for ch in String(a):
				row.add_child(ElementIcon.make(ch, _z(orb)))
			rows.add_child(row)
		pat.add_child(rows)
	else:
		for i in full.length():
			var ic := ElementIcon.make(full[i], _z(orb))
			ic.sealed = i in seals
			pat.add_child(ic)
	v.add_child(pat)
	_pat = pat
	if not compact:
		var d := RichTextLabel.new()
		d.bbcode_enabled = true
		d.fit_content = true
		d.scroll_active = false
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(_z(RULES_W), 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.add_theme_color_override("default_color", INK)
		# plain sentences; the size is picked once the rest of the card is built (see _fit_text)
		d.text = "[center]" + Keywords.colorize(SpellText.card_text(spell), true, false, _zi(23)) + "[/center]"
		_rules = d
		# the rules sit in the middle of the space left, so the card has no empty gap
		var mid := CenterContainer.new()
		mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(d)
		v.add_child(mid)
	var tags := [spell.rarity_name.to_upper(), SpellDB.KIND_NAMES[spell.kind].to_upper()]
	if spell.power:
		tags.append("POWER")
	if spell.get("fleeting", false):
		tags.append("FLEETING")
	if spell.get("fused", false):
		tags.append("FUSED")
	if spell.get("anti", false):
		tags.append("ANTI-SPELL")
	if spell.get("ephemeral", false):
		tags.append("EPHEMERAL")
	var tag_l := UiTheme.label(" · ".join(tags), _zi(13), RARITY_COLORS[spell.rarity])
	# many tags (an inverted conjured spell: ANTI-SPELL · EPHEMERAL) would widen the card: the line shrinks to fit
	var tag_font := tag_l.get_theme_font("font")
	var tag_fs := _zi(13)
	while tag_fs > _zi(8) and tag_font.get_string_size(tag_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs).x > _z(RULES_W):
		tag_fs -= 1
	tag_l.add_theme_font_size_override("font_size", tag_fs)
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag_l)
	_tag_l = tag_l
	_fit_text()
	# no pattern at all: it wakes whenever you chant (sealed down to nothing, or made that way)
	var pattern_words := "nothing: it wakes whenever you chant" if String(spell.get("full_pattern", spell.pattern)) == "" else "anything (every Essence is sealed: it wakes on every chant)"
	if spell.pattern != "":
		pattern_words = " ".join(Array(spell.pattern.split("")).map(func(c): return "any Essence" if c == "?" else Elements.NAMES.get(c, c)))
	var extra := "[color=#9aa89a]%s %s  ·  chant %s[/color]" % [spell.rarity_name, SpellDB.KIND_NAMES[spell.kind], pattern_words]
	if not seals.is_empty():
		extra += "\n[color=#c79be0]Sealed: %d Essence of its pattern %s no longer needed.[/color]" % [seals.size(), "is" if seals.size() == 1 else "are"]
	if spell.get("burden", "") != "":
		extra += "\n[color=#ff8a7a]Cursed (Tangled Grimoire): it needs %d more Essence than it used to.[/color]" % String(spell.burden).length()
	if spell.has("flavor"):
		extra += "\n[i][color=#9aa89a]\"%s\"[/color][/i]" % spell.flavor
	tooltip_text = Keywords.tooltip(spell.name, SpellText.describe(spell), extra, "", [Keywords.ANY_ESSENCE] if "?" in full else [])
	# overlays
	if spell.get("anti", false):
		_add_holo()
	if spell.get("ephemeral", false):
		_static_mat = _add_overlay(_static_shader())
		_static_mat.set_shader_parameter("seed", randf() * 10.0)
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.02, 0.04, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_orbit = OrbitSpark.new()
	_orbit.zoom = zoom
	_orbit.margins = [_box.content_margin_left, _box.content_margin_top, _box.content_margin_right, _box.content_margin_bottom]
	_orbit.visible = false
	add_child(_orbit)
	_flame = FlameOutline.new()
	_flame.zoom = zoom
	_flame.margins = _orbit.margins
	_flame.visible = false
	add_child(_flame)
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


## Every card is the same height. The name shrinks to fit its box, and the rules text takes the biggest size
## (21 down to 11) that fits the space the name, orbs and tags leave, so a wordy card (a fused one) is never
## cut off and a short one doesn't sit in a big empty gap.
const RULES_W := 234.0
const SEP := 5.0


func _fit_text() -> void:
	# the name: fits the card's width, leaving a little room in the corners for the ×N counter
	var font := _name_l.get_theme_font("font")
	var name_fs := 22
	while name_fs > 15 and font.get_string_size(spell.name, HORIZONTAL_ALIGNMENT_LEFT, -1, _zi(name_fs)).x > _z(W - 12 - 16 - 2 * 20):
		name_fs -= 1
	_name_l.add_theme_font_size_override("font_size", _zi(name_fs))
	if _rules == null:
		return
	# the rules: the height left once the card's frame, name, orbs and tag line are counted
	var used := _z(7 + 5) + _name_l.get_combined_minimum_size().y + _z(2) + _pat.get_combined_minimum_size().y \
		+ _tag_l.get_combined_minimum_size().y + _z(SEP) * 3
	var room := _z(H) - used
	# measured on the real text box (coloured keywords and line spacing included), at the card's text width
	_rules.size = Vector2(_z(RULES_W), 0)
	var fs := 21
	var need := 0.0
	while true:
		_rules.add_theme_font_size_override("normal_font_size", _zi(fs))
		_rules.add_theme_font_size_override("bold_font_size", _zi(fs))
		need = _rules.get_content_height()
		if need <= room or fs <= 11:
			break
		fs -= 1
	# still too much (a fusion of two wordy spells): shrink the orbs to make room for the text
	if need > room:
		for o in _orb_nodes():
			var px: float = maxf(_z(22), o.custom_minimum_size.x - (need - room))
			o.custom_minimum_size = Vector2(px, px)


## Hovering a card shows a magnified copy of it on a layer above everything else, so it's never clipped by a
## scroll area or hidden behind other cards. The copy ignores the mouse, so the real card keeps its hover.
static var _layer: CanvasLayer
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
	var z := SpellCard.make(spell, compact)
	z.is_zoom_copy = true
	z.zoom = target  # laid out at the big size, so it's crisp
	z.fit_from = true  # same text and orb sizes as this card, so it wraps exactly the same
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
	z.ignited = ignited
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


## Anti-spells look like a photo negative with a holographic sheen.
static var _holo_shader: Shader


func _add_holo() -> void:
	if _holo_shader == null:
		_holo_shader = load("res://assets/card/anti_holo.gdshader")
	_add_overlay(_holo_shader)
	# the pattern orbs stay above the negative, in their true colours: the player must see which Essence breaks it
	for o in _pat.get_children():
		o.z_index = 1


## Ephemeral (conjured) cards look like a TV with bad reception: a little see-through, faint rolling scanlines, and a
## glitch every second or two (see ephemeral_static.gdshader).
const EPHEMERAL_ALPHA := 0.78
static var _static_shader_res: Shader
var _static_mat: ShaderMaterial


static func _static_shader() -> Shader:
	if _static_shader_res == null:
		_static_shader_res = load("res://assets/card/ephemeral_static.gdshader")
	return _static_shader_res


## Conjuring: static floods the card (0 = clear, 1 = all static).
func static_up(dur := 0.3, to := 0.9) -> void:
	if _static_mat == null:
		_static_mat = _add_overlay(_static_shader())
	var tw := create_tween()
	tw.tween_method(func(v: float): _static_mat.set_shader_parameter("fizzle", v), 0.0, to, dur)
	await tw.finished


## Splitting out of (or merging back into) another card: it starts as static at `from_global` (on top of the card it
## comes from), slides into its own place and the static settles. A normal card loses its static overlay afterwards;
## an Ephemeral one keeps its bad reception.
func static_in(from_global: Vector2, dur := 0.45) -> void:
	if _static_mat == null:
		_static_mat = _add_overlay(_static_shader())
	var mat := _static_mat
	mat.set_shader_parameter("fizzle", 1.0)
	var home := position
	position = home + (from_global - global_position)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", home, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fizzle", v), 1.0, 0.0, dur).set_delay(dur * 0.35)
	await tw.finished
	if not spell.get("ephemeral", false) and mat.has_meta("holder"):
		var h: Node = mat.get_meta("holder")
		if is_instance_valid(h):
			h.queue_free()
		_static_mat = null


## Merging back: static floods it while it slides to `to_global`, where the cards meet.
func static_out_to(to_global: Vector2, dur := 0.35) -> void:
	if _static_mat == null:
		_static_mat = _add_overlay(_static_shader())
	var mat := _static_mat
	charges = 0
	fires = 0
	_orbit.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", position + (to_global - global_position), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fizzle", v), 0.0, 1.0, dur * 0.7)
	await tw.finished


## The card goes like an old TV switching off: static floods it, it collapses into a bright horizontal line, the line
## shrinks to a dot and the dot fades. (The caller removes the card afterwards.)
func fizzle_out() -> void:
	if _static_mat == null:
		_static_mat = _add_overlay(_static_shader())
	is_zoom_copy = true  # no more hover magnifier
	# settle it first: an awake card's wobble would fight the switch-off
	charges = 0
	fires = 0
	_t = 0.0
	rotation = 0.0
	scale = Vector2(base_scale, base_scale)
	self_modulate = Color.WHITE
	_orbit.visible = false
	if is_instance_valid(_zoom):
		_zoom.queue_free()
		modulate.a = EPHEMERAL_ALPHA
	pivot_offset = size / 2.0
	var s0 := scale
	var tw := create_tween()
	tw.tween_method(func(v: float): _static_mat.set_shader_parameter("fizzle", v), 0.0, 1.0, 0.32)
	tw.tween_property(self, "scale", Vector2(s0.x * 1.06, s0.y * 0.03), 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "self_modulate", Color(3, 3, 3), 0.13)
	tw.tween_property(self, "scale", Vector2(s0.x * 0.02, s0.y * 0.03), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished


## A full-card shader overlay (the anti-spell negative, the Ephemeral static). It sits in a plain holder (a
## PanelContainer would squeeze it inside its margins) and is stretched over the whole card, corners included.
func _add_overlay(shader: Shader) -> ShaderMaterial:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	# a fresh copy of the screen right before this card's overlay: otherwise every anti-spell card after the first
	# would read a copy taken before it was drawn
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	holder.add_child(copy)
	var holo := ColorRect.new()
	holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	holo.material = m
	holder.add_child(holo)
	m.set_meta("holder", holder)
	var fit := func() -> void:
		if not is_instance_valid(holo):
			return
		holo.position = -Vector2(_box.content_margin_left, _box.content_margin_top)
		holo.size = size
		m.set_shader_parameter("size", size)
		m.set_shader_parameter("radius", float(_zi(10)))
	resized.connect(fit)
	fit.call_deferred()
	return m


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
	return _orb_nodes().filter(func(o): return not o.sealed)


## Every orb of the pattern, left to right (a fused anti-spell's two rows: the first row, then the second).
func _orb_nodes() -> Array:
	if _pat == null:
		return []
	var out := []
	for o in _pat.get_children():
		if o is ElementIcon:
			out.append(o)
		elif o is VBoxContainer:
			for row in o.get_children():
				out.append_array(row.get_children().filter(func(c): return c is ElementIcon))
	return out


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
	_box.set_border_width_all(_zi(bw))
	modulate = Color(1, 1, 1, 0.45) if state == "used" else Color.WHITE
	if spell.get("ephemeral", false):
		modulate.a *= EPHEMERAL_ALPHA  # a little see-through: it isn't quite here
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
	_shade.visible = state in ["silenced", "locked", "broken"]
	_flame.visible = ignited and state != "used"
	if spell.get("anti", false):
		# an anti-spell is always active: its spark keeps circling, unless the chant breaks it (state "broken")
		_orbit.color = Color(1.0, 0.55, 0.95)
		_orbit.visible = state == ""
	else:
		_orbit.visible = fires > 0 and charges == 0 and state == ""
