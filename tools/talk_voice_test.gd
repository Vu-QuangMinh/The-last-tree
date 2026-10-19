extends SceneTree
## The Handyman's talk after "Begin the fight": nothing is said while the board is up, the first line starts when the scene and the HUD are in, its buttons wait for the voice, the later ones do not: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/talk_voice_test.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/talk_voice_test_impl.gd").new().run(self)
