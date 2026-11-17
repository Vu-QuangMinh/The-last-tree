extends SceneTree
## Die on Stage: fights against every enemy with a mechanic of its own (Wizard, Matron, Samurai + Retainer, Violet Eyes,
## Pianist, Corrector, Bug Hunter, Mirror Fairy, Inverter, Mimic Chest, Slingshot Peasant, Red Sentinel, Last Winter, Storm
## Imp...), played by a simple auto-player, to catch errors. godot --headless --path . -s tools/dice_mech_sim.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_mech_sim_impl.gd").new()
	impl.run(self)
	quit()
