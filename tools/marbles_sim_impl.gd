extends RefCounted
## Many Marbles fights, played by a simple bot (chant what you have, cast whatever wakes), against the Act 1 pools,
## mini bosses and bosses, with random cards. Catches crashes; prints wins and turns.


func run() -> void:
	var ids: Array = MarbleCards.C.keys()
	var groups := []
	var pools: Dictionary = EnemyDefs.POOLS[1]
	for tier in pools:
		for g in pools[tier]:
			groups.append(g.ids)
	for e in EnemyDefs.elites(1):
		groups.append(EnemyDefs.ids_of(e))
	for b in EnemyDefs.BOSSES[1]:
		groups.append([b])
	groups = groups.filter(func(g): return g.all(func(x): return MarblesRun.simple(x)))
	var won := 0
	var turns := 0
	var n := 0
	for k in 300:
		var r := MarblesRun.new()
		r.setup(1000 + k)
		r.cards = []
		for j in 5:
			r.cards.append(ids[r.rng.randi() % ids.size()])
			r.levels[r.cards[j]] = r.rng.randi() % 3
		r.backpack = [ids[r.rng.randi() % ids.size()]]
		for j in 3:
			r.bag.append(r.random_marble())
		var f := MarblesFight.new()
		f.setup(r, groups[k % groups.size()])
		var guard := 0
		while not f.over and guard < 40:
			guard += 1
			var tries := 0
			while not f.hand.is_empty() and f.chant.size() < MarblesFight.MAX_CHANT and tries < 10:
				tries += 1
				f.put(0)
			f.do_chant()
			for loop in 12:
				if f.over:
					break
				if f.pending_replace >= 0:
					f.replace_with(0)
				for ci in r.cards.size():
					if f.can_cast(ci):
						var t: Array = f.targets(ci)
						f.cast(ci, t[0] if not t.is_empty() else -1)
			f.events.clear()
			if not f.over:
				f.end_turn()
		f.finish()
		n += 1
		turns += f.turn
		if f.won:
			won += 1
	print("MARBLES SIM: %d fights, %d won, %.1f turns each" % [n, won, float(turns) / n])
