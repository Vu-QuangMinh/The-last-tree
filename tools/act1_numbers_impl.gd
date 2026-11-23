extends RefCounted
## (tools/act1_numbers.gd runs this once the autoloads are up)


func run() -> void:
	var r := RunState.new()
	r.setup(SpellDB.from_marbles(), [], [], 3)
	var ids := {}
	for pool in [r.marble_ids(["ashling"]), ["ashling", "iceling", "zephling", "leech_bat", "hush_moth", "mirror_fairy", "bramble_back", "winged_tortoise", "greenseer", "rolling_bear", "giant_slime", "purple_slime", "green_slime", "yellow_slime"]]:
		for id in pool:
			ids[id] = true
	for act in [1, 2]:
		r.act = act
		var mr := r.marble_run()
		var f := MarblesFight.new()
		f.setup(mr, ids.keys())
		for foe: StageFight.Foe in f.foes:
			var atk := foe.moves.filter(func(m): return String(m.get("kind", "")) == "attack").map(func(m): return "%dx%d" % [int(m.n), int(m.get("hits", 1))])
			print("ACT%d %s: %d HP, attacks %s" % [act, foe.id, foe.max_hp, atk])
