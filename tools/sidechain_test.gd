extends SceneTree
## Does a sound effect duck the music? Plays a music track, then an effect, and prints the Music bus level (peak, dB) around it:
## godot --path . --audio-driver Dummy -s tools/sidechain_test.gd   (headless-safe: the Master bus is muted by the -s flag, the Music bus level is read before it)


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/sidechain_test_impl.gd").new()
	await impl.run(self)
