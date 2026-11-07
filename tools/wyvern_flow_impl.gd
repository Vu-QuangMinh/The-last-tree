extends RefCounted
## Stills of the Winter Wyvern in the real flow: at rest (twice, a moment apart: the wings and tail must have moved) and with each intent shown.
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://wyvern_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	if args.size() > 1 and args[1] == "room":
		main.start_room_test()
		await t.create_timer(0.5).timeout
		main._enter_test_room({"type": "elite", "label": "Elite", "act": 3, "row": 8})
	else:
		main._test_fight(["wyvern_head", "wyvern_tail"], ["fire_ball", "water_wall", "tailwind"])
	await t.create_timer(3.5).timeout
	var fs = main.current
	var f: Fight = fs.fight
	var head: EnemyState = f.enemies[0]
	var tail: EnemyState = f.enemies[1]
	for e in fs._views:
		var c = fs._views[e].creature
		if c._dragon != null and e.def.get("rig_part", "") == "head":
			var gt: Transform2D = c.get_global_transform()
			var r = c._dragon
			var l: Vector2 = gt * (r.last_root * Vector2(-510.0, 743.0))
			var rr: Vector2 = gt * (r.last_root * Vector2(1937.0, 743.0))
			print("RIG x from ", l.x, " to ", rr.x, " centre ", (l.x + rr.x) / 2.0, " ground y ", l.y)
	head.intent = {"kind": "silence", "turns": 1}  # (no part pose: the rig rests)
	tail.intent = {"kind": "silence", "turns": 1}
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png("%s/rest_a.png" % out)
	await t.create_timer(0.9).timeout
	root.get_texture().get_image().save_png("%s/rest_b.png" % out)
	var n := 0
	for pose in [[{"head": "up"}, {"tail": "slam"}], [{"head": "bite"}, {"tail": "sweep"}]]:
		head.intent = {"kind": "attack", "n": 2, "parts": pose[0]}
		tail.intent = {"kind": "attack", "n": 2, "parts": pose[1]}
		fs._sync_views()
		fs._refresh_all()
		await t.create_timer(1.6).timeout
		root.get_texture().get_image().save_png("%s/pose_%d.png" % [out, n])
		n += 1
	# the Fireball intent (the head's "up" pose), then the move itself: the head comes up for the shot
	head.intent = {"kind": "summon", "id": "wyvern_fireball", "n": 1, "parts": {"head": "up"}}
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(1.6).timeout
	root.get_texture().get_image().save_png("%s/fire_intent.png" % out)
	for e in fs._views:
		var c = fs._views[e].creature
		if c._dragon != null and e.def.get("rig_part", "") == "head":
			c._dragon.play(head)
	await t.create_timer(0.55).timeout
	root.get_texture().get_image().save_png("%s/fire_move.png" % out)
	await t.create_timer(1.6).timeout
	head.intent = {"kind": "silence", "turns": 1}
	tail.intent = {"kind": "silence", "turns": 1}
	head.winged = false
	tail.winged = false
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(2.5).timeout
	for k in 3:
		root.get_texture().get_image().save_png("%s/wing_%d.png" % [out, k])
		await t.create_timer(0.55).timeout
	t.quit()
