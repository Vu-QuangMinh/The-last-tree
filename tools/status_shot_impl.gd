extends RefCounted
## See tools/status_shot.gd.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://status_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m._start_fight(["iceling", "ashling"])
	await t.create_timer(6.0).timeout
	var br: MarbleBridge = m.current.fight
	var f0 = br.m.foes[0]
	f0.burn = 3
	f0.weak = 2
	f0.expose = 1
	f0.power = 1
	br.m.foes[1].stun = 1
	br.m.foes[1].thorns = 2
	br.m.my_power = 2
	br.m.my_thorns = 3
	br.m.weak = 1
	br._b_show(br.m.snap())
	br._b_sync()
	m.current._h_hud._refresh_all()
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/s1_statuses.png")
	var chips := root.find_children("*", "TipPanel", true, false).filter(func(c): return c.get_parent() != null and c.get_parent().name == "Icons")
	print("enemy status chips: ", chips.size())
	if not chips.is_empty():
		var at: Vector2 = (chips[0] as Control).get_global_rect().get_center()
		root.warp_mouse(at)
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		root.push_input(mm)
		await t.create_timer(1.2).timeout
		root.get_texture().get_image().save_png(out + "/s2_hover.png")
