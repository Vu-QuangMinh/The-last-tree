extends RefCounted
## A bot plays Act 1 runs of the new cards: the real fight order (EnemyDefs.roll_fight_plan; the first fight one ling
## alone, as RunState.marble_ids), 2 mini bosses, the boss. It builds its chant greedily (each awake card's pattern
## from the marbles it has, short patterns first, Repeatable copies too), casts everything awake (damage at the
## weakest enemy), and takes rewards (70/30 card / marble; a random offered card). HP carries over; a death is counted
## and the bot goes on at full HP so later fights still get measured.

const RUNS := 400
const NORMAL := 6  # normal fights on a path through Act 1
const ELITE_AFTER := [2, 4]  # a mini boss after these normal fights (0-based)


func run() -> void:
	enemy_table()
	for progress in [false, true]:
		var stats := {}  # slot -> {n, turns, won, lost_hp, max_t}
		var order: Array = []
		for k in RUNS:
			var r := MarblesRun.new()
			r.setup(5000 + k)
			r.bag.clear()
			for c in MarblesRun.COLOURS:
				for j in 4:
					r.bag.append({"c": c, "sym": ""})
			var plan := EnemyDefs.roll_fight_plan(1, r.rng, MarblesRun.simple)
			var rooms: Array = []
			for i in NORMAL:
				var ids: Array
				if i == 0:
					ids = [StageFight.LINGS[r.rng.randi() % StageFight.LINGS.size()]]
				else:
					ids = _marble_ids(plan[i].ids, r)
				rooms.append(["fight %d" % (i + 1), ids])
				if i in ELITE_AFTER:
					var pool := EnemyDefs.elites(1).filter(func(id): return EnemyDefs.ids_of(id).all(func(x): return MarblesRun.simple(x)))
					var e: String = pool[r.rng.randi() % pool.size()]
					rooms.append(["elite %d" % (ELITE_AFTER.find(i) + 1), EnemyDefs.ids_of(e)])
			var bosses := (EnemyDefs.BOSSES[1] as Array).filter(func(id): return MarblesRun.simple(id))
			rooms.append(["boss", [bosses[r.rng.randi() % bosses.size()]]])
			var card_lean := 0.7
			var first := true
			for room in rooms:
				var slot: String = room[0]
				if not (slot in order):
					order.append(slot)
				var hp0 := r.hp
				var res := _fight(r, room[1])
				var s: Dictionary = stats.get(slot, {"n": 0, "turns": 0, "won": 0, "lost": 0, "max": 0, "names": {}})
				s.n += 1
				s.turns += res.turns
				s.max = maxi(s.max, res.turns)
				s.won += 1 if res.won else 0
				s.lost += hp0 - r.hp if res.won else hp0
				var nm := ",".join(room[1])
				var e2: Array = s.names.get(nm, [0, 0, 0, 0])
				s.names[nm] = [e2[0] + 1, e2[1] + res.turns, e2[2] + (1 if res.won else 0), e2[3] + (hp0 - r.hp if res.won else hp0)]
				stats[slot] = s
				if not res.won:
					r.hp = r.max_hp
				if progress and slot != "boss":
					var card := first or r.rng.randf() < card_lean
					if not first:
						card_lean = clampf(card_lean + (-0.15 if card else 0.4), 0.3, 1.0)
					first = false
					if card or slot.begins_with("elite"):
						var offer := r.card_offer(3)
						if not offer.is_empty():
							r.take_card(offer[r.rng.randi() % offer.size()])
					else:
						r.bag.append(r.random_marble())
		print("\n=== %s (%d runs, HP %d) ===" % ["cards picked up along the way" if progress else "starting cards only", RUNS, r_hp()])
		var all_t := 0
		var all_n := 0
		for slot in order:
			var s: Dictionary = stats[slot]
			print("%-8s %.1f turns (max %d)  won %d%%  HP lost %.1f" % [slot, float(s.turns) / s.n, s.max, 100 * s.won / s.n, float(s.lost) / s.n])
			if slot.begins_with("fight"):
				all_t += s.turns
				all_n += s.n
		print("normal fights overall: %.1f turns" % (float(all_t) / all_n))
		for slot in order:
			print("-- %s:" % slot)
			var nms: Dictionary = stats[slot].names
			var ks := nms.keys()
			ks.sort_custom(func(p, q): return nms[p][0] > nms[q][0])
			for nm in ks:
				var x: Array = nms[nm]
				print("   %-40s %3d%%  %.1f turns  won %d%%  HP lost %.1f" % [nm, 100 * x[0] / stats[slot].n, float(x[1]) / x[0], 100 * x[2] / x[0], float(x[3]) / x[0]])
		var by := {}
		for slot in order:
			for nm in stats[slot].names:
				var e: Array = by.get(nm, [0, 0])
				var x: Array = stats[slot].names[nm]
				by[nm] = [e[0] + x[0], e[1] + x[1]]
		var keys := by.keys()
		keys.sort_custom(func(p, q): return float(by[p][1]) / by[p][0] < float(by[q][1]) / by[q][0])
		print("by encounter:")
		for nm in keys:
			print("   %-40s %.1f turns  (%d fights)" % [nm, float(by[nm][1]) / by[nm][0], by[nm][0]])


func enemy_table() -> void:
	var ids := []
	for tier in EnemyDefs.POOLS[1]:
		for g in EnemyDefs.POOLS[1][tier]:
			for id in g.ids:
				if not (id in ids):
					ids.append(id)
	for e in EnemyDefs.elites(1):
		for id in EnemyDefs.ids_of(e):
			if not (id in ids) and MarblesRun.simple(id):
				ids.append(id)
	print("
=== enemy stats (Act 1, as the fight sets them up) ===")
	for id in ids:
		var r := MarblesRun.new()
		r.setup(1)
		var f := MarblesFight.new()
		f.setup(r, [id])
		var fo = f.foes[0]
		var mv := []
		for m in fo.moves:
			mv.append(StageFight.intent_text(m, fo))
		var extra := ""
		if fo.armor > 0:
			extra += " armor %d" % fo.armor
		if fo.thorns > 0:
			extra += " thorns %d" % fo.thorns
		print("   %-18s HP %3d%s | %s" % [id, fo.max_hp, extra, " -> ".join(mv)])


func r_hp() -> int:
	return int(PlayerState.new().max_hp)


func _marble_ids(ids: Array, r: MarblesRun) -> Array:
	var out := ids.filter(func(id): return MarblesRun.simple(String(id)))
	if out.size() == 1 and String(out[0]) in StageFight.LINGS:
		var others := StageFight.LINGS.filter(func(x): return x != out[0])
		out.append(others[r.rng.randi() % others.size()])
	return out if not out.is_empty() else ["ashling", "iceling"]


func _fight(r: MarblesRun, ids: Array) -> Dictionary:
	var f := MarblesFight.new()
	f.setup(r, ids)
	var guard := 0
	while not f.over and guard < 60:
		guard += 1
		_build_chant(f, r)
		f.do_chant()
		for loop in 15:
			if f.over:
				break
			if f.pending_replace >= 0:
				f.replace_with(0)
			var any := false
			for ci in r.cards.size():
				if f.can_cast(ci):
					var t: Array = f.targets(ci)
					var pick := -1
					for i in t:
						if pick < 0 or f.foes[i].hp < f.foes[pick].hp:
							pick = i
					f.cast(ci, pick)
					any = true
			if not any:
				break
		f.events.clear()
		if not f.over:
			f.end_turn()
	f.finish()
	return {"turns": f.turn, "won": f.won}


## Greedy: each usable card's pattern, shortest first, as many copies as Repeatable allows, from the marbles in hand.
func _build_chant(f: MarblesFight, r: MarblesRun) -> void:
	var order: Array = []
	for ci in r.cards.size():
		if f.usable(ci):
			order.append(ci)
	order.sort_custom(func(a, b): return String(f.card(a).pattern).length() < String(f.card(b).pattern).length())
	for ci in order:
		var c := f.card(ci)
		var pat := String(c.pattern)
		if pat == "":
			continue
		for rep in int(c.p.get("rep", 1)):
			if f.chant.size() + pat.length() > MarblesFight.MAX_CHANT:
				break
			var picks := []
			var ok := true
			for k in pat.length():
				var h := -1
				for i in f.hand.size():
					if i in picks or bool(f.hand[i].get("frozen", false)):
						continue
					if String(f.hand[i].c) == pat[k] and String(f.hand[i].sym) != "star":
						h = i
						break
				if h < 0:
					for i in f.hand.size():
						if not (i in picks) and String(f.hand[i].sym) == "star" and not bool(f.hand[i].get("frozen", false)):
							h = i
							break
				if h < 0:
					ok = false
					break
				picks.append(h)
			if not ok:
				break
			var ms := picks.map(func(i): return f.hand[i])
			for m in ms:
				f.put(f.hand.find(m))
	if f.chant.is_empty():
		for i in f.hand.size():
			if f.put(i):
				break
