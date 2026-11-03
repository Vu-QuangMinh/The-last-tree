extends SceneTree
## see music_play_test_impl.gd
func _init() -> void:
	await process_frame
	create_timer(60.0).timeout.connect(quit)
	await load("res://tools/music_play_test_impl.gd").new().run(self)
