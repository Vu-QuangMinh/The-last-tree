extends RefCounted
## Elemental Fishing on its stage (real main flow): the fisherman and his flat stream, the sea (back wall + reefs, kelp, algae) while the game is on, the tally, and the act's stage given back.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/fish_stage_test.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://fish_stage_test.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("elemental_fishing")
	await t.create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "/fish_1_start.png")
	(main._overlay as EventStage)._choose(0)
	await t.create_timer(2.0).timeout
	(main._overlay as EventStage)._choose(0)  # (Ready)
	await t.create_timer(9.0).timeout
	var g: FishGame = main._overlay as FishGame
	print("game up: ", g != null)
	root.get_texture().get_image().save_png(out + "/fish_2_game.png")
	await t.create_timer(14.0).timeout
	root.get_texture().get_image().save_png(out + "/fish_3_game_later.png")
	g._t = 59.5
	await t.create_timer(6.0).timeout
	print("overlay now: ", main._overlay, " valid ", is_instance_valid(main._overlay), " current ", main.current)
	var es: EventStage = main._overlay as EventStage if is_instance_valid(main._overlay) else null
	print("tally page: ", es != null, " underwater: ", es._stage.is_underwater() if es != null and es._stage != null else "?")
	root.get_texture().get_image().save_png(out + "/fish_4_tally.png")
	var stage: PuppetStage = es._stage
	es.continued.emit()
	await t.create_timer(8.0).timeout
	print("after Continue underwater: ", stage.is_underwater() if is_instance_valid(stage) else "stage gone")
	root.get_texture().get_image().save_png(out + "/fish_5_after.png")
	print("FISH DONE")
	t.quit()
