extends SceneTree
## The older "?" events through the real screens: see event_batch2_flow_impl.gd.
func _init() -> void:
	await process_frame
	create_timer(300.0).timeout.connect(quit)
	await load("res://tools/event_batch2_flow_impl.gd").new().run(self)
