extends SceneTree
## Logs chant / cast / release / ball-launch timing: godot --headless --path . -s tools/turn_timing.gd -- <theme>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/turn_timing_impl.gd").new()
	await impl.run(self)
