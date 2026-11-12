extends RefCounted
## Real-input check of the InputMap actions: F1 opens the Wiki, F5 reaches rope mode (toast in a non-room), F7 opens the TextInspector.
var toasts := 0
func _tap(t: SceneTree, key: Key) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = key
	k.pressed = true
	Input.parse_input_event(k)
	await t.process_frame
	k = InputEventKey.new()
	k.physical_keycode = key
	k.pressed = false
	Input.parse_input_event(k)
	await t.process_frame
func run(t: SceneTree) -> void:
	var root: Window = t.root
	root.get_node("SaveManager").use_test_file("user://keys_save.json")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(2.0).timeout
	root.get_node("Events").toast.connect(func(_m, _c): toasts += 1)
	main._test_mode = true
	var before: int = main.overlay_layer.get_child_count()
	await _tap(t, KEY_F1)
	print("F1 wiki: overlay children ", before, " -> ", main.overlay_layer.get_child_count())
	var t0 := toasts
	await _tap(t, KEY_F5)
	print("F5 rope: toasts ", t0, " -> ", toasts)
	var c0: int = root.get_child_count()
	await _tap(t, KEY_F7)
	print("F7 inspector: root children ", c0, " -> ", root.get_child_count())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://keys_save.json"))
	t.quit()
