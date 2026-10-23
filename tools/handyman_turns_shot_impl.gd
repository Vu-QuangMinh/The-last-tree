extends RefCounted
## Real enemy turns of the Handyman fight (turn 1 vs turn 2): frames of the Sword Hand's attack and the Tweezer Hand's steal.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://handyman_turns_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["handyman"])
	var with_talk: bool = args.size() > 2 and args[2] == "talk"
	if not with_talk:
		f.talk_id = ""
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	if with_talk:  # (the boss talk first, as in the real game: press Engage!)
		var btn := _find_button(root, "Engage!")
		print("engage button: ", btn)
		if btn != null:
			btn.pressed.emit()
		await t.create_timer(6.0).timeout
	if args.size() > 1 and args[1] == "emptybag":  # (the bag is empty: the Tweezer Hand grabs at nothing)
		f.player.stock.clear()
		fs._refresh_all()
	for turn in 2:
		f.pass_turn()  # (a coroutine: the turn plays out while we take pictures)
		for k in (90 if args.size() > 1 and args[1] == "dense" else 22):
			await t.create_timer(0.05 if args.size() > 1 and args[1] == "dense" else 0.3).timeout
			_shot(root, out + "/ht_t%d_%02d.png" % [turn + 1, k])
		await t.create_timer(2.0).timeout
	print("done; bag ", f.player.stock.size())
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
