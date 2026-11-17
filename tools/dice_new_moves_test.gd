extends SceneTree
## Die on Stage: the 2026-11-17 moves, each checked once. godot --headless --path . -s tools/dice_new_moves_test.gd


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_new_moves_test_impl.gd").new()
	impl.run(self)
	quit()
