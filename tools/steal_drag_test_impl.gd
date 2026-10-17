extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/steal_%s.png" % [out, name])


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/temp/shots"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://steal_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["yin_yang_beast", "rolling_bear"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	for k in 3:
		fs._add_stock_index(k)
		await t.create_timer(0.4).timeout
	await t.create_timer(1.5).timeout
	var spell: Dictionary = gd.db.get_spell("thieving_wind")
	var eff := {}
	for e in spell.effects:
		if e.op == "steal":
			eff = e
	f.current_eff = eff
	fs._pick_any_essence(spell, true)
	await t.create_timer(0.6).timeout
	print("row scale ", fs._spell_row.scale, " hover_off ", SpellCard.hover_off)
	await _shot(t, out, "1_hand")
	var v: EnemyView = fs._views[f.enemies[0]]
	var before := fs._bag_icons.size()
	fs._begin_steal_drag(v, 0)
	var bag_c: Vector2 = fs._stock_row.get_global_rect().get_center()
	fs._test_pointer = bag_c
	fs._aim_cursor.point = bag_c
	await t.create_timer(0.4).timeout
	await _shot(t, out, "2_over_bag")
	print("glow panel valid ", is_instance_valid(fs._glow_panel))
	fs._test_pointer = Vector2(-1, -1)
	print("stock rect ", fs._stock_row.get_global_rect(), " drag ", fs._steal_drag.size())
	var stolen_el: String = f.enemies[0].elements[0]
	fs._end_steal_drag(bag_c)
	fs.fight.player.add_element(stolen_el)  # (what the fight does with the pick)
	fs._refresh_all()
	await t.create_timer(0.12).timeout
	await _shot(t, out, "3_flying")
	await t.create_timer(0.8).timeout
	await _shot(t, out, "4_landed")
	print("bag icons ", before, " -> ", fs._bag_icons.size(), " machine busy ", fs._machine.busy, " launching ", fs._launching)
	await t.create_timer(1.5).timeout
	print("row scale after ", fs._spell_row.scale, " hover_off ", SpellCard.hover_off, " picking ", fs._picking_any, " ghost count ", fs._fx.get_child_count())
	# dragging your own orb: a fist, and the chant's sockets stay
	var uid: int = fs.fight.player.stock[0].uid
	fs._press_element("stock", 0)
	fs._begin_build_drag(Vector2(900, 900))
	fs._grab_cursor.point = Vector2(900, 800)
	fs._bdrag.set_pointer(Vector2(900, 800))
	await t.create_timer(0.4).timeout
	print("grab cursor ", is_instance_valid(fs._grab_cursor))
	await _shot(t, out, "5_drag_own")
	t.quit()
