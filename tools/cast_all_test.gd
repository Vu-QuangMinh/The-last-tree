extends SceneTree
## One click casts a card's whole Repeatable stack when there is no target to choose (windowed, off screen):
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/cast_all_test.gd


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	await load("res://tools/cast_all_test_impl.gd").new().run(self)
	quit()
