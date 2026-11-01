extends RefCounted
## An Abandoned Camp on its stage (real main flow): the torch cursor, picking two spells, fusing in the cauldron, the new card + Continue.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/camp_fuse_test.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://camp_fuse_test.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("lost_camp")
	await t.create_timer(3.0).timeout
	var es: EventStage = main._overlay as EventStage
	print("cursor override: ", WoodCursor.override_name)
	root.get_texture().get_image().save_png(out + "/camp_1_start.png")
	es._choose(0)
	await t.create_timer(2.0).timeout
	print("fusable: ", es._fz_ids.size()," row ", es._fz_row.size())
	root.get_texture().get_image().save_png(out + "/camp_2_cards.png")
	es._fuse_click(es._fz_ids[0])
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/camp_3_one.png")
	var second := ""
	for id: String in es._fz_ids:
		if id != es._fz_ids[0] and main.run.can_fuse_pair(es._fz_ids[0], id):
			second = id
			break
	es._fuse_drop(1, {"fuse": second, "from": -1})
	await t.create_timer(0.6).timeout
	print("fuse enabled: ", not es._fz_fuse.disabled)
	root.get_texture().get_image().save_png(out + "/camp_4_two.png")
	es._fuse_go()
	await t.create_timer(1.8).timeout
	root.get_texture().get_image().save_png(out + "/camp_5_fx.png")
	await t.create_timer(3.5).timeout
	root.get_texture().get_image().save_png(out + "/camp_6_result.png")
	print("result: ", es._result_text.left(40))
	es.continued.emit()
	await t.create_timer(1.0).timeout
	print("EXIT cursor override: ", WoodCursor.override_name)
	# the other option: plant the torch
	main._test_event("lost_camp")
	await t.create_timer(3.0).timeout
	es = main._overlay as EventStage
	es._choose(1)
	await t.create_timer(1.2).timeout
	root.get_texture().get_image().save_png(out + "/camp_7_tent.png")
	await t.create_timer(3.0).timeout
	print("CAMP DONE")
	t.quit()
