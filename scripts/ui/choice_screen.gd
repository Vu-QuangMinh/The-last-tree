class_name ChoiceScreen
extends Control
## Pick one of a few spells or artifacts (or skip). Used for rewards, treasure and the starting relic.

signal chosen(index: int)  # -1 = skipped

var title := ""
var subtitle := ""
var spells: Array = []
var artifacts: Array = []
var can_skip := true
var act := 1
var pulse := false  # an event asks for one of these (give it, cast it): the cards glow on and off
var on_stage := false  # Puppet Stage: laid over the stage (no backdrop of its own), the shade a little lighter
var hang := false  # Puppet Stage, artifacts only (the keepsakes): they dangle from the ceiling on strings where the enemies stand, each in a spotlight

const HANG_X := [540.0, 960.0, 1380.0]  # where the enemies stand (three of them)
const HANG_Y := [300.0, 450.0, 380.0]  # the middle of each artifact: the left one highest, the middle one lowest (strings of different lengths)
const HANG_PX := 170.0
const HANG_FEET := 600.0  # the floor under them, where the light pools
const HANG_TOP := 96.0  # the strings come down from the lower edge of the ceiling
const SWING_K := 9.0  # (a pendulum, as the puppets and the merchant's artifacts swing)
const SWING_DAMP := 1.1
const SWING_MAX := 0.22
var _hung: Array[Dictionary] = []  # {art, a, v, drop, phase}
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.42 if on_stage else 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if hang and on_stage and spells.is_empty() and not artifacts.is_empty() and artifacts.size() <= HANG_X.size():
		shade.color.a = 0.6  # (the stage dims; only the three spotlights are lit)
		_build_hanging()
		return
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var t := UiTheme.heading(title, 40, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := UiTheme.label(subtitle, 20, UiTheme.MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1800, 290 if spells.size() <= 5 else 640)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(scroll)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(1780, 0)
	row.add_theme_constant_override("h_separation", 24)
	row.add_theme_constant_override("v_separation", 18)
	scroll.add_child(row)
	# reward cards are drawn larger (laid out big, not stretched, so they stay sharp)
	var big := 1.35 if spells.size() <= 5 else 1.0
	for i in spells.size():
		var card := SpellCard.make(spells[i])
		card.zoom = big
		var idx := i
		card.clicked.connect(func(_c): chosen.emit(idx))
		row.add_child(card)
		_pulse(card, i)
	for i in artifacts.size():
		var card := ArtifactCard.make(artifacts[i])
		var idx := i
		card.clicked.connect(func(): chosen.emit(idx))
		row.add_child(card)
		_pulse(card, spells.size() + i)
	if can_skip:
		var skip := UiTheme.button("Skip", func(): chosen.emit(-1), 20)
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skip.custom_minimum_size = Vector2(200, 48)
		v.add_child(skip)
	# the scroll area is as tall as its cards need, up to a limit. It follows the cards' size whenever it changes
	# (they can finish laying out a few frames late), and is never shorter than one full card.
	var floor_h := SpellCard.H * big + 12.0 if not spells.is_empty() else 200.0
	var fit := func():
		if is_instance_valid(row) and is_instance_valid(scroll):
			scroll.custom_minimum_size.y = clampf(row.get_combined_minimum_size().y + 12.0, floor_h, 700.0)
	row.minimum_size_changed.connect(fit)
	fit.call()
	await get_tree().process_frame
	fit.call()


## The keepsakes on the stage: each dangles on a string from the ceiling where an enemy would stand, in a spotlight, its name and
## what it does written on the floor under it. Click one to take it.
func _build_hanging() -> void:
	var lights := StageLights.new()
	lights.feet = func() -> Array:
		var out: Array = []
		for k in _hung.size():
			out.append(Vector2(HANG_X[k], HANG_FEET))
		return out
	add_child(lights)
	var strings := _Strings.new()
	strings.screen = self
	add_child(strings)
	var t := UiTheme.heading(title, 40, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0.0, 118.0)
	t.size = Vector2(1920.0, 50.0)
	add_child(t)
	var sub := UiTheme.label(subtitle, 20, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0.0, 170.0)
	sub.size = Vector2(1920.0, 30.0)
	add_child(sub)
	for i in artifacts.size():
		var a: Dictionary = artifacts[i]
		var art: Control = UiSkin.artifact_icon(a.id, HANG_PX)
		if art == null:
			var l := UiTheme.label(a.get("icon", "◆"), 90, Color.WHITE)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			art = l
		art.size = Vector2(HANG_PX, HANG_PX)
		art.pivot_offset = art.size / 2.0
		art.mouse_filter = Control.MOUSE_FILTER_STOP
		art.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		art.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(idx))
		var d := {"art": art, "a": 0.0, "v": 0.0, "drop": -900.0, "phase": randf() * TAU}
		art.mouse_entered.connect(func():
			d.v += 0.35 * (1.0 if randf() < 0.5 else -1.0)  # (touched: it swings)
			Audio.play("ui_hover", -6.0)
			art.create_tween().tween_property(art, "scale", Vector2.ONE * 1.15, 0.14))
		art.mouse_exited.connect(func(): art.create_tween().tween_property(art, "scale", Vector2.ONE, 0.14))
		add_child(art)
		_hung.append(d)
		var drop := create_tween()
		drop.tween_interval(0.15 + 0.18 * i)
		drop.tween_callback(func(): Audio.play("shop_frame_drop", -3.0, randf_range(0.95, 1.05)))
		drop.tween_method(func(v: float): d.drop = v, -900.0, 0.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drop.tween_callback(func(): d.v += randf_range(-0.3, 0.3))
		# its name and what it does, on the floor under it, in its light
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 2)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UiTheme.heading(a.name, 26, ArtifactCard.color_of(a))  # (its rarity's colour)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_constant_override("outline_size", 8)
		nm.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
		words.add_child(nm)
		var ds := UiTheme.label(a.desc, 18, Color(0.95, 0.92, 0.85))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.custom_minimum_size = Vector2(330.0, 0.0)
		ds.add_theme_constant_override("outline_size", 6)
		ds.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
		words.add_child(ds)
		add_child(words)
		words.size = Vector2(340.0, 0.0)
		words.position = Vector2(float(HANG_X[i]) - 170.0, HANG_FEET + 30.0)
	set_process(true)


func _process(delta: float) -> void:
	if _hung.is_empty():
		return
	_t += delta
	for k in _hung.size():
		var d: Dictionary = _hung[k]
		var breeze := 0.045 * sin(_t * 0.8 + float(d.phase)) + 0.02 * sin(_t * 1.9 + float(d.phase) * 1.7)
		d.v += (-SWING_K * (float(d.a) - breeze) - SWING_DAMP * float(d.v)) * delta
		d.a = clampf(float(d.a) + float(d.v) * delta, -SWING_MAX, SWING_MAX)
		var art: Control = d.art
		var c := _centre(k)
		art.position = c - art.size / 2.0
		art.rotation = float(d.a)


## Where the middle of the k-th artifact is now (the end of its string).
func _centre(k: int) -> Vector2:
	var d: Dictionary = _hung[k]
	var hook := Vector2(HANG_X[k], HANG_TOP)
	return hook + Vector2(-sin(float(d.a)), cos(float(d.a))) * (float(HANG_Y[k]) - HANG_TOP + float(d.drop))


## The strings: thin, black and tight, from the ceiling to the middle of each artifact (behind it).
class _Strings extends Control:
	var screen: ChoiceScreen

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for k in screen._hung.size():
			draw_line(Vector2(ChoiceScreen.HANG_X[k], ChoiceScreen.HANG_TOP), screen._centre(k), Color(0.03, 0.03, 0.03, 0.9), RopeRig.STRING_W, true)


## The cards glow on and off (one after the other), to say "one of these goes".
func _pulse(card: Control, k: int) -> void:
	if not pulse:
		return
	var tw := card.create_tween().set_loops()
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.0).set_delay(0.12 * k)
	tw.tween_property(card, "modulate", Color(1.4, 1.32, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
