extends SceneTree
## The Act sign of a Puppet fight drops at the start and goes back up after 10 s: godot --headless --path . --script res://tools/act_sign_check.gd
func _init() -> void:
	await process_frame
	var impl = load("res://tools/act_sign_check_impl.gd").new()
	await impl.run(self)
