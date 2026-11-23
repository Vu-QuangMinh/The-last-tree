extends SceneTree
## Windowed: carved marbles on the balls and the boost lines on the main fight screen.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/boost_shot.gd -- <out dir>


func _init() -> void:
	create_timer(150.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/boost_shot_impl.gd").new().run(self)
	quit()
