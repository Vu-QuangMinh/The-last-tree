extends SceneTree
## Headless: Self-replace on the main game's fight (MarbleBridge): casting Alchemy gives its bottle, asks for a backpack
## card (the screen's spell chooser) and puts the chosen one in its place; "Keep it" leaves the row alone.


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	await load("res://tools/self_replace_test_impl.gd").new().run()
	quit()
