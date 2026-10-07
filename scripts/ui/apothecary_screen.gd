class_name ApothecaryScreen
extends Control
## The Wandering Apothecary's clearing, built from the loose pictures of Room Background.pdf (layout and stacking order:
## apothecary_layout.gd). The forest sways in the wind, fireflies wander through it, the lantern on the cart flickers like an
## oil lamp and the crystal on the merchant's staff glows softly (both lights take their colour from their own picture).
## Three things to click, as at the campfire: the merchant (PAY), the cart (a free SAMPLE), the signpost (WALK ON). Click one
## and the plate slides up from behind the log with what it does; the object stays lit. Click another object and the plate
## shows that one instead; click the same object again (or anywhere else) and the plate slides back down. Click the plate
## to do it.

signal chosen(which: String)  # "pay" | "sample" | "walk"

const CHOICES := {"merchant": "pay", "cart": "sample", "sign": "walk"}  # picture -> choice
const RISE_TIME := 0.42
const GOLD := Color(0.863, 0.631, 0.302)  # the first line of the plate
const WHITE := Color(1, 1, 1)
const PLATE_SCALE := 0.7  # the plate, its text and its coin are drawn at 70% of the picture's size
const FONT_SIZE := 31
const LINE_GAP := 7.0  # px between the two lines of text
const CONFIRM_HINT := "Click the plate to confirm  ·  click anywhere else to cancel"

var run: RunState
var enabled := {"pay": true, "sample": true, "walk": true}
var hints := {"pay": [], "sample": [], "walk": []}  # what each choice does: the plate's lines, each {t: text, c: colour, coin: amber icon after it}
var extra: Control  # shown at the bottom left (your HP)

var _stage: Control  # the 1080 px tall picture, centred on the 1920 stage
var _hot := {}  # choice -> its picture
var _plate: Control
var _plate_lines: VBoxContainer
var _plate_drop := 300.0  # how far it sinks to be out of sight below the picture
var _plate_home := Vector2.ZERO  # where it stands raised
var _plate_tween: Tween
var _hint: Label
var _hovered := ""
var _selected := ""
var _raised := false
var _lights := []  # [{node, kind, base, t}]
var _t := 0.0
var _noise := FastNoiseLite.new()


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 17
	_noise.frequency = 1.0
	# either side of the (square) picture: the picture itself, blown up, blurred and dimmed
	var sides := UiSkin.tex("apothecary_sides")
	if sides != null:
		var sr := TextureRect.new()
		sr.texture = sides
		sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sr.stretch_mode = TextureRect.STRETCH_SCALE
		sr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sr)
	_stage = Control.new()
	_stage.size = Vector2(ApothecaryLayout.SCENE_W, 1080)
	_stage.position = Vector2((1920 - ApothecaryLayout.SCENE_W) / 2.0, 0)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	# every layer and every special (fireflies, plate, lights) in z order
	var items: Array = []
	for L in ApothecaryLayout.LAYERS:
		items.append({"z": L.z, "layer": L})
	items.append({"z": 1620.0, "special": "fireflies"})  # (just in front of the wood and what stands in it, behind the merchant and the cart)
	items.append({"z": ApothecaryLayout.PLATE.z + 0.1, "special": "lights"})
	items.sort_custom(func(a, b): return a.z < b.z)
	for it in items:
		if it.has("layer"):
			_add_layer(it.layer)
		elif it.special == "fireflies":
			var ff := FireflyField.new()  # (wandering and blinking through the wood, most of them up among the trees)
			ff.top = 0.04
			ff.bottom = 0.7
			ff.count = 46
			_stage.add_child(ff)
		else:
			_make_lights()
	var hud := HudBar.new()
	hud.setup(run)
	add_child(hud)
	_hint = UiTheme.label("", 26, Color(1, 0.95, 0.8))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 80)
	_hint.size = Vector2(1920, 40)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	if extra != null:
		extra.position = Vector2(40, 1010)
		add_child(extra)
	for which in _hot:
		_hot[which].set_enabled(enabled.get(which, true))


func _add_layer(L: Dictionary) -> void:
	var tex := UiSkin.tex(L.file)
	if tex == null:
		return
	var id: String = L.id
	if id == "plate":
		_make_plate(tex, L)
		return
	var node: Control
	if CHOICES.has(id):
		node = CampfireHot.new()
		node.setup(tex, CHOICES[id])
		node.hovered.connect(_on_hover)
		node.pressed.connect(_on_press)
		_hot[CHOICES[id]] = node
	else:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node = r
	node.position = Vector2(L.x, L.y)
	node.size = Vector2(L.w, L.h)
	if id == "forest":
		var sh := Shader.new()
		sh.code = Backdrop.WIND_SHADER  # (the swaying wood of the act backgrounds and the campfire)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("amp", 0.003)
		mat.set_shader_parameter("ground", 0.99)
		node.material = mat
	_stage.add_child(node)


## The plate (the painted legend plaque): out of sight below the picture until something is chosen. Its lines are set per choice.
func _make_plate(tex: Texture2D, L: Dictionary) -> void:
	var full := Vector2(L.w, L.h)
	var small := full * PLATE_SCALE
	_plate_home = Vector2(L.x, L.y) + (full - small) / 2.0  # (shrunk about its middle)
	_plate_drop = 1080.0 - _plate_home.y + 12.0
	_plate = TextureRect.new()
	_plate.texture = tex
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.size = small
	_plate.position = _plate_home + Vector2(0, _plate_drop)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (it only takes clicks while it is up)
	_plate.gui_input.connect(_on_plate_input)
	_plate_lines = VBoxContainer.new()
	_plate_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_plate_lines.add_theme_constant_override("separation", 0)
	_plate_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_plate_lines)
	_stage.add_child(_plate)


## What the plate says: one row per line, each in its own colour; "coin" puts the amber leaf after the text.
func _set_plate_lines(lines: Array) -> void:
	for c in _plate_lines.get_children():
		_plate_lines.remove_child(c)
		c.queue_free()
	var f := UiTheme.cut("regular")
	var fs := FONT_SIZE  # (one size for every line: the largest that lets the longest line fit the plate's frame)
	var room := _plate.size.x * 0.8
	if f != null:
		for ln in lines:
			while fs > 14 and f.get_string_size(ln.t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
	for n in lines.size():
		var ln: Dictionary = lines[n]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 7)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiTheme.label(ln.t, fs, ln.c)
		if f != null:
			l.add_theme_font_override("font", f)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		if ln.get("coin", false):
			var coin := UiSkin.icon("icon_amber", int(fs * 0.95))
			if coin != null:
				coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(coin)
		_plate_lines.add_child(row)
	# (a label is taller than its letters: the boxes overlap a little so the LETTERS of the two lines sit LINE_GAP apart)
	_plate_lines.add_theme_constant_override("separation", int(LINE_GAP - fs * 1.0 - 1.0))


## A soft round light, added on top of what is below (the colour sits in the gradient).
func _light_rect(color: Color, radius: float, at: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(color, 0.9), Color(color, 0.3), Color(color, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(radius, radius) * 2.0
	r.position = at - Vector2(radius, radius)
	r.pivot_offset = Vector2(radius, radius)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = add
	return r


## The cart's lantern (a weak, flickering oil lamp) and the staff's crystal (a clearer, slower pulse): colours from their own pictures.
func _make_lights() -> void:
	var lamp: Dictionary = ApothecaryLayout.LIGHTS.get("lantern", {})
	if not lamp.is_empty():
		var at := Vector2(lamp.x, lamp.y)
		var n := _light_rect(lamp.color, 330.0, at)
		_stage.add_child(n)
		_lights.append({"node": n, "kind": "lantern", "base": 0.42, "at": at})
		var core := _light_rect(lamp.color, 90.0, at)  # (a tighter glow right round the glass)
		_stage.add_child(core)
		_lights.append({"node": core, "kind": "lantern", "base": 0.5, "at": at})
	var gem: Dictionary = ApothecaryLayout.LIGHTS.get("crystal", {})
	if not gem.is_empty():
		var at2 := Vector2(gem.x, gem.y)
		var halo := _light_rect(gem.color, 190.0, at2)
		_stage.add_child(halo)
		_lights.append({"node": halo, "kind": "crystal", "base": 0.62, "at": at2})
		var heart := _light_rect(gem.color.lightened(0.35), 70.0, at2)
		_stage.add_child(heart)
		_lights.append({"node": heart, "kind": "crystal", "base": 0.85, "at": at2})


func _process(d: float) -> void:
	_t += d
	for l in _lights:
		var n: TextureRect = l.node
		if l.kind == "lantern":  # an oil flame: quick uneven flutter, a small shiver of the light itself
			var f := 0.72 + 0.28 * _noise.get_noise_2d(_t * 4.2, 3.0) + 0.1 * sin(_t * 17.0)
			n.modulate.a = clampf(l.base * f, 0.0, 1.0)
			n.scale = Vector2.ONE * (1.0 + 0.04 * _noise.get_noise_2d(_t * 3.0, 9.0))
			n.position = l.at - n.pivot_offset + Vector2(_noise.get_noise_2d(_t * 2.0, 1.0), _noise.get_noise_2d(_t * 2.0, 5.0)) * 3.0
		else:  # the crystal: a slow, deep pulse (about 4.5 s a breath: slower than the lamp's flutter)
			var k := 0.5 + 0.5 * sin(_t * 1.4)
			n.modulate.a = clampf(l.base * (0.45 + 0.55 * k), 0.0, 1.0)
			n.scale = Vector2.ONE * (0.92 + 0.12 * k)


func _on_hover(which: String, on: bool) -> void:
	if on:
		_hovered = which
		Audio.play("ui_hover", -6.0)
	elif _hovered == which:
		_hovered = ""
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _hovered != "" and _hovered != _selected:
		_hint.text = "Click to choose"
	elif _selected != "":
		_hint.text = CONFIRM_HINT if enabled.get(_selected, true) else "Not available right now"
	else:
		_hint.text = ""


## An object was clicked: the same one again puts the plate away, another one changes what the plate says.
func _on_press(which: String) -> void:
	Audio.play("ui_click")
	if which == _selected:
		_cancel()
		return
	_select(which)


func _select(which: String) -> void:
	for w in _hot:
		_hot[w].set_selected(w == which)
	_selected = which
	_set_plate_lines(hints.get(which, []))
	_raise(true)
	_refresh_hint()


func _cancel() -> void:
	_selected = ""
	for w in _hot:
		_hot[w].set_selected(false)
	_raise(false)
	_refresh_hint()


## The plate slides up from behind the log (or back down behind it).
func _raise(on: bool) -> void:
	if _plate == null or on == _raised:
		return
	_raised = on
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if is_instance_valid(_plate_tween):
		_plate_tween.kill()
	var to := _plate_home if on else _plate_home + Vector2(0, _plate_drop)
	_plate_tween = create_tween()
	_plate_tween.tween_property(_plate, "position", to, RISE_TIME).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on:
		Audio.play("ui_open_panel", -10.0)


## The plate was clicked: do the chosen thing.
func _on_plate_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _selected != "":
		_plate.accept_event()
		if not enabled.get(_selected, true):
			Audio.play("ui_error")
			return
		Audio.play("ui_click")
		chosen.emit(_selected)


## Clicking anywhere that is neither an object nor the plate puts the choice back.
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _selected != "":
		_cancel()
