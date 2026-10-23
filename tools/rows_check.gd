extends SceneTree
## Rows of a boss's Essence in every mode: godot --path . --position 6000,0 --no-focus -s tools/rows_check.gd


func _init() -> void:
	await process_frame
	await load("res://tools/rows_check_impl.gd").new().run(self)
