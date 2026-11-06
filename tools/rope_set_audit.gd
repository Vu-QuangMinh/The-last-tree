extends SceneTree
## How many enemies each Room Test rope set holds, and which enemy is in none: godot --headless --path . -s tools/rope_set_audit.gd
func _init() -> void:
	await process_frame
	await load("res://tools/rope_set_audit_impl.gd").new().run(self)
