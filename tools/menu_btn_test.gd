extends SceneTree
## see menu_btn_test_impl.gd
func _init() -> void:
	await process_frame
	create_timer(100.0).timeout.connect(quit)
	await load("res://tools/menu_btn_test_impl.gd").new().run(self)
