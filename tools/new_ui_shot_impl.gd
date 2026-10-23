extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://nu_shot_save.json")
	save.data.settings["theme"] = "new_ui"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, [], [], 0)
	r.artifacts = ["ember_charm", "wind_chime", "fire_emblem", "water_emblem", "lucky_acorn", "thornbark", "iron_bark", "healing_sap", "rain_chalice", "flame_lens"]
	var ids: Array = TestModeScreen.STRONGEST
	r.spellbook = ids.duplicate()
	r.loadout = ids.duplicate()
	r.player.bottles = ["fire_flask", "healing_tonic", "frost_phial", "iron_tonic", "echo_draught"]
	r.act = 1
	r.row = 4
	var enemies: Array = ["winged_tortoise"]
	r.encounter = enemies.duplicate()
	r.encounter_extra = enemies.map(func(id): return EnemyDefs.extra_for(id, 1, r.depth(), r.rng, 1))
	var f := r.make_fight(enemies)
	f.player.hp = 37
	f.player.max_hp = 50
	f.player.shield = 8.0
	f.player.lasting = 4.0
	f.player.confuse_turns = 2
	f.player.poison = 3
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	_shot(root, out + "/nu_start.png")
	var sv = fs._stage.verts
	print("stage: floor_range ", fs._stage.floor_range(), " front_l ", sv["front_l"], " front_r ", sv["front_r"], " low_top_l ", sv.get("low_top_l"), " low_bot_l ", sv.get("low_bot_l"), " back_bot_l ", sv["back_bot_l"], " SCENE_DY ", PuppetStage.SCENE_DY)
	var card0 = fs._cards[0]
	print("card0 global rect ", card0.get_global_rect(), " scale ", card0.scale)
	print("act line: ", fs._info.text.c_escape(), " size ", fs._info.size, " wrap ", fs._info.autowrap_mode, " lines ", fs._info.get_line_count())
	for k in 3:  # the Menu tab as it is, under the mouse (lighter) and pressed (darker)
		fs._nu_menu_state(k)
		await t.create_timer(0.1).timeout
		_shot(root, out + "/nu_menu%d.png" % k)
	fs._nu_menu_state(0)
	var fr: Control = fs._machine.front
	for k in range(fr.get_child_count() - 3, fr.get_child_count()):
		var c: Control = fr.get_child(k)
		print("lever part ", k, " ", c.get_class(), " global ", c.get_global_rect(), " vis ", c.is_visible_in_tree(), " tex ", (c as TextureRect).texture != null if c is TextureRect else "-")
	# the HP drops: the liquid runs to its new place, overshoots and rocks (shots 0.12 s, 0.3 s and 0.55 s after)
	f.player.hp = 14
	fs._refresh_all()
	for k in 3:
		await t.create_timer([0.12, 0.18, 0.25][k]).timeout
		_shot(root, out + "/nu_slosh%d.png" % k)
	await t.create_timer(1.5).timeout
	# the Shield is put up over the end of the HP (it grows from the right to the left), then it breaks (it goes back from the left to the right)
	f.player.hp = 37
	f.player.shield = 3.0
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	f.player.shield = 25.0
	fs._refresh_all()
	for k in 3:
		await t.create_timer([0.08, 0.1, 0.12][k]).timeout
		_shot(root, out + "/nu_shield_up%d.png" % k)
	await t.create_timer(1.5).timeout
	f.player.shield = 0.0
	fs._refresh_all()
	for k in 3:
		await t.create_timer([0.08, 0.1, 0.12][k]).timeout
		_shot(root, out + "/nu_shield_down%d.png" % k)
	await t.create_timer(1.0).timeout
	f.player.shield = 12.0
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	_shot(root, out + "/nu_final.png")
	f.player.add_element("F")
	fs._refresh_all()
	await t.create_timer(0.35).timeout
	_shot(root, out + "/nu_bonus.png")
	await t.create_timer(2.0).timeout
	print("bag before turn: ", f.player.stock.map(func(s): return s.el), "  next: ", f.player.next_draw.map(func(d): return d.el))
	fs._on_end_turn()
	# does the HUD flicker while the enemies act? the artifact slots do not change by themselves: their mean brightness is sampled every frame
	await _flicker(t, root, 4.5, "pass")
	var min_gap := 9999.0
	var frames := 0
	var t_end := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < t_end:
		await t.process_frame
		var icons: Array = fs._stock_row.get_children().filter(func(c): return c is ElementIcon and c.modulate.a > 0.5 and c.scale.x > 0.9)
		for i in icons.size():
			for j in range(i + 1, icons.size()):
				if absf(icons[i].position.y - icons[j].position.y) < 8.0:
					var g: float = absf(icons[i].position.x - icons[j].position.x)
					if g < min_gap:
						min_gap = g
						print("  closer: t=", Time.get_ticks_msec() - t_end + 6000, " gap ", g, " a=", icons[i].position, " rolling=", icons[i].has_meta("rolling"), " b=", icons[j].position, " rolling=", icons[j].has_meta("rolling"), " alphas ", icons[i].modulate.a, icons[j].modulate.a)
		frames += 1
		if frames == 60:
			_shot(root, out + "/nu_turn0.png")
	print("closest two orbs on the row: ", min_gap, " px apart (orb is 52 wide), frames ", frames)
	await t.create_timer(1.0).timeout
	_shot(root, out + "/nu_turn1.png")
	await t.create_timer(4.0).timeout
	_shot(root, out + "/nu_turn2.png")
	print("hp of the enemy before: ", fs.fight.enemies[0].hp_text() if fs.fight.enemies[0].has_method("hp_text") else "?")
	fs._auto_fill()
	await t.create_timer(2.5).timeout
	fs._on_cast()
	await _flicker(t, root, 6.0, "cast")
	# a heavy hit (hit-stop, shake, red flash): does the HUD vanish for a moment?
	f.player.hp = 45
	fs._refresh_all()
	await t.create_timer(1.0).timeout
	_dbg_fs = fs
	fs._enemy_attack({"enemy": f.enemies[0], "n": 22, "blocked": false})
	await _flicker(t, root, 3.0, "heavy hit")
	print("bag after turn: ", f.player.stock.map(func(s): return s.el), "  next: ", f.player.next_draw.map(func(d): return d.el))
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

## Samples the mean brightness of some static parts of the HUD every frame for `secs` seconds and prints the biggest jump between two frames (a flicker shows as a jump).
var _dbg_fs


func _flicker(t: SceneTree, root: Window, secs: float, label: String) -> void:
	var regions := {"artifacts": Rect2(30, 960, 250, 106), "bottles": Rect2(375, 992, 250, 50), "bag tray": Rect2(730, 975, 400, 80), "chant": Rect2(720, 885, 300, 75), "cards": Rect2(300, 640, 1300, 200), "block A": Rect2(5, 1070, 500, 8), "whole HUD": Rect2(0, 860, 1920, 220)}
	var series := {}
	for k in regions:
		series[k] = []
	var t_flick := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < t_flick:
		await t.process_frame
		var img: Image = root.get_texture().get_image()
		var kk := img.get_width() / 1920.0
		if label == "heavy hit" and series["artifacts"].size() >= 8 and series["artifacts"].size() < 30:
			var fsn = root.get_node("FightScreenDebug") if root.has_node("FightScreenDebug") else null
			var nb = _dbg_fs._nu_back
			print("frame ", series["artifacts"].size(), " back visible ", nb.visible, " in tree ", nb.is_visible_in_tree(), " mod ", nb.modulate, " self_mod ", nb.self_modulate, " pos ", nb.position, " gpos ", nb.global_position, " size ", nb.size, " z ", nb.z_index, " top_layer pos ", _dbg_fs._top_layer.position, " fs pos ", _dbg_fs.position, " scale ", _dbg_fs.scale, " time_scale ", Engine.time_scale)
		if label == "heavy hit" and series["artifacts"].size() >= 10 and series["artifacts"].size() < 26:
			img.save_png(OS.get_environment("TEMP") + "/nu_out/hit_%02d.png" % series["artifacts"].size())
		for name in regions:
			var rg: Rect2 = regions[name]
			var sum := 0.0
			var cnt := 0
			for yy in range(int(rg.position.y), int(rg.end.y), 8):
				for xx in range(int(rg.position.x), int(rg.end.x), 8):
					var c := img.get_pixel(int(xx * kk), int(yy * kk))
					sum += c.r + c.g + c.b
					cnt += 1
			series[name].append(sum / maxi(cnt, 1))
	for name in regions:
		var worst := 0.0
		var at := 0
		var ls: Array = series[name]
		for i in range(1, ls.size()):
			if absf(ls[i] - ls[i - 1]) > worst:
				worst = absf(ls[i] - ls[i - 1])
				at = i
		print("flicker ", label, " ", name, ": frames ", ls.size(), " biggest jump between two frames ", snappedf(worst, 0.001), " at frame ", at, " (mean ", snappedf(ls.reduce(func(a, b): return a + b) / ls.size(), 0.001), ")")
