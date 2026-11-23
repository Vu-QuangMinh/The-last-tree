extends SceneTree
## Headless: every Act 1 enemy's HP and attacks in the new fight (after the Act 1 nerf), from its real spawn; Act 2 to compare.


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	load("res://tools/act1_numbers_impl.gd").new().run()
	quit()
