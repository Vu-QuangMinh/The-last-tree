class_name FightWait
extends RefCounted
## The waits of the fight screen's helpers (fight_anim / fight_hud / fight_input / fight_machine / fight_talk).
## A helper is a RefCounted that lives as long as a coroutine of it is suspended, so when the FightScreen is freed in the middle of a wait (F5 in the test
## room, leaving a fight while an effect plays) the coroutine used to wake up with `scr` gone and touch it ("previously freed instance"). Code that sat in
## the screen itself simply stopped. These waits give the helpers the same behaviour: if the screen is gone before or after the wait, the coroutine is
## parked for good and never runs another line. (A parked coroutine is a few bytes that stay until the program quits; it happens only when a screen is
## thrown away mid-effect.)

class _Park extends RefCounted:
	signal never

static var _park := _Park.new()


static func seconds(scr: Node, t: float) -> void:
	if not is_instance_valid(scr):
		await _park.never
	await (Engine.get_main_loop() as SceneTree).create_timer(t).timeout
	if not is_instance_valid(scr):
		await _park.never


static func frame(scr: Node) -> void:
	if not is_instance_valid(scr):
		await _park.never
	await (Engine.get_main_loop() as SceneTree).process_frame
	if not is_instance_valid(scr):
		await _park.never
