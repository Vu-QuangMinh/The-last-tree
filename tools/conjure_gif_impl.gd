extends RefCounted

var root: Window
var tree: SceneTree
var out := ""
var k := 0
var recording := true


func run(t: SceneTree) -> void:
	tree = t
	root = t.root
	out = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://conjure_gif_save.json")
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 21)
	run.learn_spell("stormcaller")
	var f := run.make_fight(["puddle_slime"])
	for e in f.enemies:
		e.elements = ["W", "W", "W", "W", "W", "W", "W", "W", "W", "W"]
		e.armor.resize(10)
		e.armor.fill(false)
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await _frames(20)
	fs.auto_release = false  # keep the turn open so the conjured spells can be cast for the recording
	fs.phase = "spells"
	f.spoken = true
	f.chant = ["A", "F", "A"]
	f.charges = {"stormcaller": 1}
	fs._refresh_all()
	_record()
	await _frames(10)
	fs._on_card_clicked(fs._card_for("stormcaller"))
	await _frames(70)
	# cast the conjured spells one after the other: the first switches off, the last merges back
	for sp in f.loadout.filter(func(s): return s.get("ephemeral", false)):
		f.charges[sp.id] = 1
		fs.busy = false
		fs._refresh_all()
		var c: SpellCard = fs._card_for(sp.id)
		if c != null:
			if fs._needs_pick(sp):
				f.resolve_spell(sp.id, 0)
			else:
				fs._on_card_clicked(c)
		await _frames(60)
	await _frames(20)
	recording = false
	print("FRAMES ", k)


func _record() -> void:
	while recording:
		await tree.process_frame
		await tree.process_frame
		if not recording:
			break
		root.get_texture().get_image().save_png("%s_%03d.png" % [out, k])
		k += 1


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame
