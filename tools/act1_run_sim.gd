extends SceneTree
## Act 1 run simulation, logic only (no window): godot --headless --path . --script res://tools/act1_run_sim.gd -- <runs> <out prefix>
## See tools/act1_run_sim_impl.gd.


func _init() -> void:
	create_timer(14400).timeout.connect(quit)
	await process_frame
	await load("res://tools/act1_run_sim_impl.gd").new().run(self)
	quit()
