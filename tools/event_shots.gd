extends SceneTree
## Every event that has props, on the Puppet Stage (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/event_shots.gd -- <out folder> [event id ...]
func _init() -> void:
	await process_frame
	create_timer(240.0).timeout.connect(quit)
	await load("res://tools/event_shots_impl.gd").new().run(self)
