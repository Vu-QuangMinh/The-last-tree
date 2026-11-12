extends RefCounted


func run(t: SceneTree) -> void:
	var root := t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://self_repaint_flow.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["ashling"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	f.player.stock.clear()
	for el in ["W", "A", "W"]:
		f.player.add_element(el)
	f.cast_chant([0, 1, 2])
	await t.create_timer(0.5).timeout
	var sp: Dictionary = f.db.get_spell("ripplewind")
	f.current_eff = {"op": "self_repaint", "n": 2, "to": "W"}
	var done := [false]
	(func():
		await f._apply({"op": "self_repaint", "n": 2, "to": "W"}, sp, {})
		done[0] = true).call()
	await t.create_timer(0.5).timeout
	print("mode=", fs.chant_mode, " chant=", f.chant_string(), " cursor=", fs.chant_i, " blocked=", [fs._chant_blocked(0), fs._chant_blocked(1), fs._chant_blocked(2)])
	fs._h_anim._emit_chant_done(0)  # a Water: refused
	await t.create_timer(0.4).timeout
	print("after click on Water: mode=", fs.chant_mode, " chant=", f.chant_string(), " done=", done[0])
	fs._h_anim._emit_chant_done(1)  # the Air: painted Water
	await t.create_timer(1.5).timeout
	print("after click on Air: chant=", f.chant_string(), " mode=", fs.chant_mode, " done=", done[0])
	fs.queue_free()
	t.quit()
