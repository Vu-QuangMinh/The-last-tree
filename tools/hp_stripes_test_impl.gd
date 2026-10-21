extends RefCounted


func _crop(t: SceneTree, name: String) -> void:
	await t.process_frame
	var img: Image = t.root.get_texture().get_image()
	var k := float(img.get_width()) / 1920.0
	var r := Rect2i(Vector2i(int(430 * k), int(940 * k)), Vector2i(int(330 * k), int(110 * k)))
	img.get_region(r).save_png("C:/temp/hp_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://hp_test_save.json")
	save.data.settings["theme"] = "puppet"
	var run := RunState.new()
	run.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.setup(run, run.make_fight(["greenseer", "rolling_bear"]))
	root.add_child(fs)
	await t.create_timer(2.0).timeout
	var p = fs.fight.player
	await _crop(t, "1_full")
	p.hp = 31.0
	fs._refresh_all()
	await t.create_timer(0.25).timeout
	await _crop(t, "2_hit_mid")
	await t.create_timer(1.6).timeout
	await _crop(t, "3_hit_after")
	p.shield = 12.0
	fs._refresh_all()
	await t.create_timer(0.3).timeout
	await _crop(t, "4_shield_mid")
	await t.create_timer(1.0).timeout
	await _crop(t, "5_shield")
	p.shield = 3.0
	fs._refresh_all()
	await t.create_timer(0.25).timeout
	await _crop(t, "6_shield_break_mid")
	await t.create_timer(1.5).timeout
	await _crop(t, "7_shield_small")
	p.shield = 0.0
	p.hp = 44.0
	fs._refresh_all()
	await t.create_timer(0.3).timeout
	await _crop(t, "8_heal_mid")
	await t.create_timer(1.2).timeout
	await _crop(t, "9_healed")
	t.quit()
