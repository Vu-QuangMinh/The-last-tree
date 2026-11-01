extends SceneTree
## Every text of the given events (pages, outcomes) with the key the game plays its voice under: godot --headless --path . --script res://tools/dump_event_texts.gd -- out.json id [id ...]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: Array = []
	for id in args.slice(1):
		var seen := {}
		_walk(MapEvents.get_event(id), id, out, seen)
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	quit()


func _walk(node, id: String, out: Array, seen: Dictionary) -> void:
	if node is Dictionary:
		for k in node:
			if (k == "text" or k == "text_if_owned") and node[k] is String and not seen.has(node[k]):
				seen[node[k]] = true
				out.append({"event": id, "key": ("evv_" + String(node[k]).md5_text().substr(0, 8)), "text": node[k]})
			else:
				_walk(node[k], id, out, seen)
	elif node is Array:
		for v in node:
			_walk(v, id, out, seen)
