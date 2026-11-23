extends RefCounted


func run(_t: SceneTree) -> void:
	var fired := {}
	var n := 0
	for id in DiceCards.CARDS:
		for up in ["", "boost", "slot", "alt"]:
			var r := DiceRun.new()
			r.setup(300 + n)
			n += 1
			r.cards = [id, "punch", "block", "hype_up" if id != "hype_up" else "calm_down"]
			if up != "":
				r.upgrade(id, up)
			r.hp = 400
			r.max_hp = 400
			var f := DiceFight.new()
			f.setup(r, ["ashling", "yellow_slime", "iceling"])
			while not f.over and f.turn < 25:
				for d in f.rolled.size():
					if f.rolled[d].used or f.rolled[d].frozen:
						continue
					for ci in r.cards.size():
						var placed := false
						for k in int(r.card_at(ci).get("slots", 1)):
							if f.can_place(d, ci, k):
								if f.place(d, ci, k):
									var ts := f.targets_for(ci)
									f.fire(ci, ts[0] if not ts.is_empty() else -1)
									fired["%s/%s" % [id, up]] = true
								placed = true
								break
						if placed:
							break
				f.events.clear()
				if not f.over:
					f.end_turn()
					f.events.clear()
	var never := []
	for id in DiceCards.CARDS:
		for up in ["", "boost", "slot", "alt"]:
			if up == "alt" and not DiceCards.CARDS[id].has("alt"):
				continue
			if not fired.has("%s/%s" % [id, up]) and not (DiceCards.CARDS[id].has("tweak")):
				never.append("%s/%s" % [id, up])
	print("MOVES SIM: %d runs. Never fired (fine if their dice are rare): %s" % [n, ", ".join(never)])
