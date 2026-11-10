extends RefCounted
## Engage through the real screens (see tools/pianist_engage_flow.gd).


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_engage_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_fight(["pianist"], ["fire_ball", "water_wall", "tailwind"])
	await t.create_timer(3.0).timeout
	var fs = main.current
	var cr: Creature = null
	for v in fs._views.values():
		cr = v.creature
	fs._pianist_start()
	for i in 14:
		await t.create_timer(0.25).timeout
		print("t=%.2f playing=%s warm=%s foot_on=%.2f lf=%.2f rh=%.1f" % [0.25 * (i + 1), fs._song.playing() if fs._song else "-", cr._bk_warm, cr._bk_foot_on, cr._bk_lf, cr._bk_rh])
		root.get_texture().get_image().save_png("%s/engage_%02d.png" % [out, i])
