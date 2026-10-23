extends RefCounted
## New UI through the real game flow (Test mode -> Fight!): an enemy hits hard and the HUD is sampled every frame (a vanishing HUD shows as a big jump).


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://nu_hit_main_save.json")
	save.data.settings["theme"] = "new_ui"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.8).timeout
	m._test_state = {"enemies": ["winged_tortoise"], "artifacts": ["ember_charm", "thornbark", "iron_bark"], "bottles": ["fire_flask", "healing_tonic"]}
	m.open_test_mode()
	await t.create_timer(1.5).timeout
	m.current.fight_requested.emit(m.current.state.enemies.duplicate(), m.current.state.spells.duplicate(), m.current.state.artifacts.duplicate(), m.current.state.bottles.duplicate())
	await t.create_timer(6.0).timeout
	var fs = m.current
	print("current: ", fs, " puppet strips ", fs._puppet_strips(), " nu ", fs._nu_ui)
	fs.fight.player.hp = 45.0
	fs.fight.player.max_hp = 50.0
	fs._refresh_all()
	await t.create_timer(1.0).timeout
	var lums: Array = []
	fs._enemy_attack({"enemy": fs.fight.enemies[0], "n": 22, "blocked": false})
	var t_end := Time.get_ticks_msec() + 3000
	var frame := 0
	while Time.get_ticks_msec() < t_end:
		await t.process_frame
		frame += 1
		var img: Image = root.get_texture().get_image()
		var k := img.get_width() / 1920.0
		var sum := 0.0
		var cnt := 0
		for yy in range(880, 1070, 8):
			for xx in range(20, 1500, 8):
				var c := img.get_pixel(int(xx * k), int(yy * k))
				sum += c.r + c.g + c.b
				cnt += 1
		lums.append(sum / cnt)
		if frame >= 8 and frame <= 14:
			var nb = fs._nu_back
			print("f", frame, " lum ", snappedf(sum / cnt, 0.01), " back vis ", nb.visible, "/", nb.is_visible_in_tree(), " modulate ", nb.modulate, " top_layer vis ", fs._top_layer.is_visible_in_tree(), " mod ", fs._top_layer.modulate, " fs mod ", fs.modulate, " fs pos ", fs.position, " ts ", Engine.time_scale, " back z ", nb.z_index, " parent ", nb.get_parent().name, " idx ", nb.get_index(), " top_layer idx ", fs._top_layer.get_index(), " stage idx ", fs._stage.get_index())
		if frame >= 8 and frame <= 26:
			img.save_png(out + "/mh_%02d.png" % frame)
	var worst := 0.0
	var at := 0
	for i in range(1, lums.size()):
		if absf(lums[i] - lums[i - 1]) > worst:
			worst = absf(lums[i] - lums[i - 1])
			at = i
	print("HUD (bottom strip) brightness: frames ", lums.size(), " biggest jump ", snappedf(worst, 0.001), " at frame ", at, "  series ", lums.slice(8, 24).map(func(v): return snappedf(v, 0.01)))
	t.quit()
