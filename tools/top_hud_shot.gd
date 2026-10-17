extends SceneTree
## The top HUD: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus -s tools/top_hud_shot.gd -- <out dir>
func _init() -> void:
	await process_frame
	var impl = load("res://tools/top_hud_shot_impl.gd").new()
	await impl.run(self)
