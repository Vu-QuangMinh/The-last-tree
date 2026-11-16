extends SceneTree
## Clicking cards while one resolves queues them (the no-target ones), cast in the order clicked. Windowed (the fight
## screen's animations): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/cast_queue_test.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/cast_queue_test_impl.gd").new()
	await impl.run(self)
