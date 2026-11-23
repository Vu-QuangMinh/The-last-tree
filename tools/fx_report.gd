extends SceneTree
## Headless: which spell effect (SpellFx op) each new card plays when cast (MarblesFight.fx_of), and its numbers.


func _init() -> void:
	create_timer(30).timeout.connect(quit)
	await process_frame
	load("res://tools/fx_report_impl.gd").new().run()
	quit()
