extends SceneTree
## Rope mode (Room Test, F5) screenshots: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus -s tools/rope_shot.gd -- <out dir>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/rope_shot_impl.gd").new()
	await impl.run(self)
