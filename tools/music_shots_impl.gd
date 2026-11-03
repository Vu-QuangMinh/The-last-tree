extends RefCounted
## The Settings screen (cream buttons) and Settings > Music Edit (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/music_shots.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://music_shots.json")
	save.data.settings["theme"] = "puppet"
	UiTheme.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	for slot in ["menu", "fight_1", "elite_1", "boss_1", "fight_2", "elite_3", "boss_3", "ev_spooky", "ev_church", "map", "boss", "fight"]:
		print("slot ", slot, " -> ", Audio.resolve_category(slot), " : ", Audio.get_track(Audio.resolve_category(slot)))
	print("fight slot elite act 2: ", Audio.fight_slot("elite", 2), "  act 7 boss: ", Audio.fight_slot("boss", 7), "  event well: ", Audio.event_slot("well"), "  event nope: '", Audio.event_slot("nope"), "'")
	Audio.play_music("ev_spooky")
	await t.create_timer(0.5).timeout
	print("playing spooky event track: ", Audio._music.playing, " ", Audio._music.stream.resource_path if Audio._music.stream else "-")
	main.open_settings()
	await t.create_timer(0.8).timeout
	root.get_texture().get_image().save_png(out + "/music_settings.png")
	var st = main.overlay_layer.get_child(main.overlay_layer.get_child_count() - 1)
	st._open_music_edit()
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/music_edit_1.png")
	st._music_edit._select(12)
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/music_edit_2.png")
	st._music_edit._select(4)
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/music_edit_3.png")
	print("MUSIC SHOTS DONE")
	t.quit()
