class_name MenuScreen
extends Control
## Title screen.

signal play
signal continue_run  # pick up the saved run
signal codex
signal unlocks
signal how_to
signal tutorial
signal test_mode  # the sandbox: pick enemies and spells, fight, come back
signal settings
signal room_test  # Dev Mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if UiSkin.is_puppet():
		_stage_backdrop()
	else:
		add_child(Backdrop.new())
	var v := VBoxContainer.new()
	var dev: bool = SaveManager.setting("dev_mode", false)
	if UiSkin.is_puppet():
		v.set_anchors_preset(Control.PRESET_TOP_LEFT)  # (placed by hand: _puppet_layout)
	else:
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if dev:
			v.offset_right = -480.0  # the whole column moves left: the Dev buttons take the right side
	v.alignment = BoxContainer.ALIGNMENT_BEGIN if UiSkin.is_puppet() else BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8 if UiSkin.is_puppet() else 16)
	add_child(v)
	var title_art := UiSkin.tex("game_title")
	if UiSkin.is_puppet():
		_puppet_title()
	elif title_art != null:  # New theme: the painted logo, at its own proportions
		var logo := TextureRect.new()
		logo.texture = title_art
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = title_art.get_size() * (0.78 if UiSkin.is_puppet() else 1.0)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(logo)
	else:
		var t := UiTheme.label("Behind the Curtain", 88, Color(0.85, 1, 0.75))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 12)
		t.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.04))
		v.add_child(t)
	if not UiSkin.is_puppet():
		var s := UiTheme.label("Chant fire, water and wind. Keep the last tree standing.", 24, UiTheme.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	if not UiSkin.is_puppet():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 30)
		v.add_child(gap)
	var st: Dictionary = SaveManager.data.stats
	_column = v
	if UiSkin.is_puppet():
		_puppet_buttons()
	else:
		_classic_buttons(v)
	_info = UiTheme.label("Runs %d  ·  Wins %d  ·  Best act %d" % [st.runs, st.wins, st.get("best_act", 0)], 16 if UiSkin.is_puppet() else 18, UiTheme.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UiSkin.is_puppet():  # the stats line sits in the bottom left corner of the screen
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_info.offset_left = 24.0
		_info.offset_top = -40.0
		_info.offset_bottom = -12.0
		_info.offset_right = 420.0
		add_child(_info)
	else:
		v.add_child(_info)
	if dev:
		_dev_column()
	if UiSkin.is_puppet():
		_puppet_layout(dev)


var _column: VBoxContainer
var _title: Node2D  # (Puppet) the title, which drifts sideways like the clouds (a Node2D: Controls are snapped to whole pixels, which made it move in steps)
var _title_x := 0.0
var _title_y := 0.0
var _t := 0.0
const TITLE_SLIDE := 42.0  # px it drifts to each side
const TITLE_SPEED := 0.32  # rad/s: a cloud's pace
var _info: Label
var _buttons: Array[Button] = []


## The other themes: one column with every button.
func _classic_buttons(v: VBoxContainer) -> void:
	var tut_label := "Tutorial" if SaveManager.setting("tutorial_done", false) else "Tutorial  (recommended)"
	var items := [["Play", play], [tut_label, tutorial], ["How to play · Wiki", how_to], ["Codex", codex], ["Unlocks  (✿ %d)" % SaveManager.data.seedlings, unlocks], ["Settings", settings], ["Quit", null]]
	if SaveManager.has_run():
		items.insert(0, ["Continue", continue_run])  # the saved run, where you left it
		items[1][0] = "New run"
	for pair in items:
		v.add_child(_make_button(pair))


func _make_button(pair: Array) -> Button:
	var sig = pair[1]
	var puppet := UiSkin.is_puppet()
	var b := UiTheme.button(pair[0], func(): if sig == null: get_tree().quit() elif sig is Signal: sig.emit() else: sig.call(), BTN_FONT if puppet else 26)
	b.custom_minimum_size = BTN if puppet else Vector2(360, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if pair[0] == "Play" or pair[0] == "Continue":
		UiTheme.use_play_style(b)
	elif pair[0].begins_with("Unlocks"):
		UiSkin.seedling_count_button(b, "Unlocks", int(SaveManager.data.seedlings), BTN_FONT if puppet else 26)
	return b


## Puppet Stage: every button is 80% as tall and 50% as wide as before (170 x 42). Three columns side by side: the main one (Continue, New run,
## More..., Quit); the one More... opens on its right (Tutorial, How to play, Codex, Unlocks, Settings); and, in Dev Mode, the Dev one at the far right.
const BTN := Vector2(170.0, 42.0)
const BTN_FONT := 20
const COL_STEP := 190.0  # distance between the columns' middles
var _more_col: VBoxContainer
var _dev_col: VBoxContainer


func _puppet_buttons() -> void:
	var items: Array = [["Play", play], ["More...", _toggle_more], ["Quit", null]]
	if SaveManager.has_run():
		items = [["Continue", continue_run], ["New run", play], ["More...", _toggle_more], ["Quit", null]]
	for pair in items:
		var b := _make_button(pair)
		_column.add_child(b)
		_buttons.append(b)
	_more_col = VBoxContainer.new()
	_more_col.add_theme_constant_override("separation", 8)
	_more_col.visible = false
	add_child(_more_col)
	var tut_label := "Tutorial" if SaveManager.setting("tutorial_done", false) else "Tutorial (new)"
	for pair in [[tut_label, tutorial], ["How to play", how_to], ["Codex", codex], ["Unlocks  (✿ %d)" % SaveManager.data.seedlings, unlocks], ["Settings", settings]]:
		_more_col.add_child(_make_button(pair))


func _toggle_more() -> void:
	_more_col.visible = not _more_col.visible


## Where the columns stand: the first button of each just under the near edge of the floor; the main column in the middle of the screen, the More column on its right, the Dev column after it.
func _puppet_layout(dev: bool) -> void:
	var top := _stage.floor_range().y + 26.0
	var mid := get_viewport_rect().size.x / 2.0
	var cols: Array = [_column, _more_col]
	if dev:
		cols.append(_dev_col)
	for i in cols.size():  # (the main column is in the middle of the screen; More opens on its right, Dev is the outermost)
		var c: Control = cols[i]
		c.position = Vector2(mid + i * COL_STEP - BTN.x / 2.0, top)
		c.size = Vector2(BTN.x, 0.0)
	_column.add_theme_constant_override("separation", 8)


## Dev Mode: a column of test buttons on the right (more to come).
func _dev_column() -> void:
	var d := VBoxContainer.new()
	var puppet := UiSkin.is_puppet()
	if not puppet:
		d.position = Vector2(1180, 0)
		d.size = Vector2(360, 1080)
		d.alignment = BoxContainer.ALIGNMENT_CENTER
	d.add_theme_constant_override("separation", 8 if puppet else 16)
	add_child(d)
	_dev_col = d
	for pair in [["Test mode", test_mode], ["Room Test", room_test]]:
		var sig: Signal = pair[1]
		var b := UiTheme.button(pair[0], func(): sig.emit(), BTN_FONT if puppet else 26)
		b.custom_minimum_size = BTN if puppet else Vector2(360, 60)
		d.add_child(b)


## Puppet Stage: the Act 1 theatre is the backdrop. Puppets walk on, stand a while and walk off; every so often the whole set of props is cleared away
## (they leave to the left) and a new one is brought in from the right.
const PROPS_EVERY := 45.0
var _stage: PuppetStage


func _stage_backdrop() -> void:
	_stage = PuppetStage.new(1)
	add_child(_stage)
	_stage.add_default_props()
	_stage.fit(get_viewport_rect().size.x)
	get_viewport().size_changed.connect(func() -> void: _stage.fit(get_viewport_rect().size.x))
	var actors := MenuActors.new()
	var fr := _stage.floor_range()
	actors.floor_top = fr.x
	actors.floor_bottom = fr.y
	add_child(actors)
	var timer := Timer.new()
	timer.wait_time = PROPS_EVERY
	timer.autostart = true
	timer.timeout.connect(_change_props)
	add_child(timer)


func _change_props() -> void:
	if not is_instance_valid(_stage) or _stage.is_clearing():
		return
	_stage.clear_props()
	await _stage.cleared
	if is_instance_valid(_stage):
		_stage.bring_props()


## Puppet Stage: the title (UI/Misc/Title.png, the user's own picture) hangs under the ceiling valance (z below PuppetStage.CEILING_Z), a little lower
## than its edge. Its cast shadow is faked cheaply: the picture is shrunk to a third of its size once (that blurs it by about 3 px when it is drawn
## back at full size), drawn black (by modulate) at a low opacity and shifted down and right.
const TITLE_W := 400.0
const TITLE_Y := 150.0
const TITLE_CROP := Rect2(57, 198, 2641, 1120)  # the painted part of the 2752 x 1536 picture
const SHADOW_OFFSET := Vector2(8.0, 12.0)
const SHADOW_ALPHA := 0.4
static var _shadow_tex: ImageTexture  # (made once)


func _puppet_title() -> void:
	var src := load("res://assets/Puppet/UI/Misc/Title.png") as Texture2D
	if src == null:
		return
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = TITLE_CROP
	var h := TITLE_W * TITLE_CROP.size.y / TITLE_CROP.size.x
	var holder := Node2D.new()
	holder.z_index = PuppetStage.CEILING_Z - 20
	holder.position = Vector2(get_viewport_rect().size.x / 2.0, TITLE_Y + h / 2.0)  # (its middle)
	_title = holder
	_title_x = holder.position.x
	_title_y = holder.position.y
	add_child(holder)
	if _shadow_tex == null:
		var img := src.get_image()
		if img.is_compressed():
			img.decompress()
		img = img.get_region(Rect2i(TITLE_CROP))
		img.resize(roundi(TITLE_W / 3.0), roundi(h / 3.0), Image.INTERPOLATE_LANCZOS)
		_shadow_tex = ImageTexture.create_from_image(img)
	var sh := Sprite2D.new()
	sh.texture = _shadow_tex
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sh.scale = Vector2(TITLE_W / float(_shadow_tex.get_width()), h / float(_shadow_tex.get_height()))
	sh.position = SHADOW_OFFSET
	sh.modulate = Color(0, 0, 0, SHADOW_ALPHA)  # (black: the colour is multiplied by 0, the shape stays)
	holder.add_child(sh)
	var logo := Sprite2D.new()
	logo.texture = at
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.scale = Vector2.ONE * TITLE_W / TITLE_CROP.size.x
	holder.add_child(logo)


func _process(d: float) -> void:
	_t += d
	if is_instance_valid(_title):  # (as a cloud: it slides and rocks a hair about its middle)
		var w := sin(_t * TITLE_SPEED)
		_title.position.x = _title_x + w * TITLE_SLIDE
		_title.rotation = w * 0.012
