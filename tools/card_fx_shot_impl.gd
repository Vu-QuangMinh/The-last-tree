extends RefCounted
## See tools/card_fx_shot.gd. Each card: a frame before (<id>_base.jpg) and every other frame of its effect (<id>_fNN.jpg).

const IDS := ["spark", "paper_cut", "hail", "laser_beam", "heat_wave", "moth_to_flame", "splash", "heed_my_call",
	"steam_engine", "bite", "fire_storm", "chosen_one"]


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var ids: Array = Array(args[1].split(",")) if args.size() > 1 else IDS
	var save = root.get_node("SaveManager")
	save.use_test_file("user://card_fx_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m._start_fight(["iceling", "zephling", "ashling"])
	await t.create_timer(6.0).timeout
	var fs: FightScreen = m.current
	root.warp_mouse(Vector2(1900, 1070))  # (no hover tooltips in the pictures)
	fs.get_viewport().gui_release_focus()
	var br: MarbleBridge = fs.fight
	for id in ids:
		var c := MarbleCards.card(String(id))
		var fx := MarblesFight.fx_of(c)
		if fx.is_empty():
			fx = {"op": "passive", "to": "you", "n": 1}
		var targets := []
		match String(fx.to):
			"foe": targets = [br.alive()[int(OS.get_environment("SHOT_TARGET")) if OS.get_environment("SHOT_TARGET") != "" else 1]]
			"all": targets = br.alive()
		var eff := {"op": String(fx.op), "n": int(fx.n), "target": "self" if String(fx.to) == "you" else "target"}
		var sp: Dictionary = br.loadout[0]
		var base := root.get_texture().get_image()
		base.resize(960, 540)
		base.save_jpg("%s/%s_base.jpg" % [out, id], 0.9)
		fs._anim({"type": "spell_effect", "op": String(fx.op), "eff": eff, "targets": targets, "spell": sp, "from_artifact": "", "drawn": [], "card": String(id)})
		for fr in 84:  # (every other frame for ~1.4 s: tools pick the frames where most is happening)
			await t.process_frame
			if fr % 2 == 0:
				var img := root.get_texture().get_image()
				img.resize(960, 540)
				img.save_jpg("%s/%s_f%02d.jpg" % [out, id, fr], 0.9)
		await t.create_timer(1.0).timeout
		print("SHOT ", id, " ", CardFx.family(String(id)))
