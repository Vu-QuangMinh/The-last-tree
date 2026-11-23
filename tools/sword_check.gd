extends SceneTree
## Headless: a carved Sword marble with Spark, through the bridge (as in a real fight).


func _init() -> void:
	create_timer(30).timeout.connect(quit)
	await process_frame
	load("res://tools/sword_check_impl.gd").new().run()
	quit()
