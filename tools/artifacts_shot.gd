extends SceneTree
## Carnival artifact screenshots (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/artifacts_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(160).timeout.connect(quit)
	await process_frame
	await load("res://tools/artifacts_shot_impl.gd").new().run(self)
	quit()
