extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_center_check.json")
	save.data.settings["theme"] = "puppet"
	var r := RunState.new()
	r.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	for a in ["thornbark", "wind_chime", "ember_charm"]:
		r.artifacts.append(a)
	var bad := 0
	for id in EventStage.LAYOUTS:
		var ev: Dictionary = MapEvents.get_event(id)
		var es := EventStage.new()
		es.ev = ev
		es.again = true
		for i in ev.options.size():
			var o: Dictionary = ev.options[i]
			var kind := ""
			if o.get("pick_spell", false) or o.get("recycle", "") == "spell" or int(o.get("wax", 0)) > 0 or o.get("do", "") == "note_swap":
				kind = "spell"
			elif o.get("recycle", "") == "artifact" or int(o.get("pick_artifact", 0)) > 0:
				kind = "artifact"
			if kind == "spell":
				for sid in r.spellbook:
					es.items.append({"opt": i, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			elif kind == "artifact":
				for aid in r.artifacts:
					es.items.append({"opt": i, "kind": "artifact", "id": aid, "need": 1, "spell": {}})
		root.add_child(es)
		for k in 4:
			await t.process_frame
		var rects: Array = []
		for v in es._item_views:
			rects.append((v.node as Control).get_global_rect())
		var btns: Array = []
		for n in es._choice_ui:
			if n is HBoxContainer:
				for c in n.get_children():
					if c is Button:
						btns.append((c as Control).get_global_rect())
		for pair in [["items", rects], ["buttons", btns]]:
			var list: Array = pair[1]
			if list.is_empty():
				continue
			var lo := 99999.0
			var hi := -99999.0
			for rc: Rect2 in list:
				lo = minf(lo, rc.position.x)
				hi = maxf(hi, rc.end.x)
			var mid := (lo + hi) / 2.0
			var off := absf(mid - 960.0)
			if off > 8.0:
				bad += 1
			print("%-16s %-8s centre x %.0f (%s)" % [id, pair[0], mid, "OK" if off <= 8.0 else "OFF by %.0f" % off])
		es.queue_free()
		await t.process_frame
	print("CENTER CHECK: %d off" % bad)
	t.quit()
