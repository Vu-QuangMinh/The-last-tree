extends SceneTree
## Light-and-impact screenshots (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/juice_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	await load("res://tools/juice_shot_impl.gd").new().run(self)
	quit()
