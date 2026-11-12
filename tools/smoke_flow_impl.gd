extends RefCounted
## The work of smoke_flow.gd (the wrapper waits for the autoloads first).

class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])


var problems: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _theme_run(t: SceneTree, theme: String) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://smoke_flow_save.json")
	save.clear_run()  # (a run left behind by an earlier stopped test would make the menu ask about it)
	UiSkin.set_theme(theme)
	var m: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	_check(m._overlay is ChoiceScreen, "%s: the keepsake choice is up" % theme)
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	var rs: RunState = m.run
	_check(rs != null and rs.choices().size() > 0, "%s: the map has a first step" % theme)
	m._overlay.node_chosen.emit(rs.choices()[0])
	await t.create_timer(3.0).timeout
	_check(m._overlay is LoadoutScreen, "%s: the loadout is up" % theme)
	m._overlay.confirmed.emit()
	await t.create_timer(9.0).timeout
	var fs: FightScreen = m.current as FightScreen
	_check(fs != null, "%s: a fight screen is up" % theme)
	if fs != null:
		_check(not fs.fight.over, "%s: the fight has not ended by itself" % theme)
		for e in fs.fight.enemies:
			e.elements.clear()
		fs.fight.over = true
		fs.fight.won = true
		fs._finish()
		await t.create_timer(5.5).timeout
		_check(m._overlay is ChoiceScreen, "%s: rewards are offered after the win" % theme)
		if m._overlay is ChoiceScreen:
			m._overlay.chosen.emit(-1)
		await t.create_timer(2.5).timeout
		_check(m._overlay is MapScreen or m.current is MapScreen, "%s: back on the map" % theme)
	m.queue_free()
	await t.process_frame
	await t.process_frame


func run(t: SceneTree) -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var themes: Array = Array(OS.get_cmdline_user_args()) if OS.get_cmdline_user_args().size() > 0 else UiSkin.OPTIONS
	for theme in themes:
		catcher.errors.clear()
		var before := problems.size()
		await _theme_run(t, str(theme))
		for e in catcher.errors:
			problems.append("%s: engine error: %s" % [theme, e])
		print("%s %s" % ["ok  " if problems.size() == before else "FAIL", theme])
	for p in problems:
		print("   " + p)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_flow_save.json"))
	print("smoke: %d themes, %d problems" % [themes.size(), problems.size()])
	t.quit(1 if problems.size() > 0 else 0)
