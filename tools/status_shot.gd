extends SceneTree
## Status symbols in a fight, and one hovered (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/status_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	await load("res://tools/status_shot_impl.gd").new().run(self)
	quit()
