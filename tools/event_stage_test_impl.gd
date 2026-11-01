extends RefCounted
var _got := -99
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_stage_test.json")
	save.data.settings["theme"] = "puppet"
	var bad := 0
	var n := 0
	for id in EventStage.LAYOUTS:
		var ev: Dictionary = MapEvents.get_event(id)
		for i in ev.options.size():
			var es := EventStage.new()
			es.ev = ev
			es.disabled = []
			_got = -99
			es.picked.connect(func(k: int): _got = k)
			root.add_child(es)
			await t.process_frame
			es._choose(i)
			var waited := 0.0
			while _got == -99 and waited < 3.0:
				await t.create_timer(0.1).timeout
				waited += 0.1
			n += 1
			if _got != i:
				bad += 1
				print("FAIL ", id, " option ", i, " got ", _got)
			es.queue_free()
			await t.process_frame
	# items on the stage: two artifacts asked for by the Mystery Shed are picked by two clicks, one id each
	var es2 := EventStage.new()
	es2.ev = MapEvents.get_event("mystery_shack")
	es2.items = [{"opt": 2, "kind": "artifact", "id": "thornbark", "need": 2, "spell": {}}, {"opt": 2, "kind": "artifact", "id": "wind_chime", "need": 2, "spell": {}}]
	var got: Array = []
	es2.item_picked.connect(func(o: int, ids: Array): got.append(o); got.append(ids))  # (a lambda gets a copy of a local: it fills the array instead)
	root.add_child(es2)
	await t.process_frame
	es2._item_click(es2.items[0])
	n += 1
	if not got.is_empty():
		bad += 1
		print("FAIL item: emitted after one click")
	es2._item_click(es2.items[1])
	n += 1
	if got.size() != 2 or got[0] != 2 or got[1] != ["thornbark", "wind_chime"]:
		bad += 1
		print("FAIL item: got ", got)
	es2.queue_free()
	print("EVENT STAGE: %d choices, %d failed" % [n, bad])
	t.quit()
