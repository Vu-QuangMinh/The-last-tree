extends SceneTree
## Engage through the real screens: stills every 0.25 s from the moment the piece is started (the music begins PIANIST_LEAD_IN s later), with the state printed.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_engage_flow.gd -- <out folder>   (engage_00.png ...)
func _init() -> void:
	create_timer(100.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/pianist_engage_flow_impl.gd").new().run(self)
	quit()
