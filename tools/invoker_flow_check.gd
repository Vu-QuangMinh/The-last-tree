extends SceneTree
## The Invoker in a real fight screen: a new set of spells buzzing in, then his rise into phase 2 (burst and reform). Saves frames.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/invoker_flow_check.gd -- <out folder>


func _init() -> void:
	create_timer(90.0, true, false, true).timeout.connect(quit)
	await process_frame
	await load("res://tools/invoker_flow_check_impl.gd").new().run(self)
	quit()
