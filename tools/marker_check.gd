extends SceneTree
func _init() -> void:
	await process_frame
	var impl = load("res://tools/marker_check_impl.gd").new()
	await impl.run(self)
