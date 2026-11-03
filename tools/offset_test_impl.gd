extends RefCounted
## A text moved by the F7 inspector keeps its place when it is made again (in a container, a text set after it was made...): godot --path . --headless -s tools/offset_test.gd
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://offset_test.json")
	var key := "the rest of your spells. Powers fire once"
	save.data.settings["text_styles"] = {key: {"font": "default", "px": 0, "spacing": 0.0, "color": "", "dx": 40, "dy": -10}}
	var h := HBoxContainer.new()
	h.position = Vector2(100, 100)
	root.add_child(h)
	var a := UiTheme.label("Spellbook", 22)
	h.add_child(a)
	var b := UiTheme.label("     " + key, 16)  # (made with its words, like the Spellbook's)
	h.add_child(b)
	var c := UiTheme.label("", 16)  # (words set after it was made)
	h.add_child(c)
	c.text = key
	var d := UiTheme.label("plain", 16)
	h.add_child(d)
	await t.create_timer(0.5).timeout
	print("b offset y: ", b.position.y, " (a: ", a.position.y, ")  c: ", c.position.y, "  d: ", d.position.y)
	# the real Loadout screen: its Spellbook line, with and without a saved offset
	var gd = root.get_node("GameData")
	var pos := []
	for with_style in [false, true]:
		save.data.settings["text_styles"] = {"the rest of your spells. Powers fire once, then leave the row for the rest of the fight.": {"font": "default", "px": 0, "spacing": 0.0, "color": "", "dx": 0, "dy": -30}} if with_style else {}
		var run := RunState.new()
		run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
		var l := LoadoutScreen.new()
		l.setup(run, ["stone_knight"])
		root.add_child(l)
		await t.create_timer(0.7).timeout
		for n in l.find_children("*", "Label", true, false):
			if (n as Label).text.contains("the rest of your spells"):
				pos.append((n as Control).global_position)
		l.queue_free()
		await t.create_timer(0.2).timeout
	print("loadout label: ", pos)
	# the same through the inspector: pick the line, move it, Save, build the screen again
	save.data.settings["text_styles"] = {}
	var run2 := RunState.new()
	run2.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var l2 := LoadoutScreen.new()
	l2.setup(run2, ["stone_knight"])
	root.add_child(l2)
	await t.create_timer(0.7).timeout
	var lab: Label = null
	for n in l2.find_children("*", "Label", true, false):
		if (n as Label).text.contains("the rest of your spells"):
			lab = n
	var before := lab.global_position
	TextInspector.toggle(root)
	await t.create_timer(0.3).timeout
	var ins = TextInspector._open
	ins._on_catcher_click(lab.global_position + Vector2(20, 8))
	print("selected: ", ins._sel == lab, "  isolate: ", ins._isolate.button_pressed)
	ins._nudge(Vector2(50, -25))
	await t.create_timer(0.2).timeout
	print("moved live: ", lab.global_position - before)
	ins.save()
	print("styles in settings: ", save.data.settings.get("text_styles", {}))
	l2.queue_free()
	await t.create_timer(0.3).timeout
	var l3 := LoadoutScreen.new()
	l3.setup(run2, ["stone_knight"])
	root.add_child(l3)
	await t.create_timer(0.7).timeout
	for n in l3.find_children("*", "Label", true, false):
		if (n as Label).text.contains("the rest of your spells"):
			print("rebuilt: ", n.global_position - before)
	print("OFFSET DONE")
	t.quit()
