extends SceneTree
## Headless: how often a card offer (3 cards) holds at least one Rare / Legendary, per kind of reward.


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	for kind in ["fight", "elite", "shop"]:
		var r := RunState.new()
		r.setup(SpellDB.from_marbles(), [], [], 11)
		var n := 20000
		var rare := 0
		var leg := 0
		var cards := 0
		var rare_cards := 0
		for k in n:
			var o := r.spell_offer(3, kind)
			cards += o.size()
			var rr := o.filter(func(s): return s.rarity == "rare").size()
			rare_cards += rr
			if rr > 0:
				rare += 1
			if o.any(func(s): return s.rarity == "legendary"):
				leg += 1
		print("ODDS %s: at least one Rare %.1f%%, Rare per card %.1f%%, at least one Legendary %.1f%%" % [kind, 100.0 * rare / n, 100.0 * rare_cards / cards, 100.0 * leg / n])
	quit()
