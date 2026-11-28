extends RefCounted
## The carnival artifacts on the real screens: every badge; a fight with some of them; the Glow Stick and the Coal
## Heart going off (mid-flight and at impact); the Carver's choice and its "Carved!"; the Halo stopping a curse.

var t: SceneTree
var out := ""


func _shot(name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	out = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://artifacts_shot.json")
	save.data.settings["theme"] = "puppet"
	# every badge
	var cl := CanvasLayer.new()
	cl.layer = 100
	var sheet := Control.new()
	sheet.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.08)
	bg.size = sheet.size
	sheet.add_child(bg)
	var ids := ["red_token", "blue_token", "green_token", "rainbow_token", "thorn_heart", "carver", "collector", "mysterious_hand",
		"golden_ticket", "bulwark", "coal_heart", "candy_apple", "dark_heart", "halo", "kunai", "hammer", "glow_stick", "cactus_plushie",
		"monochrome_prism", "shopping_list", "magician_hat", "leather_glove", "blood_pact", "cursed_book", "switcheroo"]
	for i in ids.size():
		var ic := UiSkin.artifact_icon(ids[i], 120.0)
		ic.position = Vector2(40 + (i % 9) * 205, 60 + (i / 9) * 320)
		sheet.add_child(ic)
		var l := UiTheme.label(String(Artifacts.get_def(ids[i]).name), 20, Color.WHITE)
		l.position = ic.position + Vector2(-20, 135)
		sheet.add_child(l)
	cl.add_child(sheet)
	root.add_child(cl)
	await t.create_timer(0.8).timeout
	await _shot("a1_badges")
	cl.queue_free()
	# a fight with some of them
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	for a in ["glow_stick", "coal_heart", "kunai", "hammer", "bulwark", "red_token", "halo"]:
		m.run.artifacts.append(a)
	m._start_fight(["iceling", "ashling"])
	await t.create_timer(6.0).timeout
	await _shot("a2_fight")
	var br: MarbleBridge = m.current.fight
	var anim: Callable = br.anim
	br.m._art_ev("glow_stick", "10 Burn!", 0, true)
	br.m._art_ev("coal_heart", "+2 HP")
	br._b_play(br._b_take(), false)
	await t.create_timer(0.22).timeout
	await _shot("a3_glow_flying")
	await t.create_timer(0.14).timeout
	await _shot("a4_glow_impact")
	await t.create_timer(0.7).timeout
	await _shot("a5_coal_heart")
	await t.create_timer(1.5).timeout
	# the Carver
	m._tickets.carve(1)
	await t.create_timer(0.6).timeout
	await _shot("a6_carver_pick")
	var po: PickOverlay = root.find_children("*", "PickOverlay", true, false)[0]
	po._click(0)
	await t.create_timer(0.6).timeout
	await _shot("a7_carver_roll")
	po = root.find_children("*", "PickOverlay", true, false)[0]
	po._click(1)
	await t.create_timer(0.5).timeout
	await _shot("a8_carved")
	await t.create_timer(2.5).timeout
	# the Halo
	m.run.curse()
	m._play_curses()
	await t.create_timer(6.0).timeout
	await _shot("a9_halo")
	print("anim callable valid: ", anim.is_valid())
