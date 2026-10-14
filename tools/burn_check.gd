extends SceneTree
func _init() -> void:
	await process_frame
	await load("res://tools/burn_check_impl.gd").new().run(self)
