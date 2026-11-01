extends SceneTree
## A Note to Yourself through the real screens (Main._test_event): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/note_flow_shot.gd -- <out folder> [event id]
func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	await load("res://tools/note_flow_shot_impl.gd").new().run(self)
