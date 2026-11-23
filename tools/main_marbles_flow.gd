extends SceneTree
## Windowed, off screen: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/main_marbles_flow.gd -- <out_dir>


func _init() -> void:
	create_timer(150).timeout.connect(quit)
	await process_frame
	await load("res://tools/main_marbles_flow_impl.gd").new().run(self)
	quit()
