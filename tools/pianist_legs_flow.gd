extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_legs_flow.gd -- <out folder>   -> leg_1..5.png (the music is left running; the leg picture is forced)
func _init() -> void:
	create_timer(100.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/pianist_legs_flow_impl.gd").new().run(self)
	quit()
