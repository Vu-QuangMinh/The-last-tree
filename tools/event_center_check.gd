extends SceneTree
## Are the spells / items / buttons of every event with props centred on the screen? godot --headless --path . --script res://tools/event_center_check.gd
func _init() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(quit)
	await load("res://tools/event_center_check_impl.gd").new().run(self)
