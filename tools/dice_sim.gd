extends SceneTree
## Die on Stage: plays runs headless with a simple auto-player (each die to the first card it fits, aimed at the
## weakest enemy), to catch errors in the rules and see how fights go. godot --headless --path . -s tools/dice_sim.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_sim_impl.gd").new()
	impl.run(self)
	quit()
