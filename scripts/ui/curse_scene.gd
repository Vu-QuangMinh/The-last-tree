class_name CurseScene
extends Control
## A curse lands (RunState.curse): "You have been cursed with the Curse of ...", its big burning sigil, then the spell it
## falls on comes up and the sigil flies down onto the card's top right and burns itself in. The Curse of Separation
## first tears the fused card back into its two spells (the fusion in reverse), and the sigil splits onto both.
## Click (or Continue) to go on: `done`.

signal done

const CARD_SCALE := 1.2
const SIGIL_R := 90.0
const CARD_SIGIL_R := 13.0

var kind := "burden"
var spell: Dictionary = {}  # the spell as it is now (cursed)
var fused: Dictionary = {}  # Separation: the fused spell it was
var parts: Array = []  # Separation: the two spells it was made of (as they are now)
var _can_go := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	z_index = 200
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.82, 0.3)
	_play()


func _play() -> void:
	var title := UiTheme.heading("You have been cursed with the", 30, Color(1.0, 0.85, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1400, 44)
	title.position = Vector2(260, 60)
	add_child(title)
	var name_l := UiTheme.heading(RunState.CURSE_NAMES.get(kind, kind), 58, Color(1.0, 0.3, 0.12))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_constant_override("outline_size", 10)
	name_l.add_theme_color_override("font_outline_color", Color(0.15, 0.02, 0.0))
	name_l.size = Vector2(1400, 80)
	name_l.position = Vector2(260, 104)
	add_child(name_l)
	var what := UiTheme.label(RunState.CURSE_TEXT.get(kind, ""), 24, Color(1.0, 0.85, 0.7))
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.size = Vector2(1400, 40)
	what.position = Vector2(260, 186)
	add_child(what)
	# the big sigil, flaring up
	var big := CurseSigil.make(kind, SIGIL_R)
	add_child(big)
	big.position = Vector2(960, 360) - big.size / 2.0
	big.scale = Vector2(0.2, 0.2)
	big.modulate = Color(3, 2, 2, 0)
	Audio.play("sfx_burn_apply", -2.0, 0.7)
	var tw := create_tween().set_parallel()
	tw.tween_property(big, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(big, "modulate", Color.WHITE, 0.6)
	await tw.finished
	await get_tree().create_timer(0.7).timeout
	# the spell(s) it falls on
	var targets: Array = []  # [card, spell dict]
	if kind == "separation" and not fused.is_empty() and parts.size() == 2:
		targets = await _tear_apart()
	else:
		var card := _card(_bare(spell), Vector2(960, 760))
		targets = [card]
		await get_tree().create_timer(0.35).timeout
	# the sigil flies down onto each card's top right (split in two for Separation)
	for k in targets.size():
		var card: SpellCard = targets[k]
		var s := big if k == 0 else CurseSigil.make(kind, SIGIL_R)
		if k > 0:
			add_child(s)
			s.position = big.position
		move_child(s, get_child_count() - 1)  # (over the card it lands on)
		_fly(s, card)
	Audio.play("sfx_frail_apply", -2.0)
	await get_tree().create_timer(0.75).timeout
	Audio.play("sfx_burn_apply", -4.0)
	for card in targets:
		var fx := Vfx.make(self, 10)
		fx.burst(_corner(card), 20, Color(1.0, 0.4, 0.1), Vector2(80, 280), Vector2(0.2, 0.5), Vector2(3, 7), Vfx.SPARK)
	var go := UiTheme.button("Continue", _finish, 22)
	go.custom_minimum_size = Vector2(220, 52)
	go.position = Vector2(1620, 990)
	add_child(go)
	_can_go = true


## A card's top right corner on the screen, where its first sigil burns (SpellCard._CurseMarks).
func _corner(card: SpellCard) -> Vector2:
	var sc := CARD_SCALE
	return card.global_position + Vector2(card.size.x * sc - CARD_SIGIL_R * sc * 1.4 - 6.0 * sc, CARD_SIGIL_R * sc * 1.4 - 7.0 * sc)


func _fly(s: CurseSigil, card: SpellCard) -> void:
	var from := s.position + s.size / 2.0
	var to := _corner(card)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		s.r = lerpf(SIGIL_R, CARD_SIGIL_R * CARD_SCALE, v)
		s.size = Vector2(s.r, s.r) * 2.6
		s.scale = Vector2.ONE
		s.position = from.lerp(to, v * v) - s.size / 2.0, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The spell without its curses' sigils (the one landing now is drawn by the flying sigil; the old ones stay).
func _bare(sp: Dictionary) -> Dictionary:
	var d := sp.duplicate(true)
	var cs: Array = d.get("curses", []).duplicate()
	var i := cs.rfind(kind)
	if i >= 0:
		cs.remove_at(i)
	d["curses"] = cs
	return d


func _card(sp: Dictionary, centre: Vector2) -> SpellCard:
	var c := SpellCard.make(sp)
	c.is_zoom_copy = true
	add_child(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = centre - Vector2(SpellCard.W, SpellCard.H) * CARD_SCALE / 2.0
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25)
	return c


## The fusion in reverse: the fused card shakes, flashes, and comes apart into the two spells it was made of.
func _tear_apart() -> Array:
	var f := _card(fused, Vector2(960, 760))
	await get_tree().create_timer(0.4).timeout
	var home := f.position
	var tw := create_tween()
	for k in 8:
		tw.tween_property(f, "position", home + Vector2(randf_range(-10, 10), randf_range(-4, 4)), 0.05)
	tw.tween_property(f, "modulate", Color(4, 4, 4, 1), 0.15)
	await tw.finished
	Audio.play("elem_remove", -2.0)
	var fx := Vfx.make(self, 10)
	fx.flash(Color(1, 1, 1, 0.6), 0.2)
	fx.burst(Vector2(960, 760), 30, Color(1.0, 0.85, 0.6), Vector2(200, 600), Vector2(0.3, 0.6), Vector2(3, 8), Vfx.SPARK)
	f.queue_free()
	var out: Array = []
	for k in 2:
		var c := _card(_bare(parts[k]), Vector2(960, 760))
		c.modulate.a = 1.0
		var dest := Vector2(960 + (-200.0 if k == 0 else 200.0), 760) - Vector2(SpellCard.W, SpellCard.H) * CARD_SCALE / 2.0
		c.create_tween().tween_property(c, "position", dest, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		out.append(c)
	await get_tree().create_timer(0.55).timeout
	return out


func _gui_input(ev: InputEvent) -> void:
	if _can_go and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_finish()


func _finish() -> void:
	if not _can_go:
		return
	_can_go = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	done.emit()
	queue_free()
