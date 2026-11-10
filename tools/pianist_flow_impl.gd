extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_fight(["pianist"], ["fire_ball", "water_wall", "tailwind"])
	await t.create_timer(5.0).timeout
	var fs = main.current
	if fs._song == null:
		fs._pianist_start()
	var e: EnemyState = fs.fight.enemies[0]
	await t.create_timer(3.0).timeout
	for i in 6:
		_shot(root, out, "play_%d" % i)
		await t.create_timer(0.37).timeout
	fs._song.pause()  # (the page turn: the music stops, he points at the sign, then the page swings)
	fs._page_turn(e)
	for i in 4:
		await t.create_timer(0.7).timeout
		_shot(root, out, "page_%d" % i)
	fs._song.resume()
	await t.create_timer(1.0).timeout
	fs._pianist_finale()
	for i in 3:
		await t.create_timer(0.5).timeout
		_shot(root, out, "end_%d" % i)


func _shot(root: Window, out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
