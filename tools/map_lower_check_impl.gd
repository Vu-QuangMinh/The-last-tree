extends RefCounted


func run(t: SceneTree) -> void:
	await t.process_frame
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://map_lower_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, [], [], 0)
	run.act = 3
	run.row = 5
	var m := MapScreen.new()
	m.on_stage = true
	m.setup(run)
	root.add_child(m)
	await t.create_timer(0.3).timeout
	m.rise()
	await t.create_timer(3.5).timeout
	for scroll_to in [0.0, -300.0, m._scroll_max()]:
		m._scroll_y = scroll_to
		m._scroll_to = scroll_to
		m._place_content()
		await m.lower()
		var bottom: float = m._world.position.y + m._content.position.y + m._content.size.y
		print("scroll ", scroll_to, ": map bottom after pulling up at y = ", bottom, " (must be < 0)  world y ", m._world.position.y)
		m._world.position.y = 0.0
	t.quit()
