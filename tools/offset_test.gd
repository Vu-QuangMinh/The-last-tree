extends SceneTree
## see offset_test_impl.gd
func _init() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(quit)
	await load("res://tools/offset_test_impl.gd").new().run(self)
