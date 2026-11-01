extends SceneTree
## Every event with props: each option can be chosen (by `_choose`, like a click on its prop or button) and `picked` comes back with it.
## godot --headless --path . --script res://tools/event_stage_test.gd
func _init() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(quit)
	await load("res://tools/event_stage_test_impl.gd").new().run(self)
