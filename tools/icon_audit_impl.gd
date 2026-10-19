extends RefCounted
## Which pictures the game asks for by name that do not exist (Puppet theme; "fallback" = only the older New art has it).
## godot --headless --path . --script res://tools/icon_audit.gd


func _where(name: String) -> String:
	var p := UiSkin.path_of(name)
	if p == "":
		return "MISSING"
	if p.contains("/Puppet/"):
		return "ok"
	return "fallback"


func run(tree: SceneTree) -> void:
	var root: Window = tree.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://icon_audit.json")
	save.data.settings["theme"] = "puppet"
	var miss := {}  # group -> Array of names
	var fall := {}
	var put := func(group: String, name: String) -> void:
		var w := _where(name)
		if w == "MISSING":
			miss[group] = miss.get(group, []) + [name]
		elif w == "fallback":
			fall[group] = fall.get(group, []) + [name]
	# artifacts
	for a in Artifacts.ALL:
		put.call("artifact", UiSkin.ARTIFACT_ART.get(a.id, a.id))
	# bottles: their own picture, else the nearest-colour generic bottle
	for b in Bottles.ALL:
		put.call("bottle", b.id)
	# intents used by Act 1 enemies (and all kinds the game knows)
	var kinds := {}
	for id in EnemyDefs.E:
		var d: Dictionary = EnemyDefs.E[id]
		for m in d.get("moves", []):
			kinds[m.kind] = d.get("act", 1) if not kinds.has(m.kind) else mini(kinds[m.kind], d.get("act", 1))
			if m.get("also") is Dictionary:
				kinds[m.also.kind] = kinds.get(m.also.kind, d.get("act", 1))
	for k in IntentChip.INFO:
		if not kinds.has(k):
			kinds[k] = 0  # (known to the game, no enemy found using it)
	for k in kinds:
		var art: String = IntentChip.ART.get(k, "")
		if art == "":
			miss["intent (no picture name at all)"] = miss.get("intent (no picture name at all)", []) + ["%s (first used in act %d)" % [k, kinds[k]]]
		else:
			put.call("intent", art)
	# every literal name the scripts ask for
	for n in FileAccess.get_file_as_string("res://tools/icon_audit_names.txt").split("\n", false):
		put.call("literal", n)
	for t in ["fight", "elite", "rest", "treasure", "shop", "event", "boss"]:
		var a: String = MapScreen.ART[t]
		put.call("map icon", "map_icon_" + a)
		put.call("map ring", "map_ring_" + a)
	# statuses
	for n in ["status_burn", "status_poison", "status_freeze", "status_weak", "status_ethereal", "status_aegis", "status_bleed", "status_blind", "status_brittle", "status_confuse", "status_disarmed", "status_echo_ready", "status_frail", "status_overload", "status_silenced", "status_thorns", "status_toll", "status_vulnerable"]:
		put.call("status", n)
	print("== MISSING (nothing at all) ==")
	for g in miss:
		print(g, ": ", ", ".join(miss[g]))
	print("== ONLY IN THE OLD NEW THEME (Puppet falls back to it) ==")
	for g in fall:
		print(g, ": ", ", ".join(fall[g]))
	tree.quit()
