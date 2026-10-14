extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://handyman_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["handyman"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	print("player marker ", fs._player_panel.get_global_rect(), "  hp bar ", fs._hp_bar.get_global_rect(), "  point ", fs._player_point())
	_shot(root, out + "/hm_phase1.png")
	# a hand takes damage: his face cries for a moment
	var sw0 = f.enemies.filter(func(x): return x.id == "hand_sword")[0]
	fs._views[sw0].hit_flash()
	await t.create_timer(0.4).timeout
	_shot(root, out + "/hm_cry.png")
	await t.create_timer(2.2).timeout
	_shot(root, out + "/hm_smile.png")
	# the tweezer hand steals two Essence from the bag
	var twz = f.enemies.filter(func(x): return x.id == "hand_tweezer")[0]
	f._do_move(twz, {"kind": "steal", "n": 2})
	for k in 5:
		await t.create_timer(0.35).timeout
		_shot(root, out + "/hm_steal%d.png" % k)
	await t.create_timer(1.0).timeout
	print("bag after: ", f.player.stock.map(func(x): return x.el), "  tweezer row: ", twz.elements)
	# the hammer hand hits the Fire Ball card three times
	var hmh = f.enemies.filter(func(x): return x.id == "hand_hammer")
	f._hm_phase(2, ["hand_hammer", "hand_crossbow"], "")
	hmh = f.enemies.filter(func(x): return x.id == "hand_hammer")[0]
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	for k in 3:
		f.hammer_hits["fire_ball"] = k + 1
		fs._hammer_fx({"enemy": hmh, "id": "fire_ball", "hits": k + 1, "broken": k == 2})
		await t.create_timer(0.9).timeout
		_shot(root, out + "/hm_hammer%d.png" % k)
		if k == 2:
			await t.create_timer(0.4).timeout
			_shot(root, out + "/hm_hammer3.png")
		await t.create_timer(1.0).timeout
	# the last stand: all six hands
	f._hm_phase(2, ["hand_hammer", "hand_crossbow"], "")
	f._hm_phase(3, ["hand_spear", "hand_shield"], "")
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(2.5).timeout
	_shot(root, out + "/hm_phase3.png")
	for e in fs._views:
		var v: EnemyView = fs._views[e]
		var ch := v.intent_chip()
		print("%-14s creature mid %s  name %s  hp %s  chip %s  bounds %s" % [e.id, v.creature.global_position + v.creature.size / 2.0, v._name.global_position, v._hp_row.global_position, ch.global_position if ch else "-", v.creature.puppet_bounds()])
	# clicks: the middle of each arm and its text take them, an empty corner of the view does not
	for e in fs._views:
		var v: EnemyView = fs._views[e]
		var mid: Vector2 = v._holder.position + v.creature.position + v.creature.size / 2.0
		var tb: Rect2 = v._puppet_rect()
		tb.position += v._holder.position
		print("%-14s hit: arm mid %s  text %s  corner %s" % [e.id, v._has_point(mid), v._has_point(tb.get_center()), v._has_point(Vector2(5, 5))])
	# the target reticle on a hand
	var tv: EnemyView = fs._views[f.enemies.filter(func(x): return x.id == "hand_hammer")[0]]
	tv.targetable = true
	tv.targeted = true
	tv.refresh({})
	await t.create_timer(0.5).timeout
	print("marker: ", tv._marker, " visible ", tv._marker.visible if tv._marker else "-", " rect ", tv._marker.get_global_rect() if tv._marker else "-", " alpha ", tv._marker.modulate.a if tv._marker else "-", " creature mid ", tv.creature.global_position + tv.creature.size / 2.0)
	_shot(root, out + "/hm_marker.png")
	tv.targetable = false
	tv.targeted = false
	tv.refresh({})
	# a real attack of the sword hand (the swing, then the blow lands on you)
	var sw = f.enemies.filter(func(x): return x.id == "hand_sword")[0]
	fs._enemy_attack({"enemy": sw, "n": 5, "blocked": false})
	await t.create_timer(0.22).timeout
	_shot(root, out + "/hm_attack.png")
	await t.create_timer(1.6).timeout
	# every hand mid-swing, the shield knocked out
	for e in fs._views:
		fs._arm_swing(fs._views[e].creature, 1.0)
	var sh = f.enemies.filter(func(e): return e.id == "hand_shield")[0]
	sh.knocked = true
	await t.create_timer(0.27).timeout
	_shot(root, out + "/hm_swing.png")
	await t.create_timer(1.5).timeout
	_shot(root, out + "/hm_limp.png")
	# the tweezer hand is knocked out: it fades and folds back behind him in jerks; when it comes back it reaches out again
	var tw_h = f.enemies.filter(func(x): return x.id == "hand_tweezer")[0]
	tw_h.knocked = true
	var sh2 = f.enemies.filter(func(x): return x.id == "hand_shield")[0]
	sh2.knocked = true
	for k in 8:
		await t.create_timer(0.8).timeout
		_shot(root, out + "/hm_fold%d.png" % k)
	await t.create_timer(2.0).timeout
	for e in fs._views:
		if e == tw_h:
			print("tweezer: knocked ", tw_h.knocked, " fold_t ", fs._views[e].creature._fold_t, " view alive ", is_instance_valid(fs._views[e]), " same ", fs._views[e].creature._enemy == tw_h)
	_shot(root, out + "/hm_folded.png")
	tw_h.knocked = false
	await t.create_timer(0.45).timeout
	_shot(root, out + "/hm_unfold.png")
	await t.create_timer(1.5).timeout
	# the sword hand is down for good: it breaks
	sw.elements.clear()
	f.enemies.erase(sw)
	fs._sync_views()
	await t.create_timer(0.5).timeout
	_shot(root, out + "/hm_break1.png")
	await t.create_timer(0.7).timeout
	_shot(root, out + "/hm_break2.png")
	# every hand knocked out: all six arms end up pointing at the sky
	for e in f.enemies:
		if e.has_passive("hand"):
			e.knocked = true
	await t.create_timer(3.0).timeout
	_shot(root, out + "/hm_allmid.png")
	await t.create_timer(9.0).timeout
	_shot(root, out + "/hm_allup.png")
	# he shows himself
	for e in f.enemies.duplicate():
		if e.has_passive("hand"):
			f.enemies.erase(e)
	f._handyman_step()
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(2.0).timeout
	_shot(root, out + "/hm_body.png")
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
