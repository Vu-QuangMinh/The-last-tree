extends RefCounted
## The light-and-impact pass on the real fight screen: a card cast, the chant lighting up, a hit with its number, a kill,
## a heal on you; and Juice.pop (a reward picked, something bought).

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
	save.use_test_file("user://juice_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m._start_fight(["iceling", "ashling"])
	await t.create_timer(6.0).timeout
	var fs: FightScreen = m.current
	var br: MarbleBridge = fs.fight
	br.anim.call({"type": "spell", "spell": br.loadout[0]})
	await t.create_timer(0.1).timeout
	await _shot("j1_cast")
	await t.create_timer(0.6).timeout
	br.anim.call({"type": "chant", "chant": "FWA"})
	await t.create_timer(0.12).timeout
	await _shot("j2_chant")
	await t.create_timer(0.6).timeout
	br.m._hit(br.m.foes[0], 4)
	br._b_play(br._b_take(), false)
	await t.create_timer(0.12).timeout
	await _shot("j3_hit")
	await t.create_timer(1.0).timeout
	br.m._hit(br.m.foes[1], 30)
	br._b_play(br._b_take(), false)
	await t.create_timer(0.25).timeout
	await _shot("j4_big_hit_and_kill")
	await t.create_timer(1.2).timeout
	br.m.run.hp = 30
	br.m._heal(8)
	br._b_play(br._b_take(), false)
	await t.create_timer(0.15).timeout
	await _shot("j5_heal")
	await t.create_timer(1.0).timeout
	Juice.pop(t, Vector2(960, 540), Color(1.0, 0.82, 0.3), "Bought!", true)
	await t.create_timer(0.1).timeout
	await _shot("j6_bought")
