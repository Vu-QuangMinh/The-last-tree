extends SceneTree
## The Winter Wyvern through the REAL screens (main.gd, Test mode fight): several stills while it idles, to see its shape and whether it moves.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/wyvern_flow.gd -- <out folder> [room]
func _init() -> void:
	create_timer(120.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/wyvern_flow_impl.gd").new().run(self)
	quit()
