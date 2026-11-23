extends RefCounted
## The new cards in the main game's run (2026-11-21): fusion, curses, wax seals, the backpack cap, the run <-> fight
## hand-over.

var bad := 0


func _ok(what: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		bad += 1


func _run() -> RunState:
	var r := RunState.new()
	r.setup(SpellDB.from_marbles(), [], [], 5)
	return r


func _fight(r: RunState, ids := ["iceling"]) -> MarblesFight:
	var mr := r.marble_run()
	var f := MarblesFight.new()
	f.setup(mr, ids)
	for x in f.foes:
		x.max_hp = 200
		x.hp = 200
		x.block = 0
	f.block = 0
	return f


func _chant(f: MarblesFight, pat: String) -> void:
	f.hand.clear()
	f.chant.clear()
	f.chanted = false
	for ch in pat:
		f.chant.append({"c": ch, "sym": "", "src": -1, "uid": 0})
	f.do_chant()


func run() -> void:
	var r := _run()
	_ok("starting cards are new cards", r.loadout.size() == 3 and MarbleCards.has(String(r.loadout[0])))
	_ok("a bag of 12 marbles (4 of each)", r.marble_bag.size() == 12)
	# upgrade by finding it again
	r.learn_spell("spark")
	_ok("found again: upgraded", int(r.card_levels.get("spark", 0)) == 1 and r.spell("spark").name == "Spark+")
	# fusion: Spark (FF) + Splash (WW) -> FFWW, deals 5 and gives 2 Shield
	var fz := r.fuse_preview("spark", "splash")
	_ok("fused pattern: first then second", String(fz.pattern) == "FFWW")
	_ok("fused name: one of the user's", String(fz.name) != "" and String(fz.desc).contains("damage"))
	r.fuse_commit(fz, "spark", "splash")
	var fid := String(fz.id)
	_ok("fused card in the row", fid in r.loadout)
	var f := _fight(r)
	var ci := f.run.cards.find(fid)
	_chant(f, "FFWW")
	f.cast(ci, 0)
	_ok("fused card does both: 5 damage (Spark+) and 2 Shield", f.foes[0].hp == 195 and f.block == 2)
	# a wax seal: Splash's first W sealed -> needs only "W"
	r = _run()
	r.seal_spell("splash", 0)
	f = _fight(r)
	_chant(f, "W")
	_ok("wax seal: Splash wakes on one Water", int(f.charges.get(r.loadout.find("splash"), 0)) == 1)
	# curses
	r = _run()
	r.curses["spark"] = ["pain", "hesitation"]
	f = _fight(r)
	var hp0 := f.run.hp
	_chant(f, "FF")
	f.cast(r.loadout.find("spark"), 0)
	_ok("Curse of Pain: casting Spark hurts you 3", hp0 - f.run.hp == 3)
	_ok("Curse of Hesitation: a Cooldown", f.cooldown.has(r.loadout.find("spark")))
	# the backpack cap
	r = _run()
	for id in ["ocean", "rain", "mist", "hail", "bite", "geyser", "drop", "flicker"]:
		r.learn_spell(id)
	_ok("row of 5, backpack of 5 at most", r.loadout.size() == 5 and r.backpack().size() == 5)
	_ok("no room for an 11th", not r.has_room("thousand_cuts"))
	r.learn_spell("thousand_cuts")
	_ok("so it isn't taken", not ("thousand_cuts" in r.spellbook))
	_ok("a card you have still upgrades", r.has_room("ocean"))
	_ok("a full backpack takes no card from the row", not r.toggle_active(String(r.loadout[0])))
	# the hand-over: what the fight changed comes home
	r = _run()
	f = _fight(r)
	f.mrun.hp = 33
	f.mrun.bag.append({"c": "F", "sym": "sword"})
	r.take_back(f.mrun)
	_ok("hp and bag come home", int(r.player.hp) == 33 and r.marble_bag.size() == 13)
	# what events leave for the next fight
	r = _run()
	r.burn_next = 2
	r.fight_gift = ["random", "A"]
	r.lasting_next = 5
	var bridge := r.make_fight(["iceling"])
	_ok("a fight with the new cards runs on the main game's fight (MarbleBridge)", bridge is MarbleBridge)
	f = (bridge as MarbleBridge).m
	print("  (burn %d block %d hand %d)" % [f.burn, f.block, f.hand.size()])
	_ok("an event's Burn, Shield and gift marbles reach the new fight", f.burn == 2 and f.block == 5 and f.hand.size() == 8)
	r.learn_spell("trade_winds")
	_ok("Aole's Blessing is Aole's Last Wish now", "aoles_last_wish" in r.spellbook)
	r.learn_spell("summoning_bill")
	_ok("no old spell gets in", not ("summoning_bill" in r.spellbook))
	# the main game's physics (2026-11-22): drag into a ring, reorder the chant, orb progress, ten rings
	var g := _fight(_run())
	g.hand.clear()
	g.chant.clear()
	for ch in "FWAF":
		g.hand.append({"c": ch, "sym": "", "src": -1, "uid": 0})
	g.put_at(0, 0)  # F
	g.put_at(0, 0)  # W in front: W F
	_ok("a marble dropped on a ring goes in at that place", g.chant_letters() == ["W", "F"])
	g.move_chant(0, 1)
	_ok("a chant marble dragged along moves", g.chant_letters() == ["F", "W"])
	_ok("orb progress: the chant ends with the pattern's start", g.progress("WA") == 1 and g.progress("FW") == 2 and g.progress("AF") == 0)
	g.chant.append({"c": "A", "sym": "star", "src": -1, "uid": 0})
	_ok("a Star matches any colour", g.progress("WFF") == 2)
	_ok("the chant row takes ten", MarblesFight.MAX_CHANT == 10)
	# rewards after normal fights: the first a card, then 70 / 30 cards to marbles, never 3 marbles in a row
	var cards_n := 0
	var all_n := 0
	var first_ok := true
	var worst := 0
	for k in 300:
		var rr := _run()
		rr.rng.seed = 1000 + k
		if rr.reward_kind() != "card":
			first_ok = false
		var run_of := 0
		for j in 20:
			var got := rr.reward_kind()
			all_n += 1
			if got == "card":
				cards_n += 1
				run_of = 0
			else:
				run_of += 1
				worst = maxi(worst, run_of)
	print("  (rewards: %.1f%% cards, at most %d marbles in a row)" % [100.0 * cards_n / all_n, worst])
	_ok("the first reward of a run is a card", first_ok)
	_ok("about 70% cards after that", absf(float(cards_n) / all_n - 0.7) < 0.03)
	_ok("never 3 marble rewards in a row", worst <= 2)
	# Knivel's Innocence: its words show x as it is now; casting gains x, then x grows for the run
	var kr := _run()
	kr.spellbook.append("knivels_innocence")
	kr.loadout = ["knivels_innocence"]
	_ok("Knivel's Innocence shows x = 1 at first", String(kr.spell("knivels_innocence").desc).begins_with("Gain 1 Shield."))
	var kf := _fight(kr)
	kf.mrun.hp = 30
	_chant(kf, "WAA")
	kf.cast(0)
	_ok("cast: gain 1 Shield, no heal any more", kf.block == 1 and kf.mrun.hp == 30)
	_ok("then x is 2, and the card says so", String(kf.card(0).text).begins_with("Gain 2 Shield.") and String(kf.card(0).text).contains("Durability 3"))
	kr.take_back(kf.mrun)
	_ok("x stays 2 for the rest of the run", String(kr.spell("knivels_innocence").desc).begins_with("Gain 2 Shield."))
	# Stream: Durability 3, and its numbers on the card double after each cast
	var sr := _run()
	sr.spellbook.append("stream")
	sr.loadout = ["stream"]
	var sb := sr.make_fight(["iceling"]) as MarbleBridge
	sb.m.foes[0].hp = 50
	_chant(sb.m, "AWW")
	sb._b_sync()
	var s0 := String(sb.loadout[0].desc)
	sb.m.cast(0, 0)
	sb._b_sync()
	var s1 := String(sb.loadout[0].desc)
	print("  (stream: %s -> %s)" % [s0, s1])
	_ok("Stream: Deal 1 / gain 1, Durability 3, then Deal 2 / gain 2, Durability 2", s0.begins_with("Deal 1 damage and gain 1 Shield.") and s0.contains("Durability 3") and s1.begins_with("Deal 2 damage and gain 2 Shield.") and s1.contains("Durability 2"))
	# Durability in a card's words is its value now (the fight screen's card, through MarbleBridge)
	var dr := _run()
	dr.spellbook.append("knivels_innocence")
	dr.loadout = ["knivels_innocence"]
	var br := dr.make_fight(["iceling"]) as MarbleBridge
	_chant(br.m, "WAA")
	br.m.cast(0)
	br._b_sync()
	print("  (worn card: %s)" % String(br.loadout[0].desc))
	_ok("after a cast the card says Durability 2", String(br.loadout[0].desc).contains("Durability 2.") and not String(br.loadout[0].desc).contains("Durability 3"))
	# Water Gun's X on the fight screen's card (the bridge's spell dict, which the card redraws from)
	var wr := _run()
	wr.spellbook.append_array(["water_gun"])
	wr.loadout = ["splash", "water_gun"]
	var wb := wr.make_fight(["iceling"]) as MarbleBridge
	_chant(wb.m, "WWWWF")
	wb._b_sync()
	var before := String(wb.loadout[1].desc)
	wb.m.cast(0)
	wb._b_sync()
	print("  (water gun: %s -> %s)" % [before.left(14), String(wb.loadout[1].desc).left(14)])
	_ok("the screen's Water Gun goes from Deal 2 to Deal 4 after Splash", before.begins_with("Deal 2 damage") and String(wb.loadout[1].desc).begins_with("Deal 4 damage") and bool(wb.loadout[1].get("live_text", false)))
	# the slot machine never shows a short draw while the recycle bin has marbles: the bin goes back into the bag first
	var sm := _fight(_run())
	sm.used_pile.append_array(sm.draw_pile.slice(0, sm.draw_pile.size() - 1))
	sm.draw_pile = sm.draw_pile.slice(sm.draw_pile.size() - 1)
	var keep_last: int = sm.draw_pile[0]
	var shown := sm.next_draw_known()
	_ok("1 marble left in the bag, the bin full: next turn shows 3", shown.size() == 3 and sm.used_pile.is_empty())
	_ok("and the one left in the bag comes out first", shown[0] == sm.mrun.bag[keep_last])
	print("MAIN MARBLES: %d failed" % bad)
