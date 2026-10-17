extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://top_hud_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var counts: Array = OS.get_environment("HUD_N").split(",") if OS.get_environment("HUD_N") != "" else ["3", "2"]
	var arts: Array = ["heartwood_seed", "ember_charm", "lucky_acorn", "wind_chime", "second_wind", "blood_pact", "withered_idol", "thornbark", "venom_gland", "chant_bell"]
	for k in int(counts[0]):
		run.artifacts.append(arts[k])
	run.player.bottles.clear()
	for k in int(counts[1]):
		run.player.bottles.append(String(Bottles.ALL[k % Bottles.ALL.size()].id))
	var f := run.make_fight(["ashling"])
	var nd := int(OS.get_environment("HUD_DEBUFFS")) if OS.get_environment("HUD_DEBUFFS") != "" else 0
	if nd > 0:
		var pl = f.player
		pl.bleed = 3
		if nd > 1: pl.confuse_turns = 2
		if nd > 2: pl.disarmed_turns = 1
		if nd > 3: pl.toll = 5
		if nd > 4: pl.lasting = 4.0
		if nd > 5: pl.aegis = 2
		if nd > 6: pl.thorns_turn = 3
		if nd > 7: pl.shield = 6.0
		if nd > 8: pl.blind_turns = 2
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(7.0).timeout
	root.get_texture().get_image().save_png(out + "/a_normal.png")
	# hover the first artifact
	var chip: Control = null
	for c in fs._arts.get_children():
		chip = c
		break
	if chip != null:
		var at: Vector2 = chip.get_global_rect().get_center()
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		root.push_input(mv)
		await t.create_timer(1.6).timeout
		root.get_texture().get_image().save_png(out + "/b_hover.png")
		fs._arts.flash(chip.id)
		await t.create_timer(0.35).timeout
		root.get_texture().get_image().save_png(out + "/c_active.png")
	await t.create_timer(0.4).timeout
	for what in ["status", "bottle"]:
		var node: Control = fs._status_row.get_child(1) if what == "status" and fs._status_row.get_child_count() > 1 else (fs._bottle_row.get_child(1) if what == "bottle" and fs._bottle_row.get_child_count() > 1 else null)
		if node == null:
			continue
		var at2: Vector2 = node.get_global_rect().get_center()
		var mv2 := InputEventMouseMotion.new()
		mv2.position = at2
		mv2.global_position = at2
		root.push_input(mv2)
		await t.create_timer(1.6).timeout
		root.get_texture().get_image().save_png(out + "/e_hover_%s.png" % what)
	var off := InputEventMouseMotion.new()
	off.position = Vector2(960, 600)
	off.global_position = Vector2(960, 600)
	root.push_input(off)
	await t.create_timer(0.6).timeout
	# drink the first bottle
	if fs._bottle_row.get_child_count() > 0:
		var bc: BottleChip = fs._bottle_row.get_child(0)
		fs._on_bottle(bc)
		for k in 8:
			await t.create_timer(0.2).timeout
			root.get_texture().get_image().save_png(out + "/d_bottle%d.png" % k)
	t.quit()
