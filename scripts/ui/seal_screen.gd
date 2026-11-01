class_name SealScreen
extends Control
## Upgrading a spell: you pick one Essence of its pattern and a purple wax seal is stamped over it. That Essence
## isn't needed any more (the spell is easier to wake); the card keeps its name and shows the seal.

signal done
signal hint_changed(text: String)  # embedded: the words go to the event's hint panel
signal backed  # (can_back) Back or a right-click before the wax is stamped: pick another spell

var run: RunState
var spell_id := ""
var _card_holder: CenterContainer
var _orbs: HBoxContainer
var _hint: Label
var _sealed := false
var embedded := false  # laid over an event's stage: no backdrop, no shade, no title, smaller, in the upper part of the screen
var can_back := false  # Back (top left) and a right-click go back to the spells, until the wax is stamped (that is final)
var _back_btn: Button


func setup(p_run: RunState, p_id: String) -> void:
	run = p_run
	spell_id = p_id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if not embedded:
		var bd := Backdrop.new()
		bd.act = run.act
		add_child(bd)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN if embedded else BoxContainer.ALIGNMENT_CENTER
	if embedded:
		v.offset_top = 150.0
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if can_back:
		_back_btn = UiTheme.button("Back", _back, 24)
		_back_btn.custom_minimum_size = Vector2(200, 52)
		_back_btn.position = Vector2(24.0, 190.0)
		add_child(_back_btn)
	v.add_theme_constant_override("separation", 14 if embedded else 26)
	add_child(v)
	if not embedded:
		var title := UiTheme.label("🟣 A purple seal for %s" % run.spell(spell_id).name, 40, Color(0.85, 0.6, 1.0))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)
	_hint = UiTheme.label("Click the Essence to seal. It won't be needed to wake the spell any more.", 22, Color(0.9, 0.9, 0.85))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	if embedded:
		_hint.visible = false
		hint_changed.emit.call_deferred(_hint.text)
	_card_holder = CenterContainer.new()
	_card_holder.custom_minimum_size = Vector2(0, SpellCard.H * (1.2 if embedded else 1.5))
	_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_card_holder)
	_orbs = HBoxContainer.new()
	_orbs.alignment = BoxContainer.ALIGNMENT_CENTER
	_orbs.add_theme_constant_override("separation", 22)
	_orbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_orbs)
	_rebuild()


func _rebuild() -> void:
	for c in _card_holder.get_children():
		c.queue_free()
	var card := SpellCard.make(run.spell(spell_id))
	card.zoom = 1.2 if embedded else 1.5
	_card_holder.add_child(card)
	for c in _orbs.get_children():
		c.queue_free()
	var s := run.spell(spell_id)
	var full: String = s.get("full_pattern", s.pattern)
	var seals: Array = s.get("seals", [])
	for i in full.length():
		var ic := ElementIcon.make(full[i], 96)
		ic.size = Vector2(96, 96)
		ic.sealed = i in seals
		if not ic.sealed and not _sealed:
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ic.tooltip_text = "Seal this %s" % Elements.NAMES.get(full[i], "Essence")
			var k := i
			ic.mouse_entered.connect(func():
				ic.pivot_offset = ic.size / 2.0
				ic.highlight = true
				ic.create_tween().tween_property(ic, "scale", Vector2(1.15, 1.15), 0.08)
				ic.queue_redraw())
			ic.mouse_exited.connect(func():
				ic.highlight = false
				ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.08)
				ic.queue_redraw())
			ic.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_seal(k, ic))
		_orbs.add_child(ic)


func _back() -> void:
	if _sealed:
		return
	Audio.play("ui_click", -4.0)
	backed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if can_back and not _sealed and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_back()


## The seal drops from above, spinning, lands with a thump and a splash of purple, and the orb is covered.
func _seal(i: int, orb: ElementIcon) -> void:
	if _sealed:
		return
	_sealed = true
	if is_instance_valid(_back_btn):
		_back_btn.queue_free()  # (the stamp is final)
	var at := orb.get_global_rect().get_center()
	var wax := ElementIcon.make(orb.el, 96)
	wax.size = Vector2(96, 96)
	wax.sealed = true
	wax.pivot_offset = wax.size / 2.0
	wax.position = at - wax.size / 2.0 + Vector2(0, -260)
	wax.scale = Vector2(2.4, 2.4)
	wax.rotation = -1.2
	wax.z_index = 20
	add_child(wax)
	var tw := wax.create_tween()
	tw.set_parallel()
	tw.tween_property(wax, "position", at - wax.size / 2.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wax, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wax, "rotation", 0.0, 0.32)
	await get_tree().create_timer(0.32).timeout
	# thump
	Audio.play("sfx_wax_seal")  # (a thick wet splat: the wax lands)
	var fx := Vfx.make(self, 30)
	fx.glow(at, 200, Color(0.8, 0.45, 1.0, 0.8), 0.5)
	fx.ring(at, 30, 190, Color(0.8, 0.5, 1.0), 0.45, 10.0)
	for d in fx.burst(at, 22, Color(0.62, 0.25, 0.7), Vector2(150, 420), Vector2(0.5, 0.8), Vector2(5, 9), Vfx.DROP):
		d.grav = Vector2(0, 1000)
		d.size1 = d.size0 * 0.6
	fx.burst(at, 16, Color(1, 0.85, 1), Vector2(200, 500), Vector2(0.2, 0.4), Vector2(3, 6))
	var sq := wax.create_tween()
	sq.tween_property(wax, "scale", Vector2(1.25, 0.8), 0.06)
	sq.tween_property(wax, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	run.seal_spell(spell_id, i)
	await get_tree().create_timer(0.4).timeout
	wax.queue_free()
	_rebuild()
	var left := String(run.spell(spell_id).pattern).length()
	_hint.text = ("Sealed. %s now needs %d Essence." % [run.spell(spell_id).name, left]) if left > 0 else "Sealed. %s now wakes on every chant!" % run.spell(spell_id).name
	hint_changed.emit(_hint.text)
	var go := UiTheme.button("Continue", func(): done.emit(), 22)
	go.custom_minimum_size = Vector2(0, 52) if embedded else Vector2(260, 56)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_orbs.get_parent().add_child(go)
