extends SceneTree
## Ticket screenshots (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/tickets_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(150).timeout.connect(quit)
	await process_frame
	await load("res://tools/tickets_shot_impl.gd").new().run(self)
	quit()
