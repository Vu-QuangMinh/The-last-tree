extends SceneTree
## They See Me Rolling on the Puppet Stage: the bush, the hover tag, the click on the bear (shatter + coins). godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/bear_shot.gd -- <out folder>
func _init() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(quit)
	await load("res://tools/bear_shot_impl.gd").new().run(self)
