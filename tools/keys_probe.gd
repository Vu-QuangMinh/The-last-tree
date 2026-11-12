extends SceneTree
func _init() -> void:
	await process_frame
	create_timer(60.0).timeout.connect(func(): quit(2))
	var impl = load("res://tools/keys_probe_impl.gd").new()
	await impl.run(self)
