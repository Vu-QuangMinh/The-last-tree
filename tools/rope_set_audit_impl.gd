extends RefCounted
func run(t: SceneTree) -> void:
	print("elites act 3: ", EnemyDefs.elites(3))
	var t_s := TestModeScreen.new()
	var all := []
	for g in t_s._enemy_groups():
		all.append_array(g[1])
	print("fire dragon in test mode: ", all.any(func(id): return String(id).begins_with("dragon_") or id == "fire_dragon"))
	var sets := RopeSets.build("elite", 3)
	print("rope sets elite act 3: ", sets)
	t.quit()
