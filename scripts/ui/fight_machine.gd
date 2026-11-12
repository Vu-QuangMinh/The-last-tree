class_name FightMachine
extends RefCounted
## The Essence machine: launching, rolling, the tube and the tray (moved out of fight_screen.gd, docs/plan_dot3_kien_truc.md L15): the code is unchanged except that FightScreen's own members are reached through `scr.`.

var scr: FightScreen


func _init(p_owner: FightScreen) -> void:
	scr = p_owner


var _tube_gear: TextureRect


var _tube_handle: TextureRect


var _crank_tween: Tween


var _tube_hold_until := 0  # ticks: the tube rests, empty, until then (2 s after a launch)


var _tube_sync_pending := false


var _pending: Array = []  # balls a spell gave "for next turn": they lie in the tray on top of the machine; at the next spawn they go down with the others


## Puppet HUD ver 2: the vertical tube is two pictures, the back (z 59) under the Essence that fall and wait in it (z 60) and the front (z 61) over them; the right board is over the
## whole tube, so its right strip is drawn once more (z 62) over everything of the tube. They are children of the Bag strip, so they sink, fade and go away with the HUD
## (the tube only exists together with the HUD board and the Bag tray).
func _build_hud2_tube(holder: Control) -> void:
	var specs := [["hud2_tube_lower", Hud2Layout.TUBE_LOWER, 59], ["hud2_tube_upper", Hud2Layout.TUBE_UPPER, 61]]
	for sp in specs:
		var t := UiSkin.tex(sp[0])
		if t == null:
			continue
		var trect := TextureRect.new()
		trect.texture = t
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_SCALE
		trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var r := Hud2Layout.s(sp[1])
		trect.position = r.position - _bag_at()  # (local to the Bag strip)
		trect.size = r.size
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trect.z_index = sp[2]
		holder.add_child(trect)
	var bt := UiSkin.tex("hud2_board_right")
	if bt != null:
		var px := bt.get_width() / Hud2Layout.BOARD_RIGHT.size.x  # (source px per pt)
		var x0 := Hud2Layout.BOARD_COVER_X - Hud2Layout.BOARD_RIGHT.position.x
		var at := AtlasTexture.new()
		at.atlas = bt
		at.region = Rect2(x0 * px, 0.0, bt.get_width() - x0 * px, bt.get_height())
		var cover := TextureRect.new()
		cover.texture = at
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_SCALE
		cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var cr := Hud2Layout.s(Rect2(Hud2Layout.BOARD_COVER_X, Hud2Layout.BOARD_RIGHT.position.y, Hud2Layout.BOARD_RIGHT.end.x - Hud2Layout.BOARD_COVER_X, Hud2Layout.BOARD_RIGHT.size.y))
		cover.position = cr.position - _bag_at()
		cover.size = cr.size
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.z_index = 62
		holder.add_child(cover)


## The Bag strip's top-left on the screen.
func _bag_at() -> Vector2:
	return NewUiLayout.BAG_AT if scr._nu_ui else PuppetLayout.BAG_AT


## The Chant strip's top-left, from the Bag strip's.
func _chant_at() -> Vector2:
	return NewUiLayout.CHANT_AT if scr._nu_ui else PuppetLayout.CHANT_AT


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.custom_minimum_size = r.size
	c.size = r.size


## Where the k-th resting Essence of the bag sits (local to _stock_row) when there are n of them: Cirus lays them in one
## row from the strip's left end, squeezing together (even overlapping) when there are more than fit before the crank.
func _bag_slot(k: int, n: int) -> Vector2:
	if not scr._h_hud._circus_strips():
		return Vector2(minf(scr._stock_row.size.x - FightScreen.BAG_PX, k * (FightScreen.BAG_PX + FightScreen.BAG_GAP)), 0)
	if scr._h_hud._puppet_strips():
		var proom := (NewUiLayout.REST_END if scr._nu_ui else PuppetLayout.REST_END) - PuppetLayout.REST_X - FightScreen.BAG_PX
		var pstep := minf(NewUiLayout.RING_STEP if scr._nu_ui else PuppetLayout.RING_STEP, proom / maxf(1.0, n - 1))
		return Vector2(PuppetLayout.REST_X + minf(k * pstep, proom), PuppetLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)
	var room := ChantLayout.REST_END - ChantLayout.REST_X - FightScreen.BAG_PX
	var step := minf(FightScreen.BAG_PX + 4.0, room / maxf(1.0, n - 1))
	return Vector2(ChantLayout.REST_X + minf(k * step, room), ChantLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)


## The crank turns once and the gear twice (the same 0.9 s).
func _turn_crank(seconds := 0.9) -> void:
	if scr._h_hud._puppet_strips():
		return  # (the slot machine's lever is pulled by _puppet_launch)
	if _tube_handle == null or not is_instance_valid(_tube_handle) or (_crank_tween != null and _crank_tween.is_valid()):
		return
	_tube_handle.rotation = 0.0
	_tube_gear.rotation = 0.0
	Audio.play("sfx_crank_ratchet", -6.0)
	_crank_tween = scr.create_tween().set_parallel(true)
	_crank_tween.tween_property(_tube_handle, "rotation", TAU, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crank_tween.tween_property(_tube_gear, "rotation", TAU * 2.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crank_tween.chain().tween_callback(func():
		_tube_handle.rotation = 0.0
		_tube_gear.rotation = 0.0)


## Where the j-th of n Essence waiting in the tube sits (local to _stock_row): from the glass's left end, squeezing under
## the red block when there are many.
func _tube_pos(j: int, n: int) -> Vector2:
	var x0: float = ChantLayout.TUBE_GLASS.x + 28.0
	var step := minf(FightScreen.TUBE_BALL_STEP, (ChantLayout.TUBE_RIGHT - 8.0 - FightScreen.BAG_PX - x0) / maxf(1.0, n - 1))
	return Vector2(x0 + j * step, ChantLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)


## Where an Essence enters the tube: wholly inside the red block (it must never poke out of the tube's right end), so it
## is hidden there until it rolls out of it into the glass.
func _tube_hidden() -> Vector2:
	return Vector2(minf(ChantLayout.TUBE_HIDE_X + 8.0, ChantLayout.TUBE_RIGHT - FightScreen.BAG_PX - 10.0), ChantLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)


## A ball rolling left along the strip from where it is to to_x (spinning whole turns, so it ends upright); a soft tok at the
## end. Used for the Essence rolling into the tube.
func _roll_in(ic: ElementIcon, to_x: float, delay: float) -> void:
	scr._rolling_in += 1
	if delay > 0.0:
		await scr.get_tree().create_timer(delay).timeout
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		scr._rolling_in -= 1
		return
	var d := ic.position.x - to_x
	if d <= 1.0:
		ic.position.x = to_x
		scr._rolling_in -= 1
		return
	var t := 0.3 + d / 650.0
	var turns := roundf(d / (PI * FightScreen.BAG_PX))
	scr._h_anim._ball_sound("roll", -7.0, randf_range(0.9, 1.1))
	ic.set_meta("tube_to", to_x)
	var from_x := ic.position.x
	var tw := ic.create_tween().set_parallel(true)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			ic.position.x = _no_overlap(ic, lerpf(from_x, to_x, e), scr._tube_icons.filter(func(c): return c != ic and is_instance_valid(c) and c.has_meta("tube_to") and float(c.get_meta("tube_to")) < to_x)), 0.0, 1.0, t)
	tw.tween_property(ic, "rotation", -TAU * turns, t).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	scr._rolling_in -= 1
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		return
	ic.rotation = 0.0
	scr._h_anim._ball_sound("hit", -5.0, randf_range(0.85, 1.0))


## A rolling ball may not go through the ones in front of it (smaller x, on the same row): it stays one ball's width behind the nearest.
func _no_overlap(ic: Control, x: float, ahead: Array, gap := -1.0) -> float:
	if gap < 0.0:
		gap = FightScreen.BAG_PX + 3.0
	for o in ahead:
		if is_instance_valid(o) and o.position.x < ic.position.x - 1.0:  # (strictly in front: balls that wait at the same spot do not count)
			x = maxf(x, o.position.x + gap)
	return x


## Cirus "coming next turn": the tube holds next turn's Essence (fight.player.next_draw), in the bag's order (fire, water,
## wind). New ones are spawned inside the red block and roll out of it one by one; the others slide along to make room. A
## ball a spell sent is already waiting in the red block and just rolls in. After a launch the tube stays empty for 2 s.
func _sync_tube() -> void:
	if not scr._h_hud._circus_strips() or scr.fight == null or scr._tube_prep:
		return
	if Time.get_ticks_msec() < _tube_hold_until:  # (the tube is resting after a launch)
		if not _tube_sync_pending:
			_tube_sync_pending = true
			scr.get_tree().create_timer((_tube_hold_until - Time.get_ticks_msec()) / 1000.0 + 0.05).timeout.connect(func():
				_tube_sync_pending = false
				_sync_tube())
		return
	if scr._h_hud._puppet_strips():
		_sync_reels()
		return
	var ranked: Array = []
	for i in scr.fight.player.next_draw.size():
		var d: Dictionary = scr.fight.player.next_draw[i]
		ranked.append([maxi(0, "FWA".find(d.el) + 1), i, d])
	ranked.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var pool: Array = scr._tube_icons.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	var now: Array = []
	for r in ranked:
		var d: Dictionary = r[2]
		var found := -1
		for k in pool.size():
			if pool[k].el == d.el and pool[k].temp == d.temp:
				found = k
				break
		if found >= 0:
			now.append(pool[found])
			pool.remove_at(found)
			continue
		var nb := ElementIcon.make(d.el, FightScreen.BAG_PX)
		nb.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
		nb.pivot_offset = nb.size / 2.0
		nb.temp = d.temp
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.position = _tube_hidden()
		scr._stock_row.add_child(nb)
		now.append(nb)
	var keep: Array = []
	for c in pool:
		if c.has_meta("stash_until") and Time.get_ticks_msec() < int(c.get_meta("stash_until")):
			keep.append(c)  # (a spell's Essence that is still on its way in: the effect has not landed yet)
		else:
			c.queue_free()
	scr._tube_icons = now + keep
	var order := 0
	for j in now.size():
		var ic: ElementIcon = now[j]
		var to := _tube_pos(j, now.size())
		if ic.has_meta("slide"):
			var old: Tween = ic.get_meta("slide")
			if old != null and old.is_valid():
				old.kill()
		if ic.position.x >= ChantLayout.TUBE_HIDE_X - 2.0:  # still inside the red block: it rolls out of it, one after another
			_roll_in(ic, to.x, order * 0.15)
			order += 1
		elif absf(ic.position.x - to.x) > 1.0:
			var tw := ic.create_tween()
			tw.tween_property(ic, "position", to, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ic.set_meta("slide", tw)


## Cirus: a spell that gives Essence for next turn. Each one flies from the card to the tube and slips in behind the red block
## (it is drawn under the tube's glass layer); once the effect has landed, _sync_tube rolls it into the tube.
func _stash_flight(ev: Dictionary, from: Vector2) -> float:
	if scr._h_hud._puppet_strips():
		return _stash_to_machine(ev, from)
	var els: Array = ev.get("drawn", [])
	if els.is_empty():
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var last := 0.0
	for i in els.size():
		var ic := ElementIcon.make(els[i], FightScreen.BAG_PX)
		ic.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.temp = ev.eff.get("temp", false)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var a := from - scr._stock_row.global_position - ic.size / 2.0
		var b := _tube_hidden()
		ic.position = a
		ic.scale = Vector2(0.4, 0.4)
		ic.modulate = Color(1.6, 1.6, 1.6, 0.0)
		ic.set_meta("stash_until", Time.get_ticks_msec() + 4000)
		scr._stock_row.add_child(ic)
		scr._tube_icons.append(ic)
		var delay: float = i * 0.14
		var tw := ic.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			Audio.play("spell_glow", -7.0, randf_range(1.15, 1.35))  # (it leaves the card: a bright whoosh)
			scr._h_anim._ball_sound("hit", -6.0, 1.2))
		tw.tween_method(_stash_step.bind(ic, a, b), 0.0, 1.0, 0.62)
		tw.tween_callback(func():
			ic.rotation = 0.0
			ic.modulate = Color.WHITE
			ic.position = b)
		last = delay + 0.62
	return last + 0.1


## Puppet Stage: Essence a Lens (or the Storm Crown) gives back leave their chant slot, fly to the top funnel and come out of the port like any bonus Essence: the
## Bag's own ball (hidden until then) makes the whole trip. The one whose home is furthest left goes first (the balls cannot pass each other).
func _refund_flight(ev: Dictionary) -> void:
	if not scr._h_hud._puppet_strips() or scr._stock_row == null:
		return
	var uids: Array = ev.uids
	scr._keep_bag_order = true  # (the refunded balls roll to the back of the Bag: nothing is placed ahead of time or sorted until the next spawn)
	for u in uids:
		scr._flying[u] = true
	scr._h_hud._refresh_stock()
	var by_home: Array = range(mini(ev.els.size(), uids.size()))  # (never more than there are new Essence)
	by_home.sort_custom(func(x: int, y: int) -> bool: return float(scr._bag_target.get(uids[x], Vector2.ZERO).x) < float(scr._bag_target.get(uids[y], Vector2.ZERO).x))
	for k in by_home.size():
		var i: int = by_home[k]
		var uid: int = uids[i]
		var slot: int = clampi(int(ev.slots[i]) if i < ev.slots.size() else scr.fight.chant.size() - 1, 0, maxi(0, scr.fight.chant.size() - 1))
		scr._flying.erase(uid)
		var real: ElementIcon = scr._bag_icons.get(uid)
		if real != null and is_instance_valid(real):
			real.set_meta("rolling", true)
			real.modulate.a = 0.0
			scr._bonus_from = scr._h_hud._chant_slot_center(slot)
			_tube_launch([[real, scr._bag_target.get(uid, real.position), uid]])
		else:
			scr._h_hud._refresh_stock()
		await scr._h_anim._wait(0.18)
	await scr._h_anim._wait(0.5)


func _stash_step(u: float, ic: ElementIcon, a: Vector2, b: Vector2) -> void:
	if not is_instance_valid(ic):
		return
	var arc := Vector2(0, -150.0 * sin(u * PI))  # up and over, then down into the tube
	ic.position = a.lerp(b, u * u * (3.0 - 2.0 * u)) + arc
	ic.rotation = -u * TAU * 1.5
	ic.scale = Vector2.ONE * lerpf(0.4, 1.0, minf(1.0, u * 2.0))
	var al := minf(1.0, u * 14.0)
	ic.modulate = Color(1, 1, 1, al).lerp(Color(1.6, 1.6, 1.6, al), 1.0 - u)


## Wait until nothing is rolling any more (the Essence of a launch, or going into the tube): effects that land ON the Essence
## (Freeze, Hex...) start after that.
func _rolls_done() -> void:
	var t0 := Time.get_ticks_msec()
	while (scr._launching > 0 or scr._rolling_in > 0) and Time.get_ticks_msec() - t0 < 7000:
		await scr.get_tree().process_frame


## A batch of new Essence rolls out of the tube. At the start of a turn these ARE the Essence that were waiting in the
## tube (they take their places); any others (the first hand of a fight, Essence conjured "now") roll in from the red block
## first. The crank turns once, the gear twice, and the balls roll out and left along the strip, like billiard balls, to
## their places, the first one going furthest. Each stop is a "tok", and the ball it hit rocks a little. 2 s after the last
## ball has left, the tube is loaded for the next turn. balls: [[icon, rest position (local to _stock_row), uid], ...].
func _tube_launch(balls: Array) -> void:
	if balls.is_empty():
		return
	if scr._h_hud._puppet_strips():
		_puppet_launch(balls)
		return
	scr._launching += 1
	balls.sort_custom(func(a, b): return a[1].x < b[1].x)
	var n := balls.size()
	var from_tube := Time.get_ticks_msec() < scr._turn_batch_until
	scr._turn_batch_until = 0
	var pool: Array = scr._tube_icons.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	pool.sort_custom(func(a, b): return a.position.x < b.position.x)
	var starts_x: Array = []
	var dropped := 0
	scr._tube_prep = true  # (the tube is not reloaded until we know when the last ball leaves)
	for j in n:
		var ic: ElementIcon = balls[j][0]
		ic.set_meta("rolling", true)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var taken := -1
		if from_tube:
			for k in pool.size():
				if pool[k].el == ic.el and pool[k].temp == ic.temp:
					taken = k
					break
		if taken >= 0:  # the ball that was waiting in the tube becomes this one
			var waiting: ElementIcon = pool[taken]
			pool.remove_at(taken)
			ic.position = waiting.position
			ic.modulate.a = 1.0
			starts_x.append(waiting.position.x)
			waiting.queue_free()
		else:  # it rolls out of the red block into the glass first
			var at := _tube_pos(dropped, n)
			ic.modulate.a = 1.0
			ic.position = _tube_hidden()
			_roll_in(ic, at.x, dropped * 0.15)
			dropped += 1
			starts_x.append(at.x)
	scr._tube_icons = pool  # (whatever was not taken stays waiting)
	var load_wait := 0.1
	if dropped > 0:
		load_wait = 0.8 + (dropped - 1) * 0.15
	await scr.get_tree().create_timer(load_wait).timeout
	_turn_crank()
	await scr.get_tree().create_timer(0.3).timeout
	# when does each ball arrive? one after the other, 0.12 s apart, the first one furthest
	var travel: Array = []
	var starts: Array = []
	var arrive_t := 0.0
	var last_start := 0.0
	for j in n:
		var d: float = float(starts_x[j]) - balls[j][1].x
		var t := 0.25 + maxf(0.0, d) / 820.0
		travel.append(t)
		arrive_t = t if j == 0 else maxf(t, arrive_t + 0.12)
		starts.append(arrive_t - t)
		last_start = maxf(last_start, arrive_t - t)
	_tube_hold_until = Time.get_ticks_msec() + int((last_start + 2.0) * 1000.0)  # the tube reloads 2 s after the last ball is away
	scr._tube_prep = false
	for j in n:
		_roll_ball(balls, j, float(starts_x[j]), float(travel[j]), float(starts[j]))
	scr._launching -= 1
	_sync_tube()  # (it waits for _tube_hold_until)


## A ball rolling to its place: a steady speed, and only the last quarter of the trip slows to a stop. (The old quadratic ease-out slowed every ball
## down from the start; the ones behind were held back by the one in front, so the whole line seemed to stall on the way before it settled.)
func _roll_ease(u: float) -> float:
	var f := 0.25
	var c := 1.0 / (1.0 - f / 2.0)
	if u <= 1.0 - f:
		return c * u
	var w := 1.0 - u
	return c * (1.0 - f) + c * (f / 2.0 - w * w / (2.0 * f))


func _roll_ball(balls: Array, j: int, from_x: float, t: float, delay: float) -> void:
	if not is_instance_valid(balls[j][0]):
		return  # (freed before its turn to roll)
	var ic: ElementIcon = balls[j][0]
	var uid: int = balls[j][2]
	var turns := roundf(maxf(0.0, from_x - balls[j][1].x) / (PI * FightScreen.BAG_PX))  # whole turns, so it comes to rest the right way up
	scr._launching += 1
	await scr.get_tree().create_timer(delay).timeout
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		scr._launching -= 1
		return
	scr._h_anim._ball_sound("roll", -8.0, randf_range(0.95, 1.05))
	var goal_x: float = scr._bag_target.get(uid, balls[j][1]).x
	# (with many balls in the Bag the places are closer than a ball is wide: the gap that ball keeps is never more than the distance between two places)
	var slot_gap := minf(FightScreen.BAG_PX + 3.0, absf(_bag_slot(1, maxi(2, scr._bag_order.size())).x - _bag_slot(0, maxi(2, scr._bag_order.size())).x))
	var others: Array = []
	for k in balls.size():
		if k != j:
			others.append(balls[k][0])
	if scr._stock_row != null:  # (the balls of another launch that are still rolling count too: a refund sends its balls one at a time)
		for c in scr._stock_row.get_children():
			if c is ElementIcon and c != ic and c.has_meta("rolling") and not others.has(c):
				others.append(c)
	var tw := ic.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			var e := _roll_ease(u)  # (the same curve for the slide and the spin, so the ball really rolls instead of skidding)
			ic.position.x = _no_overlap(ic, lerpf(from_x, goal_x, e), others, slot_gap)
			ic.rotation = -TAU * turns * e, 0.0, 1.0, t)
	await tw.finished
	scr._launching -= 1
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		return
	ic.rotation = 0.0
	ic.remove_meta("rolling")
	ic.mouse_filter = Control.MOUSE_FILTER_STOP
	ic.position = scr._bag_target.get(uid, ic.position)
	scr._h_anim._ball_sound("hit", -3.0 if j > 0 else -8.0, randf_range(0.95, 1.08))
	if j > 0:  # the ball it hit rocks a little
		var prev = balls[j - 1][0]  # (untyped: the ball it hit may have been freed meanwhile, e.g. stolen out of the bag, and a typed variable cannot hold that)
		if is_instance_valid(prev) and not prev.has_meta("rolling"):
			var rock: Tween = prev.create_tween()
			rock.tween_property(prev, "position:x", prev.position.x - 4.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rock.tween_property(prev, "position:x", prev.position.x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if scr._launching == 0:
		scr._h_hud._resort_bag()  # (Puppet Stage: the shooting is over, now the balls swap into their types)


## Puppet HUD ver 2: an Essence in the vertical tube is 60 pt = 56 px, as the page shows them.
func _ball_k() -> float:
	return Hud2Layout.BALL_PT * Hud2Layout.K / FightScreen.BAG_PX if NewUiLayout.hud2 else FightScreen.SLOT_BALL_SCALE


func _tray_k() -> float:
	return Hud2Layout.BALL_PT * Hud2Layout.K / FightScreen.BAG_PX if NewUiLayout.hud2 else FightScreen.TRAY_SCALE


## The reels at rest show next turn's draw (in the Bag's order, three at most): what is about to spawn.
func _sync_reels() -> void:
	return  # (the faces on the reels are pictures of what was rolled at the lever: a bonus Essence never changes them; the old body that re-ranked them is in git history before 2026-11-12)


func _path_point(pts: Array, at: float) -> Vector2:
	var acc := 0.0
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if at <= acc + seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf((at - acc) / maxf(seg, 0.001), 0.0, 1.0))
		acc += seg
	return pts[pts.size() - 1]


## An Essence's trip to the Bag, set up as one tween on the icon: it starts `delay` seconds from now, mode "reel" (it takes over from the Essence dropping out of a reel: it
## starts in the bottom funnel), "from" (it flies from `from_local` into the top funnel first), "tray" (it lay in the tray at `from_local` and slips into the funnel)
## or "pop" (it pops up over the top funnel), then it falls through the machine,
## goes down the tube, shrinks into the cap at the Bag strip's edge and comes up out of the port. Returns when it is up (seconds from now).
## New UI: how long an Essence's trip takes from the start of `mode` until it has come up out of the circle (see _slot_route).
func _slot_route_time(mode: String, from_local: Vector2) -> float:
	var m := scr._machine
	var pts: Array = [from_local, m.funnel_bottom_in()] if mode == "reel" else _funnel_sink(m)
	if mode == "reel":
		pts = [from_local, Vector2(from_local.x, NewUiLayout.TUBE_ROW_Y)]
	pts.append_array(m.tube_path())
	var fly: float = {"from": 0.5, "pop": 0.28, "tray": 0.2}.get(mode, 0.0)
	return fly + _path_len(pts) / FightScreen.NU_TUBE_SPEED + (FightScreen.NU_EMERGE_T if NewUiLayout.v2 else 0.0)


## A bonus Essence's way from the funnel's mouth to where it enters the tube. NewUI Ver2: it sinks straight down into the funnel (behind its upper layer, then behind the machine's body) before it turns towards the tube.
func _funnel_sink(m: SlotMachine) -> Array:
	var mouth := m.funnel_top_mouth()
	if NewUiLayout.v2:
		return [mouth, mouth + Vector2(0.0, 70.0), m.funnel_bottom_in()]
	return [mouth, m.funnel_bottom_in()]


func _path_len(pts: Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


func _slot_route(ic: ElementIcon, delay: float, mode: String, from_local := Vector2.ZERO) -> float:
	var m := scr._machine
	var half := ic.size / 2.0
	var row_y := PuppetLayout.AXIS_Y - FightScreen.BAG_PX / 2.0
	var pts: Array = [from_local, m.funnel_bottom_in()] if mode == "reel" else _funnel_sink(m)
	if scr._nu_ui and mode == "reel":  # (New UI: straight down from its reel to the tube's row, so the three come to the tube in the order of the reels)
		pts = [from_local, Vector2(from_local.x, NewUiLayout.TUBE_ROW_Y)]
	pts.append_array(m.tube_path())
	var total := _path_len(pts)
	var dur := total / (FightScreen.NU_TUBE_SPEED if scr._nu_ui else FightScreen.SLOT_TUBE_SPEED)
	ic.position = Vector2(m.port_center().x + 400.0, row_y)  # (parked out of the way until its turn: it must not count as a ball in front of the others)
	ic.rotation = 0.0
	ic.modulate.a = 0.0
	ic.scale = Vector2.ONE * _ball_k()
	var mouth := m.funnel_top_mouth()
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	var fly := 0.0
	if mode == "from":
		fly = 0.5
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 1.0
				ic.scale = Vector2.ONE * 0.4)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				var e := u * u * (3.0 - 2.0 * u)
				ic.position = from_local.lerp(mouth, e) + Vector2(0.0, -110.0 * sin(u * PI)) - half
				ic.rotation = -u * TAU * 1.5
				ic.scale = Vector2.ONE * lerpf(0.4, _ball_k(), minf(1.0, u * 2.0)), 0.0, 1.0, fly)
	elif mode == "pop":
		fly = 0.28
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 0.0
				ic.scale = Vector2.ONE * 0.3)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				ic.position = mouth + Vector2(0.0, lerpf(-80.0, 0.0, u * u)) - half
				ic.modulate.a = minf(1.0, u * 4.0)
				ic.scale = Vector2.ONE * lerpf(0.3, _ball_k(), minf(1.0, u * 2.0)), 0.0, 1.0, fly)
	elif mode == "tray":  # (it lay in the tray at from_local: it slips off into the funnel's mouth)
		fly = 0.2
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 1.0
				ic.scale = Vector2.ONE * _tray_k()
				ic.position = from_local - half)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				ic.position = from_local.lerp(mouth, u * u) - half
				ic.scale = Vector2.ONE * lerpf(_tray_k(), _ball_k(), u), 0.0, 1.0, fly)
	else:  # (mode "reel": it starts hidden behind the cabinet, where its reel is)
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.position = pts[0] - half
				ic.modulate.a = 1.0)
	var edge_x := NewUi2Layout.BAG_EDGE_X - NewUiLayout.BAG_AT.x if NewUiLayout.v2 else -99999.0
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			var at := _path_point(pts, u * total)
			ic.position = at - half
			ic.rotation = -u * TAU * maxf(1.0, roundf(total / (PI * FightScreen.BAG_PX)))
			ic.scale = Vector2.ONE * _ball_k()
			if NewUiLayout.v2:  # (NewUI Ver2: the tube lies UNDER the Bag tray: the Essence goes in under its edge and is out of sight until the hole)
				ic.modulate.a = clampf((at.x - (edge_x - FightScreen.BAG_PX * 0.5)) / (FightScreen.BAG_PX * 0.5), 0.0, 1.0), 0.0, 1.0, dur)
	if NewUiLayout.v2:  # (...and comes up out of the hole: it rises from deeper down, growing, then rolls on along the Bag)
		var mouth_at: Vector2 = pts[pts.size() - 1]
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				var e := 1.0 - (1.0 - u) * (1.0 - u)
				ic.position = mouth_at + Vector2(0.0, lerpf(FightScreen.BAG_PX * 0.35, 0.0, e)) - half
				ic.modulate.a = minf(1.0, u * 3.0)
				ic.scale = Vector2.ONE * _ball_k() * lerpf(0.45, 1.0, e)
				ic.rotation = 0.0, 0.0, 1.0, FightScreen.NU_EMERGE_T)
		return delay + fly + dur + FightScreen.NU_EMERGE_T
	# out of the tube it keeps rolling, straight into the Bag strip (no hole: one continuous roll), growing to its full size; _roll_ball takes over from there
	var tube_end: Vector2 = pts[pts.size() - 1]
	if scr._nu_ui:  # (the tube is straight: the Essence runs out of its mouth into the Bag tray, where _nu_roll takes it on at the same speed)
		return delay + fly + dur
	var entry := Vector2(m.port_center().x, row_y + half.y)
	var spin0 := -TAU * maxf(1.0, roundf(total / (PI * FightScreen.BAG_PX)))
	var out_t := maxf(0.05, tube_end.distance_to(entry) / FightScreen.SLOT_TUBE_SPEED)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			ic.position = tube_end.lerp(entry, u) - half
			ic.rotation = spin0 - u * TAU  # (one whole turn: it ends upright, where the roll along the Bag starts)
			ic.scale = Vector2.ONE * lerpf(_ball_k(), 1.0, u), 0.0, 1.0, out_t)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ic):
			ic.rotation = 0.0)
	return delay + fly + dur + out_t


## Pull the lever, spin the reels for 2 s and stop them on these Essence (they stay there: next turn they drop out). One sound covers the pull and the return.
func _roll_reels(els: Array) -> void:
	if scr._machine.headless:  # (Puppet HUD ver 2: no machine, nothing to roll)
		scr._reel_shown = els.duplicate()
		scr._reels_armed = true
		return
	Audio.play("sfx_lever_pull", -2.0)
	scr._machine.lever_pull()
	await scr.get_tree().create_timer(0.3).timeout
	await scr._machine.spin(els, 2.0)
	scr._machine.lever_return()
	scr._machine.busy = false
	scr._reel_shown = els.duplicate()
	scr._reels_armed = true


## Once the balls of a spawn are all in the Bag (`wait` seconds is when the last one comes up out of the port), the machine rolls next turn's draw: the lever is
## pulled, the reels spin for 2 s and stop on the Essence that will spawn next turn.
func _roll_next_on_reels(wait: float) -> void:
	await scr.get_tree().create_timer(wait + 0.4).timeout
	var t0 := Time.get_ticks_msec()
	while scr._launching > 0 and Time.get_ticks_msec() - t0 < 8000 and scr.is_inside_tree():
		await scr.get_tree().process_frame
	await scr.get_tree().create_timer(0.3).timeout
	if not scr.is_inside_tree() or scr._machine == null or scr.fight == null or scr.fight.over or scr._machine.busy or scr._launching > 0 or Time.get_ticks_msec() < scr._turn_batch_until:
		return
	var ranked: Array = []
	for i in scr.fight.player.next_draw.size():
		var d: Dictionary = scr.fight.player.next_draw[i]
		ranked.append([maxi(0, "FWA".find(d.el) + 1), i, d])
	ranked.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var els: Array = []
	for r in ranked:
		if els.size() < 3:
			els.append(r[2].el)
	await _roll_reels(els)


## The centre of the k-th Essence lying in the tray (local to the Bag strip): side by side over the funnel's mouth, three to a row, the next row on top.
func _tray_center(k: int) -> Vector2:
	if scr._machine.headless:  # (Puppet HUD ver 2: they wait one above the other in the vertical tube)
		return Hud2Layout.stack_pos(k)
	var mouth := scr._machine.funnel_top_mouth()
	var step := FightScreen.BAG_PX * _tray_k() * 0.82
	var row := floori(k / 3.0)
	var col := k % 3
	var x := mouth.x + (col - 1) * step + (step * 0.5 if row % 2 == 1 else 0.0)
	return Vector2(x, mouth.y - FightScreen.BAG_PX * _tray_k() * 0.42 - row * step * 0.8)


## Artifacts that give Essence for next turn: each one shines up briefly, then a ball of light flies from it to the tray
## on top of the machine and materializes there (like a spell's "gain Essence next turn"). Shown once per Essence.
func _stash_artifact_draws(for_turn: int) -> void:
	if not scr._h_hud._puppet_strips() or scr._stock_row == null or scr._arts == null:
		return
	var by_art := {}
	for d in scr.fight.player.next_draw:
		if d.has("from") and not d.get("shown", false):
			d.shown = true
			if not by_art.has(d.from):
				by_art[d.from] = []
			by_art[d.from].append(d.el)
	for id in by_art:
		scr._arts.flash(id)
		var at = scr._arts.chip_center(id)
		if at == null:
			continue
		await scr._h_anim._wait(0.25)  # (it shines up first)
		var before := _pending.size()
		_stash_to_machine({"drawn": by_art[id], "eff": {"op": "draw", "n": by_art[id].size(), "when": "next"}}, at)
		for k in range(before, _pending.size()):
			_pending[k].set_meta("for_turn", for_turn)
		await scr._h_anim._wait(0.2)


func _stash_to_machine(ev: Dictionary, from: Vector2) -> float:
	var els: Array = ev.get("drawn", [])
	if els.is_empty():
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var dests := []
	var base_k := _pending.size()
	for i in els.size():
		var ic := ElementIcon.make(els[i], FightScreen.BAG_PX)
		ic.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.temp = ev.eff.get("temp", false)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.scale = Vector2.ONE * _tray_k()
		ic.modulate.a = 0.0  # (it shows when its comet lands)
		var c := _tray_center(base_k + i)
		ic.position = c - ic.size / 2.0
		scr._stock_row.add_child(ic)
		_pending.append(ic)
		dests.append({"body": scr._stock_row.global_position + c, "row": scr._stock_row.global_position + c, "el": els[i], "px": FightScreen.BAG_PX * _tray_k(), "ghost": false})  # (no copy on top: the real one shows behind the tray's front wall)
		# (SpellFx._draw_fx: the i-th comet lands 0.13 s after the one before it, 0.6 s after it set off; it materializes there and this Essence takes over)
		var tw := ic.create_tween()
		tw.tween_interval(i * 0.13 + 0.62)
		tw.tween_callback(func() -> void: scr._h_anim._ball_sound("hit", -9.0, randf_range(1.05, 1.2)))
		tw.tween_property(ic, "modulate:a", 1.0, 0.25)
	return SpellFx.play(scr._fx, "draw", ev.eff, from, dests, Color.WHITE, Vector2.ZERO, scr._h_anim._shake, scr._h_anim._hitstop)


## New balls of the Bag (rolled: [[icon, place, uid]]) come out of the machine. See the block comment above.
## The first hand of a fight: one Essence of each element is in the Bag already when the fight opens; only the rest come out of the machine.
func _puppet_launch(balls: Array) -> void:
	scr._launching += 1
	scr._tube_prep = true
	balls.sort_custom(func(a, b): return a[1].x < b[1].x)
	var first_hand := not scr._spawned_once
	var spawn := Time.get_ticks_msec() < scr._turn_batch_until or first_hand
	scr._keep_bag_order = not spawn  # (a spawn: when its balls are all in, the Bag sorts itself once; a bonus / refund: it keeps its order, the new balls stay at the back)
	scr._turn_batch_until = 0
	scr._spawned_once = true
	var from_pt := scr._bonus_from
	scr._bonus_from = Vector2.INF
	for b in balls:
		var hidden_ic: ElementIcon = b[0]
		hidden_ic.set_meta("rolling", true)
		hidden_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hidden_ic.modulate.a = 0.0
		hidden_ic.position = Vector2(scr._machine.port_center().x + 400.0, PuppetLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)  # (out of the way)
	# who is who. The first hand: one of each element is already in the Bag ("preset"). At a spawn, a ball whose twin lies in the tray (a spell gave it "for next
	# turn") comes from the tray ("tray"); the first three of the others come out of the reels ("reel"); the rest pop over the top funnel ("extra").
	var n := balls.size()
	var role: Array = []
	role.resize(n)
	role.fill("extra")
	if first_hand:
		for el in ["F", "W", "A"]:
			for j in n:
				if role[j] == "extra" and balls[j][0].el == el:
					role[j] = "preset"
					break
	var twin_of := {}
	if spawn:
		var pool: Array = _pending.filter(func(c): return is_instance_valid(c) and int(c.get_meta("for_turn", scr.fight.turn)) <= scr.fight.turn)  # (not the ones already lying there for the turn after)
		for j in n:
			if role[j] != "extra":
				continue
			for k in pool.size():
				if pool[k].el == balls[j][0].el:
					twin_of[j] = pool[k]
					pool.remove_at(k)
					role[j] = "tray"
					break
	var reel_of := {}  # ball index -> reel
	if spawn:
		var r_i := 0
		for j in n:
			if role[j] == "extra" and r_i < 3:
				role[j] = "reel"
				reel_of[j] = r_i
				r_i += 1
	# The balls come out of the port one after another and cannot pass each other: the first out gets the home furthest left, the next the next one, and so on. The
	# Essence already in the Bag take the first homes; then the reels' balls, then the tray's, then the rest (the order they come out in). Which Essence is which does
	# not change; the ones that swapped homes slide into their types after (_resort_bag).
	var homes: Array = balls.map(func(b): return b[1])
	homes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var slots_in_order: Array = []  # the places in _bag_order the batch holds
	var batch_uids: Array = balls.map(func(b): return b[2])
	for k in scr._bag_order.size():
		if scr._bag_order[k] in batch_uids:
			slots_in_order.append(k)
	var order: Array = []
	for want in (["preset", "tray", "reel", "extra"] if scr._machine.headless else ["preset", "reel", "tray", "extra"]):  # (Puppet HUD ver 2: the ones already in the tube go first)
		var group: Array = []
		for j in n:
			if role[j] == want:
				group.append(j)
		if want == "reel":
			group.sort_custom(func(a, b): return reel_of[a] < reel_of[b])
		order.append_array(group)
	for k in n:
		var j: int = order[k]
		var uid_j: int = balls[j][2]
		balls[j][1] = homes[k]
		scr._bag_target[uid_j] = homes[k]
		if is_instance_valid(balls[j][0]):
			(balls[j][0] as Control).set_meta("goal", homes[k])
		if k < slots_in_order.size():
			scr._bag_order[slots_in_order[k]] = uid_j
	# the first hand's one of each element: in its place at once, no trip through the machine
	for j in n:
		if role[j] == "preset" and is_instance_valid(balls[j][0]):
			var pic: ElementIcon = balls[j][0]
			pic.remove_meta("rolling")
			pic.mouse_filter = Control.MOUSE_FILTER_STOP
			pic.position = balls[j][1]
			pic.rotation = 0.0
			pic.scale = Vector2.ONE
			pic.modulate.a = 1.0
	# the machine is on the HUD: when the HUD is still below the screen (the fight is being set up) it waits
	while (scr._h_hud._hud_hidden() or not scr._machine_ready) and scr.is_inside_tree():
		await scr.get_tree().process_frame
	if not scr.is_inside_tree() or scr._machine == null:
		scr._launching -= 1
		scr._tube_prep = false
		return
	if spawn:
		var finals: Array = []
		for j in order:
			if role[j] == "reel":
				finals.append(balls[j][0].el)
		while scr._machine.busy and scr.is_inside_tree():  # (the reels are still rolling next turn's draw: wait for them)
			await scr.get_tree().process_frame
		if scr._reel_shown.is_empty():  # the first hand of a fight: nothing was rolled yet, so the lever is pulled now
			if not finals.is_empty():
				await _roll_reels(finals)
		elif finals != scr._reel_shown:  # (what spawns is not what the reels showed: they show what really spawns)
			scr._machine.set_faces(finals, true)
			await scr.get_tree().create_timer(0.25).timeout
		scr._reel_shown = []
		scr._reels_armed = false
	var gap := 0.26 if scr._nu_ui else 0.2  # (New UI: the orbs run one after another, 160 px apart)
	var emerge: Array = []  # seconds from now until each ball comes up out of the port
	emerge.resize(n)
	emerge.fill(0.0)
	var tray_k := 0
	var extra_k := 0
	var n_tray := role.count("tray")
	# New UI: the balls come up out of the circle one after another, `gap` apart whatever way each one took (the next only starts when the one before has rolled away)
	var nu_next := [0.0]
	var pick_delay := func(default_d: float, mode: String, from_local: Vector2) -> float:
		if not scr._nu_ui:
			return default_d
		var rt := _slot_route_time(mode, from_local)
		var e: float = maxf(nu_next[0], rt)
		nu_next[0] = e + gap
		return e - rt
	var hud2_emerge: Dictionary = _hud2_launch(order, role, balls, twin_of, from_pt, spawn) if scr._machine.headless else {}
	for j in order:
		var ic = balls[j][0]  # (untyped: it may have been freed while the reels spun, e.g. the tutorial moved on)
		if not is_instance_valid(ic) or role[j] == "preset":
			continue
		if hud2_emerge.has(j):  # (Puppet HUD ver 2: the vertical tube is simulated as a whole, see _hud2_launch)
			emerge[j] = hud2_emerge[j]
			continue
		if role[j] == "reel":  # (the real ball falls from behind the cabinet into the bottom funnel; the faces on the reels are only pictures and stay until the next roll)
			var rc: Vector2 = scr._machine.reel_center(reel_of[j])
			emerge[j] = _slot_route(ic, pick_delay.call(reel_of[j] * gap, "reel", rc), "reel", rc)
		elif role[j] == "tray":  # it goes down with the others: it slips off the tray into the funnel (the real ball takes over from the one lying there)
			var lying = twin_of[j]  # (untyped: it may have been freed meanwhile)
			_pending.erase(lying)
			var at: Vector2 = (lying.position + lying.size / 2.0) if is_instance_valid(lying) else scr._machine.funnel_top_mouth()
			var d: float = pick_delay.call(0.45 + tray_k * gap, "tray", at)
			tray_k += 1
			scr.get_tree().create_timer(d).timeout.connect(func() -> void:
				if is_instance_valid(lying):
					lying.queue_free())
			emerge[j] = _slot_route(ic, d, "tray", at)
		else:
			var d0 := (0.45 + (n_tray + extra_k) * gap) if spawn else extra_k * gap
			extra_k += 1
			if from_pt != Vector2.INF and not spawn:
				var fl := from_pt - scr._stock_row.global_position
				emerge[j] = _slot_route(ic, pick_delay.call(d0, "from", fl), "from", fl)
			else:
				emerge[j] = _slot_route(ic, pick_delay.call(d0, "pop", Vector2.ZERO), "pop")
	var port_x: float = scr._machine.port_center().x - FightScreen.BAG_PX / 2.0
	var last_emerge := 0.0
	var rollers: Array = []  # (the balls that roll in; the ones already in the Bag don't)
	for j in order:
		if role[j] != "preset":
			rollers.append(balls[j])
	var nu_b := _nu_brake(port_x, rollers.map(func(b): return b[1])) if scr._nu_ui and not rollers.is_empty() else 0.0
	for r in rollers.size():
		var j: int = balls.find(rollers[r])
		last_emerge = maxf(last_emerge, float(emerge[j]))
		if scr._nu_ui:
			last_emerge = maxf(last_emerge, _nu_roll(rollers[r][0], rollers[r][1], float(emerge[j]), port_x, nu_b, FightScreen.NU_TUBE_SPEED))
			continue
		var dx := port_x - float(rollers[r][1].x)
		_roll_ball(rollers, r, port_x, 0.25 + maxf(0.0, dx) / 820.0, float(emerge[j]))
	_tube_hold_until = Time.get_ticks_msec() + int((last_emerge + 1.0) * 1000.0)  # the reels show the next draw again a second after the last ball is out
	scr._tube_prep = false
	scr._machine.busy = false  # (the faces of the reels are on their way out)
	scr._launching -= 1
	_sync_tube()  # (it waits for _tube_hold_until)
	if spawn:
		_roll_next_on_reels(last_emerge)  # (as soon as these balls are in the Bag, the lever is pulled for the next turn's draw)
	if rollers.is_empty():
		scr._h_hud._resort_bag()  # (nothing rolled: nothing else will sort the Bag)


## ---- Puppet HUD ver 2: the Essence in the vertical tube are real objects ---------------------------------------------------------------------------------------------
## They stand one above the other in the tube (the first one in at the bottom, at the bend), nobody passes anybody, and they leave in the order they came in. A launch is
## simulated once (every 1/60 s: gravity down the tube, a ball is stopped by the one below it, the lowest one is let go after it has waited a moment, the next ones one gap
## later) and every ball then plays back its own track along the tube's centre line (top, down, round the bend, into the hole).


func _hud2_track() -> Array:
	var L = NewUiLayout
	var k: float = Hud2Layout.K
	var out: Array = []
	for p in Hud2Layout.track_pts():  # (drop, the first waiting places, the bend, and for MinhHUD the loop round the flask)
		out.append(p * k - L.BAG_AT)
	out.append(Vector2(L.MOUTH_X, L.TUBE_ROW_Y))
	return out


func _hud2_at(track: Array, s: float) -> Vector2:
	var acc := 0.0
	for i in track.size() - 1:
		var seg: float = track[i].distance_to(track[i + 1])
		if s <= acc + seg or i == track.size() - 2:
			return track[i].lerp(track[i + 1], clampf((s - acc) / maxf(seg, 0.001), 0.0, 1.0))
		acc += seg
	return track[track.size() - 1]


## How far down the track (px) the point `p` is (the nearest point of the track).
func _hud2_project(track: Array, p: Vector2) -> float:
	var best := 0.0
	var best_d := INF
	var acc := 0.0
	for i in track.size() - 1:
		var a: Vector2 = track[i]
		var b: Vector2 = track[i + 1]
		var seg := a.distance_to(b)
		var u := clampf((p - a).dot(b - a) / maxf(seg * seg, 0.001), 0.0, 1.0)
		var d := p.distance_to(a.lerp(b, u))
		if d < best_d:
			best_d = d
			best = acc + u * seg
		acc += seg
	return best


## The furthest down the track a ball can be when the one below it is at `s_prev`: their centres must be a whole ball apart in a straight line (round the bend, along the track
## alone is not enough).
func _hud2_behind(track: Array, s_prev: float, pitch: float) -> float:
	var p := _hud2_at(track, s_prev)
	var d := s_prev - pitch
	while d > -400.0 and _hud2_at(track, d).distance_to(p) < pitch:
		d -= 1.5
	return d


func _hud2_released_before(st: PackedInt32Array, i: int) -> bool:
	return i == 0 or st[i - 1] >= 2


## Sets up the whole launch: `order` is the order the balls go in. Returns ball index -> seconds from now until it is in the hole (where _nu_roll takes it on).
func _hud2_launch(order: Array, role: Array, balls: Array, twin_of: Dictionary, from_pt: Vector2, spawn: bool) -> Dictionary:
	var track := _hud2_track()
	var pitch: float = Hud2Layout.STACK_STEP * Hud2Layout.K
	var s_bend: float = track[0].distance_to(track[1]) + track[1].distance_to(track[2])
	var s_hole: float = s_bend
	for i in range(2, track.size() - 1):
		s_hole += track[i].distance_to(track[i + 1])
	var half := Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX) / 2.0
	var entries: Array = []  # {j, ic, s0 (already in the tube) or -1, kind, fly, enter}
	var twins: Array = twin_of.values()
	var stay_top := INF  # the highest of the Essence that stay in the tube for a later turn: new ones come to rest on top of them
	for c in _pending:
		if is_instance_valid(c) and not twins.has(c):
			stay_top = minf(stay_top, _hud2_project(track, c.position + c.size / 2.0))
	var residents: Array = []
	for j in order:
		if role[j] == "tray" and is_instance_valid(balls[j][0]):
			var lying = twin_of[j]
			var s0 := _hud2_project(track, lying.position + lying.size / 2.0) if is_instance_valid(lying) else s_bend
			_pending.erase(lying)
			if is_instance_valid(lying):
				lying.queue_free()  # (the real ball takes over from the one lying there, at the same place)
			residents.append({"j": j, "ic": balls[j][0], "s0": s0, "kind": "tray", "fly": 0.0, "enter": 0.0})
	residents.sort_custom(func(a, b): return a.s0 > b.s0)  # (the lowest is first)
	entries.append_array(residents)
	var k_new := 0
	for j in order:
		if role[j] == "preset" or role[j] == "tray" or not is_instance_valid(balls[j][0]):
			continue
		var kind := "pop"
		if role[j] == "reel":
			kind = "reel"
		elif from_pt != Vector2.INF and not spawn:
			kind = "from"
		var fly: float = {"from": 0.5, "pop": 0.28, "reel": 0.0}[kind]
		var from_l := (from_pt - scr._stock_row.global_position) if kind == "from" else Vector2.ZERO
		entries.append({"j": j, "ic": balls[j][0], "s0": -1.0, "kind": kind, "fly": fly, "enter": fly + 0.15 + k_new * 0.2, "from": from_l})
		k_new += 1
	var n := entries.size()
	# --- the simulation
	var s := PackedFloat32Array()
	var v := PackedFloat32Array()
	var st := PackedInt32Array()  # 0 not in yet, 1 in the tube, 2 let go, 3 in the hole
	var landed := PackedFloat32Array()
	var start_i := PackedInt32Array()
	var track_s: Array = []
	for i in n:
		s.append(entries[i].s0 if entries[i].s0 >= 0.0 else 0.0)
		v.append(0.0)
		st.append(1 if entries[i].s0 >= 0.0 else 0)
		landed.append(0.0 if entries[i].s0 >= 0.0 else -1.0)
		start_i.append(0)
		track_s.append(PackedFloat32Array())
	var last_release := -999.0
	var step := 0
	var done := 0
	var t_hole := PackedFloat32Array()
	t_hole.resize(n)
	while done < n and step < 3000:
		var t := step * FightScreen.HUD2_DT
		for i in n:
			if st[i] == 3:
				continue
			var below_gone := i == 0 or st[i - 1] == 3
			if st[i] == 0:
				if t >= float(entries[i].enter) and (i == 0 or (st[i - 1] != 0 and (st[i - 1] == 3 or s[i - 1] >= pitch))):
					st[i] = 1
					s[i] = 0.0
					start_i[i] = step
				else:
					continue
			var lim := INF
			if i > 0 and st[i - 1] != 3:
				lim = _hud2_behind(track, s[i - 1], pitch)
			if st[i] == 1:
				lim = minf(lim, s_bend if below_gone else INF)
				if stay_top < INF:
					lim = minf(lim, stay_top - pitch)
				v[i] = minf(v[i] + FightScreen.HUD2_G * FightScreen.HUD2_DT, FightScreen.NU_TUBE_SPEED)
				s[i] = minf(s[i] + v[i] * FightScreen.HUD2_DT, lim)
				if s[i] >= lim - 0.001:
					v[i] = 0.0
					if landed[i] < 0.0:
						landed[i] = t
					if t - landed[i] >= FightScreen.HUD2_HOLD and t - last_release >= FightScreen.HUD2_GAP and _hud2_released_before(st, i):
						st[i] = 2
						last_release = t
			else:
				v[i] = minf(v[i] + FightScreen.HUD2_ACC * FightScreen.HUD2_DT, FightScreen.NU_TUBE_SPEED)
				s[i] = minf(s[i] + v[i] * FightScreen.HUD2_DT, lim)
				if s[i] >= s_hole:
					s[i] = s_hole
					st[i] = 3
					t_hole[i] = t
					done += 1
			track_s[i].append(s[i])
		step += 1
	# --- playback
	var out := {}
	var turns := maxf(1.0, roundf(s_hole / (PI * FightScreen.BAG_PX)))
	for i in n:
		var e: Dictionary = entries[i]
		var ic: ElementIcon = e.ic
		var samples: PackedFloat32Array = track_s[i]
		if samples.is_empty():
			continue
		ic.set_meta("rolling", true)
		ic.rotation = 0.0
		ic.scale = Vector2.ONE * _ball_k()
		var t_in: float = start_i[i] * FightScreen.HUD2_DT
		var count := samples.size()
		var tw := ic.create_tween()
		if e.kind == "tray":  # (it already stands in the tube)
			ic.position = _hud2_at(track, samples[0]) - half
			ic.modulate.a = 1.0
		else:
			ic.modulate.a = 0.0
			ic.position = Vector2(scr._machine.port_center().x + 400.0, PuppetLayout.AXIS_Y - FightScreen.BAG_PX / 2.0)  # (parked out of the way until its turn)
			var top := _hud2_at(track, 0.0)
			var fly: float = e.fly
			tw.tween_interval(maxf(0.0, t_in * 1.0 - fly))
			if e.kind == "from":
				var from_l: Vector2 = e.from
				tw.tween_callback(func() -> void:
					if is_instance_valid(ic):
						ic.modulate.a = 1.0
						ic.scale = Vector2.ONE * 0.4)
				tw.tween_method(func(u: float) -> void:
					if is_instance_valid(ic):
						var ease_u := u * u * (3.0 - 2.0 * u)
						ic.position = from_l.lerp(top, ease_u) + Vector2(0.0, -110.0 * sin(u * PI)) - half
						ic.rotation = -u * TAU * 1.5
						ic.scale = Vector2.ONE * lerpf(0.4, _ball_k(), minf(1.0, u * 2.0)), 0.0, 1.0, fly)
			elif e.kind == "pop":
				tw.tween_callback(func() -> void:
					if is_instance_valid(ic):
						ic.modulate.a = 0.0
						ic.scale = Vector2.ONE * 0.3)
				tw.tween_method(func(u: float) -> void:
					if is_instance_valid(ic):
						ic.position = top + Vector2(0.0, lerpf(80.0 if Hud2Layout.minh else -80.0, 0.0, u * u)) - half
						ic.modulate.a = minf(1.0, u * 4.0)
						ic.scale = Vector2.ONE * lerpf(0.3, _ball_k(), minf(1.0, u * 2.0)), 0.0, 1.0, fly)
			else:
				tw.tween_callback(func() -> void:
					if is_instance_valid(ic):
						ic.position = top - half
						ic.modulate.a = 1.0)
		var dur := maxf(FightScreen.HUD2_DT, (count - 1) * FightScreen.HUD2_DT)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(ic):
				return
			var f := u * float(count - 1)
			var a := int(f)
			var sv := lerpf(samples[a], samples[mini(a + 1, count - 1)], f - a)
			ic.position = _hud2_at(track, sv) - half
			ic.rotation = -TAU * turns * (sv / s_hole), 0.0, 1.0, dur)
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.rotation = -TAU * turns)
		out[e.j] = t_hole[i]
	return out


## ---- New UI: the Essence of the machine run straight out of the tube into the Bag tray ----------------------------------------------------------------------------
## The machine is the Puppet one (see SlotMachine, with `straight`): its Essence fall to the tube's row and run straight left through the tube; out of its mouth they go on along
## the Bag tray at the same speed and slow to a stop at their places (_nu_roll). The Bag is not re-sorted: new orbs stay after the ones that are there.


## How long the last stretch of a launch's rolls is (the same for all of them, see _nu_roll): never more than 1.6 times the shortest way.
func _nu_brake(from_x: float, homes: Array) -> float:
	var shortest := 99999.0
	for h in homes:
		shortest = minf(shortest, from_x - float(h.x))
	return clampf(shortest * 1.6, 24.0, FightScreen.NU_ROLL_BRAKE)


## One orb rolls from `from_x` to `home` (the places along the Bag strip, so only x changes), `delay` seconds from now. Its speed is a smooth start, a steady run and a
## smooth stop, and it spins by the distance it covers (whole turns, so it lies upright). The orbs of a launch all follow the same rule: x = home + soft(r), where r shrinks
## at the same pace for all of them and soft() never changes faster than r, so an orb that comes later can never get closer to the one before it than the time between them
## allows, and the Bag's places are further apart than an orb is wide. `b` = the length of the smooth stop (the same for the whole launch, see _nu_brake).
## Returns when it is in place (seconds from now).
func _nu_roll(ic: ElementIcon, home: Vector2, delay: float, from_x: float, b: float, v0 := 0.0) -> float:
	var r0 := from_x - home.x
	scr._launching += 1
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	var dur := 0.0
	if r0 > 1.0:
		var v := v0 if v0 > 0.0 else FightScreen.NU_ROLL_SPEED  # (v0: it comes in already running at that speed, no start-up)
		var a := 0.0 if v0 > 0.0 else FightScreen.NU_ROLL_ACCEL
		var big := r0 + b / 2.0  # (where the "head" starts: soft(big) = r0, so the orb starts exactly where it stands)
		dur = big / v if a == 0.0 else ((a / 2.0 + big / v) if big >= v * a / 2.0 else sqrt(2.0 * a * big / v))
		var turns := roundf(r0 / (PI * FightScreen.BAG_PX))
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.position.x = from_x
				scr._h_anim._ball_sound("roll", -8.0, randf_range(0.95, 1.05)))
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(ic):
				return
			var s := v * u if a == 0.0 else (v * u * u / (2.0 * a) if u < a else v * (u - a / 2.0))
			var r := maxf(0.0, big - s)
			var soft := r * r / (2.0 * b) if r < b else r - b / 2.0
			ic.position.x = home.x + soft
			ic.rotation = -TAU * turns * clampf(1.0 - soft / r0, 0.0, 1.0), 0.0, dur, dur)
	tw.tween_callback(func() -> void:
		scr._launching -= 1
		if is_instance_valid(ic):
			ic.rotation = 0.0
			ic.position = home
			ic.remove_meta("rolling")
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			scr._h_anim._ball_sound("hit", -6.0, randf_range(0.95, 1.08))
		if scr._launching == 0:
			scr._h_hud._resort_bag())
	return delay + dur
