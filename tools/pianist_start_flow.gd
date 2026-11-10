extends SceneTree
## The Pianist from the moment the fight screen opens, through the real screens: a still every 0.5 s (start_00.png ...), to see the idle position before the music starts.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_start_flow.gd -- <out folder>
func _init() -> void:
	create_timer(100.0).timeout.connect(quit)
	await process_frame
	var root: Window = self.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_start_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._test_fight(["pianist"], ["fire_ball", "water_wall", "tailwind"])
	for i in 14:
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("%s/start_%02d.png" % [out, i])
	quit()
