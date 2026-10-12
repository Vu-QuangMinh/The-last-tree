extends SceneTree
## One fight screenshot in the Puppet Stage theme: godot --path . --position 6000,0 --no-focus -s tools/puppet_fight_shot.gd -- <out.png>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/puppet_fight_shot_impl.gd").new()
	await impl.run(self)
