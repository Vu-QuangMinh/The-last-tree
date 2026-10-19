extends SceneTree
## Which pictures the game asks for by name that do not exist (Puppet theme): godot --headless --path . --script res://tools/icon_audit.gd


func _init() -> void:
	await process_frame
	await load("res://tools/icon_audit_impl.gd").new().run(self)
