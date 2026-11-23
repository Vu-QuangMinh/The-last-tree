extends SceneTree
## Headless: godot --headless --path . --script res://tools/marbles_sim.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	load("res://tools/marbles_sim_impl.gd").new().run()
	quit()
