extends SceneTree
## Test mode fight (Auto-fill / Auto-ball buttons): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/test_mode_shot.gd -- <out folder>
## Writes tm_start.png, tm_ball.png (after Auto-ball), tm_fill.png (after Auto-fill) and prints what the chant became.


func _init() -> void:
	await process_frame
	var impl = load("res://tools/test_mode_shot_impl.gd").new()
	await impl.run(self)
