extends SceneTree
## The Extension slams 6, 7, 8 in a real fight (Puppet theme): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ext_slam_shot.gd -- <out folder>  (ext_6/7/8.png)


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/ext_slam_shot_impl.gd").new()
	await impl.run(self)
