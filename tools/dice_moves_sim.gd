extends SceneTree
## Die on Stage: every move, plain and with each upgrade, played by a simple auto-player against a group, to catch
## errors. godot --headless --path . -s tools/dice_moves_sim.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_moves_sim_impl.gd").new()
	impl.run(self)
	quit()
