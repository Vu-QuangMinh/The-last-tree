extends SceneTree
## Every enemy that is met in a run, with its Essence (and second-phase Essence): godot --headless --path . -s tools/hp_list.gd


func _init() -> void:
	for id in EnemyDefs.E:
		var d: Dictionary = EnemyDefs.E[id]
		if int(d.act) < 1 or d.get("retired", false):
			continue
		var kind := "boss" if d.get("boss", false) else ("mini boss" if d.get("elite", false) else "enemy")
		print("HP act %d | %s | %s | %d%s" % [d.act, kind, d.name, String(d.hp).length(), (" / phase 2: %d" % String(d.hp2).length()) if d.has("hp2") else ""])
	quit()
