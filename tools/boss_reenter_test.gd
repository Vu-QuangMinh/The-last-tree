extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/boss_reenter_test.gd


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)  # (a guard: an error must not leave a window hanging)
	await process_frame
	var impl = load("res://tools/boss_reenter_test_impl.gd").new()
	await impl.run(self)
