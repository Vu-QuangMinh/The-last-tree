extends SceneTree
## The tweezer hand over the HUD (only its lower stick climbs) and the Resurrecting intent (hand + hourglass): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/tweezer_revive_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/tweezer_revive_shot_impl.gd").new().run(self)
