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
	assert_true(Tickets.usable_in("wax", "map") and not Tickets.usable_in("wax", "fight"))


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
	f.use_ticket("duplication", {"hand": f.hand.size() - 1})
	assert_eq(f.mrun.bag.size(), bag + 3)
	assert_eq(String(f.hand[f.hand.size() - 1].c), "W", "a copy of the one chosen")


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
