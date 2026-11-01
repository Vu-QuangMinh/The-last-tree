extends RefCounted
## The older "?" events through the REAL screens (main.gd): choose an option, see what the stage says and where Continue leads.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/event_batch2_flow.gd -- <out folder> [event id ...]
const CASES := [
	{"id": "well", "pick": [0]}, {"id": "well", "pick": [2]}, {"id": "lost_sprite", "pick": [0]}, {"id": "lost_sprite", "pick": [1]},
	{"id": "mushroom_ring", "pick": [0]}, {"id": "hollow_stump", "pick": [0]}, {"id": "cursed_shrine", "pick": [0]}, {"id": "cursed_shrine", "pick": [2]},
	{"id": "lost_camp", "pick": [1]}, {"id": "bard", "pick": [1]}, {"id": "bard", "pick": [0]}, {"id": "bard", "pick": [2, 0]},
	{"id": "elemental_fishing", "pick": [0]}, {"id": "mausoleum", "pick": [0]}, {"id": "mausoleum", "pick": [2]},
	{"id": "watchtower", "pick": [0]}, {"id": "watchtower", "pick": [1]}, {"id": "watchtower", "pick": [2]},
	{"id": "skipping_stones", "pick": [0, 0, 0]}, {"id": "mystery_shack", "pick": [0]},
]


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var only: Array = args.slice(1)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_batch2_flow.json")
	save.data.settings["theme"] = "puppet"
	var n := 0
	for c: Dictionary in CASES:
		if not only.is_empty() and not (c.id in only):
			continue
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await t.create_timer(1.5).timeout
		main._test_event(c.id)
		main.run.amber = 300
		main.run.player.take_effect(0.0)
		await t.create_timer(1.8).timeout
		var line := "%s %s: " % [c.id, str(c.pick)]
		for k in c.pick.size():
			var es: EventStage = main._overlay as EventStage
			if es == null:
				line += "[no EventStage at step %d: %s] " % [k, str(main.current)]
				break
			var props_with_opt := es._props.filter(func(r: Dictionary) -> bool: return int(r.opt) >= 0).size()
			line += "(step %d: %d props clickable, again=%s) " % [k, props_with_opt, str(es.again)]
			es._choose(int(c.pick[k]))
			await t.create_timer(4.5 if c.id == "skipping_stones" else 3.0).timeout
		var es2: EventStage = main._overlay as EventStage
		if es2 != null:
			line += "-> stage still up, result: '%s'" % es2._result_text.left(50)
			n += 1
			root.get_texture().get_image().save_png("%s/flow_%02d_%s.png" % [out, n, c.id])
			if es2._result_text != "":
				es2.continued.emit()
				await t.create_timer(2.0).timeout
				line += " | after Continue: %s / overlay %s" % [main.current.get_script().resource_path.get_file() if main.current != null and main.current.get_script() != null else "none", str(main._overlay)]
		else:
			line += "-> no stage overlay, screen: %s" % [str(main.current)]
		print(line)
		main.queue_free()
		await t.process_frame
	print("FLOW DONE")
	t.quit()
