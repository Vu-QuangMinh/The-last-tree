extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_shot.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	r.amber = 300
	for id in ["thornbark", "wind_chime", "ember_charm"]:
		if Artifacts.view(id, false) != null:
			r.gain_artifact(id)
	var sh := ShopScreen.new()
	sh.setup(r, r.shop_stock())
	root.add_child(sh)
	await t.create_timer(2.0).timeout
	root.get_texture().get_image().save_png(out + "/shop.png")
	t.quit()
