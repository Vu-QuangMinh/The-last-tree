extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var n := [10, 5, 3]
	if OS.get_environment("HUD_N") != "":
		n = Array(OS.get_environment("HUD_N").split(",")).map(func(x): return int(x))
	var step := float(OS.get_environment("HUD_FRAMES")) if OS.get_environment("HUD_FRAMES") != "" else 0.3
	var save = root.get_node("SaveManager")
	save.use_test_file("user://hud2_shot_save.json")
	save.data.settings["theme"] = OS.get_environment("HUD_THEME") if OS.get_environment("HUD_THEME") != "" else "hud2"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, [], [], 0)
	var all_arts := ["ember_charm", "wind_chime", "fire_emblem", "water_emblem", "lucky_acorn", "thornbark", "iron_bark", "healing_sap", "rain_chalice", "flame_lens", "scholar_quill"]
	r.artifacts = all_arts.slice(0, n[0])
	var ids: Array = TestModeScreen.STRONGEST
	r.spellbook = ids.duplicate()
	r.loadout = ids.duplicate()
	r.player.bottles = ["fire_flask", "healing_tonic", "frost_phial", "iron_tonic", "echo_draught", "echo_draught"].slice(0, n[1])
	r.act = 1
	r.row = 4
	var enemies: Array = ["winged_tortoise"]
	r.encounter = enemies.duplicate()
	r.encounter_extra = enemies.map(func(id): return EnemyDefs.extra_for(id, 1, r.depth(), r.rng, 1))
	var f := r.make_fight(enemies)
	f.player.hp = 37
	f.player.max_hp = 50
	f.player.shield = 8.0
	f.player.confuse_turns = 2 if n[2] > 0 else 0
	f.player.poison = 3 if n[2] > 1 else 0
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	t.create_timer(120.0).timeout.connect(t.quit)
	await t.create_timer(1.2).timeout
	for k in 14:
		root.get_texture().get_image().save_png("%s/h2_%02d.png" % [out, k])
		await t.create_timer(step).timeout
	await t.create_timer(2.0).timeout
	if OS.get_environment("HUD_STASH") != "":  # (HUD_STASH=4: four Essence given for next turn stand waiting in the vertical tube; then the next turn lets them go)
		var els: Array = []
		for i in int(OS.get_environment("HUD_STASH")):
			els.append(["F", "W", "A"][i % 3])
		fs._stash_to_machine({"drawn": els, "eff": {"op": "draw", "n": els.size(), "when": "next"}}, Vector2(900, 400))
		await t.create_timer(2.5).timeout
		root.get_texture().get_image().save_png(out + "/h2_stash.png")
	if OS.get_environment("HUD_PASS") != "":  # (end the turn: the waiting Essence and the new turn's draw leave the tube; measure how close two rolling orbs ever get)
		fs._on_end_turn()
		var min_p := 9999.0
		for k in 220:
			await t.process_frame
			await t.create_timer(0.03).timeout
			var cp: Array = []
			for c in fs._stock_row.get_children():
				if c is ElementIcon and c.has_meta("rolling") and c.modulate.a > 0.5 and c.scale.x > 0.9:
					cp.append(c.get_global_transform() * c.pivot_offset)
			for i in cp.size():
				for j in range(i + 1, cp.size()):
					min_p = minf(min_p, cp[i].distance_to(cp[j]))
			if k % 15 == 0:
				root.get_texture().get_image().save_png("%s/h2_pass%02d.png" % [out, k / 15])
		print("pass: closest two rolling orbs ", min_p)
	if OS.get_environment("HUD_BONUS") != "":  # (HUD_BONUS=n: n bonus Essence at once; they must fly to the top of the tube, roll down, wait, and leave one by one in the order they came in, never overlapping)
		if OS.get_environment("HUD_SLOW") != "":  # (HUD_SLOW=0.2: the game runs at that speed, so a picture every frame catches every moment)
			Engine.time_scale = float(OS.get_environment("HUD_SLOW"))
		for i in int(OS.get_environment("HUD_BONUS")):
			fs.fight.player.add_element(["F", "W", "A"][i % 3])
		fs._refresh_all()
		var min_d := 9999.0
		for k in 90:
			await t.process_frame
			await t.create_timer(0.04).timeout
			var cs: Array = []
			for c in fs._stock_row.get_children():
				if c is ElementIcon and c.has_meta("rolling") and c.modulate.a > 0.5 and c.scale.x > 0.9:
					cs.append(c.get_global_transform() * c.pivot_offset)
			for i in cs.size():
				for j in range(i + 1, cs.size()):
					min_d = minf(min_d, cs[i].distance_to(cs[j]))
					if cs[i].distance_to(cs[j]) < 50.0:
						print("frame ", k, " close: ", cs[i], cs[j], " d=", cs[i].distance_to(cs[j]))
			if OS.get_environment("HUD_TRACE") != "":  # (HUD_TRACE=1: where every visible Essence of the Bag strip is, per frame, page px)
				for c in fs._stock_row.get_children():
					if c is ElementIcon and c.modulate.a > 0.05 and (c.get_global_transform() * c.pivot_offset).x > 1300.0:
						print("trace ", k, " ", c.get_global_transform() * c.pivot_offset, " a=", snappedf(c.modulate.a, 0.01), " s=", snappedf(c.scale.x, 0.01))
			var every := int(OS.get_environment("HUD_EVERY")) if OS.get_environment("HUD_EVERY") != "" else 6  # (HUD_EVERY=n: a picture every n frames)
			if k % every == 0:
				root.get_texture().get_image().save_png("%s/h2_bonus%02d.png" % [out, k / every])
		print("closest two rolling orbs: ", min_d, " (one orb is ", 60.0 * 0.9375, ")")
	if OS.get_environment("HUD_DUMP") != "":  # (HUD_DUMP=file.json: every HUD picture of the screen in draw order, for tools/export_ui_pdf.py: [{"tex", "rect": [x, y, w, h], "z", "order", "alpha"}])
		var items: Array = []
		var order := [0]
		_walk_hud(fs, 0, items, order)
		var jf := FileAccess.open(OS.get_environment("HUD_DUMP"), FileAccess.WRITE)
		jf.store_string(JSON.stringify(items))
		jf.close()
		print("dumped ", items.size(), " pictures")
	if OS.get_environment("HUD_CHANT") != "":  # (HUD_CHANT=n: put n Essence in the chant (the rings lie in the tray), press the REAL Chant button, then shoot the flip of the round button into Release, HUD_PRESS=1 also shoots Chant pressed and Pass pressed first)
		for i in int(OS.get_environment("HUD_CHANT")):
			fs._add_stock_index(i)
		await t.create_timer(1.0).timeout
		root.get_texture().get_image().save_png(out + "/h2_chant_rings.png")
		if OS.get_environment("HUD_PRESS") != "" and fs._minh_disc != null:
			fs._minh_disc.set_press(2)
			await t.create_timer(0.1).timeout
			root.get_texture().get_image().save_png(out + "/h2_press_chant.png")
			fs._minh_disc.set_press(3)
			await t.create_timer(0.1).timeout
			root.get_texture().get_image().save_png(out + "/h2_press_pass.png")
			fs._minh_disc.set_press(0)
		print("before: kind ", fs._cast_kind, " cast rect ", fs._cast_btn.get_global_rect(), " pass visible ", fs._end_btn.visible)
		fs._cast_btn.pressed.emit()
		for k in 14:
			await t.create_timer(0.05).timeout
			root.get_texture().get_image().save_png("%s/h2_flip%02d.png" % [out, k])
		await t.create_timer(2.0).timeout
		root.get_texture().get_image().save_png(out + "/h2_released_state.png")
		print("after: kind ", fs._cast_kind, " phase ", fs.phase, " cast rect ", fs._cast_btn.get_global_rect(), " pass visible ", fs._end_btn.visible)
		if OS.get_environment("HUD_PRESS") != "" and fs._minh_disc != null:
			fs._minh_disc.set_press(2)
			await t.create_timer(0.1).timeout
			root.get_texture().get_image().save_png(out + "/h2_press_release.png")
			fs._minh_disc.set_press(0)
	if OS.get_environment("HUD_SINK") != "":  # (the HUD sinks between fights: the tube must go down with it)
		fs._set_hud_shift(fs.HUD_DOWN)
		await t.create_timer(0.3).timeout
		root.get_texture().get_image().save_png(out + "/h2_sink.png")
	root.get_texture().get_image().save_png(out + "/h2_end.png")
	print("balls rolling: ", fs._launching, " arts ", fs._arts.artifacts.size(), " chip positions ", fs._arts.get_children().map(func(c): return c.position))
	for b in [fs._cast_btn, fs._clear_btn, fs._end_btn, fs._menu_btn]:
		print("button ", b.text, " rect ", b.get_global_rect(), " disabled ", b.disabled)
	t.quit()


func _walk_hud(n: Node, z: int, items: Array, order: Array) -> void:
	var zz := z
	if n is CanvasItem and n.z_index != 0 and n.z_as_relative:
		zz += n.z_index
	elif n is CanvasItem and not n.z_as_relative:
		zz = n.z_index
	if n is CanvasItem and not n.is_visible_in_tree():
		return
	order[0] += 1
	var tex: Texture2D = null
	var rect := Rect2()
	if n is TextureRect and n.texture != null:
		tex = n.texture
		rect = n.get_global_rect()
	elif n is Control:
		for sn in ["panel", "normal"]:
			var sb: StyleBox = n.get_theme_stylebox(sn) if n.has_theme_stylebox(sn) else null
			if sb is StyleBoxTexture and sb.texture != null:
				tex = sb.texture
				rect = n.get_global_rect()
				break
	if tex != null and tex.resource_path.contains("/UI/") and not tex.resource_path.contains("Essence") and not tex.resource_path.contains("/Icons") and rect.position.y > 850.0:
		var gt: Transform2D = n.get_global_transform()
		var r2: Rect2 = gt * Rect2(Vector2.ZERO, n.size)
		items.append({"tex": tex.resource_path, "rect": [r2.position.x, r2.position.y, r2.size.x, r2.size.y], "z": zz, "order": order[0], "alpha": n.modulate.a, "name": str(n.name)})
	for c in n.get_children():
		_walk_hud(c, zz, items, order)
