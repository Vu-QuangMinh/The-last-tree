class_name CampfireScreen
extends Control
## The campfire room, built from the loose pictures of the PDF (layout and stacking order: campfire_layout.gd):
## the forest sways in the wind with leaves drifting through it, the cauldron smoke wriggles and fades, the flame flickers
## between its big and small shape with sparks spiralling up, and the three things you can choose glow when the mouse is
## on them (the cauldron AND its fire count as one: SEAL; the log and books: FUSE; the tent: REST).
## The signboard in front of the fire reads CAMPFIRE, or the word of whatever the mouse is on. Click a choice and the post
## rises out of the grass, showing a second board with what the choice does, while the post and the choice stay lit; click
## the BOARD to do it (clicking the choice again, or anywhere else, cancels).

signal chosen(which: String)  # "seal" | "fuse" | "rest"

const CHOICES := {"fuse": "fuse", "rest": "rest"}  # picture -> choice (the fire pit itself is just scenery)
const WORDS := {"seal": "SEAL", "fuse": "FUSE", "rest": "REST"}
const IDLE_WORD := "CAMPFIRE"
const RISE_TIME := 0.42
const CONFIRM_HINT := "Click the signboard to confirm  ·  click anywhere else to cancel"

var run: RunState
var enabled := {"fuse": true, "rest": true}
var hints := {"fuse": "", "rest": ""}  # what each choice does (or why it can't be chosen): the second board
var extra: Control  # shown at the bottom left (your HP)

var _stage: Control
var _post: TextureRect  # the signboard's post with its two boards
var _post_mat: ShaderMaterial
var _post_bits: BitMap  # the drawn pixels of the post: only they count as the board
var _post_home := Vector2.ZERO  # where it stands lowered (behind the grass)
var _title: Label  # on the top board
var _info: Label  # on the second board
var _hint: Label
var _hot := {}  # choice -> its picture
var _flame: CampfireFlame
var _hovered := ""
var _selected := ""
var _raised := false
var _rise_tween: Tween
var _post_tween: Tween
var _post_glow := 0.0


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var by_id := {}
	for L in CampfireLayout.LAYERS:
		by_id[L.id] = L
	for L in CampfireLayout.LAYERS:
		var tex := UiSkin.tex(L.file)
		if tex == null:
			continue
		var id: String = L.id
		if id == "fire_big" or id == "fire_small" or id == "sign_grass" or id == "sign_shadow":
			continue  # (the flame is one node that owns both pictures; the grass and the shadow go in with the post)
		var node: Control
		if CHOICES.has(id):
			node = CampfireHot.new()
			node.setup(tex, CHOICES[id])
			node.hovered.connect(_on_hover)
			node.pressed.connect(_on_press)
			_hot[CHOICES[id]] = node
		elif id == "sign_post":
			node = _make_post(tex, L, by_id)
		else:
			var r := TextureRect.new()
			r.texture = tex
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_SCALE
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node = r
		node.position = Vector2(L.x, L.y)
		node.size = Vector2(L.w, L.h)
		if id == "smoke":
			_smoke_style(node)
			_stage.add_child(_smoke_twin(node))  # (the slower copy goes behind the plume)
		elif id == "forest":
			_wind(node)
		_stage.add_child(node)
		if id == "decor_forest":
			var leaves := BackdropFx.new()  # the leaves drifting through the wood, as in the fights of act 1
			leaves.act = 1
			_stage.add_child(leaves)
		if id == "resin":
			_add_flame(by_id, node)
			_add_sparks(by_id)  # (the sparks rise behind the signboard)
		if id == "sign_post":
			_add_grass(by_id)
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
	_refresh_title()


## The grass in front of the post: the post rises out from behind it.
func _add_grass(by_id: Dictionary) -> void:
	var g: Dictionary = by_id.get("sign_grass", {})
	if g.is_empty():
		return
	var gt := UiSkin.tex(g.file)
	if gt == null:
		return
	var gr := TextureRect.new()
	gr.texture = gt
	gr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gr.stretch_mode = TextureRect.STRETCH_SCALE
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gr.position = Vector2(g.x, g.y)
	gr.size = Vector2(g.w, g.h)
	_stage.add_child(gr)


## The signboard's post (lowered, behind the grass), with the word on its top board and the text on the second board.
func _make_post(tex: Texture2D, L: Dictionary, by_id: Dictionary) -> TextureRect:
	_post = TextureRect.new()
	_post.texture = tex
	_post.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_post.stretch_mode = TextureRect.STRETCH_SCALE
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CampfireHot.GLOW_SHADER
	_post_mat.shader = sh
	_post.material = _post_mat
	var pimg := tex.get_image()
	if pimg != null:
		if pimg.is_compressed():
			pimg.decompress()
		_post_bits = BitMap.new()
		_post_bits.create_from_image_alpha(pimg, 0.12)
	_post_home = Vector2(L.x, L.y)
	var sh_layer: Dictionary = by_id.get("sign_shadow", {})
	var sh_tex := UiSkin.tex(sh_layer.get("file", ""))
	if sh_tex != null:  # the backing / shadow of the first board: it goes up and down with the post
		var shadow := TextureRect.new()
		shadow.texture = sh_tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_SCALE
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.show_behind_parent = true
		shadow.position = Vector2(sh_layer.x, sh_layer.y) - _post_home
		shadow.size = Vector2(sh_layer.w, sh_layer.h)
		_post.add_child(shadow)
	var st: Dictionary = CampfireLayout.SIGN_TEXT
	_title = UiTheme.label("", int(st.size), st.color)
	var f := UiTheme.title_font()
	if f != null:
		_title.add_theme_font_override("font", f)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size = Vector2(300, 90)
	_title.position = Vector2(st.cx, st.cy) - _post_home - _title.size / 2.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.add_child(_title)
	var it: Dictionary = CampfireLayout.INFO_TEXT
	_info = UiTheme.label("", int(it.size), it.color)
	var fo := UiTheme.cut("oblique")
	if fo != null:
		_info.add_theme_font_override("font", fo)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size = Vector2(it.w, 70)
	_info.position = Vector2(it.cx, it.cy) - _post_home - _info.size / 2.0
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	_post.add_child(_info)
	return _post


## The word on the top board, shrunk to fit it.
func _refresh_title() -> void:
	if _title == null:
		return
	var word: String = IDLE_WORD
	if _hovered != "":
		word = WORDS[_hovered]
	elif _selected != "":
		word = WORDS[_selected]
	_title.text = word
	var size: int = int(CampfireLayout.SIGN_TEXT.size)
	var f := _title.get_theme_font("font")
	var room: float = float(CampfireLayout.SIGN.get("board_w", 200)) * 0.82
	while size > 14 and f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	_title.add_theme_font_size_override("font_size", size)


## The post rises out of the grass (or sinks back into it).
func _raise(on: bool) -> void:
	if _post == null or on == _raised:
		return
	_raised = on
	if is_instance_valid(_rise_tween):
		_rise_tween.kill()
	var to := _post_home
	if on:
		to = _post_home - Vector2(0, float(CampfireLayout.SIGN.get("delta", 0)))
	_rise_tween = create_tween()
	_rise_tween.tween_property(_post, "position", to, RISE_TIME).set_trans(Tween.TRANS_BACK if on else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on:
		Audio.play("ui_open_panel", -10.0)


func _set_post_glow(to: float) -> void:
	if _post_mat == null:
		return
	if is_instance_valid(_post_tween):
		_post_tween.kill()
	_post_tween = create_tween()
	_post_tween.tween_method(func(v: float):
		_post_glow = v
		_post_mat.set_shader_parameter("glow", v), _post_glow, to, 0.18)


## The forest sways and flutters a little in the wind (the same shader as the painted forests of the acts).
func _wind(n: Control) -> void:
	var sh := Shader.new()
	sh.code = Backdrop.WIND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("amp", 0.003)
	mat.set_shader_parameter("ground", 0.99)
	n.material = mat


const SMOKE_SHADER := """
shader_type canvas_item;
uniform float phase = 0.0;
uniform float strength = 1.0;
void fragment() {
	float h = 1.0 - UV.y;  // 0 at the cauldron, 1 at the top of the plume
	float sway = (sin(TIME * 1.7 + UV.y * 8.0 + phase) * 0.05 + sin(TIME * 0.8 + UV.y * 3.0 + phase * 1.7) * 0.045) * h * strength;
	float curl = sin(TIME * 1.1 + UV.y * 5.0 + phase) * 0.02 * h;
	vec4 c = texture(TEXTURE, vec2(UV.x + sway + curl, UV.y));
	float fade = 1.0 - smoothstep(0.25, 1.0, h);  // thinner and thinner as it rises
	float breathe = 0.78 + 0.22 * sin(TIME * 0.9 + phase * 2.3 + h * 4.0);
	c.a *= fade * breathe;
	COLOR = c;
}
"""


## Cauldron smoke: the plume wriggles, thins out towards the top and breathes.
func _smoke_style(n: Control) -> void:
	var sh := Shader.new()
	sh.code = SMOKE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("phase", 0.0)
	n.material = mat
	n.pivot_offset = Vector2(n.size.x / 2.0, n.size.y)
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "scale", Vector2(1.04, 1.05), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "scale", Vector2(0.97, 0.97), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A second, slower copy of the plume behind it gives the smoke body.
func _smoke_twin(n: Control) -> TextureRect:
	var back := n.duplicate() as TextureRect
	var mat2 := (n.material as ShaderMaterial).duplicate() as ShaderMaterial
	mat2.set_shader_parameter("phase", 2.4)
	mat2.set_shader_parameter("strength", 1.5)
	back.material = mat2
	back.modulate = Color(1, 1, 1, 0.6)
	back.scale = Vector2(1.1, 0.96)
	back.pivot_offset = n.pivot_offset
	var tw2 := back.create_tween().set_loops()
	tw2.tween_property(back, "scale", Vector2(0.96, 0.94), 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(back, "scale", Vector2(1.1, 1.08), 3.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return back


func _add_flame(by_id: Dictionary, resin: Control) -> void:
	var small: Dictionary = by_id.get("fire_small", {})
	var big: Dictionary = by_id.get("fire_big", {})
	if small.is_empty() or big.is_empty():
		return
	var ts := UiSkin.tex(small.file)
	var tb := UiSkin.tex(big.file)
	if ts == null or tb == null:
		return
	_flame = CampfireFlame.new()
	_flame.setup(ts, Vector2(small.x, small.y), tb, Vector2(big.x, big.y))
	_stage.add_child(_flame)
	# when the fire pit is a choice, the fire is part of it (hovering or clicking the fire is hovering or clicking the
	# pit). It's only scenery now (Seal is gone), so there is nothing to join it to.
	if resin is CampfireHot:
		var u := Rect2(Vector2(small.x, small.y), Vector2(small.w, small.h)).merge(Rect2(Vector2(big.x, big.y), Vector2(big.w, big.h)))
		(resin as CampfireHot).extra_area = Rect2(u.position - resin.position, u.size)


func _add_sparks(by_id: Dictionary) -> void:
	var textures: Array[Texture2D] = []
	for i in 12:
		var t := UiSkin.tex("campfire_spark_%d" % i)
		if t == null:
			break
		textures.append(t)
	if textures.is_empty() or by_id.get("fire_big") == null:
		return
	var big: Dictionary = by_id["fire_big"]
	var sparks := CampfireSparks.new()
	sparks.textures = textures
	sparks.origin = Vector2(big.x + big.w / 2.0, big.y + big.h * 0.35)
	sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(sparks)


func _on_hover(which: String, on: bool) -> void:
	if on:
		_hovered = which
		Audio.play("ui_hover", -6.0)
	elif _hovered == which:
		_hovered = ""
	_refresh_title()
	_refresh_hint()
	_refresh_flame()


func _refresh_flame() -> void:
	if _flame != null:
		_flame.boost = false


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _hovered != "" and _hovered != _selected:
		_hint.text = "Click to choose"
	elif _selected != "":
		_hint.text = CONFIRM_HINT if enabled.get(_selected, true) else "Not available right now"
	else:
		_hint.text = ""


func _on_press(which: String) -> void:
	Audio.play("ui_click")
	if which == _selected:  # the board is up: clicking the chosen thing again puts it back (another one switches the board)
		_cancel()
		return
	_select(which)


## The second click, on the board: do the chosen thing.
func _confirm() -> void:
	if not enabled.get(_selected, true):
		Audio.play("ui_error")
		return
	Audio.play("ui_click")
	chosen.emit(_selected)


func _select(which: String) -> void:
	for w in _hot:
		_hot[w].set_selected(w == which)
	_selected = which
	_info.text = hints.get(which, "")
	_info.visible = true
	_raise(true)
	_set_post_glow(1.0 if enabled.get(which, true) else 0.0)
	_refresh_title()
	_refresh_hint()
	_refresh_flame()


func _cancel() -> void:
	_selected = ""
	for w in _hot:
		_hot[w].set_selected(false)
	_raise(false)
	_set_post_glow(0.0)
	_info.visible = false
	_refresh_title()
	_refresh_hint()
	_refresh_flame()


## Is the point on the raised signboard (its drawn pixels)?
func _on_board(pos: Vector2) -> bool:
	if _post == null or not _raised or _post_bits == null:
		return false
	var local := pos - _post.position
	var bs := _post_bits.get_size()
	if _post.size.x <= 0.0 or _post.size.y <= 0.0:
		return false
	var x := int(local.x / _post.size.x * bs.x)
	var y := int(local.y / _post.size.y * bs.y)
	return local.x >= 0.0 and local.y >= 0.0 and x < bs.x and y < bs.y and _post_bits.get_bit(x, y)


## With the board up: a click on it confirms, a click anywhere else that is not a choice cancels.
func _gui_input(ev: InputEvent) -> void:
	if _selected == "":
		return
	if ev is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _on_board(ev.position) else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _on_board(ev.position):
			_confirm()
		else:
			_cancel()
		mouse_default_cursor_shape = Control.CURSOR_ARROW
