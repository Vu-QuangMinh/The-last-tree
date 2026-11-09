extends RefCounted
## The five leg pictures of the Pianist, one after the other, through the real screens (see tools/pianist_legs_flow.gd).


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://pianist_legs_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_fight(["pianist"], ["fire_ball", "water_wall", "tailwind"])
	await t.create_timer(5.0).timeout
	var fs = main.current
	if fs._song == null:
		fs._pianist_start()
	var cr: Creature = null
	for v in fs._views.values():
		cr = v.creature
	cr._bk_foot_on = 1.0
	for k in 5:
		cr._bk_lf_target = float(k)
		cr._bk_lf = float(k)
		cr._bk_rh_target = 6.5
		cr._bk_rh = 6.5
		await t.create_timer(0.25).timeout
		cr._bk_lf = float(k)
		cr._bk_foot_on = 1.0
		root.get_texture().get_image().save_png("%s/leg_%d.png" % [out, k + 1])
