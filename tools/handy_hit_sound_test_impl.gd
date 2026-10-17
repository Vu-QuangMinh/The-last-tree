extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://handy_hit_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["handyman"])
	f.talk_id = ""
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	var picks := []
	var sw = f.enemies.filter(func(x): return x.id == "hand_sword")[0]
	var twz = f.enemies.filter(func(x): return x.id == "hand_tweezer")[0]
	for k in 6:
		fs._views[sw].hit_flash()
		picks.append(Creature._handy_hit_last)
		await t.create_timer(0.6).timeout
	var before := Creature._handy_hit_at
	fs._views[twz].hit_flash()  # (right after another: the second grunt of the same moment is skipped)
	fs._views[sw].hit_flash()
	print("grunts picked: ", picks, "  two hits at once made one grunt: ", Creature._handy_hit_at != before)
	# a hand knocked out: the one grunt kept for it (hit_2), not a normal one
	var last_normal := Creature._handy_hit_last
	await t.create_timer(0.7).timeout
	var at0 := Creature._handy_hit_at
	sw.knocked = true
	await t.create_timer(0.3).timeout
	print("knock-out grunt played: ", Creature._handy_hit_at != at0, "  normal pick unchanged: ", Creature._handy_hit_last == last_normal)
	# the blow that takes the last Essence makes no normal grunt
	await t.create_timer(0.7).timeout
	var at1 := Creature._handy_hit_at
	while twz.size() > 0:
		twz.elements.pop_back()
		twz.armor.pop_back() if twz.armor.size() > twz.elements.size() else null
	fs._views[twz].hit_flash()
	print("killing blow made a normal grunt: ", Creature._handy_hit_at != at1)
	t.quit()
