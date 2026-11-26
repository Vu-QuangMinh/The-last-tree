extends RefCounted
## (tools/self_replace_test.gd runs this once the autoloads are up.)


func run() -> void:
	var bad := 0
	for pick in [0, -1]:
		var r := RunState.new()
		r.setup(SpellDB.from_marbles(), [], [], 5)
		r.loadout = ["alchemy", "splash"]
		r.spellbook = ["alchemy", "splash", "spark"]
		var b := r.make_fight(["iceling"]) as MarbleBridge
		var asked := []
		b.spell_chooser = func(spells: Array, why: String) -> int:
			asked.append([spells.map(func(s): return String(s.name)), why])
			return pick
		b.anim = func(_ev: Dictionary) -> void:
			pass
		var m := b.m
		m.hand = [{"c": "F", "sym": "", "src": -1, "uid": 9001}, {"c": "A", "sym": "", "src": -1, "uid": 9002}, {"c": "W", "sym": "", "src": -1, "uid": 9003}]
		for k in 3:
			m.put(0)
		m.do_chant()
		m.events.clear()
		b._b_sync()
		await b.resolve_spell(String(b.loadout[0].id))
		var ok_ask := asked.size() == 1 and String(asked[0][1]) == "swap" and (asked[0][0] as Array) == ["Spark"]
		var ok_bottle := m.mrun.bottles.size() == 1
		var ok_row: bool
		if pick == 0:
			ok_row = m.run.cards[0] == "spark" and m.mrun.backpack == ["alchemy"] and String(b.loadout[0].name).begins_with("Spark")
		else:
			ok_row = m.run.cards[0] == "alchemy" and m.mrun.backpack == ["spark"]
		for x in [["asked with the backpack", ok_ask], ["a bottle", ok_bottle], ["row after pick %d" % pick, ok_row]]:
			print("  %s %s" % ["ok  " if x[1] else "FAIL", x[0]])
			bad += 0 if x[1] else 1
	print("SELF REPLACE: %d failed" % bad)
