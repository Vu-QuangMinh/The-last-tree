extends SceneTree
## Headless: godot --headless --path . --script res://tools/marbles_main_test.gd


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame  # (the autoloads first: RunState reaches the screen code through MarbleBridge)
	load("res://tools/marbles_main_test_impl.gd").new().run()
	quit()
