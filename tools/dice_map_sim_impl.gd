extends RefCounted

const VALUE := {"artifact": 3.0, "card": 3.0, "dice": 2.0}


func run(_t: SceneTree) -> void:
	for policy in ["greedy", "random"]:
		var tot := {}
		var lists := {}
		for s in 100:
			var rng := RandomNumberGenerator.new()
			rng.seed = 5000 + s
			var res := _one(rng, policy)
			for k in res:
				tot[k] = tot.get(k, 0.0) + float(res[k])
				if not lists.has(k):
					lists[k] = []
				lists[k].append(float(res[k]))
		print("=== %s (100 runs): average [min-max]" % policy)
		for k in ["tiles", "fights", "plain", "dice", "card", "artifact", "elite", "double", "shop", "rest", "caught_turn", "zone_easy", "zone_mid", "zone_hard", "stuck",
				"dice_easy", "dice_mid", "dice_hard", "card_easy", "card_mid", "card_hard", "artifact_easy", "artifact_mid", "artifact_hard"]:
			var l: Array = lists.get(k, [0.0])
			print("  %-12s %5.1f  [%d-%d]" % [k, tot.get(k, 0.0) / 100.0, int(l.min()), int(l.max())])


func _one(rng: RandomNumberGenerator, policy: String) -> Dictionary:
	var rows := DiceMapGen.make_zoned(rng)
	var me := Vector2i(-1, 0)  # (row, col) on the map; -1: before the start
	var boss := DiceMapGen.boss_home(rows)
	var out := {"tiles": 0, "fights": 0, "plain": 0, "dice": 0, "card": 0, "artifact": 0, "elite": 0, "double": 0, "shop": 0, "rest": 0,
		"caught_turn": 0, "zone_easy": 0, "zone_mid": 0, "zone_hard": 0, "stuck": 0}
	var used := {}
	for turn in range(1, 200):
		var opts := DiceMapGen.forward(rows, me.x, me.y)
		if not opts.is_empty():
			var best: Vector2i = opts[rng.randi() % opts.size()]
			if policy == "greedy":
				var best_v := -99.0
				for p: Vector2i in opts:
					var n: Dictionary = rows[p.x][p.y]
					var v := float(VALUE.get(n.get("bonus", ""), 0.0))
					if n.type in ["shop", "rest"]:
						v = 2.5 if not used.has(n.type) else 0.0
					v += 1.0 if p.x == me.x + 1 else 0.0  # (a one-level step: slower, more tiles)
					v += rng.randf() * 0.5
					if v > best_v:
						best_v = v
						best = p
			me = best
			var n2: Dictionary = rows[me.x][me.y]
			out.tiles += 1
			out[["zone_easy", "zone_mid", "zone_hard"][DiceMapGen.zone_of(me.x)]] += 1
			if n2.type in ["shop", "rest"]:
				if not used.has(n2.type):
					used[n2.type] = true
					out[n2.type] += 1
			else:
				out.fights += 1
				var b: String = n2.get("bonus", "")
				if b == "":
					out.plain += 1
				else:
					out[b] += 1
					var zk := "%s_%s" % [b, ["easy", "mid", "hard"][DiceMapGen.zone_of(me.x)]]
					out[zk] = out.get(zk, 0) + 1
				if n2.has("fight"):
					out[n2.fight] += 1
		else:
			out.stuck += 1  # (nothing ahead: you wait for the boss)
		var me_cell := Vector2i(me.x, int(rows[me.x][me.y].lane)) if me.x >= 0 else Vector2i(-9, -9)
		if boss == me_cell:
			out.caught_turn = turn
			return out
		if turn > DiceMapGen.BOSS_WAIT:
			for k in DiceMapGen.BOSS_STEPS:
				boss = DiceMapGen.boss_step(rows, boss, me_cell)
				if boss == me_cell:
					out.caught_turn = turn
					return out
	return out
