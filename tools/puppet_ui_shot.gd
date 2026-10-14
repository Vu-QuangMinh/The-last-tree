extends SceneTree
## Puppet UI pieces on one screen: godot --path . --position 6000,0 --no-focus -s tools/puppet_ui_shot.gd -- <out.png>


func _init() -> void:
	await process_frame
	await load("res://tools/puppet_ui_shot_impl.gd").new().run(self)
