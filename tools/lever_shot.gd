extends SceneTree
## The Act sign and the lever at 0 / 0.4 / 0.7 / 1 of its pull: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus --audio-driver Dummy -s tools/lever_shot.gd -- <out dir>
func _init() -> void:
	await process_frame
	var impl = load("res://tools/lever_shot_impl.gd").new()
	await impl.run(self)
