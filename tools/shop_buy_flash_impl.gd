extends RefCounted
const CORNER := Rect2i(0, 0, 700, 420)  # (the upper left of the 1600 x 900 test window)


func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in range(0, CORNER.size.y, 2):
		for x in range(0, CORNER.size.x, 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.25:
				n += 1
	return n


func run(t: SceneTree) -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	t.create_timer(170.0).timeout.connect(t.quit)
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_stage_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	for _i in 60:
		await t.create_timer(0.25).timeout
		if m._overlay != null:
			break
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	m.run.amber = 300
	var col: int = m.run.choices()[0]
	m.run.map[m.run.row + 1][col].type = "shop"
	m._overlay.node_chosen.emit(col)
	await t.create_timer(24.0).timeout
	var shop = m._overlay
	await t.process_frame
	var base := root.get_texture().get_image().get_region(CORNER)
	shop._buy(0)
	for i in 12:
		await t.process_frame
		var img := root.get_texture().get_image().get_region(CORNER)
		var d := _diff(base, img)
		print("frame ", i, " corner pixels changed: ", d)
		if d > 40:
			img.save_png("%s/flash_%02d.png" % [out, i])
	t.quit()
