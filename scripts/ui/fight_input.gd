class_name FightInput
extends RefCounted
## Player input: building the chant, casting, choosers and drags (moved out of fight_screen.gd, docs/plan_dot3_kien_truc.md L15): the code is unchanged except that FightScreen's own members are reached through `scr.`.

var scr: FightScreen


func _init(p_owner: FightScreen) -> void:
	scr = p_owner


var _help_panel: Control


var _prepicked := {}  # EnemyState -> the Essence already chosen for it (the picker hands it straight back)


var _pick_style := "shoot"  # "shoot": remove spells (a crosshair, you shoot the Essence off) · "hand": steal (drag it to your bag) · "brush": Expose (paint it Any)


var _pick_only: EnemyState = null  # picking again on the same enemy (a spell that takes several)


var _pick_el := ""  # only Essence of this kind can be picked right now (the rest are dimmed)


var _steal_into_chant := false  # Instant Steal: the stolen Essence is dropped into the chant, not the bag


var _infuse_at := -1  # Instant Steal: where in the chant it was dropped (the placer hands it straight back)


func _show_help() -> void:
	var text := ""
	if scr.help_override.is_valid():
		text = scr.help_override.call()
	if text == "":
		text = scr.situation_help()
	if is_instance_valid(_help_panel):
		_help_panel.queue_free()
	# a box on the left side, under your artifacts: it covers nothing you need, and only its ✕ takes clicks
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.95, 0.82)
	sb.border_color = Color(1, 0.75, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(4, 5)
	var paper := UiSkin.box("panel_paper_frame", [46, 46, 46, 46] if UiSkin.is_puppet() else [24, 24, 24, 24], [36, 28, 34, 34] if UiSkin.is_puppet() else [24, 14, 22, 22])
	p.add_theme_stylebox_override("panel", (paper as StyleBox) if paper != null else sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 99
	p.position = Vector2(24, 112)
	p.custom_minimum_size = Vector2(440, 0)
	var slide := scr._h_hud._puppet_strips()  # (Puppet Stage: it slides in from the right edge of the screen, just under the Leaves' frame, and slides back out)
	var shown_x := 1920.0 - 24.0 - 440.0
	var hidden_x := 1920.0 + 40.0
	if slide:
		p.position = Vector2(hidden_x, 170.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var sprout: Control = UiSkin.icon("icon_seedling", 40)  # New theme: the painted Seedling instead of the 🌱 emoji
	if sprout == null:
		sprout = UiTheme.label("🌱", 34, Color.WHITE)
	sprout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sprout)
	var who := UiTheme.label("Seedling", 22, Color(0.2, 0.45, 0.15))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close"
	close.add_theme_font_size_override("font_size", 22)
	var close_art := UiSkin.box("button_close_x_normal")
	if close_art != null:  # New theme: the round painted button (its x is part of the picture), always a square 40 px
		close.flat = false
		close.text = ""
		close.custom_minimum_size = Vector2(40, 40)
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close.add_theme_stylebox_override("normal", close_art)
		close.add_theme_stylebox_override("hover", UiSkin.box("button_close_x_hover"))
		close.add_theme_stylebox_override("pressed", UiSkin.box("button_close_x_pressed"))
	close.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2))
	close.add_theme_color_override("font_hover_color", Color(0.8, 0.2, 0.15))
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(func(): if is_instance_valid(p): p.queue_free())
	head.add_child(close)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(412, 0)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.add_theme_color_override("default_color", Color(0.14, 0.11, 0.08))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = Keywords.colorize(text, true)
	v.add_child(r)
	scr.add_child(p)
	_help_panel = p
	if slide:
		shown_x = 1920.0 - maxf(440.0, p.get_combined_minimum_size().x) + 6.0  # (flush with the right edge: the wooden rim hugs the screen)
	var bob := sprout.create_tween().set_loops(6)
	bob.tween_property(sprout, "position:y", -5.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprout, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	var tw := p.create_tween()
	if slide:
		tw.tween_property(p, "position:x", shown_x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # (no overshoot: it must not slide deeper into the screen)
		tw.tween_interval(25.0)
		tw.tween_property(p, "position:x", hidden_x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		p.modulate.a = 0.0
		tw.tween_property(p, "modulate:a", 1.0, 0.2)
		tw.tween_interval(25.0)  # it stays a good while (or until you close it)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	scr._h_anim._pulse_next_thing()


func _press_element(kind: String, i: int) -> void:
	if scr.busy or scr.phase != "build" or i < 0:
		return
	scr._press = {"kind": kind, "i": i, "at": scr.get_global_mouse_position()}


## Pick the element up: the chant becomes a live row where it can land anywhere (the others slide aside).
func _begin_build_drag(pointer: Vector2) -> void:
	var src := scr._press.duplicate()
	var p := scr.fight.player
	var els: Array = scr.chant_idx.map(func(k): return p.stock[k].el)
	var held := -1
	if src.kind == "stock" and src.i in scr.chant_idx:
		src = {"kind": "chant", "i": scr.chant_idx.find(src.i)}  # it's already in the chant: move it
	if src.kind == "stock":
		if p.stock[src.i].frozen or scr.chant_idx.size() >= p.chant_slots():
			scr._press = {}
			return
		els.append(p.stock[src.i].el)
		held = els.size() - 1
	else:
		held = src.i
	for c in scr._chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	var live := []
	for k in els.size():
		live.append(k == held)
	d.live = live
	d.slots = scr._h_hud._chant_rings()
	var lay := scr._h_hud._chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	scr._chant_row.add_child(d)
	d.begin_external(held, pointer)
	scr._bdrag = d
	scr._bdrag_src = src
	if scr._h_hud._puppet_strips() and UiSkin.tex("cursor_hand_fist") != null and not is_instance_valid(scr._grab_cursor):
		scr._grab_cursor = AimCursor.new()  # (the pointer is a fist round the Essence while you drag it)
		scr._grab_cursor.mode = "grab"
		scr.add_child(scr._grab_cursor)
		scr.Input.mouse_mode = scr.Input.MOUSE_MODE_HIDDEN
	if not scr._h_hud._puppet_strips():
		scr._h_anim._elem_sound("grab")
	scr._h_hud._refresh_stock()


## Let go: over the chant it lands in the gap; away from the chant, a chant element goes back to your bag.
func _end_build_drag() -> void:
	var res: Dictionary = scr._bdrag.external_result()
	var src := scr._bdrag_src
	var held_at: Vector2 = scr._bdrag.held_center()
	var held_px: float = scr._bdrag.px
	scr._bdrag.queue_free()
	scr._bdrag = null
	var p := scr.fight.player
	var back := {}  # a chant element let go away from the chant: it flies home to the bag
	if src.kind == "stock":
		if res.inside and scr.chant_idx.size() < p.chant_slots() and p.stun_turns == 0 and scr._allowed("add", p.stock[src.i].el):
			# (the tutorial's scripted chant is built left to right, so there it always goes on the end)
			var at: int = res.to if scr.gate.call("insert", null) else scr.chant_idx.size()
			scr.chant_idx.insert(clampi(at, 0, scr.chant_idx.size()), src.i)
			scr._h_anim._elem_sound("place")
	elif res.inside:
		if res.to != src.i and scr._allowed("rearrange"):
			var k: int = scr.chant_idx[src.i]
			scr.chant_idx.remove_at(src.i)
			scr.chant_idx.insert(clampi(res.to, 0, scr.chant_idx.size()), k)
			scr._h_anim._elem_sound("place")
	elif scr._allowed("remove"):
		back = p.stock[scr.chant_idx[src.i]]
		scr.chant_idx.remove_at(src.i)
		scr._h_anim._elem_sound("remove")
		scr._flying[back.uid] = true
	scr._h_hud._chant_changed()
	if not back.is_empty():
		scr._h_anim._fly(back, held_at, scr._h_hud._bag_target_center(back.uid), held_px, FightScreen.BAG_PX)


func _toggle_stock(i: int) -> void:
	if scr.busy or scr.phase != "build" or i < 0 or scr.fight.player.stun_turns > 0:
		return  # (Stunned: the bag stays shut)
	if i in scr.chant_idx:
		_remove_from_chant(scr.chant_idx.find(i))
	elif not scr.fight.player.stock[i].frozen and scr.chant_idx.size() < scr.fight.player.chant_slots():
		if not scr._allowed("add", scr.fight.player.stock[i].el):
			return
		_add_stock_index(i)


## Take an element from the bag into the end of the chant: it jumps up, then the bag closes the gap.
func _add_stock_index(i: int) -> void:
	var s: Dictionary = scr.fight.player.stock[i]
	var from := scr._h_hud._bag_center(s.uid)
	scr.chant_idx.append(i)
	scr._h_anim._elem_sound("grab")
	scr._flying[s.uid] = true
	scr._bag_delay = FightScreen.FLY_TIME * 0.4
	scr._h_hud._chant_changed()
	scr._h_anim._fly(s, from, scr._h_hud._chant_slot_center(scr.chant_idx.size() - 1), FightScreen.BAG_PX, scr._h_hud._chant_px())


func _remove_from_chant(pos: int) -> void:
	if scr.busy or scr.phase != "build" or pos < 0 or pos >= scr.chant_idx.size() or not scr._allowed("remove"):
		return
	var s: Dictionary = scr.fight.player.stock[scr.chant_idx[pos]]
	var from := scr._h_hud._chant_slot_center(pos)
	var px := scr._h_hud._chant_px()
	scr.chant_idx.remove_at(pos)
	scr._h_anim._elem_sound("remove")
	scr._flying[s.uid] = true
	scr._h_hud._chant_changed()  # the bag makes room for it; its icon waits there, unseen, until this one lands
	scr._h_anim._fly(s, from, scr._h_hud._bag_target_center(s.uid), px, FightScreen.BAG_PX)


func _add_element(el: String) -> void:
	if scr.busy or scr.phase != "build" or scr.chant_idx.size() >= scr.fight.player.chant_slots() or not scr._allowed("add", el):
		return
	var pick := -1
	for i in scr.fight.player.stock.size():
		var s: Dictionary = scr.fight.player.stock[i]
		var rolling: Control = scr._bag_icons.get(s.uid)
		if s.el != el or s.frozen or i in scr.chant_idx or (rolling != null and is_instance_valid(rolling) and rolling.has_meta("rolling")):
			continue
		if pick == -1 or (s.temp and not scr.fight.player.stock[pick].temp) or false:
			pick = i
	if pick >= 0:
		_add_stock_index(pick)
	elif el != "?":
		_add_element("?")  # (none of that left: an Any Essence fits as any element)


## The Essence in the bag that can go into the chant now: their stock indices.
func _usable_stock() -> Array:
	var out: Array = []
	var st: Array = scr.fight.player.stock
	for i in st.size():
		if not st[i].frozen:
			out.append(i)
	return out


## The best chant the bag can make: of every ordering of the bag's letters (at most 3^10, `max_len` long) the one that wakes the most spells
## (a spell wakes once per turn, so the score is how many different spells have their pattern in the chant), cut back afterwards from both
## ends while it still wakes as many. `score_of` is a Callable(chant) -> int. Gives up looking after 2.5 s.
func _best_chant(counts: Dictionary, max_len: int, score_of: Callable) -> String:
	var found := ["", -1]  # [the best chant so far, its score]
	_dfs_step("", counts.duplicate(), counts.keys(), max_len, score_of, Time.get_ticks_msec(), found)
	var c: String = found[0]
	var sc: int = found[1]
	while c.length() > 1 and int(score_of.call(c.left(c.length() - 1))) >= sc:
		c = c.left(c.length() - 1)  # (the last letter is not needed)
	while c.length() > 1 and int(score_of.call(c.substr(1))) >= sc:
		c = c.substr(1)
	return c


func _dfs_step(cur: String, left: Dictionary, letters: Array, max_len: int, score_of: Callable, t0: int, found: Array) -> void:
	if Time.get_ticks_msec() - t0 > 2500:
		return
	if cur.length() == max_len:
		var sc: int = score_of.call(cur)
		if sc > int(found[1]):
			found[0] = cur
			found[1] = sc
		return
	for el in letters:
		if int(left[el]) > 0:
			left[el] = int(left[el]) - 1
			_dfs_step(cur + el, left, letters, max_len, score_of, t0, found)
			left[el] = int(left[el]) + 1


## Test mode: take the chant apart and rebuild it so that as many spells as possible are awake.
func _auto_fill() -> void:
	if scr.busy or scr._auto_busy or scr.phase != "build":
		return
	scr._auto_busy = true
	if not scr.chant_idx.is_empty():
		_clear_chant()
		await scr._h_anim._wait(0.45)
	var usable := _usable_stock()
	var counts := {}
	for i in usable:
		var el: String = scr.fight.player.stock[i].el
		counts[el] = int(counts.get(el, 0)) + 1
	var spells: Array = scr.fight.usable_spells()
	var max_len := mini(usable.size(), mini(scr.fight.player.chant_slots(), 10))
	if max_len <= 0 or spells.is_empty():
		scr._auto_busy = false
		Events.toast.emit("Nothing to fill: no Essence in the bag or no spell that can fire.", UiTheme.DANGER)
		return
	var score_of := func(c: String) -> int:
		var n := 0
		for sp in spells:
			if not scr.fight._occ(sp, c).is_empty():
				n += 1
		return n
	var chant := _best_chant(counts, max_len, score_of)
	var woken := 0
	for sp in spells:
		if not scr.fight._occ(sp, chant).is_empty():
			woken += 1
	var taken: Array = []
	for k in chant.length():
		for i in _usable_stock():  # (looked up afresh for every Essence: the bag changes while this plays)
			if i < scr.fight.player.stock.size() and not taken.has(i) and scr.fight.player.stock[i].el == chant[k]:  # (the bag can shrink while this plays: the Tweezer Hand steals from it)
				taken.append(i)
				_add_stock_index(i)
				break
		await scr._h_anim._wait(0.13)
	scr._auto_busy = false
	scr._h_hud._refresh_all()
	Events.toast.emit("Auto-fill: %d of %d spells wake with %s" % [woken, spells.size(), " ".join(Array(chant.split("")))], Color(0.7, 0.95, 0.7))


## Test mode: new Essence come out of the machine until the bag holds 10.
func _auto_ball() -> void:
	if scr.busy or scr._auto_busy or scr.phase != "build":
		return
	scr._auto_busy = true  # (Auto-fill must not start while the new Essence are still rolling into the bag)
	scr.get_tree().create_timer(0.8).timeout.connect(func(): scr._auto_busy = false)
	var p := scr.fight.player
	var need := 10 - p.stock.size()
	if need <= 0:
		Events.toast.emit("The bag already holds %d Essence." % p.stock.size(), UiTheme.MUTED)
		return
	for i in need:
		p.add_element(scr.fight._random_element())
	scr._h_hud._refresh_all()  # (the newcomers roll out of the tube into the bag)


func _clear_chant() -> void:
	if scr.busy or scr.phase != "build" or not scr._allowed("clear"):
		return
	var going: Array = []
	var px := scr._h_hud._chant_px()
	for k in scr.chant_idx.size():
		going.append([scr.fight.player.stock[scr.chant_idx[k]], scr._h_hud._chant_slot_center(k)])
	scr.chant_idx.clear()
	scr._h_anim._elem_sound("remove")
	for g in going:
		scr._flying[g[0].uid] = true
	scr._h_hud._chant_changed()
	for g in going:
		scr._h_anim._fly(g[0], g[1], scr._h_hud._bag_target_center(g[0].uid), px, FightScreen.BAG_PX)


func _cancel() -> void:
	if not scr._allowed("cancel"):
		return
	if scr._picking_any and scr._picking_any_cancellable:
		scr._any_picked.emit([])  # put the spell back
	elif scr.aiming and scr.aim_cancellable:
		_finish_aim(-1)
	elif scr.move_view != null:
		scr._move_done.emit([])


# ------------------------------------------------------------------ casting


func _on_primary() -> void:
	if scr.phase == "build":
		_on_cast()
	else:
		_on_end_turn()


func _on_cast() -> void:
	if scr.busy or scr.phase != "build" or scr.chant_idx.is_empty() or not scr._allowed("chant"):
		return
	scr.busy = true
	scr.end_confirm = false
	var idx := scr.chant_idx.duplicate()
	scr.chant_idx.clear()
	scr._cast_uids.clear()
	for i in idx:
		scr._cast_uids[scr.fight.player.stock[i].uid] = true
	scr.phase = "spells"
	scr._h_hud._refresh_all()
	await scr.fight.cast_chant(idx)
	scr._cast_uids.clear()
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()
	scr.tut.emit("chanted", scr.fight.chant_string())
	scr.busy = false
	scr._h_hud._refresh_all()
	if scr.fight.over:
		await scr._h_anim._finish()
	elif not scr.fight.has_valid_move() and scr.auto_release:
		await scr._h_anim._wait(0.5)
		await scr._h_anim._damage_step()


func _on_card_clicked(card: SpellCard) -> void:
	if scr.phase != "spells" and card.charges > 0 and not scr.busy:
		# a stored spell: awake, but spells are cast after the chant
		scr._h_anim._float_text("Chant first", card.global_position + Vector2(card.size.x * card.scale.x / 2.0 - 60, -10), Color(1, 0.9, 0.55))
		Audio.play("release_armour_block", -6.0)
		return
	if scr.busy or scr.aiming or scr.phase != "spells" or card.charges <= 0 or not scr._allowed("cast", card.spell.id):
		return
	var spell: Dictionary = card.spell
	var target := -1
	var first: Dictionary = spell.effects[0] if not spell.effects.is_empty() else {}
	if first.get("target", "") in ["target", "two"]:
		if _picks_any_essence(first):
			# no enemy to aim at: every enemy's Essence lights up under the cursor; one click picks enemy and Essence
			var got := await _pick_any_essence(spell, true)
			if got.is_empty():
				return
			target = got[0]
			_prepicked = {scr.fight.enemies[got[0]]: got[1]}
		else:
			var cands := scr.fight.target_candidates()
			if cands.size() <= _max_picks(spell):
				target = cands[0]  # (no more enemies than it picks: it hits them all, nothing to choose)
			else:
				target = await _aim(card, _card_point(card), cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % spell.name, true)
				if target < 0:
					return
	scr.busy = true
	scr.end_confirm = false
	_casting = true
	await scr.fight.resolve_spell(spell.id, target)
	_end_casting()
	if spell.get("power", false):
		scr._h_hud._build_spells()  # (the Power left the row: the others close up)
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()
	scr.tut.emit("cast", spell.id)
	scr.busy = false
	scr._h_hud._refresh_all()
	if scr.fight.over:
		await scr._h_anim._finish()
	elif scr.fight.page_turn_pending:
		await scr._h_talk._page_turn_check()
	elif not scr.fight.has_valid_move() and scr.auto_release:
		# nothing left to cast: the chant is Released by itself
		await scr._h_anim._wait(0.3)
		await scr._h_anim._damage_step()


## No spell ever casts itself: every awake spell waits for the player's click, even one with nothing to aim at
## (the user's rule; an automatic cast was added once by mistake and taken out again).


## Does the player point this spell at an enemy before it resolves? (Effects aimed at "target".)
func _needs_pick(spell: Dictionary) -> bool:
	for e in spell.effects:
		if e.get("target", "") in ["target", "two"]:
			return true
	return false


func _on_end_turn() -> void:
	if scr.busy or scr.aiming or scr.move_view != null or scr.pick_view != null or scr.chant_mode != "":
		return
	if not scr._allowed("release" if scr.phase == "spells" else "pass"):
		return
	if scr.phase == "spells":  # (spells still alive aren't lost: they're stored for your next chant)
		await scr._h_anim._damage_step()
		return
	# before chanting: pass the turn and keep your elements
	scr.busy = true
	scr.chant_idx.clear()
	scr._prompt.text = "The enemies act…"
	scr._h_hud._refresh_all()
	await scr.fight.pass_turn()
	await scr._h_anim._after_turn()


## Drink a bottle: on your turn, when nothing else is going on. Bottles that need an enemy ask for one first.
func _on_bottle(chip: BottleChip) -> void:
	if scr.busy or scr.aiming or scr.fight.over or scr.chant_mode != "" or scr.pick_view != null or scr.move_view != null:
		return
	if not (scr.phase in ["build", "spells"]) or scr._released:
		return
	var i := chip.index
	var id: String = scr.fight.player.bottles[i] if i < scr.fight.player.bottles.size() else ""
	if id == "":
		return
	scr._bottle_from = chip.get_global_rect().get_center()
	var target := -1
	var bfirst: Dictionary = Bottles.get_def(id).effects[0]
	if _picks_any_essence(bfirst):
		var got := await _pick_any_essence(Bottles.as_spell(id), true)
		if got.is_empty():
			return
		target = got[0]
		_prepicked = {scr.fight.enemies[got[0]]: got[1]}
	elif Bottles.needs_target(id):
		var cands := scr.fight.target_candidates()
		if cands.size() == 1:
			target = cands[0]
		else:
			target = await _aim(null, scr._bottle_from, cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % Bottles.get_def(id).name, true)
			if target < 0:
				return
	scr.busy = true
	_casting = true
	if UiSkin.tex(chip._art_name()) != null:  # it grows, shines and vaporises in a puff of smoke (a picture of its own: the real chip is gone as soon as the screen refreshes)
		BottleVapor.play(scr._fx, chip._art_name(), chip.get_global_rect().get_center() - scr._fx.global_position, chip.size.x)
		chip.modulate.a = 0.0
	await scr.fight.use_bottle(i, target)
	_end_casting()
	scr._h_hud._sync_views()
	scr.busy = false
	scr._h_hud._refresh_all()
	if scr.fight.over:
		await scr._h_anim._finish()
	elif scr.fight.page_turn_pending:
		await scr._h_talk._page_turn_check()


## Grimoire Ink: choose a spell from your spellbook (not already active). Returns its index, or -1.
func _spell_chooser(spells: Array) -> int:
	if spells.is_empty():
		return -1
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 90
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(v)
	var t := UiTheme.heading("Grimoire Ink: choose a spell to join your active spells for this fight", 28, Color(1, 0.9, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ribbon := UiSkin.box("banner_grimoire_ink", [184, 0, 174, 0], [110, 10, 110, 22])
	if ribbon != null:  # New theme: the title on a paper ribbon (dark ink, not gold)
		t.add_theme_color_override("font_color", Color(0.28, 0.16, 0.1))
		var rb := PanelContainer.new()
		rb.add_theme_stylebox_override("panel", ribbon)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rb.custom_minimum_size = Vector2(0, 110)  # the ribbon art is cut at this height: its end curls keep their shape
		rb.add_child(t)
		v.add_child(rb)
	else:
		v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1800, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.custom_minimum_size = Vector2(1780, 0)
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	scroll.add_child(flow)
	var center := CenterContainer.new()
	center.add_child(scroll)
	v.add_child(center)
	for i in spells.size():
		var card := SpellCard.make(spells[i])
		var k := i
		card.clicked.connect(func(_c): scr._spell_chosen.emit(k))
		flow.add_child(card)
	var skip := UiTheme.button("Keep the ink (choose nothing)", func(): scr._spell_chosen.emit(-1), 20)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(skip)
	scr.add_child(overlay)
	var idx: int = await scr._spell_chosen
	overlay.queue_free()
	return idx


# ------------------------------------------------------------------ pause menu


func _open_pause_menu() -> void:
	if scr._pause_overlay != null:
		return
	var saved := "Your run is saved: Continue on the main menu starts this fight over."
	var pm := PauseMenu.open(scr,
		"Return to the Main Menu? " + saved if scr.run_saved else "Abandon this run and return to the Main Menu?",
		"Quit Behind the Curtain? " + saved if scr.run_saved else "Quit Behind the Curtain?")
	pm.world_keep = [scr._enemy_row, scr._fx]  # (a "Without UI" screenshot keeps the enemies and the effects on the stage)
	pm.resumed.connect(_close_pause_menu)
	pm.settings_closed.connect(scr._h_hud._refresh_all)
	pm.main_menu.connect(func(): scr.menu_requested.emit())
	scr._pause_overlay = pm


func _close_pause_menu() -> void:
	if scr._pause_overlay == null:
		return
	scr._pause_overlay.queue_free()
	scr._pause_overlay = null


# ------------------------------------------------------------------ aiming (the arrow)


func _card_point(card: SpellCard) -> Vector2:
	return card.global_position + Vector2(card.size.x * card.scale.x / 2.0, 10)


## Pull an arrow from `from` to the mouse until an enemy is chosen. Returns its index, or -1 if cancelled.
func _aim(card: SpellCard, from: Vector2, cands: Array, prompt: String, cancellable: bool) -> int:
	scr.aiming = true
	scr.tut.emit("aiming", null)
	scr.aim_card = card
	scr.aim_from = from
	scr.aim_cands = cands
	scr.aim_i = 0
	scr.aim_cancellable = cancellable
	scr._prompt.text = prompt
	scr._h_hud._refresh_all()
	var idx: int = await scr._aim_done
	return idx


func _finish_aim(idx: int) -> void:
	scr.aiming = false
	scr.aim_card = null
	scr._arrow.queue_redraw()
	scr._h_hud._refresh_all()
	scr._aim_done.emit(idx)


func _on_enemy_clicked(v: EnemyView) -> void:
	if not scr.aiming:
		return
	var idx := scr.fight.enemies.find(v.enemy)
	if idx in scr.aim_cands and scr._allowed("target", idx):
		_finish_aim(idx)


var _hover_panel: PanelContainer


var _hover_key := ""


var _hover_t := 0.0


func _update_hover_info(d: float, m := Vector2(-1, -1)) -> void:
	if m.x < 0.0:
		m = scr.get_global_mouse_position()
	var key := ""
	var text := ""
	var anchor := Rect2()
	var avoid := Rect2()  # (the puppet it is about: the panel never covers it)
	if not (scr.aiming or scr._picking_any or scr.pick_view != null or scr.move_view != null or scr.chant_mode != "" or scr._pause_overlay != null):
		for e in scr._views:
			var v: EnemyView = scr._views[e]
			if not is_instance_valid(v):
				continue
			var chip := v.intent_chip()
			# its intent bubble explains what it is about to do
			if chip != null and chip.get_global_rect().has_point(m):
				key = "intent:%d" % v.get_instance_id()
				text = chip.get_meta("info", "")
				anchor = chip.get_global_rect()
				avoid = v.puppet_global_rect()
				break
			# its HP: every status on it explained (Power, Burn, armour, passives...)
			if v.hp_hovered(m):
				key = "hp:%d" % v.get_instance_id()
				text = v.info_text()
				anchor = Rect2(m - Vector2(20, 20), Vector2(40, 40))
				avoid = v.puppet_global_rect()
				break
			# the sprite itself: everything about the enemy, and under it what it is about to do (the same words as its intent bubble)
			var body_r := v.puppet_global_rect()
			if body_r.has_point(m) and not v.enemy.is_dead():
				key = "body:%d" % v.get_instance_id()
				text = v.info_text()
				var said: String = chip.get_meta("info", "") if chip != null else ""
				if said != "":
					text += "

" + said
				anchor = Rect2(m - Vector2(20, 20), Vector2(40, 40))
				avoid = body_r
				break
	if key != _hover_key:
		_hover_key = key
		_hover_t = 0.0
		if is_instance_valid(_hover_panel):
			_hover_panel.queue_free()
		_hover_panel = null
	if key == "" or text == "":
		return
	_hover_t += d
	if _hover_t < FightScreen.HOVER_DELAY or is_instance_valid(_hover_panel):
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 120
	var body := Keywords.make_tooltip(text)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(body)
	scr.add_child(p)
	_hover_panel = p
	await scr.get_tree().process_frame
	if not is_instance_valid(p):
		return
	if avoid.has_area():  # on the puppet's left, where its intent bubble stands (on its right when the left side has no room): never over the puppet
		var left := avoid.position.x - 4.0 - p.size.x
		var ax := left if left >= 10.0 else avoid.end.x + 4.0
		p.position = Vector2(clampf(ax, 10.0, 1910.0 - p.size.x), clampf(avoid.get_center().y - p.size.y / 2.0, 10.0, 1070.0 - p.size.y))
		return
	# beside the enemy (right if there's room, else left), kept on screen
	var x := anchor.end.x + 12.0
	if x + p.size.x > 1910.0:
		x = anchor.position.x - p.size.x - 12.0
	p.position = Vector2(clampf(x, 10.0, 1910.0 - p.size.x), clampf(anchor.position.y, 10.0, 1070.0 - p.size.y))


var _glow_tween: Tween


func _drag_feedback() -> void:
	if is_instance_valid(scr._grab_cursor) and not is_instance_valid(scr._bdrag):
		scr._grab_cursor.queue_free()
		scr._grab_cursor = null
		if not scr._picking_any:
			scr.Input.mouse_mode = scr.Input.MOUSE_MODE_VISIBLE
	var panel: Control = null
	if not scr._steal_drag.is_empty():
		var chant_drop := _steal_into_chant
		var r := (scr._chant_row if chant_drop else scr._stock_row).get_global_rect().grow(FightScreen.BAG_DROP_MARGIN * (0.6 if chant_drop else 1.0))
		if r.has_point(scr._test_pointer if scr._test_pointer.x >= 0.0 else scr.get_global_mouse_position()):
			panel = scr._chant_panel if chant_drop else scr._bag_panel
	elif is_instance_valid(scr._bdrag) and scr._bdrag_src.get("kind", "") == "chant" and not scr._bdrag.external_result().inside:
		panel = scr._bag_panel  # (let go away from the chant: it goes home to the Bag)
	if panel == scr._glow_panel:
		return
	if is_instance_valid(scr._glow_panel):
		var tw0 := scr.create_tween()
		tw0.tween_property(scr._glow_panel, "self_modulate", Color.WHITE, 0.15)
	scr._glow_panel = panel
	if panel != null:
		if _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = scr.create_tween()
		_glow_tween.tween_property(panel, "self_modulate", Color(1.6, 1.4, 0.85), 0.15)


## The fight needs a target it wasn't given (a Power at the start of your turn, or the target died mid-spell).
func _choose_target(spell: Dictionary, cands: Array) -> int:
	if _picks_any_essence(scr.fight.current_eff):
		# a later line of the spell takes any Essence, anywhere: pick it straight from the enemies
		var got := await _pick_any_essence(spell, false)
		if not got.is_empty():
			_prepicked = {scr.fight.enemies[got[0]]: got[1]}
			return got[0]
	if cands.size() <= _max_picks(spell):
		return cands[0]  # (no more enemies than it picks: nothing to choose)
	var card: SpellCard = null
	for c in scr._cards:
		if c.spell.id == spell.id:
			card = c
	var from := _card_point(card) if card else scr._player_panel.global_position + Vector2(250, 0)
	var second: bool = spell.effects.any(func(x): return x.get("target", "") == "two")
	var what := "choose a SECOND, different enemy" if second else "choose a target"
	return await _aim(card, from, cands, "%s: %s  ·  click, or Tab + Enter" % [spell.name, what], false)


func _mover(spell: Dictionary, _hint: EnemyState) -> Array:
	var rows: Array[EnemyView] = []
	for x in scr.fight.hittable():
		var xv: EnemyView = scr._views.get(x)
		if xv != null and not (x.has_passive("briar_walls") and x.has_walls()):
			rows.append(xv)
	if rows.is_empty():
		return []
	for v in rows:
		v.move_mode = true
		v.move_pick = -1
	scr.move_view = rows[0]
	scr._prompt.text = "%s: drag an Essence to another spot, in its own row or onto another enemy  ·  right-click to skip" % spell.name
	scr._h_hud._refresh_all()
	await scr.get_tree().process_frame  # (the rows grow for the move: lay them out first)
	var drags := {}  # EnemyView -> ChantDrag
	for v in rows:
		var d: ChantDrag = v.begin_row_drag(scr)
		d.free_drop = true
		drags[v] = d
	for v in rows:
		var d: ChantDrag = drags[v]
		var src: int = scr.fight.enemies.find(v.enemy)
		d.dropped.connect(func(from, to): scr._move_done.emit([from, to, src, src]))
		d.carried.connect(func(at):
			for o in drags.values():
				if o != d:
					o.set_guest(at))
		d.dropped_out.connect(func(from, at):
			for ov in drags:
				var o: ChantDrag = drags[ov]
				if o != d:
					var to := o.set_guest(at)
					if to >= 0:
						scr._move_done.emit([from, to, src, scr.fight.enemies.find(ov.enemy)])
						return
			d.float_back())  # (let go away from every row: it goes back where it was)
	scr._edrag = drags[rows[0]]
	var mv: Array = await scr._move_done
	await scr._h_anim._wait(0.25)  # (let the dropped one settle)
	for v in rows:
		if is_instance_valid(drags[v]):
			drags[v].queue_free()
		if is_instance_valid(v):
			v.end_row_drag()
			v.move_mode = false
			v.move_pick = -1
	scr._edrag = null
	scr.move_view = null
	scr._h_hud._refresh_all()
	return mv


## Pluck: choose which element of this enemy's HP to remove. Click it, or Tab through and Enter.
func _picker(spell: Dictionary, e: EnemyState) -> int:
	if _prepicked.has(e):
		# chosen already, straight from the enemies' Essence
		var pre: int = _prepicked[e]
		_prepicked.erase(e)
		scr.tut.emit("picked", pre)
		return pre
	var v: EnemyView = scr._views.get(e)
	if v == null:
		return e.armor.find(false)
	var verb := "steal" if spell.effects.any(func(x): return x.op == "steal") else "knock off"
	var open_idx := []
	for i in e.size():
		if not e.armor[i] and (scr.fight.pick_el == "" or e.elements[i] == scr.fight.pick_el):
			open_idx.append(i)
	if open_idx.size() <= 1:
		# no real choice (e.g. its very last element): take it without asking
		scr.tut.emit("picking", null)
		var only: int = open_idx[0] if open_idx.size() == 1 else -1
		scr.tut.emit("picked", only)
		return only
	# another pick on this enemy: the crosshair / hand again, on it only
	var again := await _pick_any_essence(spell, false, e)
	if not again.is_empty():
		scr.tut.emit("picked", again[1])
		return again[1]
	scr.pick_view = v
	scr.tut.emit("picking", null)
	v.pick_mode = true
	v.pick_el = scr.fight.pick_el
	v.pick_i = open_idx[0]
	scr._prompt.text = "%s: choose an Essence of %s to %s  ·  click it, or Tab + Enter" % [spell.name, e.name, verb]
	scr._h_anim._callout("Choose an Essence of [b]%s[/b] to %s" % [e.name, verb], v.global_position + Vector2(v.size.x / 2.0, 120), Color(1, 0.85, 0.4), 2.5)
	scr._h_hud._refresh_all()
	var idx: int = await scr._pick_done
	scr.tut.emit("picked", idx)
	v.keep_big = v.keep_big or _casting
	v.pick_mode = false
	v.pick_el = ""
	v.pick_i = -1
	scr.pick_view = null
	scr._h_hud._refresh_all()
	return idx


func _cycle_pick(step: int) -> void:
	var e := scr.pick_view.enemy
	var i := scr.pick_view.pick_i
	for k in e.size():
		i = (i + step + e.size()) % e.size()
		if not e.armor[i] and (scr.pick_view.pick_el == "" or e.elements[i] == scr.pick_view.pick_el):
			break
	scr.pick_view.pick_i = i
	scr.pick_view.refresh({})


## A spell (or bottle) is being cast: enemy rows enlarged for one of its picks stay enlarged until it's all done,
## instead of shrinking between picks (Expose 2, steals and removals of several Essence).
var _casting := false


func _end_casting() -> void:
	_casting = false
	# (the cast is over: no aiming pointer may stay behind, and the mouse pointer comes back)
	if not scr._picking_any:
		for c in scr.find_children("*", "AimCursor", true, false):
			if c != scr._grab_cursor:
				c.queue_free()
		scr._aim_cursor = null
		scr.Input.mouse_mode = scr.Input.MOUSE_MODE_VISIBLE
	var any := false
	for v in scr._views.values():
		if is_instance_valid(v) and v.keep_big:
			v.keep_big = false
			any = true
	if any:
		scr._h_hud._refresh_all()


## Spells that take "an Essence of your choice" (Pluck, Steal any): the choice is the Essence itself, anywhere.
func _picks_any_essence(eff: Dictionary) -> bool:
	return eff.get("op", "") in ["pluck", "steal"] or (eff.get("op", "") == "purge" and eff.get("target", "") in ["target", "two"])


## A spell that takes only one kind of Essence ("remove up to 3 Fire", "steal up to 2 Water"): that kind, else "".
func _pick_kind(eff: Dictionary) -> String:
	if eff.get("op", "") == "purge" or (eff.get("op", "") == "steal" and eff.get("el", "any") != "any"):
		return String(eff.get("el", ""))
	return ""


## Every enemy's Essence becomes pickable at once; the one under the cursor lights up. Returns
## [enemy index, Essence index], or [] if it was put back (right-click, when cancellable).
func _pick_any_essence(spell: Dictionary, cancellable: bool, only: EnemyState = null, style := "") -> Array:
	var eff: Dictionary = scr.fight.current_eff if _picks_any_essence(scr.fight.current_eff) else {}
	if eff.is_empty():
		for e2 in spell.effects:
			if _picks_any_essence(e2):
				eff = e2
				break
	_pick_style = style if style != "" else ("hand" if eff.get("op", "") == "steal" else "shoot")
	_pick_only = only
	_pick_el = scr.fight.pick_el if scr.fight.pick_el != "" else _pick_kind(eff)
	_steal_into_chant = eff.get("into", "") == "chant"
	var greyed: Control = null
	if _pick_style == "hand":
		greyed = scr._chant_row if not _steal_into_chant else scr._stock_row
		greyed.modulate = Color(0.55, 0.55, 0.55, 0.6)
	scr._picking_any = true
	scr._picking_any_cancellable = cancellable
	if _pick_style == "hand":
		scr._h_anim._shrink_cards(true)  # (the cards must not cover the enemies' rows of Essence)
	scr.tut.emit("picking", null)
	for v in scr._views.values():
		v.pick_mode = (only == null or v.enemy == only) and not v.enemy.is_dead()  # (not a fallen hand)
		v.paint_mode = _pick_style == "brush"
		v.paint_to = scr.fight.paint_to
		v.pick_el = _pick_el
		v.pick_i = -1
	# the pointer becomes a crosshair (remove), an open hand (steal) or a paint brush (Expose)
	if is_instance_valid(scr._aim_cursor):
		scr._aim_cursor.queue_free()  # (never two at once: one left over would stay on the screen)
	scr._aim_cursor = AimCursor.new()
	scr._aim_cursor.mode = _pick_style
	scr.add_child(scr._aim_cursor)
	scr.Input.mouse_mode = scr.Input.MOUSE_MODE_HIDDEN
	var what: String = Elements.NAMES.get(_pick_el, "Essence")  # (a spell that takes one kind names it: "an enemy's Fire")
	var paint: String = "an Any Essence" if scr.fight.paint_to == "?" else Elements.NAMES[scr.fight.paint_to]
	var how: String = {"hand": ("drag an enemy's %s down into your chant" if _steal_into_chant else "drag an enemy's %s down into your bag") % what, "brush": "paint an enemy's Essence: it becomes %s" % paint}.get(_pick_style, "shoot an enemy's %s off" % what)
	scr._prompt.text = "%s: %s%s" % [spell.name, how, "  ·  right-click to put it back" if cancellable else ""]
	scr._h_anim._callout("[b]%s[/b]: %s" % [spell.name, how], Vector2(960, 150), Color(1, 0.85, 0.4), 2.0)
	scr._h_hud._refresh_all()
	var got: Array = await scr._any_picked
	if greyed != null:
		greyed.modulate = Color.WHITE
	if _pick_style == "hand":
		scr._h_anim._shrink_cards(false)
	scr._picking_any = false
	_pick_only = null
	_pick_el = ""
	scr._steal_drag = {}
	if is_instance_valid(scr._aim_cursor):
		scr._aim_cursor.queue_free()
	scr._aim_cursor = null
	scr.Input.mouse_mode = scr.Input.MOUSE_MODE_VISIBLE
	for v in scr._views.values():
		if is_instance_valid(v):
			v.keep_big = v.keep_big or (_casting and v.pick_mode)
			v.pick_mode = false
			v.paint_mode = false
			v.pick_el = ""
			v.pick_i = -1
	scr._h_hud._refresh_all()
	return got


## Expose: the brush comes out and you paint one enemy Essence (anywhere) into an Any Essence. Asked once per paint.
func _painter(spell: Dictionary) -> Array:
	return await _pick_any_essence(spell, false, null, "brush")


## Steal: you grip an Essence; it follows your hand on a tether until you let go.
func _begin_steal_drag(v: EnemyView, index: int) -> void:
	var icon: Control = v._hp_icons[index] if index < v._hp_icons.size() else null
	if icon != null:
		icon.modulate.a = 0.3
	scr._steal_drag = {"enemy": v.enemy, "index": index, "el": v.enemy.elements[index], "from": v.hp_point(index), "icon": icon}
	if is_instance_valid(scr._aim_cursor):
		scr._aim_cursor.holding = scr._steal_drag.el
		scr._aim_cursor.tether_from = scr._steal_drag.from
	Audio.play("elem_pickup")


## Let go near your bag: it lands at the end of the bag and the spell goes through. Anywhere else: it snaps back to
## the enemy as if nothing happened, and you can try again.
func _end_steal_drag(at: Vector2) -> void:
	var d := scr._steal_drag
	scr._steal_drag = {}
	if is_instance_valid(scr._aim_cursor):
		scr._aim_cursor.holding = ""
	var bag := scr._stock_row.get_global_rect().grow(FightScreen.BAG_DROP_MARGIN)
	if _steal_into_chant:
		bag = scr._chant_row.get_global_rect().grow(FightScreen.BAG_DROP_MARGIN * 0.6)  # (Instant Steal: it goes into the chant)
	var ghost := ElementIcon.make(d.el, 52)
	ghost.size = Vector2(52, 52)
	ghost.pivot_offset = ghost.size / 2.0
	ghost.z_index = 150
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = at + Vector2(0, -35.0) - ghost.size / 2.0 - scr._fx.global_position  # (where the hand held it)
	ghost.scale = Vector2.ONE * (34.0 / 52.0)  # (as small as in the hand)
	scr._fx.add_child(ghost)
	if bag.has_point(at):
		var to := scr._stock_row.global_position + scr._h_machine._bag_slot(scr._bag_icons.size(), scr._bag_icons.size() + 1) - scr._fx.global_position
		if _steal_into_chant:
			# Instant Steal: like a Steal into the bag, it flies to the chant's next free spot
			var n := scr.fight.chant.size()
			var slot: Control = scr._chant_row.get_child(n) if n < scr._chant_row.get_child_count() else null
			var end := (slot.get_global_rect().get_center() if slot != null else scr._chant_row.get_global_rect().end - Vector2(30, scr._chant_row.size.y / 2.0))
			to = end - ghost.size / 2.0 - scr._fx.global_position
		var direct := scr._h_hud._puppet_strips() and not _steal_into_chant
		if direct:  # the Essence goes straight into the Bag (no machine, no show): the Bag's own ball shows up when this one has landed
			scr._direct_in += 1
			scr._direct_until = Time.get_ticks_msec() + 5000
			scr._direct_landed = false
			scr._direct_wait.clear()
			scr._keep_bag_order = true  # (it stays at the back; the Bag is sorted once at the next spawn)
			to = scr._stock_row.global_position + scr._h_machine._bag_slot(scr._bag_icons.size(), scr._bag_icons.size() + 1) - scr._fx.global_position
		var tw := ghost.create_tween().set_parallel(true)
		tw.tween_property(ghost, "position", to, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # (it grows to the size of your own Essence)
		tw.chain().tween_callback(func():
			if direct:
				scr._direct_landed = true
				for w in scr._direct_wait:
					if is_instance_valid(w):
						w.modulate.a = 1.0
				scr._direct_wait.clear()
				scr._h_anim._ball_sound("hit", -4.0, randf_range(0.95, 1.08))
			ghost.queue_free())
		if not direct:
			Audio.play("elem_remove")
		scr._any_picked.emit([scr.fight.enemies.find(d.enemy), d.index])
	else:
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "position", d.from - ghost.size / 2.0 - scr._fx.global_position, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			ghost.queue_free()
			if is_instance_valid(d.icon):
				d.icon.modulate.a = 1.0)


func _on_hp_clicked(v: EnemyView, index: int) -> void:
	if scr._picking_any:
		if _pick_only != null and v.enemy != _pick_only:
			return
		if _pick_style == "brush":
			if index < v.enemy.size() and v.enemy.elements[index] != scr.fight.paint_to and scr._allowed("pick", index):
				if is_instance_valid(scr._aim_cursor):
					scr._aim_cursor.kick()  # the brush presses down
				scr._any_picked.emit([scr.fight.enemies.find(v.enemy), index])
			return
		if index < v.enemy.size() and _pick_el != "" and v.enemy.elements[index] != _pick_el:
			return  # (dimmed: not the kind this spell takes)
		if index < v.enemy.size() and not v.enemy.armor[index] and scr._allowed("pick", index) and scr._steal_drag.is_empty():
			if _pick_style == "hand":
				_begin_steal_drag(v, index)  # the pick happens when it's dropped on the bag
			else:
				scr._h_anim._fire_shot(v, index)
				scr._any_picked.emit([scr.fight.enemies.find(v.enemy), index])
		return
	if v == scr.pick_view:
		if index < v.enemy.size() and scr._allowed("pick", index) and not v.enemy.armor[index] and (v.pick_el == "" or v.enemy.elements[index] == v.pick_el):
			scr._pick_done.emit(index)
		return
	if v != scr.move_view:
		return
	if v.move_pick < 0:
		if index < v.enemy.size():
			v.move_pick = index
			scr._prompt.text = "Now click where it goes (it takes that spot), or ▸ for the end  ·  click it again to put it down"
			v.refresh({})
		return
	if index == v.move_pick:
		v.move_pick = -1
		scr._prompt.text = "Click an Essence to pick it up  ·  right-click to skip"
		v.refresh({})
		return
	var vi: int = scr.fight.enemies.find(v.enemy)
	scr._move_done.emit([v.move_pick, index, vi, vi])


## Infuse: the new element appears at the end of the chant, shining; drag it where it should go
## (or Left / Right + Enter).
func _placer(spell: Dictionary, el: String) -> int:
	if _infuse_at >= 0:
		# Instant Steal: it was dropped straight onto its spot in the chant
		var at := clampi(_infuse_at, 0, scr.fight.chant.size())
		_infuse_at = -1
		return at
	scr.chant_mode = "insert"
	scr.tut.emit("placing", null)
	scr.chant_i = scr.fight.chant.size()
	scr._prompt.text = "%s: drag the glowing %s from the card into your chant" % [spell.name, Elements.NAMES[el]]
	scr._h_hud._refresh_all()
	scr._h_anim._spawn_infuse_orb(spell, el)
	var i: int = await scr._chant_done
	scr._infuse_dragging = false
	if is_instance_valid(scr._infuse_orb):
		scr._infuse_orb.queue_free()
	scr._infuse_orb = null
	await _hide_drag()
	scr.chant_mode = ""
	scr._h_hud._refresh_all()
	scr.tut.emit("placed", i)
	return i


## Picked up from the card: the chant becomes a live row that opens a gap wherever you hold it.
func _infuse_grab(pointer: Vector2) -> void:
	if scr._infuse_dragging or not is_instance_valid(scr._infuse_orb):
		return
	scr._infuse_orb.visible = false
	var els: Array = scr.fight.chant.duplicate()
	els.append(scr._infuse_el)
	var live := []
	for k in els.size():
		live.append(k == els.size() - 1)
	for c in scr._chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	d.live = live
	d.slots = scr._h_hud._chant_rings()
	var lay := scr._h_hud._chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	scr._chant_row.add_child(d)
	d.begin_external(els.size() - 1, pointer)
	scr._drag = d
	scr._infuse_dragging = true
	Audio.play("elem_pickup")


## Let go: over the chant it's placed there; anywhere else it floats back to the card to wait.
func _infuse_drop() -> void:
	var res: Dictionary = scr._drag.external_result()
	scr._infuse_dragging = false
	if res.inside and scr._allowed("place", res.to):
		scr._chant_done.emit(res.to)
		return
	scr._drag.queue_free()
	scr._drag = null
	scr._h_hud._refresh_chant()
	if is_instance_valid(scr._infuse_orb):
		scr._infuse_orb.visible = true
		scr._infuse_orb.scale = Vector2(0.6, 0.6)
		scr._infuse_orb.create_tween().tween_property(scr._infuse_orb, "scale", Vector2.ONE, 0.15)


## Wild Rearrange: your chant and every enemy row come alive at once; drag one Essence to another spot in its own
## row (chant or enemy). Returns [from, to] for the chant, [from, to, enemy index] for an enemy, [] to skip.
func _wild_arranger(spell: Dictionary) -> Array:
	scr.chant_mode = "arrange"
	var in_chant: bool = scr.fight.spoken and scr.fight.chant.size() > 1
	if in_chant:
		var live := []
		for c in scr.fight.chant:
			live.append(true)
		_show_drag(scr.fight.chant.duplicate(), live, true)
		scr._drag.dropped.connect(func(from, to): scr._arrange_done.emit([from, to]))
	var rows := []
	for e in scr.fight.alive():
		var v: EnemyView = scr._views.get(e)
		if v != null and e.size() > 1 and not e.has_passive("briar_walls"):
			v.move_mode = true
			rows.append(v)
	scr._prompt.text = "%s: drag an Essence to another spot, in your chant or in an enemy's row  ·  right-click: keep them" % spell.name
	scr._h_hud._refresh_all()
	await scr.get_tree().process_frame
	var drags := []
	for v in rows:
		var d: ChantDrag = v.begin_row_drag(scr)
		var idx: int = scr.fight.enemies.find(v.enemy)
		d.dropped.connect(func(from, to): scr._arrange_done.emit([from, to, idx]))
		drags.append(d)
	var mv: Array = await scr._arrange_done
	await scr._h_anim._wait(0.25)
	for d in drags:
		d.queue_free()
	for v in rows:
		v.end_row_drag()
		v.move_mode = false
	if in_chant:
		await _hide_drag()
	scr.chant_mode = ""
	scr._h_hud._refresh_all()
	return mv


func _wild_painter(spell: Dictionary) -> Array:
	var st := {"done": false}  # (shared by both handlers: the first pick wins)
	var on_chant := func(i: int) -> void:
		if not st.done:
			st.done = true
			scr._wild_painted.emit(["chant", i])
	var on_enemy := func(pair: Array) -> void:
		if not st.done:
			st.done = true
			scr._wild_painted.emit(["enemy", pair[0], pair[1]] if pair.size() == 2 else [])
	scr._chant_done.connect(on_chant)
	scr._any_picked.connect(on_enemy)
	if scr.fight.spoken and not scr.fight.chant.is_empty():
		scr.chant_mode = "pick"
		scr.chant_i = 0
	_pick_any_essence(spell, false, null, "brush")  # (it waits for an enemy pick on its own; a chant pick ends it)
	if scr.chant_mode == "pick":
		scr._prompt.text = "%s: paint an enemy's Essence, or click one of your chant" % spell.name
		scr._h_hud._refresh_chant()
	var got: Array = await scr._wild_painted
	scr._chant_done.disconnect(on_chant)
	scr._any_picked.disconnect(on_enemy)
	if got.size() == 2 and scr._picking_any:
		scr._any_picked.emit([])  # put the brush away
	scr.chant_mode = ""
	scr._h_hud._refresh_all()
	return got


## Rearrange: every chant element comes alive; drag one to another spot (right-click keeps the chant as it is).
func _arranger(spell: Dictionary) -> Array:
	scr.chant_mode = "arrange"
	var live := []
	for c in scr.fight.chant:
		live.append(true)
	_show_drag(scr.fight.chant.duplicate(), live, true)
	scr._prompt.text = "%s: grab any Essence of your chant and drag it to another spot  ·  Tab + Left / Right + Enter  ·  right-click: keep it" % spell.name
	scr._h_hud._refresh_all()
	scr._drag.dropped.connect(func(from, to): scr._arrange_done.emit([from, to]))
	var mv: Array = await scr._arrange_done
	await _hide_drag()
	scr.chant_mode = ""
	scr._h_hud._refresh_all()
	return mv


func _show_drag(els: Array, live: Array, same_spot_is_no_move: bool) -> void:
	for c in scr._chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	d.live = live
	d.slots = scr._h_hud._chant_rings()
	var lay := scr._h_hud._chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	d.same_spot_is_no_move = same_spot_is_no_move
	scr._chant_row.add_child(d)
	scr._drag = d


## Let the dropped element settle for a moment, then hand the row back to the normal chant view.
func _hide_drag() -> void:
	await scr._h_anim._wait(0.3)
	if is_instance_valid(scr._drag):
		scr._drag.queue_free()
	scr._drag = null


## Resonance: choose the chant element to copy.
func _chant_picker(spell: Dictionary) -> int:
	scr.chant_mode = "pick"
	scr.chant_i = 0
	if scr.fight.current_eff.get("op", "") == "retain":
		scr._prompt.text = "%s: which Essence of the chant comes back to your bag after the Release?  ·  click it, or Tab + Enter" % spell.name
		scr.chant_mode = "pick"
		scr.chant_i = 0
		scr._h_hud._refresh_all()
		var r: int = await scr._chant_done
		scr.chant_mode = ""
		scr._h_hud._refresh_all()
		return r
	var self_paint: bool = scr.fight.current_eff.get("op", "") == "self_repaint"
	var to: String = scr.fight.current_eff.get("to", "?")
	scr._prompt.text = ("%s: which Essence of the chant should be repainted %s?  ·  click it, or Tab + Enter" % [spell.name, "Any" if to == "?" else Elements.NAMES[to]]) if self_paint else \
		"%s: which Essence of the chant should be duplicated?  ·  click it, or Tab + Enter" % spell.name
	scr._h_hud._refresh_all()
	var i: int = await scr._chant_done
	scr.chant_mode = ""
	scr._h_hud._refresh_all()
	return i


## Attunement: the screen dims, the card's Essence shine and fly to the middle; you click one, and it flies down to
## your statuses, where it becomes a badge (+1 of it each turn).
func _attune_chooser(spell: Dictionary) -> String:
	var card := scr._h_anim._card_for(spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 70
	scr.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.35)
	var title := UiTheme.label("%s: pick an Essence to gain every turn" % spell.name, 34, Color(1.0, 0.92, 0.7))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1920, 50)
	title.position = Vector2(0, 250)
	title.z_index = 72
	title.modulate.a = 0.0
	scr.add_child(title)
	title.create_tween().tween_property(title, "modulate:a", 1.0, 0.4)
	var els := []
	for ch in String(spell.get("pattern", "FWA")):
		if ch in ["F", "W", "A"] and not (ch in els):
			els.append(ch)
	if els.is_empty():
		els = ["F", "W", "A"]
	var orbs := {}
	var px := 120.0
	for i in els.size():
		var el: String = els[i]
		var orb := ElementIcon.make(el, px)
		orb.size = Vector2(px, px)
		orb.pivot_offset = orb.size / 2.0
		orb.position = from - orb.size / 2.0
		orb.scale = Vector2(0.3, 0.3)
		orb.z_index = 72
		orb.highlight = true
		orb.mouse_filter = Control.MOUSE_FILTER_STOP
		orb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		scr.add_child(orb)
		var to := Vector2(960 + (i - (els.size() - 1) / 2.0) * 260, 440) - orb.size / 2.0
		var tw := orb.create_tween().set_parallel(true)
		tw.tween_property(orb, "position", to, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property(orb, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_delay(i * 0.12)
		var glow := orb.create_tween().set_loops()
		glow.tween_property(orb, "modulate", Color(1.7, 1.6, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
		glow.tween_property(orb, "modulate", Color(1.2, 1.15, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		orb.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._element_chosen.emit(el))
		orbs[el] = orb
	Audio.play("spell_glow")
	scr._choosing_el = true
	var chosen: String = await scr._element_chosen
	scr._choosing_el = false
	title.create_tween().tween_property(title, "modulate:a", 0.0, 0.25)
	# the others fade away; the chosen one flies down to your statuses
	for el in orbs:
		var o: ElementIcon = orbs[el]
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if el != chosen:
			var gone := o.create_tween().set_parallel(true)
			gone.tween_property(o, "scale", Vector2(0.3, 0.3), 0.4)
			gone.tween_property(o, "modulate:a", 0.0, 0.4)
			gone.chain().tween_callback(o.queue_free)
	var ic: ElementIcon = orbs[chosen]
	var target := scr._status_row.global_position + Vector2(scr._status_row.size.x + 40.0, 16.0)
	var fly := ic.create_tween().set_parallel(true)
	fly.tween_property(ic, "position", target - ic.size / 2.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(0.15)
	fly.tween_property(ic, "scale", Vector2(0.22, 0.22), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(0.15)
	var fade := dim.create_tween()
	fade.tween_property(dim, "color:a", 0.0, 0.5)
	fade.tween_callback(dim.queue_free)
	await fly.finished
	ic.queue_free()
	title.queue_free()
	# it arrives: a little burst where it becomes a badge
	var col: Color = Elements.COLORS[chosen]
	var fx := Vfx.make(scr._fx, 70)
	fx.ring(target, 6, 60, col, 0.35, 5.0)
	fx.burst(target, 14, col.lightened(0.3), Vector2(80, 220), Vector2(0.2, 0.4), Vector2(3, 6), Vfx.GLOW)
	Audio.play("artifact_get", -6.0)
	return chosen


func _element_chooser(spell: Dictionary, counts: Dictionary) -> String:
	var card := scr._h_anim._card_for(spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 70
	scr.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.35)
	var title := UiTheme.label("%s: choose an Essence to wipe out" % spell.name, 34, Color(1.0, 0.8, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1920, 50)
	title.position = Vector2(0, 250)
	title.z_index = 72
	title.modulate.a = 0.0
	scr.add_child(title)
	title.create_tween().tween_property(title, "modulate:a", 1.0, 0.4)
	var orbs := {}
	var els := ["F", "W", "A"]
	var px := 120.0
	for i in 3:
		var el: String = els[i]
		var orb := ElementIcon.make(el, px)
		orb.size = Vector2(px, px)
		orb.pivot_offset = orb.size / 2.0
		orb.position = from - orb.size / 2.0
		orb.scale = Vector2(0.3, 0.3)
		orb.z_index = 72
		orb.highlight = true
		orb.mouse_filter = Control.MOUSE_FILTER_STOP
		orb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		scr.add_child(orb)
		var n := UiTheme.label("−%d Essence" % counts.get(el, 0), 24, Color(1, 0.95, 0.85))
		n.add_theme_constant_override("outline_size", 6)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.size = Vector2(px + 80, 30)
		n.position = Vector2(-40, px + 12)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(n)
		# float softly up out of the card, then keep shining
		var to := Vector2(960 + (i - 1) * 260, 440) - orb.size / 2.0
		var tw := orb.create_tween().set_parallel(true)
		tw.tween_property(orb, "position", to, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property(orb, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_delay(i * 0.12)
		var glow := orb.create_tween().set_loops()
		glow.tween_property(orb, "modulate", Color(1.7, 1.6, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
		glow.tween_property(orb, "modulate", Color(1.2, 1.15, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		orb.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._element_chosen.emit(el))
		orbs[el] = orb
	Audio.play("spell_glow")
	scr._choosing_el = true
	var chosen: String = await scr._element_chosen
	scr._choosing_el = false
	title.create_tween().tween_property(title, "modulate:a", 0.0, 0.25)
	# the other two drift back into the card and vanish
	for el in orbs:
		var o: ElementIcon = orbs[el]
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if el == chosen:
			continue
		var back := o.create_tween().set_parallel(true)
		back.tween_property(o, "position", from - o.size / 2.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(o, "scale", Vector2(0.2, 0.2), 0.8)
		back.tween_property(o, "modulate:a", 0.0, 0.8)
		back.chain().tween_callback(o.queue_free)
	# the chosen one shakes violently and cracks, then shatters
	var ic: ElementIcon = orbs[chosen]
	for c in ic.get_children():
		c.queue_free()
	await scr._h_anim._wait(0.35)
	await scr._h_anim._crack_and_shatter(ic, 16.0, 1.6)
	var fade := dim.create_tween()
	fade.tween_property(dim, "color:a", 0.0, 0.35)
	fade.tween_callback(dim.queue_free)
	title.queue_free()
	return chosen


## How many different enemies a spell picks: 2 for "2 different enemies" (Glacial Spike), else 1. With no more enemies
## than that, it just hits them all: no aiming.
func _max_picks(spell: Dictionary) -> int:
	return 2 if spell.get("effects", []).any(func(e): return e.get("target", "") == "two") else 1


## The bow comes back from its aim.
func _aim_release(cr: Creature) -> void:
	await scr._h_anim._wait(0.4)
	if not is_instance_valid(cr):
		return
	var back := scr.create_tween()
	back.tween_property(cr, "aim", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.aim = 0.0
		cr.aim_dir = INF
