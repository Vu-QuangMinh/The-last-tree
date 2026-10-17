extends RefCounted

var t: SceneTree
var fs: FightScreen
var stalls := 0
var overlaps := 0
var stuck := 0
var notes: Array = []
var _last := {}  # uid -> [x, still seconds]


func _to_win(p: Vector2) -> Vector2:
	return t.root.get_final_transform() * p


func _motion(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = _to_win(p)
	mv.global_position = mv.position
	t.root.push_input(mv)
	await t.process_frame


func _button(p: Vector2, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	b.position = _to_win(p)
	b.global_position = b.position
	t.root.push_input(b)
	await t.process_frame


func _drag(a: Vector2, b: Vector2, steps := 10) -> void:
	await _motion(a)
	await _button(a, true)
	for k in steps:
		await _motion(a.lerp(b, (k + 1.0) / steps))
	await _button(b, false)


func _click(p: Vector2) -> void:
	await _motion(p)
	await _button(p, true)
	await _button(p, false)


## One frame of watching: a ball that is rolling must move every frame (a hair of rest at its start delay is allowed).
func _watch(d: float) -> void:
	var rolling: Array = []
	for uid in fs._bag_icons:
		var ic: Control = fs._bag_icons[uid]
		if is_instance_valid(ic) and ic.has_meta("rolling") and ic.modulate.a > 0.5 and ic.position.x < PuppetSlotMachine.PORT_C.x - PuppetLayout.BAG_AT.x - 20.0:  # (before it comes up out of the port it is hidden: waiting there is not a stall)
			rolling.append(ic)
			var x := ic.position.x
			var rec: Array = _last.get(uid, [x, 0.0, x])  # [last x, still seconds, x where it began]
			if absf(x - float(rec[0])) < 0.01:
				rec[1] = float(rec[1]) + d
			else:
				rec[1] = 0.0
			rec[0] = x
			_last[uid] = rec
			var goal_x: float = fs._bag_target.get(uid, Vector2(x, 0)).x
			# mid-way stall: it has moved, it is not yet home, and it stands still for 0.15 s
			if absf(float(rec[2]) - x) > 8.0 and absf(x - goal_x) > 3.0 and float(rec[1]) > 0.15 and float(rec[1]) - d <= 0.15:
				stalls += 1
				var who := ""
				for ouid in fs._bag_icons:
					var oc: Control = fs._bag_icons[ouid]
					if oc != ic and is_instance_valid(oc) and oc.position.x < x and x - oc.position.x < fs.BAG_PX + 12.0 and absf(oc.position.y - ic.position.y) < 6.0:
						who = "blocked by ball %d at x=%.0f (rolling %s, home %.0f, alpha %.1f, in_tube %s)" % [ouid, oc.position.x, oc.has_meta("rolling"), fs._bag_target.get(ouid, Vector2.ZERO).x, oc.modulate.a, oc.has_meta("in_tube")]
				notes.append("MID-WAY STALL: ball %d stops at x=%.0f (home %.0f) for 0.15 s; %s" % [uid, x, goal_x, who if who != "" else "NOTHING IN FRONT within a ball"])
		else:
			_last.erase(uid)
	for i in rolling.size():
		for j in range(i + 1, rolling.size()):
			var a: Control = rolling[i]
			var b: Control = rolling[j]
			if absf(a.position.y - b.position.y) < 4.0 and absf(a.position.x - b.position.x) < fs.BAG_PX * 0.55:
				overlaps += 1


func _settle(secs: float, label: String) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await t.process_frame
		_watch(1.0 / 60.0)
	var bad := 0
	for uid in fs._bag_icons:
		var ic: Control = fs._bag_icons[uid]
		if not is_instance_valid(ic):
			continue
		var in_chant := false
		for i in fs.chant_idx:
			if fs.fight.player.stock[i].uid == uid:
				in_chant = true
		if ic.has_meta("rolling") or (ic.modulate.a < 0.5 and not in_chant and not fs._flying.has(uid)):
			bad += 1
			notes.append("%s: ball %d stuck (rolling %s alpha %.2f flying %s)" % [label, uid, ic.has_meta("rolling"), ic.modulate.a, fs._flying.has(uid)])
		elif not in_chant and absf(ic.position.x - fs._bag_target.get(uid, ic.position).x) > 1.5:
			bad += 1
			notes.append("%s: ball %d rests at %.1f, its place is %.1f" % [label, uid, ic.position.x, fs._bag_target.get(uid, ic.position).x])
	stuck += bad


func _chant_check(label: String, expect: int) -> void:
	if fs.chant_idx.size() != expect:
		stuck += 1
		notes.append("%s: the chant has %d balls, expected %d" % [label, fs.chant_idx.size(), expect])


func _wait_idle(phase: String, limit: float) -> void:
	var w := 0.0
	while (fs.busy or fs.phase != phase) and w < limit:
		await t.process_frame
		_watch(1.0 / 60.0)
		w += 1.0 / 60.0


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ball_stress_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 11)
	var f := r.make_fight(["greenseer", "rolling_bear"])
	fs = FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	# 1) the first hand rolls out of the tube
	await _settle(7.0, "start")
	print("start: balls ", fs.fight.player.stock.size(), " stalls ", stalls, " overlaps ", overlaps)
	# 2) quick clicks and quick drags down, without waiting for the flights
	var bag_y := 1010.0
	for round in 3:
		fs.chant_idx.clear()
		fs._chant_changed()
		await _settle(1.2, "r%d clear" % round)
		for k in 4:
			var uid: int = fs.fight.player.stock[k].uid
			await _click(fs._bag_icons[uid].get_global_rect().get_center())
			await t.process_frame
		await _settle(1.0, "r%d four clicks" % round)
		_chant_check("r%d four quick clicks" % round, 4)
		for k in 4:
			var slots: Array = fs._chant_row.get_children().filter(func(c): return c is Panel)
			if slots.is_empty():
				break
			var from: Vector2 = slots[0].get_global_rect().get_center()
			await _drag(from, Vector2(from.x, bag_y))
			await t.create_timer(0.12).timeout
		await _settle(1.2, "r%d four drags down" % round)
		_chant_check("r%d four quick drags down" % round, 0)
	# 3) a whole turn; the new hand rolls out and is clicked and dragged while it rolls
	fs.chant_idx.clear()
	fs._add_stock_index(0)
	fs._add_stock_index(1)
	await _settle(1.0, "chant 2")
	fs._on_primary()
	await _wait_idle("spells", 15.0)
	fs._damage_step()
	await t.create_timer(0.5).timeout
	await _wait_idle("build", 40.0)
	print("turn 2 reached: stalls ", stalls, " overlaps ", overlaps)
	for round in 2:
		fs.chant_idx.clear()
		fs._chant_changed()
		await t.create_timer(0.2).timeout
		var tried := 0
		for uid in fs._bag_icons.keys():
			var ic: Control = fs._bag_icons[uid]
			if is_instance_valid(ic) and ic.modulate.a > 0.5 and tried < 3:
				await _click(ic.get_global_rect().get_center())
				tried += 1
				await t.create_timer(0.08).timeout
		await _settle(3.0, "r%d turn2 clicks" % round)
		print("turn 2 round ", round, ": clicked ", tried, " balls, chant ", fs.chant_idx.size())
		while fs.chant_idx.size() > 0:
			var sl: Array = fs._chant_row.get_children().filter(func(c): return c is Panel)
			var c0: Vector2 = sl[0].get_global_rect().get_center()
			var before: int = fs.chant_idx.size()
			await _drag(c0, Vector2(c0.x, bag_y))
			await t.create_timer(0.3).timeout
			if fs.chant_idx.size() == before:
				stuck += 1
				notes.append("turn 2 round %d: a chant ball could not be dragged down (chant still %d)" % [round, before])
				break
		await _settle(1.5, "r%d turn2 drags" % round)
	# 4) several turns with spells that send Essence through the pipe (Tailwind: draw next turn), cast by clicking its card; then new hands roll out
	for turn in 4:
		var p := fs.fight.player
		for k in 2:
			p.add_element("A")
		fs._refresh_all()
		await _settle(1.5, "t%d added" % turn)
		fs.chant_idx.clear()
		var found := 0
		for i in p.stock.size():
			if p.stock[i].el == "A" and found < 2 and not p.stock[i].frozen:
				var uid: int = p.stock[i].uid
				var ic: Control = fs._bag_icons.get(uid)
				if ic != null and is_instance_valid(ic) and ic.modulate.a > 0.5:
					await _click(ic.get_global_rect().get_center())
					await t.create_timer(0.2).timeout
					found += 1
		await _settle(0.8, "t%d chant" % turn)
		if fs.chant_idx.size() < 2:
			notes.append("turn %d: could not click two Air balls (chant %d)" % [turn, fs.chant_idx.size()])
		fs._on_primary()
		await _wait_idle("spells", 15.0)
		for card in fs._cards:
			if card.spell.id == "tailwind" and card.charges > 0:
				fs._on_card_clicked(card)
				await t.create_timer(0.3).timeout
				await _wait_idle("spells", 15.0)
		await _settle(1.0, "t%d cast" % turn)
		fs._damage_step()
		await t.create_timer(0.5).timeout
		await _wait_idle("build", 60.0)
		await _settle(7.0, "t%d new hand" % turn)
		print("  state: launching ", fs._launching, " tube_prep ", fs._tube_prep, " resort_wait ", fs._resort_wait, " rolling_in ", fs._rolling_in, " order ", fs._bag_order, " flying ", fs._flying.keys())
		for uid in fs._bag_icons:
			var ic2: Control = fs._bag_icons[uid]
			print("   ball ", uid, " x ", snappedf(ic2.position.x, 0.1), " target ", snappedf(fs._bag_target.get(uid, Vector2.ZERO).x, 0.1), " goal ", fs._bag_icons[uid].get_meta("goal", "-"), " rolling ", ic2.has_meta("rolling"), " slide ", (str(ic2.get_meta("slide").is_valid()) + "/" + str(ic2.get_meta("slide").is_running())) if ic2.has_meta("slide") else "-")
		await t.create_timer(2.0).timeout
		print("   after 2 s more: ", fs._bag_icons.keys().map(func(u): return snappedf(fs._bag_icons[u].position.x, 0.1)))
		print("turn ", turn, ": balls ", p.stock.size(), " stalls ", stalls, " overlaps ", overlaps, " stuck ", stuck)
	# 5) the Essence Lens: four chant balls fly into the pipe one after another, roll down it and out of the tube
	fs.chant_idx.clear()
	fs._chant_changed()
	await _settle(2.0, "lens start")
	var uids: Array = []
	var els: Array = []
	var slots_l: Array = []
	for k in 4:
		fs._add_stock_index(k)
		await t.create_timer(0.25).timeout
	await _settle(1.0, "lens chant")
	for k in 4:
		var st: Dictionary = fs.fight.player.stock[fs.chant_idx[k]]
		uids.append(st.uid)
		els.append(st.el)
		slots_l.append(k)
	fs.chant_idx.clear()
	fs._refund_flight({"uids": uids, "els": els, "slots": slots_l})
	await _settle(9.0, "lens refund")
	print("lens: stalls ", stalls, " overlaps ", overlaps, " stuck ", stuck)
	print("RESULT: stalls ", stalls, "  overlaps ", overlaps, "  stuck/wrong ", stuck)
	for l in notes.slice(0, 30):
		print("  ", l)
	t.quit()
