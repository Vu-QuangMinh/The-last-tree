extends SceneTree
## The Hush Moth in a fight, flying then knocked down (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/moth_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	await load("res://tools/moth_shot_impl.gd").new().run(self)
	quit()
