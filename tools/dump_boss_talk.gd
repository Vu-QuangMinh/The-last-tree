extends SceneTree
## The boss's lines to be spoken (id, reply, reply2) from BossTalk: godot --headless --path . --script res://tools/dump_boss_talk.gd -- out.json <boss id>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: Array = []
	var tree: Dictionary = BossTalk.tree_for(args[1])
	if tree.has("greeting"):
		out.append({"id": String(tree.get("voice_greeting", args[1] + "_greeting")), "reply": tree.greeting, "reply2": ""})
	_walk(tree.get("options", []), out)
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	quit()


func _walk(nodes: Array, out: Array) -> void:
	for n in nodes:
		if n.has("reply"):
			out.append({"id": n.id, "reply": n.reply, "reply2": n.get("reply2", "")})
		_walk(n.get("options", []), out)
