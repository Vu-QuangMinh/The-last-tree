extends RefCounted


func run(_t: SceneTree) -> void:
	var wins := 0
	var turns := 0
	var fights := 0
	for s in 40:
		var r := DiceRun.new()
		r.setup(1000 + s)
		r.cards = ["punch", "block", DiceCards.pool()[s % DiceCards.pool().size()], DiceCards.pool()[(s * 7 + 3) % DiceCards.pool().size()]]
		var kind: String = ["fight", "fight", "elite", "boss"][s % 4]
		var f := DiceFight.new()
		f.setup(r, r.encounter(kind))
		while not f.over and f.turn < 60:
			var progress := true
			while progress and not f.over:
				progress = false
				for d in f.rolled.size():
					if f.rolled[d].used:
						continue
					for ci in r.cards.size():
						var slots := int(r.card_at(ci).get("slots", 1))
						for k in slots:
							if f.can_place(d, ci, k):
								var live := f.alive()
								var weakest: Variant = null
								for x in live:
									if weakest == null or x.hp < weakest.hp:
										weakest = x
								if f.place(d, ci, k):
									var ts := f.targets_for(ci)
									f.fire(ci, f.foes.find(weakest) if f.foes.find(weakest) in ts or ts.is_empty() else ts[0])
								progress = true
								break
						if progress:
							break
					if progress:
						break
			f.events.clear()
			if not f.over:
				f.end_turn()
				f.events.clear()
		fights += 1
		turns += f.turn
		if f.won:
			wins += 1
		print("%s %s: %s in %d turns, HP left %d/%d  (%s)" % [kind, ",".join(f.foes.map(func(x): return x.es.id)), "won" if f.won else "LOST", f.turn, r.hp, r.max_hp, ",".join(r.cards)])
	print("SIM: %d fights, %d won, %.1f turns each" % [fights, wins, float(turns) / fights])
	var m := DiceMapGen.make_map(RandomNumberGenerator.new())
	var c := DiceMapGen.counts(m)
	print("MAP: ", c, " die_mod tiles: ", m.reduce(func(a, row): return a + row.filter(func(n): return n.has("die_mod")).size(), 0))
