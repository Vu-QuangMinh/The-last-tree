extends SceneTree
## Renders the code-drawn Bug Hunter alone on pure black (ImageSet reference): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/bug_hunter_ref.gd -- <out png>
## Optional 2nd arg "strike": the striker mid-swing (bell_t 0.28).


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/bug_hunter_ref_impl.gd").new()
	await impl.run(self)
