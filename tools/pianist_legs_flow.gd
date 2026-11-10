extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_legs_flow.gd -- <out folder>   -> leg_01..10.png (1-5 foot down at 5 places, 6-10 raised; the foot is forced)
func _init() -> void:
	create_timer(100.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/pianist_legs_flow_impl.gd").new().run(self)
	quit()
