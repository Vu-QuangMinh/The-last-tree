class_name MarblesFightView
extends StageView
## Marble mode (2026-11-21): the fight screen. The stage, the enemies, their intents and bars are Die on Stage's
## (StageView); the bottom is the main mode's (FightScreen's Puppet strips, PuppetLayout): the spell cards in a row
## (SpellCard, through MarbleCardView) standing on the Chant strip (its ten rings, Chant / Clear / Pass), the Bag strip
## under it with this turn's marbles (click one to put it in the chant, click a chant marble to take it back) and the
## slot machine at its right end (it spins the new marbles out at the start of each turn). Your HP, bottles and
## artifacts sit at the left as in the main mode. An intent with orb HP shows its marbles over it: chant them to stop it.

const RING_PX := 52.0  # (FightScreen.PUPPET_RING_PX)
const CHANT_RINGS := 10  # (FightScreen.CHANT_RINGS_PUPPET)
const SPELL_ROW_FITS := 8  # (FightScreen: the cards are sized so this many fit in a row)
const SPELL_GAP := 12.0

var mfight: MarblesFight
var _hand_row: Control
var _chant_row: HBoxContainer
var _chant_btn: Button
var _clear_btn: Button
var _pass_btn: Button
var _chant_panel: PanelContainer
var _bag_panel: PanelContainer
var _machine: SlotMachine
var _bottle_row: HBoxContainer
var _art_row: HBoxContainer
var _info: Label
var _ready_done := false
var _fit := 1.0
var _fx: Control  # (the main mode's spell effects play on it, over everything)
var _card_from := {}  # card index -> its centre, taken just before it is cast (the row is rebuilt right after)
var _lit := {}  # card index -> how many of its pattern orbs the chant has lit


func setup(p_run: MarblesRun, ids: Array) -> void:
	run = p_run
	mfight = MarblesFight.new()
	fight = mfight
	mfight.setup(run, ids)


func _ready() -> void:
	super._ready()
	# Die on Stage's bottom (its dark panel, the dice hint, End turn) gives way to the main mode's
	for c in get_children():
		if c is Panel and (c as Panel).position.y >= 790.0:
			(c as Panel).visible = false
		elif c is Label and String((c as Label).text).begins_with("Drag dice"):
			(c as Label).visible = false
		elif c is Label and String((c as Label).text).begins_with("🪙"):
			(c as Label).position = Vector2(PuppetLayout.HP_BAR.position.x, 1010)
	_end_btn.visible = false
	var hb: Rect2 = PuppetLayout.HP_BAR
	_hp_bar.position = hb.position
	_hp_bar.size = hb.size
	_hp_label.position = Vector2(hb.position.x, hb.end.y + 6.0)
	_hp_label.add_theme_font_size_override("font_size", 22)
	_status_label.position = Vector2(hb.position.x, hb.position.y - 126.0)
	_status_label.size = Vector2(hb.size.x, 120.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	_build_strips()
	# the spell cards: FightScreen's row, centred, its right end no further than the Chant strip's
	_cards.scale = Vector2.ONE
	_cards.pivot_offset = Vector2.ZERO
	_cards.position = Vector2.ZERO
	_cards.size = Vector2(1920, SpellCard.H)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", roundi(SPELL_GAP))
	var row_w := 2.0 * (PuppetLayout.BAG_AT.x + PuppetLayout.FRAME_CHANT.x - 960.0)
	_fit = minf(1.0, (row_w - SPELL_GAP * (SPELL_ROW_FITS - 1)) / (SPELL_ROW_FITS * SpellCard.W))
	_fit = floorf(SpellCard.W * _fit) / SpellCard.W
	_cards.position.y = _chant_panel.position.y - 5.0 - SpellCard.H * _fit
	_bottle_row = HBoxContainer.new()
	_bottle_row.position = PuppetLayout.BOTTLES.position + Vector2(8, 17)
	_bottle_row.add_theme_constant_override("separation", 8)
	add_child(_bottle_row)
	_art_row = HBoxContainer.new()
	_art_row.position = PuppetLayout.ARTIFACTS.position + Vector2(PuppetLayout.ART_X0, (PuppetLayout.ARTIFACTS.size.y - PuppetLayout.ART_PX) / 2.0)
	_art_row.add_theme_constant_override("separation", int(PuppetLayout.ART_STEP - PuppetLayout.ART_PX))
	add_child(_art_row)
	_build_artifacts()
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = PuppetStage.CEILING_Z + 30
	add_child(_fx)
	# the main mode's drag: a chant marble dropped back on the Bag strip comes out of the chant
	_hand_row.set_drag_forwarding(Callable(), _can_drop_marble.bind("hand", -1), _drop_marble.bind("hand", -1))
	_ready_done = true
	_refresh()
	_throw_dice()


## FightScreen._build_strips_puppet, for marbles: the Chant strip (the frame art has the ten rings) with its buttons, the
## Bag strip under it, and the slot machine at the Bag strip's right end.
func _build_strips() -> void:
	var cap := PuppetLayout.CAP
	var margins := [int(cap.x), 0, int(cap.y), 0]
	var bag_at: Vector2 = PuppetLayout.BAG_AT
	_chant_panel = PanelContainer.new()
	var chant_box: StyleBox = UiSkin.box("chant_frame", margins)
	if chant_box == null:
		chant_box = _plain_strip()
	_chant_panel.add_theme_stylebox_override("panel", chant_box)
	_chant_panel.position = bag_at + PuppetLayout.CHANT_AT
	_chant_panel.custom_minimum_size = PuppetLayout.FRAME_CHANT
	var cin := Control.new()
	cin.custom_minimum_size = PuppetLayout.FRAME_CHANT
	cin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chant_panel.add_child(cin)
	_info = UiTheme.label("", 16, Color(0.95, 0.9, 0.8))  # (the bag's count: in the left column, under your HP, clear of the cards)
	_info.position = Vector2(PuppetLayout.HP_BAR.position.x, 958)
	_info.size = Vector2(PuppetLayout.BOTTLES.position.x - PuppetLayout.HP_BAR.position.x - 10.0, 50)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_constant_override("outline_size", 5)
	_info.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	add_child(_info)
	_chant_row = HBoxContainer.new()
	_chant_row.add_theme_constant_override("separation", int(PuppetLayout.RING_STEP - RING_PX))
	_chant_row.position = Vector2(PuppetLayout.RING_X0 + 26.0 - RING_PX / 2.0, PuppetLayout.RING_CY - RING_PX / 2.0)
	cin.add_child(_chant_row)
	_chant_btn = UiTheme.button("Chant", _on_chant, 15)
	UiTheme.use_heading_font(_chant_btn)
	_place_rect(_chant_btn, PuppetLayout.BTN_CHANT)
	UiTheme.style_puppet_button(_chant_btn, "chant", 18)
	_chant_btn.tooltip_text = "Chant (Enter): the marbles in the chant wake the cards whose pattern they make (order counts, %d at most)." % MarblesFight.MAX_CHANT
	cin.add_child(_chant_btn)
	_clear_btn = UiTheme.button("Clear", _clear_chant, 13)
	UiTheme.use_heading_font(_clear_btn)
	_place_rect(_clear_btn, PuppetLayout.BTN_CLEAR)
	UiTheme.style_puppet_button(_clear_btn, "clear", 14)
	_clear_btn.tooltip_text = "Take every marble back out of the chant (Backspace)."
	cin.add_child(_clear_btn)
	_pass_btn = UiTheme.button("Pass", _on_end_turn, 13)
	UiTheme.use_heading_font(_pass_btn)
	_place_rect(_pass_btn, PuppetLayout.BTN_PASS)
	UiTheme.style_puppet_button(_pass_btn, "pass", 14)
	_pass_btn.tooltip_text = "End your turn (E)."
	cin.add_child(_pass_btn)
	add_child(_chant_panel)
	_bag_panel = PanelContainer.new()
	var bag_box: StyleBox = UiSkin.box("bag_frame", margins)
	if bag_box == null:
		bag_box = _plain_strip()
	_bag_panel.add_theme_stylebox_override("panel", bag_box)
	_bag_panel.position = bag_at
	_bag_panel.custom_minimum_size = PuppetLayout.FRAME_BAG
	var inner := Control.new()
	inner.custom_minimum_size = PuppetLayout.FRAME_BAG
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_panel.add_child(inner)
	if SlotMachine.available():
		_machine = SlotMachine.new()
		_machine.build()
		_machine.behind.show_behind_parent = true  # (the tube comes out from under the Bag strip)
		_bag_panel.add_child(_machine.behind)
		_bag_panel.move_child(_machine.behind, 0)
		inner.add_child(_machine.back)
	_hand_row = Control.new()
	_hand_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_hand_row.size = Vector2(PuppetLayout.REST_END, PuppetLayout.FRAME_BAG.y)
	inner.add_child(_hand_row)
	if _machine != null:
		inner.add_child(_machine.front)
	add_child(_bag_panel)


static func _plain_strip() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.07, 0.04, 0.95)
	sb.border_color = Color(0.45, 0.3, 0.15)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(30)
	return sb


static func _place_rect(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.custom_minimum_size = r.size
	c.size = r.size


## A new turn: the lever is pulled and the reels spin out the first of the new marbles, then they show in the Bag strip.
func _throw_dice() -> void:
	if not _ready_done:
		return
	if _machine == null or fight.over:
		_refresh()
		return
	_busy = true
	_hand_row.modulate.a = 0.0
	_refresh()
	var faces := []
	for m in mfight.hand:
		if faces.size() < 3:
			faces.append("hidden" if bool(m.get("hidden", false)) else String(m.get("c", "")))
	_machine.lever_pull()
	await _machine.spin(faces, 0.9)
	if not is_inside_tree():
		return
	_machine.lever_return()
	_hand_row.create_tween().tween_property(_hand_row, "modulate:a", 1.0, 0.2)
	_busy = false
	_refresh()


func _clear_chant() -> void:
	if _busy or _aiming >= 0 or mfight.chanted:
		return
	var any := false
	while not mfight.chant.is_empty() and mfight.take(0):
		any = true
	if any:
		Audio.play("ui_click", -6.0)
	_refresh()


func _refresh() -> void:
	super._refresh()
	if not _ready_done:
		return
	for i in fight.foes.size():
		var f: StageFight.Foe = fight.foes[i]
		var nd: Dictionary = _foe_nodes[i]
		var more := []
		if f.expose > 0:
			more.append("Expose %d" % f.expose)
		if f.armor > 0:
			more.append("Armor %d" % f.armor)
		if f.id in MarblesFight.MARBLE_FLYERS and f.es.flying:
			more.append("🪽 Flying: hits do 1 (%d/%d to knock it down)" % [f.fly_hits, StageFight.FLY_HITS])
		if not more.is_empty():
			nd.status.text = String(nd.status.text) + ("  " if String(nd.status.text) != "" else "") + "  ".join(more)
	var you := []
	if mfight.power_now() > 0:
		you.append("💪 Power %d" % mfight.power_now())
	if mfight.my_thorns > 0:
		you.append("🌵 Thorns %d" % mfight.my_thorns)
	for id in mfight.powers:
		you.append("✦ " + String(MarbleCards.card(id, int(mfight.powers[id])).name))
	if mfight.dmg_ops.size() + mfight.shield_ops.size() > 0:
		you.append("Carvings on: %d" % (mfight.dmg_ops.size() + mfight.shield_ops.size()))
	if you.size() > 0:
		_status_label.text = (_status_label.text + "\n" if _status_label.text != "" else "") + "\n".join(you)
	_build_bottles()
	_chant_btn.disabled = _busy or fight.over or mfight.chanted or mfight.chant.is_empty()
	_clear_btn.disabled = _busy or fight.over or mfight.chanted or mfight.chant.is_empty()
	_pass_btn.disabled = _busy or fight.over
	if _aiming >= 100:
		_prompt.text = "%s: choose a target   ·   right-click to put it back" % String(MarbleItems.bottle(String(mfight.mrun.bottles[_aiming - 100])).get("name", "Bottle")) if _aiming - 100 < mfight.mrun.bottles.size() else ""
	_info.text = "Bag: %d marbles  ·  used: %d" % [mfight.draw_pile.size(), mfight.used_pile.size()]


## Your marbles (resting in the Bag strip, as the main mode's Essence do) and the chant (in the Chant strip's rings).
func _build_tray() -> void:
	if not _ready_done:
		return
	for c in _hand_row.get_children():
		c.queue_free()
	for c in _chant_row.get_children():
		c.queue_free()
	var n := mfight.hand.size()
	var step := PuppetLayout.REST_STEP
	if n > 1:
		step = minf(step, (PuppetLayout.REST_END - PuppetLayout.REST_X - RING_PX) / float(n - 1))  # (more than fit: they squeeze together)
	for h in n:
		var mv := MarbleView.make(mfight.hand[h], RING_PX)
		mv.position = Vector2(PuppetLayout.REST_X + h * step, PuppetLayout.AXIS_Y - RING_PX / 2.0)
		mv.hot = not mfight.chanted and not bool(mfight.hand[h].get("frozen", false)) and mfight.chant.size() < MarblesFight.MAX_CHANT and not _busy
		var hh := h
		mv.pressed.connect(func():
			if _busy or _aiming >= 0 or not mfight.put(hh):
				return
			Audio.play("elem_pickup", -4.0)
			_refresh())
		mv.set_drag_forwarding(_drag_marble.bind("hand", h, mv), _can_drop_marble.bind("hand", -1), _drop_marble.bind("hand", -1))
		if mfight.chanted:
			mv.modulate = Color(1, 1, 1, 0.45)  # (left out of this chant: used at the end of the turn)
		_hand_row.add_child(mv)
	# the main mode's ten ring sockets (FightScreen: "chant_slot_empty"); the ones past MAX_CHANT are dimmed (Infuse can fill them)
	var slot_art: StyleBox = UiSkin.box("chant_slot_empty")
	for k in maxi(CHANT_RINGS, mfight.chant.size()):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(RING_PX, RING_PX)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.set_drag_forwarding(Callable(), _can_drop_marble.bind("chant", k), _drop_marble.bind("chant", k))
		if slot_art != null:
			slot.add_theme_stylebox_override("panel", slot_art)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.35)
			sb.border_color = Color(0.4, 0.5, 0.4, 0.8)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(int(RING_PX / 2.0))
			slot.add_theme_stylebox_override("panel", sb)
		if k >= MarblesFight.MAX_CHANT and k >= mfight.chant.size():
			slot.self_modulate = Color(1, 1, 1, 0.35)
		_chant_row.add_child(slot)
		if k >= mfight.chant.size():
			continue
		var m: Dictionary = (mfight.chant[k] as Dictionary).duplicate()
		m.hidden = false  # (in the chant you see it)
		var mv := MarbleView.make(m, RING_PX)
		mv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var kk := k
		mv.pressed.connect(func():
			if _busy or _aiming >= 0 or not mfight.take(kk):
				return
			Audio.play("ui_click", -6.0)
			_refresh())
		mv.set_drag_forwarding(_drag_marble.bind("chant", k, mv), _can_drop_marble.bind("chant", k), _drop_marble.bind("chant", k))
		slot.add_child(mv)


## The main mode's drag and drop: pick a marble up from the Bag strip or the chant and drop it on a ring (in the chant,
## at that place; the others move along) or back on the Bag strip.
func _drag_marble(_at: Vector2, from: String, i: int, mv: MarbleView) -> Variant:
	if _busy or _aiming >= 0 or mfight.chanted:
		return null
	var src: Array = mfight.hand if from == "hand" else mfight.chant
	if i >= src.size() or bool(src[i].get("frozen", false)):
		return null
	var m: Dictionary = (src[i] as Dictionary).duplicate()
	if from == "chant":
		m.hidden = false
	var pv := Control.new()
	var ball := MarbleView.make(m, RING_PX * 1.15)
	ball.position = -ball.size / 2.0
	ball.modulate.a = 0.9
	pv.add_child(ball)
	mv.set_drag_preview(pv)
	mv.modulate.a = 0.35  # (its place stays, faded, while it is in the air)
	Audio.play("elem_pickup", -8.0)
	return {"marble_from": from, "i": i}


func _can_drop_marble(_at: Vector2, data: Variant, to: String, _k: int) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("marble_from") or _busy or mfight.chanted:
		return false
	var from := String(data.marble_from)
	if to == "hand":
		return from == "chant"
	return from == "chant" or mfight.chant.size() < MarblesFight.MAX_CHANT


func _drop_marble(_at: Vector2, data: Variant, to: String, k: int) -> void:
	var d: Dictionary = data
	var from := String(d.marble_from)
	var i := int(d.i)
	var ok := false
	if to == "hand":
		ok = mfight.take(i)
	elif from == "hand":
		ok = mfight.put_at(i, k)
	else:
		ok = mfight.move_chant(i, k)
	if ok:
		Audio.play("elem_pickup" if to == "chant" else "ui_click", -4.0)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _ready_done and not get_viewport().gui_is_drag_successful():
		_refresh()  # (dropped nowhere: it goes back where it was)


## The cards: the main mode's SpellCard (MarbleCardView), FightScreen's size and gap, standing on the Chant strip.
func _build_cards() -> void:
	if not _ready_done:
		return
	for c in _cards.get_children():
		_cards.remove_child(c)  # (at once: old and new holders side by side would widen the centred row)
		c.queue_free()
	for ci in run.cards.size():
		var cv := MarbleCardView.new()
		cv.card = mfight.card(ci)
		var n := int(mfight.charges.get(ci, 0))
		cv.charges = n
		cv.glow = ci == _aiming
		cv.dim = mfight.chanted and n <= 0
		if int(fight.hammered.get(ci, 0)) >= StageFight.HAMMER_BREAKS or mfight.durability_left(ci) == 0:
			cv.state = "broken"
		elif fight.cocooned.has(ci):
			cv.state = "cooldown"
			cv.state_text = "IN A COCOON"
		elif mfight.power_used.has(ci):
			cv.state = "used"
		elif fight.silenced.has(ci):
			cv.state = "silenced"
			cv.state_text = "SILENCED"
		elif fight.cooldown.has(ci):
			cv.state = "cooldown"
			cv.state_text = "COOLDOWN %d" % (int(fight.cooldown[ci]) - 1)
		var bits := []
		if fight.ignited.has(ci):
			bits.append("Alight: casting it costs %d HP" % StageFight.IGNITE_DMG)
		if mfight.grow.has(ci):
			bits.append("Now: %d" % int(mfight.grow[ci]))
		if mfight.charge.has(ci):
			bits.append("Charges: %d" % int(mfight.charge[ci]))
		if cv.card.p.has("dur"):
			bits.append("Durability %d left" % mfight.durability_left(ci))
		cv.extra = "   ".join(bits)
		cv.scale = Vector2(_fit, _fit)
		var c2 := ci
		cv.pressed.connect(func(): _card_clicked(c2))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(MarbleCardView.W, MarbleCardView.H) * _fit
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cv)
		_cards.add_child(holder)
	_light_patterns()


## FightScreen._light_patterns: while you build the chant, every card lights the orbs of its pattern that the chant is
## building towards, in order, as each marble goes in (a Star counts as any colour); a full match lights them all, and
## the card's preview says how many times this chant would wake it. Taking marbles back dims them again.
func _light_patterns() -> void:
	var holders := _cards.get_children()
	for ci in holders.size():
		if (holders[ci] as Control).get_child_count() == 0:
			continue
		var cv := (holders[ci] as Control).get_child(0) as MarbleCardView
		if cv == null or cv.spell_card == null:
			continue
		var sc := cv.spell_card
		var orbs: Array = sc.live_orbs()
		var pattern := String(cv.card.get("pattern", ""))
		var live := not mfight.chanted and cv.state == "" and pattern != ""
		var k := mini(mfight.progress(pattern), orbs.size()) if live else 0
		var before := int(_lit.get(ci, 0))
		for j in orbs.size():
			var o: ElementIcon = orbs[j]
			o.highlight = j < k
			o.queue_redraw()
		for j in range(before, k):
			_pop_orb(orbs[j])
		_lit[ci] = k
		var f := mfight.occurrences(pattern) if live else 0
		if sc.fires != f:
			sc.fires = f
			sc.refresh()


## A small pop as an orb lights up (FightScreen._pop_orb).
func _pop_orb(ic: Control) -> void:
	if not is_instance_valid(ic):
		return
	ic.pivot_offset = ic.size / 2.0
	var tw := ic.create_tween()
	tw.tween_property(ic, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color(1.8, 1.75, 1.5), 0.07)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color.WHITE, 0.2)


## Your artifacts, in the main mode's artifact row (a faint outline each, the icon in it; hover: what it does).
func _build_artifacts() -> void:
	for c in _art_row.get_children():
		c.queue_free()
	for id in mfight.mrun.artifacts:
		var it := MarbleItems.artifact(String(id))
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(PuppetLayout.ART_PX, PuppetLayout.ART_PX)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(1, 1, 1, 0.18)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		slot.tooltip_text = "%s: %s" % [it.get("name", id), it.get("text", "")]
		var ic := UiTheme.label(String(it.get("icon", "✦")), 28, Color.WHITE)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)
		_art_row.add_child(slot)


func _card_clicked(ci: int) -> void:
	if _busy or not mfight.can_cast(ci):
		if not mfight.chanted:
			_float(Vector2(960, 650), "Chant first", Color(1.0, 0.85, 0.5))
		return
	if not mfight.needs_target(ci):
		await _fire_at(-1, ci)
		return
	var ts := mfight.targets(ci)
	if ts.is_empty():
		_float(Vector2(960, 650), "No target", Color(1.0, 0.7, 0.6))
	elif ts.size() == 1:
		await _fire_at(ts[0], ci)
	else:
		_aiming = ci
		Audio.play("spell_glow", -6.0)
		_refresh()


func _on_chant() -> void:
	if _busy or mfight.chanted or mfight.chant.is_empty():
		return
	Audio.play("spell_glow", -2.0)
	mfight.do_chant()
	await _play_events()
	_refresh()


func _targets_for(ci: int) -> Array:
	return mfight.targets(ci)


## A card (or a bottle: _aiming 100 + its slot) goes off at enemy `i` (-1: no target).
func _fire_at(i: int, ci := -1) -> void:
	var c := ci if ci >= 0 else _aiming
	_aiming = -1
	_card_from.clear()
	# (worked out from the row's layout: a row rebuilt this very frame isn't placed yet)
	var n := _cards.get_child_count()
	var w := MarbleCardView.W * _fit
	var x0 := _cards.position.x + (_cards.size.x - (n * w + maxf(0.0, n - 1.0) * SPELL_GAP)) / 2.0
	for h in n:
		_card_from[h] = Vector2(x0 + h * (w + SPELL_GAP) + w / 2.0, _cards.position.y + MarbleCardView.H * _fit / 2.0)
	if c >= 100:
		mfight.use_bottle(c - 100, i)
	else:
		mfight.cast(c, i)
	_busy = true
	_build_cards()  # (the card dims at once; the enemy's bar waits for the blow to land: no full refresh yet)
	await _play_events()
	_refresh()
	if mfight.pending_replace >= 0:
		_ask_replace()
	_maybe_finish()


func _unhandled_input(ev: InputEvent) -> void:
	if _aiming < 0:
		# the main mode's keys: Enter chants, Backspace clears the chant, E ends the turn
		if ev is InputEventKey and ev.pressed and not ev.echo and _ready_done:
			match (ev as InputEventKey).keycode:
				KEY_ENTER, KEY_KP_ENTER:
					_on_chant()
					get_viewport().set_input_as_handled()
				KEY_BACKSPACE:
					_clear_chant()
					get_viewport().set_input_as_handled()
				KEY_E:
					_on_end_turn()
					get_viewport().set_input_as_handled()
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT) or ev.is_action_pressed("ui_cancel"):
		_aiming = -1
		Audio.play("ui_click", -6.0)
		_refresh()
		get_viewport().set_input_as_handled()


func _build_bottles() -> void:
	for c in _bottle_row.get_children():
		c.queue_free()
	for b in mfight.mrun.bottles.size():
		var it := MarbleItems.bottle(String(mfight.mrun.bottles[b]))
		var btn := UiTheme.button(String(it.get("icon", "🍶")), func(): _bottle_clicked(b), 22)
		btn.tooltip_text = "%s: %s" % [it.get("name", ""), it.get("text", "")]
		btn.custom_minimum_size = Vector2(56, 50)
		btn.disabled = _busy or fight.over
		_bottle_row.add_child(btn)


func _bottle_clicked(b: int) -> void:
	if _busy or b >= mfight.mrun.bottles.size():
		return
	var it := MarbleItems.bottle(String(mfight.mrun.bottles[b]))
	if not bool(it.get("t", false)):
		await _fire_at(-1, 100 + b)
		return
	var ts := mfight.targets(-1)
	if ts.size() == 1:
		await _fire_at(ts[0], 100 + b)
	else:
		_aiming = 100 + b
		_refresh()


## Orb HP over an intent: the marbles to chant to stop it (the Matron's summoning, the Wizard's spells, a Charge).
func _build_spells(i: int) -> void:
	var f: StageFight.Foe = fight.foes[i]
	var row: HBoxContainer = _foe_nodes[i].spells
	for c in row.get_children():
		c.queue_free()
	if f.dead() or f.spells.is_empty():
		return
	var w := 0.0
	for sp in f.spells:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_END
		var nm := UiTheme.label(String(sp.get("name", "")) + ((" (%d)" % StageFight.charge_left(sp)) if sp.get("charge", false) else ""), 16, Color(1.0, 0.9, 0.7))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_constant_override("outline_size", 5)
		nm.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
		nm.tooltip_text = String(sp.get("text", "")) + "  Chant these marbles to stop it."
		nm.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(nm)
		var orbs := HBoxContainer.new()
		orbs.alignment = BoxContainer.ALIGNMENT_CENTER
		orbs.add_theme_constant_override("separation", 3)
		for ch in String(sp.get("orbs", "")):
			var mv := MarbleView.make({"c": ch}, 28.0)
			mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			orbs.add_child(mv)
		box.add_child(orbs)
		row.add_child(box)
		w += maxf(120.0, String(sp.get("orbs", "")).length() * 31.0) + 10.0
	row.size = Vector2(w, SPELL_H)
	row.position.x = _slot_x(i) + FOE_W / 2.0 - w / 2.0


## Marble mode's own beats (cast, double cast, Expose...), in turn with the stage's (StageView._play_events).
func _own_event(ev: Dictionary) -> bool:
	match String(ev.type):
		"cast":
			_float(Vector2(960, 640), String(ev.name), Color(1.0, 0.9, 0.5))
			await _cast_fx(ev)
			return true
	_float_own(ev)
	return false


## The main mode's spell effect for a cast card (SpellFx: a bolt, flames, ice, a shield dome...) from the card to
## where it goes; its blow lands as the effect arrives.
func _cast_fx(ev: Dictionary) -> void:
	var fx: Dictionary = ev.get("fx", {})
	if fx.is_empty() or _fx == null:
		return
	var ci := int(ev.ci)
	var from: Vector2 = _card_from.get(ci, Vector2(960.0, _cards.position.y + SpellCard.H * _fit / 2.0))
	var col := GameData.spell_color(String(mfight.card(ci).get("pattern", ""))).lightened(0.2)
	var you := _you_area()
	var dests := []
	match String(fx.get("to", "foe")):
		"you":
			dests.append(you)
		"all":
			for i in _foe_nodes.size():
				if (_foe_nodes[i].creature as Creature).visible:
					dests.append(_foe_dest(i))
		_:
			var t := int(ev.get("target", -1))
			if t < 0 or t >= _foe_nodes.size():
				var ts := mfight.targets(ci)
				t = int(ts[0]) if not ts.is_empty() else -1
			if t >= 0 and t < _foe_nodes.size():
				dests.append(_foe_dest(t))
	if dests.is_empty():
		return
	var op := String(fx.op)
	var wait := SpellFx.play(_fx, op, {"op": op, "n": int(fx.get("n", 1))}, from, dests, col, you.body, _shake_by, _hitstop)
	if wait > 0.0:
		await _wait(wait)


func _foe_dest(i: int) -> Dictionary:
	var cr: Creature = _foe_nodes[i].creature
	var body := cr.position + cr.size / 2.0
	return {"body": body, "row": body, "rect": Rect2(cr.position, cr.size)}


## Your side (FightScreen._area of the player panel): your HP bar and the space over it.
func _you_area() -> Dictionary:
	var r := Rect2(_hp_bar.position - Vector2(20, 160), Vector2(_hp_bar.size.x + 40, 160 + _hp_bar.size.y))
	return {"body": r.get_center(), "row": r.get_center(), "rect": r}


func _float_own(ev: Dictionary) -> void:
	match String(ev.type):
			"double_cast":
				_float(Vector2(960, 600), "Cast twice!", Color(1.0, 0.8, 1.0))
			"foe_expose":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -60), "Expose +%d" % int(ev.n), Color(1.0, 0.6, 0.4))
			"activate":
				_float(Vector2(960, 700), "Triggered: " + String(mfight.card(int(ev.ci)).get("name", "")), Color(0.7, 0.9, 1.0))
			"extension":
				_float(Vector2(960, 700), "Extension!", Color(0.7, 1.0, 0.7))
			"self_damage":
				_float(Vector2(190, 760), "-%d" % int(ev.n), Color(1.0, 0.4, 0.4))
			"execute":
				_float(_foe_center(int(ev.foe)), "Snuffed out!", Color(1.0, 0.85, 0.5))
			"moth":
				_float(_foe_center(int(ev.foe)) + Vector2(0, -80), "Every attack comes here!", Color(1.0, 0.7, 0.4))
			"bottle":
				_float(Vector2(190, 730), String(ev.name), Color(0.8, 1.0, 0.8))


## Alchemy / Random Things Go!: which backpack card takes its place.
func _ask_replace() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = PuppetStage.CEILING_Z + 40
	add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(560, 300)
	box.size = Vector2(800, 500)
	box.add_theme_constant_override("separation", 16)
	dim.add_child(box)
	box.add_child(UiTheme.heading("Swap it with a card from your backpack", 34, Color(1.0, 0.88, 0.55)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for b in mfight.mrun.backpack.size():
		var id := String(mfight.mrun.backpack[b])
		var cv := MarbleCardView.new()
		cv.card = MarbleCards.card(id, int(mfight.mrun.levels.get(id, 0)))
		var bb := b
		cv.pressed.connect(func():
			mfight.replace_with(bb)
			dim.queue_free()
			_refresh())
		row.add_child(cv)
	box.add_child(UiTheme.button("Keep it", func():
		mfight.replace_with(-1)
		dim.queue_free()
		_refresh(), 20))
