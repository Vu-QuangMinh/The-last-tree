extends SceneTree
## The Puppet Stage encounter flow: the new set and the enemies come in behind the encounter board; "Begin the fight" flies the chosen cards to the fight.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/stage_encounter_test.gd -- <out folder>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/stage_encounter_test_impl.gd").new()
	await impl.run(self)
