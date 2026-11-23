extends SceneTree
## Smoke test of the real UI, once per theme, no screenshots: keepsake -> map -> a fight (begun early, then won) -> rewards -> map again.
## Fails (exit 1) on any engine/script error or when a step does not end where it should.
##   godot --path . --position 6000,0 --no-focus --audio-driver Dummy --script res://tools/smoke_flow.gd [-- theme ...]


func _init() -> void:
	await process_frame
	create_timer(600.0).timeout.connect(func(): quit(2))
	var impl = load("res://tools/smoke_flow_impl.gd").new()
	await impl.run(self)
