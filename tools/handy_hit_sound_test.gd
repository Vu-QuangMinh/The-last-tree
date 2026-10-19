extends SceneTree
## The Handyman's grunt on a hit (Creature.hit): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handy_hit_sound_test.gd


func _init() -> void:
	await process_frame
	await load("res://tools/handy_hit_sound_test_impl.gd").new().run(self)
