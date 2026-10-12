extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://layers"
	DirAccess.make_dir_recursive_absolute(out)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://layers_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	run.gain_artifact("ember_charm")
	var f := run.make_fight(["greenseer", "yin_yang_clone", "rolling_bear"])
	# a transparent 3840 x 2160 viewport that shows the screen's 1920 x 1080 layout at 2x
	var vp := SubViewport.new()
	vp.size = Vector2i(3840, 2160)
	vp.size_2d_override = Vector2i(1920, 1080)
	vp.size_2d_override_stretch = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var fs := FightScreen.new()
	fs.setup(run, f)
	vp.add_child(fs)
	await t.create_timer(7.0).timeout
	fs._prompt.visible = false
	var menu: Node = null
	for c in fs.get_children():
		if c is Button and c.text.contains("Menu"):
			menu = c
	var stage: Node = fs._stage
	var quads: Array = []
	var props: Array = []
	for c in stage.get_children() + stage._scene.get_children():
		if c is Sprite2D or c is Polygon2D:
			props.append(c)
		else:
			quads.append(c)
	var lights: Node = null
	for c in fs.get_children():
		if c is StageLights:
			lights = c
	# layer name -> [nodes of fs that stay visible, extra visibility toggles]
	var layers := [
		["01_stage", [fs._backdrop, stage], quads, props],
		["02_props", [stage], props, quads],
		["03_spotlights", [lights], [], []],
		["04_enemies", [fs._enemy_row], [], []],
		["05_spell_cards", [fs._spell_row], [], []],
		["06_chant_strip", [fs._chant_panel], [], []],
		["07_bag_and_machine", [fs._bag_panel], [], []],
		["08_keeper_panel", [fs._player_panel], [], []],
		["09_hud", [fs._info, fs._arts, menu], [], []],
	]
	var rects := {}
	var add_mat: Material = lights.material
	lights.material = null  # (the spotlights are ADDED to the stage on screen; on their own transparent layer they are plain translucent light)
	for L in layers:
		for c in fs.get_children():
			c.visible = L[1].has(c)
		for n in L[2]:
			n.visible = true
		for n in L[3]:
			n.visible = false
		await t.process_frame
		await t.process_frame
		await t.process_frame
		vp.get_texture().get_image().save_png(out + "/" + L[0] + ".png")
	lights.material = add_mat
	for c in fs.get_children():
		c.visible = true
	fs._log.visible = false
	fs._prompt.visible = false
	for n in props:
		n.visible = true
	for n in quads:
		n.visible = true
	await t.process_frame
	await t.process_frame
	await t.process_frame
	vp.get_texture().get_image().save_png(out + "/00_reference_flat.png")
	# layout numbers (px of the 1920 x 1080 screen)
	var items := {
		"Chant strip (panel)": fs._chant_panel, "Bag strip + machine (panel)": fs._bag_panel, "Spell row": fs._spell_row,
		"Enemy row": fs._enemy_row, "Keeper panel": fs._player_panel, "Chant row (rings)": fs._chant_row, "Chant button": fs._cast_btn,
		"Clear button": fs._clear_btn, "Pass button": fs._end_btn, "Chant note text": fs._chant_note, "Bag Essence row": fs._stock_row,
		"Artifacts": fs._arts, "Info line": fs._info, "Menu button": menu,
	}
	for k in items:
		var n: Control = items[k]
		var r := n.get_global_rect()
		rects[k] = [round(r.position.x), round(r.position.y), round(r.size.x), round(r.size.y)]
	rects["Stage base bottom (y)"] = [0, round(fs._chant_panel.position.y), 1920, 0]
	var vi := 0
	for e in fs._views:
		vi += 1
		var v: EnemyView = fs._views[e]
		var r2 := v.get_global_rect()
		rects["Enemy %d: %s (view)" % [vi, e.def.name]] = [round(r2.position.x), round(r2.position.y), round(r2.size.x), round(r2.size.y)]
		var cr := v.creature.get_global_rect()
		rects["Enemy %d: %s (puppet)" % [vi, e.def.name]] = [round(cr.position.x), round(cr.position.y), round(cr.size.x), round(cr.size.y)]
	var jf := FileAccess.open(out + "/layout.json", FileAccess.WRITE)
	jf.store_string(JSON.stringify(rects, "\t"))
	jf.close()
	t.quit()
