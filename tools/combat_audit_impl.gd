extends RefCounted


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 100
	var name: String = args[1] if args.size() > 1 else "combat_audit.txt"
	CombatLog.enable("user://" + name)
	var gd = t.root.get_node("GameData")
	var groups := []
	for act in [1, 2, 3]:
		var pools: Dictionary = EnemyDefs.POOLS.get(act, {})
		for tier in pools:
			for g in pools[tier]:
				groups.append(g.ids)
		for e in EnemyDefs.elites(act):
			groups.append(EnemyDefs.ids_of(e))
		for b in EnemyDefs.BOSSES.get(act, []):
			groups.append([b])
	groups = groups.filter(func(g): return g.all(func(x): return MarblesRun.simple(x)))
	var ids: Array = MarbleCards.C.keys()
	var t0 := Time.get_ticks_msec()
	var done := 0
	var won := 0
	for k in count:
		if Time.get_ticks_msec() - t0 > 500000:
			break
		var rs := RunState.new()
		rs.setup(gd.db, [], [], 5000 + k)
		var r := MarblesRun.new()
		r.setup(5000 + k)
		rs.loadout = []
		for j in 5:
			var id: String = ids[r.rng.randi() % ids.size()]
			if id in rs.loadout:
				continue
			rs.loadout.append(id)
			rs.card_levels[id] = r.rng.randi() % 3
		rs.spellbook = rs.loadout.duplicate()
		rs.marble_bag = []
		for j in 14:
			rs.marble_bag.append(r.random_marble())
		var f := rs.make_fight(groups[k % groups.size()])
		var turns := 0
		while not f.over and turns < 30:
			turns += 1
			var idx := []
			for i in mini(f.player.stock.size(), MarblesFight.MAX_CHANT):
				idx.append(i)
			await f.cast_chant(idx)
			for s in f.loadout.duplicate():
				var guard := 0
				while f.charges.get(s.id, 0) > 0 and not f.over and guard < 6:
					guard += 1
					var tc: Array = f.target_candidates()
					var pick: int = tc[r.rng.randi() % tc.size()] if not tc.is_empty() else -1
					if pick >= 0 and f is MarbleBridge:
						CombatLog.line("  [PREVIEW] aiming \"%s\" at #%d shows: \"%s\"" % [s.get("name", s.id), pick, (f as MarbleBridge).words_vs(String(s.id), pick)])
					await f.resolve_spell(String(s.id), pick)
			if not f.over:
				await f.finish_turn()
		done += 1
		if f.won:
			won += 1
	print("AUDIT: %d fights played, %d won, log: %s" % [done, won, ProjectSettings.globalize_path("user://" + name)])
