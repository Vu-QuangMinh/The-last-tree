extends SceneTree
## Self-Repaint through the real FightScreen: clicking a chant Essence that is already the brush's colour must do nothing but say no (the pick stays open, the paint is not used up).
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/self_repaint_flow.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/self_repaint_flow_impl.gd").new()
	await impl.run(self)
