extends TestCase
## Tickets (2026-11-27): the run's two slots, the shop's tickets, the Discount, the out-of-fight tickets, and what the
## fight tickets do in a marble fight (MarblesFight.use_ticket), Encore's second trigger among them.

var db := SpellDB.load_from("res://data/spells.json")


func _run(seed_v := 5) -> RunState:
	var r := RunState.new()
	var ids := []
	for s in db.all_spells:
		ids.append(s.id)
	r.setup(db, ids, [], seed_v)
	return r


## A marble fight against two still iceling with lots of HP (see tools/marbles_cards_test_impl.gd).
func _fight(cards: Array) -> MarblesFight:
	var r := MarblesRun.new()
	r.setup(11)
	r.cards = cards.duplicate()
	r.hp = 60
	r.max_hp = 100
	var f := MarblesFight.new()
	f.setup(r, ["iceling", "iceling"])
	for x in f.foes:
		x.max_hp = 200
		x.hp = 200
		x.block = 0
		x.moves = [{"kind": "hold"}]
		x.random_moves = false
		x.intent = {"kind": "hold"}
	f.block = 0
	return f


func _chant(f: MarblesFight, letters: String) -> void:
	f.hand.clear()
	f.chant.clear()
	f.chanted = false
	for c in letters:
		f.chant.append({"c": c, "sym": "", "src": -1, "uid": 0, "frozen": false, "hidden": false})
	f.do_chant()


func test_every_ticket_is_described() -> void:
	assert_eq(Tickets.ALL.size(), 17, "the user's 11 and the 6 chosen from the suggestions")
	for t in Tickets.ALL:
		assert_true(String(t.desc) != "" and String(t.name) != "", "%s has its words" % t.id)
		assert_true(String(t.use) in ["any", "fight", "out", "rehearsal", "pay"], "%s says where it works" % t.id)
	for id in ["money", "upgrade", "greater_marble"]:
		assert_true(Tickets.is_rare(id), "%s is Rare" % id)
	assert_true(Tickets.usable_in("discount", "shop") and Tickets.usable_in("discount", "event") and not Tickets.usable_in("discount", "map"))
	assert_true(Tickets.usable_in("timeout", "fight") and not Tickets.usable_in("timeout", "map"))
	assert_true(Tickets.usable_in("wax", "map") and Tickets.usable_in("wax", "fight"), "Wax works in a fight too (2026-11-28)")
	assert_true(Tickets.usable_in("upgrade", "fight"), "so does Upgrade")


func test_two_slots() -> void:
	var r := _run()
	assert_true(r.gain_ticket("health") and r.gain_ticket("money"))
	assert_true(not r.gain_ticket("wax"), "a third does not fit")
	r.discard_ticket(0)
	assert_eq(r.tickets, ["money"])
	assert_true(r.gain_ticket("wax"))


func test_shop_sells_three_different_tickets_and_no_bottles() -> void:
	var r := _run()
	var stock := r.shop_stock()
	var ts := stock.filter(func(it): return it.kind == "ticket").map(func(it): return it.ticket)
	assert_eq(ts.size(), 3)
	assert_true(ts[0] != ts[1] and ts[1] != ts[2] and ts[0] != ts[2], "three different ones")
	assert_true(stock.filter(func(it): return it.kind == "bottle").is_empty(), "no bottles any more")


func test_discount_halves_the_next_shop_price() -> void:
	var r := _run()
	var it := {"kind": "artifact", "price": 110}
	assert_eq(r.shop_price(it), 110)
	r.discount_ready = true
	assert_eq(r.shop_price(it), 55)
	r.spend_discount()
	assert_eq(r.shop_price(it), 110)


func test_discount_waives_a_blood_price() -> void:
	var r := _run()
	r.discount_ready = true
	var hp_before := r.player.max_hp
	var opt := {"label": "Bleed", "outcomes": [{"chance": 1.0, "text": "Wax.", "do": [{"op": "blood", "n": 1}]}]}
	var res := r.event_outcome(opt)
	assert_eq(r.player.max_hp, hp_before, "no blood taken")
	assert_true(String(res.text).contains("ticket"), "the event's character says so")
	assert_true(not r.discount_ready)


func test_plain_tickets_outside_a_fight() -> void:
	var r := _run()
	r.player.max_hp = 100.0
	r.player.hp = 40.0
	r.use_ticket_plain("health")
	assert_eq(int(r.player.hp), 70, "30% of max HP")
	r.amber = 45
	r.use_ticket_plain("money")
	assert_eq(r.amber, 90)


func test_blessing_lifts_a_burden() -> void:
	var r := _run()
	var c := r.curse("burden", "W")
	var id := String(c.spell)
	var long := String(r.spell(id).pattern).length()
	assert_true(id in r.cursed_spells())
	assert_true(r.remove_curse(id))
	assert_true(not (id in r.cursed_spells()), "no curse left")
	assert_eq(String(r.spell(id).pattern).length(), long - 1, "the Water it added is gone")


func test_upgrade_ticket() -> void:
	var r := _run()
	r.spellbook = ["spark", "splash"]  # (the new cards: the test spell list starts with the old ones)
	var ids := r.upgradable_cards()
	assert_true(not ids.is_empty())
	var id := String(ids[0])
	r.upgrade_card(id)
	r.upgrade_card(id)
	assert_eq(int(r.card_levels.get(id, 0)), 2)
	assert_true(not (id in r.upgradable_cards()), "at its last level")


func test_fight_heal_shield_money() -> void:
	var f := _fight(["spark"])
	f.use_ticket("health")
	assert_eq(f.run.hp, 90, "30 of 100")
	f.use_ticket("shield")
	assert_eq(f.block, 50, "half your max HP")
	f.mrun.leaves = 7
	f.use_ticket("money")
	assert_eq(f.mrun.leaves, 14)


func test_fight_marbles_come_out_and_stay() -> void:
	var f := _fight(["spark"])
	var bag := f.mrun.bag.size()
	var hand := f.hand.size()
	f.use_ticket("greater_marble", {"marbles": [{"c": "F", "sym": "sword"}, {"c": "W", "sym": ""}]})
	assert_eq(f.mrun.bag.size(), bag + 2, "yours for good")
	assert_eq(f.hand.size(), hand + 2, "and out now")
	var hand2 := f.hand.size()
	var draw := f.draw_pile.size()
	f.use_ticket("duplication", {"hand": f.hand.size() - 1})
	assert_eq(f.mrun.bag.size(), bag + 3)
	assert_eq(String(f.mrun.bag[f.mrun.bag.size() - 1].c), "W", "a copy of the one chosen, in your bag for good")
	assert_eq(f.hand.size(), hand2, "not out now (the user, 2026-11-28)")
	assert_eq(f.draw_pile.size(), draw + 1, "among the marbles still to draw")


func test_fight_removal_draws_another() -> void:
	var f := _fight(["spark"])
	var bag := f.mrun.bag.size()
	var hand := f.hand.size()
	f.use_ticket("removal", {"hand": 0})
	assert_eq(f.mrun.bag.size(), bag - 1, "gone from the bag")
	assert_eq(f.hand.size(), hand, "another drawn in its place")


func test_fight_rehearsal_redraws() -> void:
	var f := _fight(["spark"])
	var hand := f.hand.size()
	f.use_ticket("rehearsal")
	assert_eq(f.hand.size(), hand, "as many as were put back")


func test_encore_triggers_the_next_card_twice() -> void:
	var f := _fight(["spark"])
	f.use_ticket("encore")
	_chant(f, "F")
	f.cast(0, 0)
	assert_eq(int(f.foes[0].hp), 194, "3 damage, twice")
	assert_eq(f.encore, 0, "the Encore is spent")
	var plain := _fight(["spark"])
	_chant(plain, "F")
	plain.cast(0, 0)
	assert_eq(int(plain.foes[0].hp), 197, "without it: once")


func test_fixing_mends_a_broken_card() -> void:
	var f := _fight(["spark"])
	f.hammered[0] = StageFight.HAMMER_BREAKS
	assert_true(f.broken(0))
	f.use_ticket("fixing", {"ci": 0})
	assert_true(not f.broken(0))
	assert_true(f.usable(0))


func test_timeout_swaps_a_card() -> void:
	var f := _fight(["spark", "splash"])
	f.mrun.backpack = ["paper_cut"]
	f.use_ticket("timeout", {"swaps": [[1, 0]]})
	assert_eq(String(f.run.cards[1]), "paper_cut")
	assert_eq(String(f.mrun.backpack[0]), "splash")


func test_alchemy_gives_tickets() -> void:
	var f := _fight(["alchemy"])
	f.mrun.tickets = ["health"]
	_chant(f, "FAW")
	f.cast(0, 0)
	assert_eq(f.mrun.tickets.size(), 2, "one ticket, into the free slot")
	assert_true(String(f.mrun.tickets[1]) in Tickets.ids())
	assert_true(MarbleCards.text("alchemy").contains("ticket"), "its words say so")


## The card changes of 2026-11-27 (after the Act 1 simulations).
func test_card_changes_2026_11_27() -> void:
	assert_eq(int(MarbleCards.card("whim_of_the_pianist").p.x), 3)
	assert_eq(int(MarbleCards.card("whim_of_the_pianist", 2).p.cd), 1, "always Cooldown 1")
	assert_eq(int(MarbleCards.card("steam_gun", 2).p.dur), 3)
	assert_eq(int(MarbleCards.card("steam_gun", 2).p.x), 1, "no more damage with upgrades")
	assert_eq(int(MarbleCards.card("heat_wave", 2).p.burn), 3)
	assert_eq(int(MarbleCards.card("firelance").p.burn), 2)
	assert_eq(MarbleCards.rarity("a_daughters_secret"), "rare")
	assert_true(MarbleCards.text("glass_cannon").contains("gone"))


func test_sadistic_nature_heals() -> void:
	var f := _fight(["sadistic_nature"])
	_chant(f, "FW")
	f.cast(0, 0)
	assert_eq(f.my_power, 0, "no Power any more")
	assert_eq(f.run.hp, 61, "heal 1 for the Vulnerable it applied")


func test_iron_maiden_gives_shield() -> void:
	var f := _fight(["iron_maiden"])
	_chant(f, "WWA")
	f.cast(0, -1)
	assert_eq(f.my_thorns, 1)
	assert_eq(f.block, 1, "1 Shield for each Thorns")
	assert_eq(int(f.foes[0].hp), 200, "no damage")


func test_glass_cannon_takes_the_marbles_for_the_fight() -> void:
	var f := _fight(["glass_cannon"])
	f.hand.clear()
	f.chant.clear()
	f.chanted = false
	for c in "FWA":
		f.chant.append({"c": c, "sym": "", "src": f.draw_pile.pop_back(), "uid": 0, "frozen": false, "hidden": false})
	var gone: Array = f.chant.map(func(m): return int(m.src))
	f.do_chant()
	f.cast(0, 0)
	assert_eq(int(f.foes[0].hp), 194, "2 a marble, 3 marbles")
	f.end_turn()
	for i in gone:
		assert_true(not (i in f.used_pile) and not (i in f.draw_pile), "those marbles are out for the fight")


func test_warm_up_grows_only_when_woken_and_not_cast() -> void:
	var f := _fight(["warm_up"])
	f._start_turn()
	assert_eq(int(f.grow.get(0, 0)), 0, "not woken: no growth")
	_chant(f, "FA")
	f._start_turn()
	assert_eq(int(f.grow.get(0, 0)), 5, "woken and not cast: +5")


func test_insight_of_the_pianist() -> void:
	var f := _fight(["insight_of_the_pianist", "spark"])
	_chant(f, "AA")
	f.cast(0, -1)
	assert_eq(f.pending_infuse, 1)
	assert_true(not f.can_cast(1), "you pick before you cast on")
	var pick: int = -1
	for i in f.infuse_choices():
		if String(f.mrun.bag[i].c) == "F":
			pick = i
	f.infuse_pick(pick)
	assert_eq(String(f.chant[f.chant.size() - 1].c), "F", "your pick joins the end of the chant")
	assert_true(f.can_cast(1), "and it wakes Spark")


func test_expose_fades_by_one_a_turn() -> void:
	var f := _fight(["spark"])
	f.foes[0].expose = 3
	f.expose = 2
	f.end_turn()
	assert_eq(f.foes[0].expose, 2, "an enemy's Expose drops by 1 at its turn")
	assert_eq(f.expose, 1, "yours drops by 1 as the enemy phase begins")


func test_no_wax_on_a_one_marble_spell() -> void:
	var r := _run()
	var one := ""
	var two := ""
	for id in r.spellbook:
		var n := String(r.spell(id).pattern).length()
		if n == 1 and one == "":
			one = String(id)
		elif n == 2 and two == "":
			two = String(id)
	if one != "":
		assert_true(not (one in r.upgradable()), "a 1-marble spell takes no wax")
		r.seal_spell(one, 0)
		assert_eq(String(r.spell(one).pattern).length(), 1, "and sealing it does nothing")
	if two != "":
		assert_true(two in r.upgradable())
		r.seal_spell(two, 0)
		assert_eq(String(r.spell(two).pattern).length(), 1, "a 2-marble spell is sealed down to 1")
		assert_true(not (two in r.upgradable()), "and no further")
		assert_true(r.sealable(two).is_empty())
