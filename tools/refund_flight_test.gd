extends SceneTree
## Puppet: an Essence given back by a Lens flies chant slot -> pipe -> box -> tube -> Bag: godot --path . --position 6000,0 --no-focus -s tools/refund_flight_test.gd


func _init() -> void:
	await process_frame
	await load("res://tools/refund_flight_test_impl.gd").new().run(self)
