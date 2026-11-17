extends RefCounted

const FIGHTS := [["invoker"], ["bramble_matron"], ["samurai", "samurai_retainer"], ["veiled_eyes"], ["pianist"], ["corrector"],
	["bug_hunter"], ["mirror_fairy"], ["inverter"], ["mimic_chest"], ["mob_slingshot"], ["sentinel"], ["echo_wraith"], ["last_winter"],
	["storm_imp", "triplet_water"], ["hush_moth", "mob_torch"], ["anxious_armadillo"]]


func run(_t: SceneTree) -> void:
	for ids in FIGHTS:
		var r := DiceRun.new()
		r.setup(77)
		r.act = int(EnemyDefs.get_def(ids[0]).get("act", 1))
		r.cards = ["punch", "block", "high_knee", "sweep"]
		r.hp = 999
		r.max_hp = 999
		var f := DiceFight.new()
		f.setup(r, ids)
		var seen := {}
		while not f.over and f.turn < 40:
			for d in f.rolled.size():
				if f.rolled[d].used or f.rolled[d].frozen:
					continue
				var done := false
				for fi in f.foes.size():  # (interrupt the Wizard's spells first)
					for k in f.foes[fi].spells.size():
						if not done and f.can_interrupt(d, fi, k) and f.interrupt(d, fi, k):
							done = true
				for ci in r.cards.size():
					if done:
						break
					for k in int(r.card_at(ci).get("slots", 1)):
						if f.can_place(d, ci, k):
							if f.place(d, ci, k):
								var ts := f.targets_for(ci)
								f.fire(ci, ts[0] if not ts.is_empty() else -1)
							done = true
							break
			for ev in f.events:
				seen[String(ev.type)] = true
			f.events.clear()
			if not f.over:
				f.end_turn()
				for ev in f.events:
					seen[String(ev.type)] = true
				f.events.clear()
		print("%-34s %s in %2d turns, %d enemies at the end. events: %s" % [",".join(ids), "won " if f.won else "LOST", f.turn, f.foes.size(), ",".join(seen.keys())])
