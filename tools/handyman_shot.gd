extends SceneTree
## Handyman fight screenshots (Puppet Stage): godot --path . --position 6000,0 --no-focus -s tools/handyman_shot.gd -- <out folder>
## Writes hm_phase1.png, hm_phase3.png (all six hands), hm_swing.png (every hand mid-swing, one knocked out) and hm_body.png (he shows himself).


func _init() -> void:
	await process_frame
	var impl = load("res://tools/handyman_shot_impl.gd").new()
	await impl.run(self)
