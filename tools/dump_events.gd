extends SceneTree
## Dumps every event (MapEvents.ALL) to JSON: godot --headless --path . -s tools/dump_events.gd -- <out.json>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(MapEvents.ALL, " "))
	f.close()
	print("DUMPED ", MapEvents.ALL.size())
	quit()
