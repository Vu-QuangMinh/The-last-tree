extends SceneTree
## The old fight screen with the new rules (MarbleBridge): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/bridge_flow.gd -- <out dir>


func _init() -> void:
	create_timer(200.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/bridge_flow_impl.gd").new()
	await impl.run(self)
	quit()
