extends SceneTree
## Lists every enemy with more than 20 Essence in a phase (its own row or its second-phase row; nothing is added on top).
## godot --headless --path . -s tools/hp_over_20.gd


func _init() -> void:
	for id in EnemyDefs.E:
		var d: Dictionary = EnemyDefs.E[id]
		var base := String(d.get("hp", "")).length()
		var hp2 := String(d.get("hp2", "")).length()
		if maxi(base, hp2) > 20:
			print("OVER20 %s | %s | act %d | %s | %d%s%s" % [id, d.name, int(d.act), "boss" if d.get("boss", false) else ("mini boss" if d.get("elite", false) else "enemy"),
				base, (" / phase 2: %d" % hp2) if hp2 > 0 else "", " RETIRED" if d.get("retired", false) else ("  (reserve: never met)" if int(d.act) == 0 else "")])
	quit()
