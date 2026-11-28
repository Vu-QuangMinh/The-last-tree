extends SceneTree
## Act 1 card balance simulation (headless, logic only): godot --headless --path . --script res://tools/act1_sim.gd -- <runs per card> <out csv>
## See tools/act1_sim_impl.gd.


func _init() -> void:
	create_timer(3000).timeout.connect(quit)
	await process_frame
	await load("res://tools/act1_sim_impl.gd").new().run(self)
	quit()
