extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://frames_shot.json")
	save.data.settings["theme"] = "puppet"
	UiTheme.reset()
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["invoker"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(6.0).timeout
	var th := UiTheme.get_theme()
	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel", th.get_stylebox("panel", "TooltipPanel"))
	tip.theme = th
	tip.add_child(UiTheme.label("Tooltip: Scorch deals 4 damage to every enemy.", 21))
	tip.position = Vector2(100, 120)
	fs.add_child(tip)
	var callout: PanelContainer = fs._callout_panel("[b]Burn[/b] — takes 2 damage each turn", Color(1.0, 0.6, 0.2))
	callout.position = Vector2(100, 260)
	fs._speech_bubble(func(): return Vector2(1000, 420), "Not so fast, scoundrel.", 6.0)
	fs._dillo_say(Vector2(1300, 300), "Ouch! My shell!", 6.0)
	var msg := MessageScreen.new()
	msg.title = "Choose"
	msg.body = "Pick one."
	msg.buttons = ["First choice (cost 1): do a thing", "Second choice (cost 2): do another", "Third"]
	fs.add_child(msg)
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out)
	t.quit()
