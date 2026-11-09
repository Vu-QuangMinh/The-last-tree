extends SceneTree
## The Pianist's sign sequence through the REAL screens (Main -> Test fight): stills every 0.35 s while he points at the sign.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_sign_flow.gd -- <out folder>     (writes sign_00.png ...)
func _init() -> void:
	create_timer(120.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/pianist_sign_flow_impl.gd").new().run(self)
	quit()
