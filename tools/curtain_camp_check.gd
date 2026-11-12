extends SceneTree
## The Curtain map: stepping on a campfire opens the normal campfire (not An Abandoned Camp).
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/curtain_camp_check.gd


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/curtain_camp_check_impl.gd").new()
	await impl.run(self)
