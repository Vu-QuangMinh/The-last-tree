extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/event_edit_test.gd   (EDIT_OUT=<folder> for the still)
func _init() -> void:
	await process_frame
	create_timer(60.0).timeout.connect(quit)
	await load("res://tools/event_edit_test_impl.gd").new().run(self)
