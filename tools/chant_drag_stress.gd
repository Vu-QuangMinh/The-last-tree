extends SceneTree
## Dragging chant balls down to the Bag in every way a player can (godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/chant_drag_stress.gd).
func _init() -> void:
	await process_frame
	var impl = load("res://tools/chant_drag_stress_impl.gd").new()
	await impl.run(self)
