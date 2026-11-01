extends SceneTree
## The older "?" events' stage reactions (batch 2): every result word played once on its own stage, a still 1.3 s in (tweens, flights and sounds can't be judged from a still).
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/event_batch2_test.gd -- <out folder> [how ...]
func _init() -> void:
	await process_frame
	create_timer(420.0).timeout.connect(quit)
	await load("res://tools/event_batch2_test_impl.gd").new().run(self)
