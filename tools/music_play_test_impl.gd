extends RefCounted
## Music Edit: the listen button plays, the bar follows and seeks: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/music_play_test.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://music_play.json")
	UiTheme.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.0).timeout
	main.open_settings()
	await t.create_timer(0.5).timeout
	var st = main.overlay_layer.get_child(main.overlay_layer.get_child_count() - 1)
	st._open_music_edit()
	await t.create_timer(0.3).timeout
	var me = st._music_edit
	Audio.set_theme("anysong_nov02")  # (the tracks of the older mp3s)
	me._theme = "anysong_nov02"
	me._build()
	Audio.set_music_level(0.0)
	Audio.play_music("menu")
	me._select(2)
	await t.create_timer(0.3).timeout
	print("tracks: ", Audio.list_tracks("fight_1"))
	me._play_btn.pressed.emit()
	await t.create_timer(1.2).timeout
	print("bg paused: ", Audio._music.stream_paused, " preview db: ", Audio._preview.volume_db); print("preview playing: ", Audio._preview.playing, " path=", Audio.current_preview_path(), " len=", Audio.preview_length(), " pos=", Audio.preview_position(), " btn=", me._play_btn.text, " bar=", me._seek.value, " time=", me._time.text)
	me._seek.value = 0.5
	await t.create_timer(0.5).timeout
	print("after seek: pos=", Audio.preview_position(), " bar=", me._seek.value, " time=", me._time.text)
	root.get_texture().get_image().save_png(out + "/music_play.png")
	Audio.stop_preview()
	var path := "res://assets/Global/Music/fight_1/zz_del_test.mp3"
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/Global/Music/fight_1/AnySong - Showtime in the Meadow.mp3"), ProjectSettings.globalize_path(path))  # (a throw-away copy for the X button)
	print("test file there: ", FileAccess.file_exists(path), " tracks ", Audio.list_tracks("fight_1"))
	Audio.set_theme("old")  # (a file with no theme prefix)
	Audio.set_track("fight_1", "zz_del_test.mp3")
	me._theme = "old"
	me._build()
	await t.create_timer(0.3).timeout
	var del: Button = null
	for b in me.find_children("*", "Button", true, false):
		if b.text == "X":
			del = b
	del.pressed.emit()
	await t.create_timer(0.3).timeout
	print("after X: file there: ", FileAccess.file_exists(path), " tracks ", Audio.list_tracks("fight_1"), " pick ", Audio.get_track("fight_1"))
	print("MUSIC PLAY DONE")
	t.quit()

