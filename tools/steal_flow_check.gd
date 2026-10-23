extends SceneTree
## The Veiled Eyes' whole theft in a real fight screen (timings + frames): godot --path . --position 6000,0 --no-focus -s tools/steal_flow_check.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/steal_flow_check_impl.gd").new().run(self)
