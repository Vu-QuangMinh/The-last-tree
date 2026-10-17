extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://cursor_shot.json")
	save.data.settings["theme"] = "puppet"
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.33, 0.22)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	for i in 4:
		var c := AimCursor.new()
		c.mode = "hand"
		c.holding = ["", "F", "W", "A"][i]
		c.point = Vector2(300 + i * 200, 300)
		root.add_child(c)
	await t.create_timer(0.5).timeout
	var args := OS.get_cmdline_user_args()
	var img: Image = root.get_texture().get_image()
	var k := float(img.get_width()) / 1920.0
	img.get_region(Rect2i(Vector2i(int(150 * k), int(180 * k)), Vector2i(int(900 * k), int(240 * k)))).save_png(args[0] if args.size() > 0 else "C:/temp/cursor_hand.png")
	t.quit()
