extends SceneTree
## Winter Wyvern fight screenshots (Puppet Stage): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dragon_shot.gd -- <out folder>
## Writes dragon_<n>.png for each of its six moves (intent shown), plus mid-move shots.


func _init() -> void:
	create_timer(220.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dragon_shot_impl.gd").new()
	await impl.run(self)
	quit()
