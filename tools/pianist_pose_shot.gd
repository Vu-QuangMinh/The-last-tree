extends SceneTree
## Stills of the Pianist (seen from behind) in each of his animations: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_pose_shot.gd -- <out folder>
## Writes pose_play.png, pose_point.png, pose_page.png, pose_slam.png (window off screen, no sound).


func _init() -> void:
	create_timer(150).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/pianist_pose_shot_impl.gd").new()
	await impl.run(self)
