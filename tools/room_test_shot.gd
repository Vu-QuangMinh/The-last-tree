extends SceneTree
## The real Room Test flow, a boss room of a chosen act, one screenshot: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/room_test_shot.gd -- <act> <out.png> [boss|fight|elite]


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/room_test_shot_impl.gd").new().run(self)
