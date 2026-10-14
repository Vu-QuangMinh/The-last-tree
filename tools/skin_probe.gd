extends SceneTree
func _init() -> void:
	await process_frame
	await load("res://tools/skin_probe_impl.gd").new().run(self)
