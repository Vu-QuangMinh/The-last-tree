extends SceneTree
## The Marbles mode: every card cast in a real fight, its effect checked. Headless:
## godot --headless --path . --script res://tools/marbles_cards_test.gd


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	load("res://tools/marbles_cards_test_impl.gd").new().run()
	quit()
