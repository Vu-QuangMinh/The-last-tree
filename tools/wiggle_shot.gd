extends SceneTree
## The reward choice, alive (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/wiggle_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	await load("res://tools/wiggle_shot_impl.gd").new().run(self)
	quit()
