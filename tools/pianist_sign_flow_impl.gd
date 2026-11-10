extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_sign_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_fight(["pianist"], ["fire_ball", "water_wall", "tailwind"])
	await t.create_timer(5.0).timeout
	var fs = main.current
	if fs._song == null:
		fs._pianist_start()
	await t.create_timer(3.0).timeout
	var cr: Creature = null
	for v in fs._views.values():
		cr = v.creature
	fs._song.pause()
	cr.pianist_point()
	for i in 14:
		await t.create_timer(0.33).timeout
		root.get_texture().get_image().save_png("%s/sign_%02d.png" % [out, i])
