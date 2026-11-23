extends RefCounted


func run() -> void:
	for order in [["F:sword", "F"], ["F", "F:sword"], ["F", "F", "W:sword"], ["F:sword", "F", "F", "F"]]:
		var rs := RunState.new()
		rs.setup(SpellDB.from_marbles(), [], [], 7)
		rs.marble_bag[0].sym = "sword"
		var b := rs.make_fight(["iceling"]) as MarbleBridge
		b.m.foes[0].hp = 50
		b.m.foes[0].max_hp = 50
		b.m.hand.clear()
		for spec in order:
			b.m._uid += 1
			b.m.hand.append({"c": spec.get_slice(":", 0), "sym": spec.get_slice(":", 1) if spec.contains(":") else "", "src": -1, "uid": b.m._uid, "frozen": false, "hidden": false})
		b._b_sync()
		var idx := range(b.player.stock.size())
		b.m.chant.clear()
		for i in idx:
			b.m.chant.append(b.m.hand[i])
		b.m.hand.clear()
		b.m.do_chant()
		var boosts := b.m.events.filter(func(e): return String(e.type) == "boost")
		var txt := String(b.m.card(0).text)
		b.m.events.clear()
		b.m.cast(0, 0)
		print("SWORD chant %s: boosts %d, card says '%s', foe 50 -> %d" % [order, boosts.size(), txt.left(20), b.m.foes[0].hp])
