class_name DiceFightView
extends Control
## Die on Stage (2026-11-15): the fight screen. The act's puppet stage with the enemies' puppets standing on its floor
## (an HP bar under each, its intent over its head); at the bottom your HP and Shield, the tray of this turn's dice, your
## cards and End turn. Each turn the dice are thrown onto the stage, bounce and tumble, and are gathered back into the
## tray. Drag a die onto a card's slot; when a card's slots are full it is ready, and one that is aimed asks for its
## target (click an enemy; right-click or Esc puts it back). With one enemy to aim at, it fires at it at once.

signal finished(won: bool)

const FOE_W := 300.0
const PUPPET := 300.0

var run: DiceRun
var fight: DiceFight
var _stage: PuppetStage
var _foe_nodes: Array = []  # per foe: {creature, bar, intent, status}
var _aiming := -1  # a ready card waiting for its target (its index in run.cards)
var _busy := false
var _throwing := false  # the dice are in the air: the tray's dice are hidden until they land in it
var _prompt: Label
var _tray: HBoxContainer
var _cards: HBoxContainer
var _hp_label: Label
var _hp_bar: Control
var _block_label: Label
var _status_label: Label
var _end_btn: Button
var _floor_y := 640.0


func setup(p_run: DiceRun, ids: Array) -> void:
	run = p_run
	fight = DiceFight.new()
	fight.setup(run, ids)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = PuppetStage.new(run.act)
	add_child(_stage)
	_stage.add_default_props()
	_stage.fit(1920.0)
	_floor_y = _stage.floor_center_y()
	_build_foes()
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.035, 0.92)
	sb.border_color = Color(0.45, 0.3, 0.15)
	sb.border_width_top = 4
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(0, 735)
	panel.size = Vector2(1920, 345)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	# you
	_hp_label = UiTheme.label("", 26, Color.WHITE)
	_hp_label.position = Vector2(40, 760)
	add_child(_hp_label)
	_hp_bar = Control.new()
	_hp_bar.position = Vector2(40, 800)
	_hp_bar.size = Vector2(300, 26)
	_hp_bar.draw.connect(func():
		_draw_bar(_hp_bar, run.hp, run.max_hp, fight.block, Color(0.8, 0.15, 0.12)))
	add_child(_hp_bar)
	_block_label = UiTheme.label("", 24, Color(0.6, 0.8, 1.0))
	_block_label.position = Vector2(40, 836)
	add_child(_block_label)
	_status_label = UiTheme.label("", 20, Color(0.95, 0.75, 1.0))
	_status_label.position = Vector2(40, 872)
	_status_label.size = Vector2(320, 120)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	var leaves := UiTheme.label("🪙 %d coins" % run.leaves, 20, Color(0.75, 0.95, 0.6))
	leaves.position = Vector2(40, 1030)
	add_child(leaves)
	# the dice tray, then the cards
	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 18)
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray.position = Vector2(560, 748)
	_tray.size = Vector2(800, DiceDieView.SIZE)
	add_child(_tray)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 22)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.position = Vector2(400, 845)
	_cards.size = Vector2(1120, DiceCardView.H)
	_cards.scale = Vector2(0.78, 0.78)
	_cards.pivot_offset = Vector2(560, 0)
	add_child(_cards)
	_end_btn = UiTheme.button("End turn", _on_end_turn, 24)
	_end_btn.custom_minimum_size = Vector2(200, 64)
	_end_btn.position = Vector2(1680, 780)
	add_child(_end_btn)
	var hint := UiTheme.label("Drag dice onto moves. A full move then asks for its target.", 17, Color(0.85, 0.78, 0.65))
	hint.position = Vector2(1500, 960)
	hint.size = Vector2(400, 100)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	_prompt = UiTheme.label("", 26, Color(1.0, 0.9, 0.55))
	_prompt.add_theme_constant_override("outline_size", 7)
	_prompt.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(1920, 40)
	_prompt.position = Vector2(0, 150)
	_prompt.z_index = PuppetStage.CEILING_Z + 10
	add_child(_prompt)
	fight.events.clear()  # (the first roll: it is thrown below)
	_refresh()
	_pianist_start()
	_throw_dice()


func _build_foes() -> void:
	for i in fight.foes.size():
		_add_foe_node(i)
	_layout_foes(false)


## Where each enemy stands: side by side in the middle of the floor (narrower when there are many).
func _slot_x(i: int) -> float:
	var n := fight.foes.size()
	var w := minf(FOE_W, 1800.0 / maxf(1.0, n))
	return 960.0 - n * w / 2.0 + i * w + (w - FOE_W) / 2.0


func _layout_foes(animate := true) -> void:
	for i in _foe_nodes.size():
		var nd: Dictionary = _foe_nodes[i]
		var x := _slot_x(i)
		var parts := {"creature": 0.0, "bar": 50.0, "intent": 0.0, "status": 0.0, "mark": 0.0, "spells": 0.0}
		for key in parts:
			var c: Control = nd[key]
			var to := Vector2(x + float(parts[key]), c.position.y)
			if animate:
				c.create_tween().tween_property(c, "position", to, 0.35).set_trans(Tween.TRANS_QUAD)
			else:
				c.position = to


## The nodes of enemy `i`: its puppet, HP bar, intent, statuses, the target mark, and (Good Ol' Wizard) his spells.
func _add_foe_node(i: int) -> void:
	var f: DiceFight.Foe = fight.foes[i]
	var cr := Creature.new()
	cr.setup(f.es)
	cr.size = Vector2(PUPPET, PUPPET)
	cr.position = Vector2(_slot_x(i), _floor_y - PUPPET + 40.0)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	cr.gui_input.connect(func(ev: InputEvent):
		var me := fight.foes.find(f)
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _aiming >= 0 and me in fight.targets_for(_aiming):
			_fire_at(me))
	add_child(cr)
	var bar := Control.new()
	bar.size = Vector2(200, 22)
	bar.position = Vector2(_slot_x(i) + 50.0, _floor_y + 52.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		_draw_bar(bar, f.hp, f.max_hp, f.block, Color(0.75, 0.12, 0.12))
		var font := ThemeDB.fallback_font
		bar.draw_string(font, Vector2(0, 17), "%d / %d" % [f.hp, f.max_hp], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 16, Color.WHITE))
	add_child(bar)
	var intent := UiTheme.label("", 24, Color(1.0, 0.92, 0.75))
	intent.add_theme_constant_override("outline_size", 6)
	intent.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent.size = Vector2(FOE_W, 34)
	intent.position = Vector2(_slot_x(i), cr.position.y - 10.0)
	intent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intent)
	var status := UiTheme.label("", 17, Color(1.0, 0.75, 0.55))
	status.add_theme_constant_override("outline_size", 5)
	status.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.size = Vector2(FOE_W, 26)
	status.position = Vector2(_slot_x(i), _floor_y + 78.0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	var mark := Label.new()
	mark.text = "▼"
	mark.add_theme_font_size_override("font_size", 30)
	mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.size = Vector2(FOE_W, 34)
	mark.position = Vector2(_slot_x(i), cr.position.y - 44.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	var spells := HBoxContainer.new()  # (Good Ol' Wizard: his spells, high above him)
	spells.add_theme_constant_override("separation", 10)
	spells.alignment = BoxContainer.ALIGNMENT_CENTER
	spells.size = Vector2(FOE_W, SPELL_H)
	spells.position = Vector2(_slot_x(i), cr.position.y - 36.0 - SPELL_H)
	spells.z_index = PuppetStage.CEILING_Z + 5  # (over the stage's valance: they hang high above him)
	add_child(spells)
	_foe_nodes.append({"creature": cr, "bar": bar, "intent": intent, "status": status, "mark": mark, "spells": spells})


const SPELL_SCALE := 0.74
const SPELL_H := DiceCardView.H * SPELL_SCALE


## Good Ol' Wizard's spells over him: a card each, its slot asking for its number (a die of it interrupts the spell).
func _build_spells(i: int) -> void:
	var f: DiceFight.Foe = fight.foes[i]
	var row: HBoxContainer = _foe_nodes[i].spells
	for c in row.get_children():
		c.queue_free()
	if f.dead():
		return
	for k in f.spells.size():
		var sp: Dictionary = f.spells[k]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(DiceCardView.W, DiceCardView.H) * SPELL_SCALE
		var cv := DiceCardView.new()
		cv.def = {"name": sp.name, "kind": "special", "slots": 1, "rule": "exact", "n": int(sp.cut),
			"text": "%s Die (%d): Interrupt this spell." % [sp.text, int(sp.cut)]}
		cv.ci = k
		cv.scale = Vector2(SPELL_SCALE, SPELL_SCALE)
		var me := i
		cv.accept = func(r: int, kk: int) -> bool: return kk == 0 and not _busy and _aiming < 0 and fight.can_interrupt(r, me, cv.ci)
		cv.slot_dropped.connect(func(kk: int, _slot: int, r: int): _interrupt(me, kk, r, cv))
		holder.add_child(cv)
		row.add_child(holder)
	var w := f.spells.size() * DiceCardView.W * SPELL_SCALE + (f.spells.size() - 1) * 10.0
	row.size = Vector2(w, SPELL_H)
	row.position.x = _slot_x(i) + FOE_W / 2.0 - w / 2.0


func _interrupt(fi: int, k: int, r: int, cv: DiceCardView) -> void:
	if _busy:
		return
	if fight.interrupt(r, fi, k):
		Audio.play("elem_remove", -2.0)
	else:
		cv.shake()
	await _play_events()
	_refresh()


## An HP bar: the HP in red, and the Shield (Block) as a blue part right after it (the bar stretches to hold both:
## Shield is not a status of its own, 2026-11-16).
const SHIELD_BLUE := Color(0.3, 0.6, 1.0)


func _draw_bar(c: Control, hp: int, max_hp: int, shield: int, col: Color) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var total := float(maxi(max_hp, hp + shield))
	c.draw_rect(r, Color(0.08, 0.04, 0.03))
	var hw := r.size.x * float(hp) / maxf(1.0, total)
	c.draw_rect(Rect2(r.position, Vector2(hw, r.size.y)), col)
	if shield > 0:
		c.draw_rect(Rect2(r.position + Vector2(hw, 0), Vector2(r.size.x * float(shield) / total, r.size.y)), SHIELD_BLUE)
	c.draw_rect(r, Color(0.9, 0.75, 0.45) if shield <= 0 else SHIELD_BLUE.lightened(0.4), false, 2.0)


func _refresh() -> void:
	var aim: Array = fight.targets_for(_aiming) if _aiming >= 0 else []
	_prompt.text = "%s: choose a target   ·   right-click to put it back" % run.card_at(_aiming).name if _aiming >= 0 else ""
	for i in fight.foes.size():
		var f: DiceFight.Foe = fight.foes[i]
		var nd: Dictionary = _foe_nodes[i]
		(nd.bar as Control).queue_redraw()
		nd.intent.text = "" if f.dead() else DiceFight.intent_text(f.intent, f)
		var st := []
		if f.thorns > 0:
			st.append("🌵 Thorns %d" % f.thorns)
		if f.ethereal > 0:
			st.append("👻 Ethereal")
		if f.burn > 0:
			st.append("🔥 Burn %d" % f.burn)
		if f.stun > 0:
			st.append("💫 Stunned")
		if f.power > 0:
			st.append("💪 %d" % f.power)
		if f.weak > 0:
			st.append("Weakened %d" % f.weak)
		if f.vulnerable > 0:
			st.append("Vulnerable %d" % f.vulnerable)
		if f.redirect:
			st.append("↩ Redirected")
		nd.status.text = "  ".join(st)
		nd.mark.visible = i in aim
		(nd.creature as Creature).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i in aim else Control.CURSOR_ARROW
		nd.bar.visible = not f.dead()
		if f.shielded():
			nd.status.text = ("  ".join(st) + "  " if not st.is_empty() else "") + "🌿 Behind her hedges"
		if f.impervious > 0:
			nd.status.text += "  ✨ Impervious"
		if f.deflect:
			nd.status.text += "  🗡 Deflect"
		if f.es.def.get("invokes", false):
			_build_spells(i)
	_hp_label.text = "❤ %d / %d" % [run.hp, run.max_hp]
	_hp_bar.queue_redraw()
	_block_label.text = ""  # (Shield is only the blue part of the HP bar, 2026-11-16)
	var you := []
	if fight.weak > 0:
		you.append("Weakened %d" % fight.weak)
	if fight.vulnerable > 0:
		you.append("Vulnerable %d" % fight.vulnerable)
	if fight.burn > 0:
		you.append("🔥 Burn %d" % fight.burn)
	if fight.ethereal:
		you.append("👻 Ethereal")
	if not fight.revenge.is_empty():
		you.append("⚔ Revenge x%d: %d so far" % [int(fight.revenge.mult), int(fight.revenge.taken)])
	if fight.dodge > 0:
		you.append("🪽 Dodge" + (" %d" % fight.dodge if fight.dodge > 1 else ""))  # (the number only when more than one)
	if fight.skull:
		you.append("☠ Double damage this turn")
	if fight.guard:
		you.append("🛡 Double Shield this turn")
	_status_label.text = "\n".join(you)
	_build_tray()
	_build_cards()
	_end_btn.disabled = _busy or fight.over


func _build_tray() -> void:
	for c in _tray.get_children():
		c.queue_free()
	for r in fight.rolled.size():
		var d := DiceDieView.new()
		d.r = r
		d.value = int(fight.rolled[r].value)
		d.paint = String(fight.rolled[r].paint)
		d.carve = String(fight.rolled[r].carve)
		d.used = bool(fight.rolled[r].used)
		d.frozen = bool(fight.rolled[r].frozen)
		d.face_down = bool(fight.rolled[r].hidden)
		d.can_reroll = not _busy and _aiming < 0 and fight.can_reroll(r)
		d.reroll_pressed.connect(func(rr: int):
			if _busy or _aiming >= 0:
				return
			fight.reroll(rr)
			Audio.play("elem_pickup", -4.0)
			await _play_events()
			_refresh())
		if _throwing:
			d.modulate.a = 0.0
		_tray.add_child(d)


func _build_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for ci in run.cards.size():
		var cv := DiceCardView.new()
		cv.id = run.cards[ci]
		cv.def = run.card_at(ci)  # (as it is now: upgraded or not)
		if String(cv.def.get("tweak", "")) == "intuition":
			cv.def.text = String(cv.def.text).replace("[x]", str(fight.intuition))
		cv.ci = ci
		cv.filled = fight.placed.get(ci, [])
		cv.faces = fight.placed_dice.get(ci, []).map(func(rr): return fight.rolled[int(rr)] if int(rr) >= 0 else {})
		cv.spent = fight.spent.has(ci) or fight.silenced.has(ci) or fight.cocooned.has(ci) or int(fight.hammered.get(ci, 0)) >= DiceFight.HAMMER_BREAKS
		if int(fight.hammered.get(ci, 0)) >= DiceFight.HAMMER_BREAKS:
			cv.state = "BROKEN"
		elif fight.cocooned.has(ci):
			cv.state = "IN A COCOON"
		elif fight.fled.has(ci):  # (Flee: its die stays in it, dimmed, for that many turns)
			var fl: Dictionary = fight.fled[ci]
			cv.filled = [int(fl.value)]
			cv.faces = [{"paint": fl.paint, "carve": fl.carve}]
			cv.spent = true
			cv.state = "HELD: %d turn%s" % [int(fl.turns), "" if int(fl.turns) == 1 else "s"]
		elif fight.gone.has(ci):
			cv.state = "GONE"
			cv.spent = true
		elif fight.cooldown.has(ci):
			cv.state = "COOLDOWN"
			cv.spent = true
		elif cv.def.has("uses"):
			cv.state = "%d / %d" % [int(fight.tweaks.get(ci, 0)), int(cv.def.uses)] if fight.tweaks.has(ci) else ""
		elif fight.ignited.has(ci):
			cv.state = "🔥 ALIGHT: -%d HP" % DiceFight.IGNITE_DMG

		elif fight.silenced.has(ci):
			cv.state = "SILENCED"
		elif not fight.has_target(ci):  # (Fan the Flames: no enemy is burning)
			cv.state = "NO BURN"
			cv.spent = true
		elif fight.hammered.has(ci):
			cv.state = "🔨 %d/%d" % [int(fight.hammered[ci]), DiceFight.HAMMER_BREAKS]
		cv.glow = ci == _aiming
		cv.accept = func(r: int, k: int) -> bool: return not _busy and _aiming < 0 and fight.can_place(r, ci, k)
		cv.slot_dropped.connect(_place)
		cv.slot_clicked.connect(func(c: int, k: int):
			if not _busy and _aiming < 0 and fight.placed.has(c):
				fight.take_back(c, k)  # (a die put back out of a two-slot card that isn't full yet)
				_refresh())
		_cards.add_child(cv)


func _place(ci: int, k: int, r: int) -> void:
	if _busy or _aiming >= 0 or not fight.can_place(r, ci, k):
		Audio.play("release_armour_block", -8.0)
		return
	Audio.play("elem_pickup", -4.0)
	if not fight.place(r, ci, k):
		if fight.events.any(func(ev): return String(ev.type) == "tweak"):  # (Hype Up / Calm Down: the die comes back changed)
			fight.events.clear()
			Audio.play("spell_glow", -6.0)
			_refresh()
			return
		if fight.events.any(func(ev): return String(ev.type) == "bounce"):
			fight.events.clear()  # (a face-down die that didn't fit: it is turned over and bounces off the card)
			for c in _cards.get_children():
				if c is DiceCardView and (c as DiceCardView).ci == ci:
					(c as DiceCardView).shake()
		_refresh()  # (or a two-slot card with one die in it: waiting for the second)
		return
	var ts := fight.targets_for(ci)
	if not bool(run.card_at(ci).get("target", false)):
		await _fire_at(-1, ci)
	elif ts.size() == 1:
		await _fire_at(ts[0], ci)
	else:
		_aiming = ci  # (ready: now its target)
		Audio.play("spell_glow", -6.0)
		_refresh()


## The ready card fires at enemy `i` (-1: it has no target).
func _fire_at(i: int, ci := -1) -> void:
	var c := ci if ci >= 0 else _aiming
	_aiming = -1
	fight.fire(c, i)
	_refresh()
	await _play_events()
	_refresh()
	_maybe_finish()


func _unhandled_input(ev: InputEvent) -> void:
	if _aiming < 0:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT) or ev.is_action_pressed("ui_cancel"):
		fight.cancel(_aiming)  # (put back: its dice go back to the tray)
		_aiming = -1
		Audio.play("ui_click", -6.0)
		_refresh()
		get_viewport().set_input_as_handled()


## The dice are thrown onto the stage from the left: they fly, bounce on the floor and tumble (their faces flicker while
## they roll fast), settle on what they rolled, then are gathered back into the tray, each to its place.
func _throw_dice() -> void:
	_busy = true
	_throwing = true
	_refresh()
	await get_tree().process_frame
	var tray := _tray.get_children()
	var flying: Array = []
	for k in tray.size():
		var fd := DiceDieView.new()
		fd.value = randi_range(1, 6)
		fd.z_index = 60
		fd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fd)
		fd.position = Vector2(-140.0 - k * 70.0, 520.0 - k * 50.0)
		flying.append({"n": fd, "v": Vector2(randf_range(1000.0, 1400.0), randf_range(-750.0, -450.0)),
			"w": randf_range(10.0, 18.0) * (1.0 if randf() < 0.5 else -1.0), "floor": 610.0 + k * 22.0,
			"final": int(fight.rolled[k].value) if k < fight.rolled.size() else 1,
			"paint": String(fight.rolled[k].paint) if k < fight.rolled.size() else "", "carve": String(fight.rolled[k].carve) if k < fight.rolled.size() else ""})
	Audio.play("wooden_ball_colide", -6.0, 1.4)
	var t := 0.0
	while t < 1.7:
		var dt := get_process_delta_time()
		t += dt
		for f in flying:
			var n: DiceDieView = f.n
			f.v.y += 2600.0 * dt
			n.position += f.v * dt
			n.rotation += f.w * dt
			if n.position.y >= f.floor and f.v.y > 0.0:
				n.position.y = f.floor
				if f.v.y > 260.0:
					Audio.play("wooden_ball_colide", -14.0, randf_range(1.5, 1.9))
				f.v.y = -f.v.y * 0.42 if f.v.y > 160.0 else 0.0
				f.v.x *= 0.72
				f.w *= 0.65
			if n.position.y >= f.floor - 1.0:
				f.v.x *= maxf(0.0, 1.0 - 2.2 * dt)  # (rolling to a stop)
				f.w *= maxf(0.0, 1.0 - 2.5 * dt)
			if n.position.x > 1700.0:
				n.position.x = 1700.0
				f.v.x = -absf(f.v.x) * 0.5
			if f.v.length() > 220.0 and randf() < 0.35:
				n.value = randi_range(1, 6)
				n.queue_redraw()
		await get_tree().process_frame
	for f in flying:
		var n: DiceDieView = f.n
		n.value = int(f.final)
		n.paint = String(f.paint)
		n.carve = String(f.carve)
		n.queue_redraw()
		n.create_tween().tween_property(n, "rotation", 0.0, 0.15)
	await get_tree().create_timer(0.45).timeout
	for k in flying.size():
		var n: DiceDieView = flying[k].n
		if k < tray.size():
			var tw := n.create_tween()
			tw.tween_property(n, "global_position", (tray[k] as Control).global_position, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(k * 0.06)
	await get_tree().create_timer(0.32 + flying.size() * 0.06 + 0.05).timeout
	for f in flying:
		(f.n as Node).queue_free()
	_throwing = false
	_busy = false
	_refresh()


func _on_end_turn() -> void:
	if _busy or fight.over:
		return
	_busy = true
	_refresh()
	fight.end_turn()
	await _play_events()
	_busy = false
	_refresh()
	if fight.over:
		_maybe_finish()
	else:
		await _throw_dice()  # (your new turn: a new throw)


func _maybe_finish() -> void:
	if fight.over:
		_busy = true
		_end_btn.disabled = true
		await get_tree().create_timer(0.8).timeout
		finished.emit(fight.won)


## Plays what happened (DiceFight.events), one beat each.
func _play_events() -> void:
	_busy = true
	var evs := fight.events.duplicate()
	fight.events.clear()
	for ev in evs:
		match String(ev.type):
			"hit":
				var nd: Dictionary = _foe_nodes[int(ev.foe)]
				(nd.creature as Creature).hit(0.4 + minf(1.0, int(ev.n) / 10.0))
				_float(_foe_center(int(ev.foe)), ("-%d" % int(ev.n)) + (("  (%d blocked)" % int(ev.blocked)) if int(ev.blocked) > 0 else ""), Color(1.0, 0.85, 0.4))
				Audio.play("chant_hit_fire", -4.0)
				_refresh_bars()
				await _wait(0.18)
			"dies":
				var cr: Creature = _foe_nodes[int(ev.foe)].creature
				PuppetShatter.spawn(self, cr)
				cr.visible = false
				await _wait(0.35)
			"block":
				_float(Vector2(190, 760), "+%d Shield" % int(ev.n), Color(0.6, 0.85, 1.0))
				Audio.play("sfx_shield_up", -4.0)
			"heal":
				_float(Vector2(190, 760), "+%d HP" % int(ev.n), Color(0.5, 1.0, 0.5))
			"stun":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -60), "Stunned!", Color(1.0, 0.9, 0.3))
				Audio.play("sfx_stun_apply", -4.0)
			"attack":
				await _lunge(int(ev.foe))
				_float(Vector2(190, 760), "-%d" % int(ev.n), Color(1.0, 0.35, 0.3))
				Audio.play("player_hurt", -2.0)
				_shake()
				_refresh_bars()
				await _wait(0.3)
			"foe_block":
				_float(_foe_center(int(ev.foe)), "+%d Block" % int(ev.n), Color(0.6, 0.85, 1.0))
				await _wait(0.3)
			"foe_heal":
				_float(_foe_center(int(ev.foe)), "+%d HP" % int(ev.n), Color(0.5, 1.0, 0.5))
				_refresh_bars()
				await _wait(0.3)
			"foe_power":
				_float(_foe_center(int(ev.foe)), "+%d Power" % int(ev.n), Color(1.0, 0.6, 0.3))
				await _wait(0.3)
			"debuff":
				_float(Vector2(190, 760), String(ev.what), Color(0.9, 0.6, 1.0))
				await _wait(0.3)
			"burn":
				_float(_foe_center(int(ev.foe)), "-%d Burn" % int(ev.n), Color(1.0, 0.55, 0.15))
				(_foe_nodes[int(ev.foe)].creature as Creature).hit(0.5)
				_refresh_bars()
				await _wait(0.5)
			"spawn":
				_add_foe_node(int(ev.foe))
				_layout_foes()
				var ncr: Creature = _foe_nodes[int(ev.foe)].creature
				ncr.modulate.a = 0.0
				ncr.create_tween().tween_property(ncr, "modulate:a", 1.0, 0.4)
				Audio.play("enemy_spawn", -4.0)
				_refresh()
				await _wait(0.45)
			"phase2":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -80), "Second phase!", Color(1.0, 0.5, 0.4))
				await _wait(0.4)
			"interrupted":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -160), "%s interrupted!" % String(ev.name), Color(0.7, 1.0, 0.7))
				await _wait(0.25)
			"bounce_spell":
				pass
			"casts":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -120), String(ev.name) + "!", Color(0.85, 0.75, 1.0))
				Audio.play("spell_glow", -4.0)
				await _wait(0.45)
			"ignite_burns":
				_float(Vector2(190, 760), "-%d Alight" % int(ev.n), Color(1.0, 0.55, 0.15))
				_refresh_bars()
				await _wait(0.25)
			"foe_cleansed":
				_float(_foe_center(int(ev.foe)), "Cleansed", Color(0.9, 1.0, 0.85))
				await _wait(0.3)
			"foe_rests":
				_float(_foe_center(int(ev.foe)), "Recharging…", Color(0.8, 0.8, 0.9))
				await _wait(0.3)
			"foe_deflect":
				_float(_foe_center(int(ev.foe)), "Ready to deflect", Color(0.9, 0.9, 1.0))
				await _wait(0.3)
			"deflected":
				_float(_foe_center(int(ev.foe)), "Deflected!", Color(1.0, 0.9, 0.6))
				_float(Vector2(190, 760), "-%d" % int(ev.n), Color(1.0, 0.35, 0.3))
				Audio.play("sword_clang", -2.0)
				_shake()
				_refresh_bars()
				await _wait(0.35)
			"foe_clock":
				_float(_foe_center(int(ev.foe)), "⏰ %d" % int(ev.n), Color(1.0, 0.85, 0.4))
				await _wait(0.25)
			"page_turn":
				await _page_turn(int(ev.foe))
			"piece_ends":
				_float(Vector2(960, 500), "The piece ends.", Color(1.0, 0.6, 0.6))
				await _wait(1.0)
			"card_back":
				_float(Vector2(960, 700), "%s is back!" % run.card_at(int(ev.ci)).name, Color(0.7, 1.0, 0.7))
				await _wait(0.3)
			"extra_dice":
				_float(Vector2(960, 700), "+%d dice" % int(ev.n), Color(1.0, 0.9, 0.6))
				await _wait(0.2)
			"revenge_set":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -50), "Marked for revenge", Color(1.0, 0.5, 0.4))
				await _wait(0.2)
			"revenge":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -80), "Revenge! %d" % int(ev.n), Color(1.0, 0.5, 0.4))
				await _wait(0.2)
			"you_ethereal":
				_float(Vector2(190, 760), "Ethereal", Color(0.8, 0.8, 1.0))
				await _wait(0.2)
			"foe_vulnerable":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -50), "Vulnerable", Color(1.0, 0.55, 0.45))
				await _wait(0.2)
			"foe_redirect":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -50), "Redirected", Color(0.9, 0.9, 1.0))
				await _wait(0.2)
			"redirected":
				await _lunge(int(ev.foe))
				(_foe_nodes[int(ev.to)].creature as Creature).hit(0.7)
				_float(_foe_center(int(ev.to)), "-%d" % int(ev.n), Color(1.0, 0.85, 0.4))
				_refresh_bars()
				await _wait(0.3)
			"flurry":
				_float(Vector2(960, 660), "Flurry: +%d to every hit this turn" % int(ev.n), Color(1.0, 0.8, 0.4))
				await _wait(0.2)
			"buff":  # (Fire Fist, Overwhelm, Smite, Taunt: what is on for the turn)
				_float(Vector2(960, 660), String(ev.what), Color(1.0, 0.8, 0.4))
				await _wait(0.2)
			"foe_burn_out":  # (Ignite: its Burn goes up all at once)
				_float(_foe_center(int(ev.foe)) + Vector2(0, -50), "Burn %d: ignited!" % int(ev.n), Color(1.0, 0.55, 0.15))
				Audio.play("sfx_burn_apply", -2.0)
				_refresh_bars()
				await _wait(0.25)
			"self_hit":
				_float(Vector2(190, 760), "-%d" % int(ev.n), Color(1.0, 0.35, 0.3))
				_refresh_bars()
				await _wait(0.2)
			"foe_burn":
				_float(_foe_center(int(ev.foe)), "+%d Burn" % int(ev.n), Color(1.0, 0.55, 0.15))
				Audio.play("sfx_burn_apply", -4.0)
				await _wait(0.25)
			"foe_weak":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -50), "Weakened", Color(0.8, 0.65, 1.0))
				await _wait(0.2)
			"foe_stunned":
				_float(_foe_center(int(ev.foe)), "Stunned: skips its turn", Color(1.0, 0.9, 0.3))
				await _wait(0.5)
			"you_burn":
				_float(Vector2(190, 760), "-%d Burn" % int(ev.n), Color(1.0, 0.55, 0.15))
				_refresh_bars()
				await _wait(0.4)
			"thorns":
				_float(Vector2(190, 760), "-%d Thorns" % int(ev.n), Color(0.75, 0.85, 0.4))
				_refresh_bars()
				await _wait(0.25)
			"foe_thorns":
				_float(_foe_center(int(ev.foe)), "+%d Thorns" % int(ev.n), Color(0.75, 0.85, 0.4))
				await _wait(0.3)
			"foe_ethereal":
				_float(_foe_center(int(ev.foe)), "Ethereal", Color(0.8, 0.8, 1.0))
				await _wait(0.3)
			"immune":
				_float(_foe_center(int(ev.foe)), "%s: no effect" % String(ev.get("why", "Ethereal")), Color(0.8, 0.8, 1.0))
				await _wait(0.2)
			"you_stunned":
				_float(Vector2(960, 600), "You are Stunned: your turn is skipped", Color(1.0, 0.9, 0.3))
				await _wait(0.8)
			"extra_die":
				_float(Vector2(960, 700), "⚄ One more die!", Color(1.0, 0.9, 0.6))
				await _wait(0.3)
			"dodge_up":
				_float(Vector2(190, 760), "+1 Dodge", Color(0.75, 0.9, 1.0))
				await _wait(0.2)
			"dodged":
				await _lunge(int(ev.foe))
				_float(Vector2(190, 760), "Dodged!", Color(0.75, 0.9, 1.0))
				await _wait(0.25)
			"skull":
				_float(Vector2(960, 660), "☠ Double damage this turn!", Color(1.0, 0.45, 0.4))
				await _wait(0.3)
			"guard":
				_float(Vector2(960, 620), "🛡 Double Shield this turn!", Color(0.6, 0.85, 1.0))
				await _wait(0.3)
			"gold":
				_float(Vector2(190, 1010), "+%d coins" % int(ev.n), Color(1.0, 0.9, 0.35))
			"reroll":
				pass
			"roll":
				Audio.play("elem_pickup", -6.0)
	_busy = false


func _refresh_bars() -> void:
	for nd in _foe_nodes:
		(nd.bar as Control).queue_redraw()
	_hp_bar.queue_redraw()
	_hp_label.text = "❤ %d / %d" % [run.hp, run.max_hp]


func _foe_center(i: int) -> Vector2:
	var cr: Creature = _foe_nodes[i].creature
	return cr.position + cr.size * Vector2(0.5, 0.4)


func _lunge(i: int) -> void:
	var cr: Creature = _foe_nodes[i].creature
	var home := cr.position
	var tw := create_tween()
	tw.tween_property(cr, "position", home + Vector2(0, 40), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(cr, "position", home, 0.18)
	await tw.finished


func _shake() -> void:
	var tw := create_tween()
	for k in 6:
		tw.tween_property(self, "position", Vector2(randf_range(-8, 8), randf_range(-6, 6)), 0.035)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _float(at: Vector2, text: String, col: Color) -> void:
	var l := UiTheme.label(text, 30, col)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	l.position = at - Vector2(60, 20)
	l.z_index = 50
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## The Pianist: his piece starts with the fight and plays in real time (PianistSong, as in the chant game). When it
## ends before he does, The End: the fight is lost.
var _song: PianistSong
const PIANIST_LEAD_IN := 2.0


func _pianist_start() -> void:
	for i in fight.foes.size():
		var f: DiceFight.Foe = fight.foes[i]
		if f.id != "pianist":
			continue
		Audio.stop_music()  # (no boss music: he is the music)
		_song = PianistSong.make("turkish_march")
		add_child(_song)
		_song.ended.connect(func():
			fight.piece_ended()
			await _play_events()
			_refresh()
			_maybe_finish())
		var cr: Creature = _foe_nodes[i].creature
		cr.song = _song
		cr.pianist_warm_up()
		await get_tree().create_timer(PIANIST_LEAD_IN).timeout
		if is_instance_valid(_song) and not fight.over:
			_song.play()
		return


## He turns the page: the music stops, he points at the sign (a knock each time), the page swings over, the piece
## goes on. His HP is full again: the next page.
func _page_turn(i: int) -> void:
	var cr: Creature = _foe_nodes[i].creature
	if is_instance_valid(_song):
		_song.pause()
	var total: float = cr.pianist_point()
	var spent := 0.0
	for kt in PianistBackRig.KNOCKS:
		await get_tree().create_timer(float(kt) - spent).timeout
		spent = float(kt)
		Audio.play("sfx_knock_wood")
	await get_tree().create_timer(maxf(0.0, total - spent)).timeout
	Audio.play("page_flip")
	var tw := create_tween()
	tw.tween_property(cr, "page_flip", 1.0, 1.1).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	cr.page_flip = -1.0
	_refresh_bars()
	if is_instance_valid(_song) and not fight.over:
		_song.resume()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
