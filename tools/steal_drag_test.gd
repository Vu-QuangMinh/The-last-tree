extends SceneTree
## The steal spell: cards shrink, hand cursor, drag an enemy Essence into the Bag (glow, straight in), fist while dragging your own: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/steal_drag_test.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/steal_drag_test_impl.gd").new().run(self)
