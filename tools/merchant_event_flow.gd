extends SceneTree
## see merchant_event_flow_impl.gd


func _init() -> void:
	await process_frame
	create_timer(60.0).timeout.connect(quit)
	await load("res://tools/merchant_event_flow_impl.gd").new().run(self)
