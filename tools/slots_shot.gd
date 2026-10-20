extends SceneTree


func _init() -> void:
	create_timer(200).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/slots_shot_impl.gd").new()
	await impl.run(self)
	quit()
