class_name FuseScreen
extends Control
## Campfire: fuse two spells into one. Pick two cards; the forged spell is shown before you commit.

signal fused(new_spell: Dictionary)
signal back

const RULES := "Fuse melts two of your spells into ONE spell that does everything both of them did.\n• Its pattern: the first spell you pick, then the whole of the second.\n• Then you may shoot ONE Essence out of the new pattern. The rest close up.\n• Both spells are used up, and the new one takes a single slot in your active row.\n• Only spells that can be fused are shown: anti-spells, Powers and fused spells can't be."

var run: RunState
var _picked: Array = []  # ids, in the order chosen
var _preview: Dictionary = {}
var _grid: HFlowContainer
var _result_box: HBoxContainer
var _status: RichTextLabel
var _fuse_btn: Button
var _drop := -1  # the Essence shot out of the fused pattern (-1 = none yet)
var _out: SpellCard  # the fused spell's card, once two are picked: you shoot an Essence out of it
var _aim: AimCursor


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = run.act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(50, 70)
	v.size = Vector2(1820, 1000)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.heading("🔥 Fuse two spells", 38, Color(1, 0.8, 0.6)))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.custom_minimum_size = Vector2(1100, 0)
	rules.add_theme_font_size_override("normal_font_size", 18)
	rules.add_theme_font_size_override("bold_font_size", 18)
	rules.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	rules.text = Keywords.colorize(RULES)
	v.add_child(rules)
	# the result, once two spells are picked
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	v.add_child(mid)
	_result_box = HBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 16)
	_result_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_result_box.custom_minimum_size = Vector2(0, SpellCard.H)
	mid.add_child(_result_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	mid.add_child(side)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(560, 0)
	_status.add_theme_font_size_override("normal_font_size", 19)
	_status.add_theme_font_size_override("bold_font_size", 19)
	_status.add_theme_color_override("default_color", Color(1, 0.9, 0.75))
	side.add_child(_status)
	_fuse_btn = UiTheme.button("Fuse them!", _commit, 24)
	_fuse_btn.custom_minimum_size = Vector2(260, 56)
	side.add_child(_fuse_btn)
	v.add_child(UiTheme.label("Your spells (click two):", 18, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1820, 300)
	v.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.custom_minimum_size = Vector2(1800, 0)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var bh := HBoxContainer.new()
	bh.position = Vector2(1500, 1000)
	add_child(bh)
	var back_btn := UiTheme.button("Back to the campfire", func(): back.emit(), 20)
	back_btn.custom_minimum_size = Vector2(300, 52)
	bh.add_child(back_btn)
	_aim = AimCursor.new()
	_aim.mode = "shoot"
	_aim.visible = false
	add_child(_aim)
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	# only the spells that can be fused are shown at all
	for id in run.fusable():
		var card := SpellCard.make(run.spell(id))
		card.selected = id in _picked
		card.set_meta("fuse_tip", "\n\nFuse: pick this and one more spell to melt them into one.")
		card.clicked.connect(func(_c): _toggle(id))
		_grid.add_child(card)
		if id in _picked:
			card.modulate = Color(1.3, 1.2, 0.9)
	for c in _result_box.get_children():
		c.queue_free()
	_out = null
	_fuse_btn.disabled = _picked.size() < 2
	match _picked.size():
		0:
			_status.text = Keywords.colorize("Pick the first spell: its pattern goes first.")
		1:
			var a := run.spell(_picked[0])
			_status.text = Keywords.colorize("%s picked. Now pick the second spell: its pattern goes after." % a.name)
			_result_box.add_child(SpellCard.make(a))
		2:
			var a := run.spell(_picked[0])
			var b := run.spell(_picked[1])
			_result_box.add_child(SpellCard.make(a))
			_result_box.add_child(UiTheme.label("+", 48, Color.WHITE))
			_result_box.add_child(SpellCard.make(b))
			_result_box.add_child(UiTheme.label("→", 48, Color(1, 0.8, 0.4)))
			_out = SpellCard.make(_preview)
			_result_box.add_child(_out)
			_status.text = _shot_status()


func _toggle(id: String) -> void:
	if not run.can_fuse(id):
		return
	if id in _picked:
		_picked.erase(id)
	elif _picked.size() < 2:
		_picked.append(id)
	else:
		_picked[1] = id
	_drop = -1
	_preview = run.fuse_preview(_picked[0], _picked[1]) if _picked.size() == 2 else {}
	_refresh.call_deferred()


func _commit() -> void:
	if _picked.size() < 2 or _preview.is_empty():
		return
	run.fuse_commit(_preview, _picked[0], _picked[1])
	fused.emit(_preview)


func _shot_status() -> String:
	if _drop >= 0:
		return Keywords.colorize("Shot! The new pattern is %d Essence long. Fuse them when you're ready, or pick again to start over." % String(_preview.pattern).length())
	if _can_shoot():
		return Keywords.colorize("Aim at the new pattern and shoot ONE Essence out of it. Or fuse them as they are.")
	return ""


func _can_shoot() -> bool:
	return _drop < 0 and is_instance_valid(_out) and String(_preview.get("pattern", "")).length() >= 2


## The crosshair replaces the pointer while it's over the fused card (until an Essence has been shot).
func _process(_d: float) -> void:
	var aiming := _can_shoot() and _out.get_global_rect().has_point(get_global_mouse_position())
	if aiming != _aim.visible:
		_aim.visible = aiming
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if aiming else Input.MOUSE_MODE_VISIBLE


func _input(ev: InputEvent) -> void:
	if not (_aim.visible and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var orbs := _out.live_orbs()
	var best := -1
	var best_d := INF
	for i in orbs.size():
		var o: Control = orbs[i]
		var d: float = (o.get_global_rect().get_center() - ev.position).length()
		if d < best_d and d <= o.size.x * 0.75:
			best = i
			best_d = d
	if best >= 0:
		_shoot(orbs, best)


## BANG: a gunshot, a muzzle flash and a bullet hole where you aimed; the Essence shatters and the rest snap together.
func _shoot(orbs: Array, index: int) -> void:
	var orb: Control = orbs[index]
	var at := orb.get_global_rect().get_center()
	var col: Color = Elements.COLORS.get(String(_preview.pattern[index]), Color.WHITE)
	Audio.play_gunshot()
	_aim.kick()
	var fx := Vfx.make(self, 80)
	fx.glow(at, 90, Color(1, 0.95, 0.75, 1.0), 0.12)
	fx.flare(at, 180, Color(1, 0.85, 0.4, 0.95), 0.14)
	fx.burst(at, 16, Color(1, 0.8, 0.35), Vector2(250, 650), Vector2(0.1, 0.25), Vector2(3, 6))
	fx.ring(at, 6, 40, Color(1, 0.9, 0.6), 0.18, 4.0)
	var hole := fx.part(at, Vector2.ZERO, Color(0.05, 0.03, 0.03, 0.95), 0.7, 9.0, Vfx.SMOKE)
	hole.size1 = 9.0
	hole.hold = 0.6
	for sh in fx.burst(at, 10, col.darkened(0.2), Vector2(120, 320), Vector2(0.4, 0.7), Vector2(4, 8), Vfx.SHARD):
		sh.grav = Vector2(0, 900)
		sh.spin = randf_range(-12, 12)
		sh.size1 = sh.size0
	_drop = index
	_preview = run.fuse_preview(_picked[0], _picked[1], _drop)
	_out.spell = _preview
	_status.text = _shot_status()
	# the shot Essence vanishes, then its gap closes and the others snap into place
	var tw := orb.create_tween()
	tw.tween_property(orb, "modulate:a", 0.0, 0.06)
	tw.tween_interval(0.15)
	tw.tween_property(orb, "custom_minimum_size:x", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(orb.queue_free)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
