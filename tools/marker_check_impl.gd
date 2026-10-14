extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://marker_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["greenseer", "yeti", "rolling_bear"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	for e in fs._views:
		var v: EnemyView = fs._views[e]
		v.targetable = true
		v.targeted = true
		v.refresh({})
	await t.create_timer(0.5).timeout
	for e in fs._views:
		var v: EnemyView = fs._views[e]
		print(e.id, " marker ", v._marker.get_global_rect(), " puppet ", v.creature.puppet_bounds(), " lift ", fs._extra_lift, " feet ", fs._feet_y(), " floor ", fs._stage.floor_range())
	root.get_texture().get_image().save_png("C:/Users/sonvt/AppData/Local/Temp/claude/C--Users-sonvt/7c0dcdbf-bdfb-49d8-a0ae-8e42a974181a/scratchpad/marker.png")
	t.quit()
