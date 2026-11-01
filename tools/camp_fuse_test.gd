extends SceneTree
## see camp_fuse_test_impl.gd
func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	await load("res://tools/camp_fuse_test_impl.gd").new().run(self)
