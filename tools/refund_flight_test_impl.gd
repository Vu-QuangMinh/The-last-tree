extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://refund_save.json")
	save.data.settings["theme"] = "puppet"
	var run := RunState.new()
	run.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.setup(run, run.make_fight(["greenseer"]))
	root.add_child(fs)
	await t.create_timer(3.5).timeout
	for k in 3:
		fs._add_stock_index(k)
		await t.create_timer(0.4).timeout
	var p = fs.fight.player
	p.add_element("F")
	p.add_element("W")
	var uids := [p.stock[p.stock.size() - 2].uid, p.stock.back().uid]
	fs.fight.chant = ["F", "F", "W"]
	var ev := {"type": "refund", "els": ["F", "W"], "uids": uids, "slots": [0, 2]}
	fs._refund_flight(ev)
	for i in 6:
		await t.create_timer(0.45).timeout
		var img: Image = root.get_texture().get_image()
		var k := float(img.get_width()) / 1920.0
		img.get_region(Rect2i(Vector2i(int(900 * k), int(860 * k)), Vector2i(int(1020 * k), int(220 * k)))).save_png("C:/temp/refund_%d.png" % i)
	print("bag icons: ", fs._bag_icons.size(), " flying: ", fs._flying.size())
	t.quit()
