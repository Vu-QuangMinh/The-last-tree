extends SceneTree
## The Test mode screen, its three tabs: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/test_screen_shot.gd -- <out folder>  (ts_0/1/2.png)


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/test_screen_shot_impl.gd").new()
	await impl.run(self)
