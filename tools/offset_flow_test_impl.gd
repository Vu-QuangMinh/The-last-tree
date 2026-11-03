extends RefCounted
## The Spellbook line moved with the F7 inspector, Saved, and the Loadout screen opened again through main's own flow: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/offset_flow_test.gd
func _label(root: Node) -> Label:
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).text.to_lower().contains("the rest of your spells"):
			return n
	return null


func _open_loadout(main, save) -> Label:
	main.show_menu()
	await main.get_tree().create_timer(1.0).timeout
	main.run = RunState.new()
	main.run.setup(GameData.db, save.unlocked_spells(), save.unlocked_artifacts())
	main._show_loadout(["stone_knight"])
	await main.get_tree().create_timer(2.0).timeout
	return _label(main)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://offset_flow_test.json")
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://save.json")).settings
	save.data.settings = real.duplicate(true)  # (the player's own settings: theme, fonts, edits, moved texts)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	var styles: Dictionary = save.data.settings.text_styles
	var key := "the rest of your spells. Powers fire once, then leave the row for the rest of the fight."
	print("theme: ", save.data.settings.get("theme"), "  style for the line: ", styles.get(key))
	# the player's settings without the line's own style: open the Loadout, change the line as the player did (size, font, a nudge), Save, open it again
	var line_style = styles.get(key)
	styles.erase(key)
	var lab: Label = await _open_loadout(main, save)
	var p0 := lab.global_position
	TextInspector.toggle(main)
	await t.create_timer(0.3).timeout
	var ins = TextInspector._open
	ins._on_catcher_click(lab.global_position + Vector2(20, 8))
	print("selected the line: ", ins._sel == lab, "  at ", p0)
	ins._size_changed(30.0)
	await t.create_timer(0.2).timeout
	ins._font_picked(3)  # (UVN Ba Le: the 3rd of FONT_OPTIONS after Default)
	await t.create_timer(0.2).timeout
	var p_font := lab.global_position
	ins._nudge(Vector2(6, -32))
	await t.create_timer(0.3).timeout
	var live := lab.global_position
	print("live: after size+font ", p_font, "  after the nudge ", live, "  (moved ", live - p_font, ")")
	ins.save()
	await t.create_timer(0.3).timeout
	var lab2: Label = await _open_loadout(main, save)
	var par := lab2.get_parent() as Container
	print("  rebuilt label: parent ", par, " sort_children connections: ", par.sort_children.get_connections().size(), "  position ", lab2.position, "  off ", lab2.get_meta("off", "none"), " applied ", lab2.get_meta("off_applied", "none"), " base would be ", lab2.position - Vector2(lab2.get_meta("off_applied", Vector2.ZERO)))
	par.queue_sort()
	await t.create_timer(0.3).timeout
	print("  after one more sort: position ", lab2.position)
	print("opened again: ", lab2.global_position, "  live was: ", live, "  difference: ", lab2.global_position - live)
	print("  style in settings: ", save.data.settings.text_styles.get(key))
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/flow_real.png")
	print("FLOW DONE")
	t.quit()
