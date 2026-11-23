extends SceneTree
## Die on Stage: the Slay the Spire map, 300 of them: rooms per map, the dice mod mix, offer rarities.
## godot --headless --path . -s tools/dice_sts_sim.gd


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rooms := {}
	var mods := {}
	var bad := 0
	for i in 300:
		var m: Array = DiceMapGen.make_sts(rng)
		for f in m.size():
			for n in m[f]:
				if n == null:
					continue
				rooms[n.type] = int(rooms.get(n.type, 0)) + 1
				if n.type == "fight":
					if not n.has("dmod"):
						bad += 1
					mods[n.dmod] = int(mods.get(n.dmod, 0)) + 1
				if f < m.size() - 1 and n.next.is_empty():
					bad += 1
	for t in rooms:
		rooms[t] = snappedf(rooms[t] / 300.0, 0.1)
	print("ROOMS per map: ", rooms)
	var tot := 0
	for k in mods:
		tot += mods[k]
	for k in mods:
		mods[k] = "%d%%" % roundi(100.0 * mods[k] / tot)
	print("DICE MODS: ", mods, "  broken rooms: ", bad)
	var r := DiceRun.new()
	r.setup(5)
	var rar := {}
	var brar := {}
	for i in 400:
		for id in r.card_offer(3):
			rar[DiceCards.rarity(id)] = int(rar.get(DiceCards.rarity(id), 0)) + 1
		for id in r.card_offer(3, true):
			brar[DiceCards.rarity(id)] = int(brar.get(DiceCards.rarity(id), 0)) + 1
	print("OFFERS: ", rar, "   BOSS OFFERS: ", brar)
	var n_r := {}
	for id in DiceCards.CARDS:
		n_r[DiceCards.rarity(id)] = int(n_r.get(DiceCards.rarity(id), 0)) + 1
	print("CARDS BY RARITY: ", n_r)
	r.cards = ["punch", "block", "jab"]
	var dup := 0
	for i in 200:
		if r.card_offer(3).any(func(id): return id in r.cards):
			dup += 1
	r.upgrades["jab"] = "boost"
	var dup_up := 0
	for i in 200:
		if r.card_offer(3).has("jab"):
			dup_up += 1
	print("offers with a card you have: %d/200;  an upgraded Jab offered: %d/200" % [dup, dup_up])
	quit()
