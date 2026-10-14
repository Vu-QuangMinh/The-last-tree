extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/fight_cycle_test.gd -- <out folder>
func _init() -> void:
	await process_frame
	await load("res://tools/fight_cycle_test_impl.gd").new().run(self)
