extends SceneTree
func _init() -> void:
	await process_frame
	await load("res://tools/fight_fx_test_impl.gd").new().run(self)
