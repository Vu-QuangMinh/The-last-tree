extends SceneTree
## see music_shots_impl.gd
func _init() -> void:
	await process_frame
	create_timer(120.0).timeout.connect(quit)
	await load("res://tools/music_shots_impl.gd").new().run(self)
