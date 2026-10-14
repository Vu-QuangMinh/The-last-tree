extends SceneTree
func _init() -> void:
	await process_frame
	await load("res://tools/chant_click_test_impl.gd").new().run(self)
