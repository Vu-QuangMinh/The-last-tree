extends SceneTree
## Rearrange in a real fight screen: drags an Essence off one enemy onto another with real mouse events, saves frames.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/rearrange_flow_check.gd -- <out folder>


func _init() -> void:
	create_timer(90.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/rearrange_flow_check_impl.gd").new().run(self)
