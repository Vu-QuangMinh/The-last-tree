extends SceneTree
## Many automatic fights through MarbleBridge (the real game logic) with the combat log on:
## godot --headless --path . --script res://tools/combat_audit.gd -- <fights> <log file name in user://>


func _init() -> void:
	create_timer(580.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/combat_audit_impl.gd").new()
	await impl.run(self)
	quit()
