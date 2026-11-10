extends SceneTree
## The Pianist through the REAL screens (main.gd, Test mode fight): frames while he plays, the page turn (he points at the sign) and the last chord.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_flow.gd -- <out folder>
## Writes play_0..5.png, page_0..3.png, end_0..2.png (whole window).
func _init() -> void:
	create_timer(170.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/pianist_flow_impl.gd").new().run(self)
	quit()
