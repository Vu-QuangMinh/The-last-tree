extends TestCase
## The carnival artifacts (2026-11-27): only they are offered; what they do when picked up; what they do in a marble
## fight (MarblesFight); Power adding to Shield.

var db := SpellDB.load_from("res://data/spells.json")
const NEW := ["red_token", "blue_token", "green_token", "rainbow_token", "thorn_heart", "carver", "collector", "mysterious_hand",
	"golden_ticket", "bulwark", "coal_heart", "candy_apple", "dark_heart", "halo", "kunai", "hammer", "glow_stick", "cactus_plushie",
	"monochrome_prism", "shopping_list", "magician_hat", "leather_glove", "blood_pact", "cursed_book", "switcheroo"]


func _run(seed_v := 5) -> RunState:
	var r := RunState.new()
	var ids := []
	for s in db.all_spells:
		ids.append(s.id)
	r.setup(db, ids, ["mysterious_hand"], seed_v)
	return r


func _fight(cards: Array, arts: Array) -> MarblesFight:
	var r := MarblesRun.new()
	r.setup(11)
	r.cards = cards.duplicate()
	r.artifacts = arts.duplicate()
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


func test_only_the_carnival_set_is_offered() -> void:
	for a in Artifacts.ALL:
		if a.pool != "none":
			assert_true(a.id in NEW, "%s is offered" % a.id)
	for id in NEW:
		assert_true(not Artifacts.get_def(id).is_empty(), "%s exists" % id)
		assert_true(ArtifactBadge.has(id), "%s has its badge" % id)
	assert_eq(Artifacts.get_def("cursed_book").pool, "boss")


func test_blood_pact_costs_max_hp() -> void:
	var r := _run()
	var mh := r.player.max_hp
	r.gain_artifact("blood_pact")
	assert_eq(r.player.max_hp, mh - 10.0)


func test_cursed_book_and_halo() -> void:
	var r := _run()
	r.loadout = ["fire_ball", "water_wall", "tailwind"]
	var slots := r.active_slots()
	r.gain_artifact("cursed_book")
	assert_eq(r.active_slots(), slots + 1, "+1 spell slot")
	assert_eq(r.cursed_spells().size(), 3, "a curse on 3 of your active spells")
	var h := _run()
	h.loadout = ["fire_ball", "water_wall", "tailwind"]
	h.gain_artifact("halo")
	h.gain_artifact("cursed_book")
	assert_true(h.cursed_spells().is_empty(), "the Halo stops them")
	assert_eq(h.pending_curses.size(), 3, "their scenes still play")
	assert_true(h.pending_curses.all(func(c): return c.get("blocked", false)))
	assert_true(h.curse().get("blocked", false), "any curse")


func test_bulwark_keeps_half_the_shield() -> void:
	var f := _fight(["spark"], ["bulwark"])
	f.block = 10
	f._start_turn()
	assert_eq(f.block, 5)


func test_power_adds_to_shield() -> void:
	var f := _fight(["splash"], [])
	f.my_power = 2
	assert_eq(f.card_shield_value(2), 4)


func test_cactus_doubles_thorns_and_stops_shield() -> void:
	var f := _fight(["spark"], ["cactus_plushie"])
	f._shield(10)
	assert_eq(f.block, 0, "no Shield")
	f.my_thorns = 3
	f._on_attacked(f.foes[0], 5)
	assert_eq(int(f.foes[0].hp), 194, "Thorns 3, doubled")


func test_thorn_heart_heals_a_fifth() -> void:
	var f := _fight(["spark"], ["thorn_heart"])
	f.my_thorns = 5
	f._on_attacked(f.foes[0], 5)
	assert_eq(f.run.hp, 61, "20% of 5")


func test_coal_heart_and_glow_stick() -> void:
	var f := _fight(["spark"], ["coal_heart", "glow_stick"])
	f._apply_burn(f.foes[0], 2)
	assert_eq(f.run.hp, 62, "Burn applied: heal 2")
	f._hurt_player(5)
	f._on_attacked(f.foes[1], 5)
	assert_eq(int(f.foes[1].burn), 10, "the first blow: 10 Burn on the attacker")
	f._hurt_player(5)
	f._on_attacked(f.foes[1], 5)
	assert_eq(int(f.foes[1].burn), 10, "only once a fight")


func test_dark_heart_and_kunai() -> void:
	var f := _fight(["spark"], ["dark_heart", "kunai"])
	f.foes[0].hp = 3
	f._hit(f.foes[0], 3)
	assert_true(f.foes[0].dead())
	assert_eq(f.run.hp, 63, "a kill: heal 3")
	f._hit(f.foes[1], 2)
	f._hit(f.foes[1], 2)
	assert_eq(int(f.foes[1].hp), 195, "the 3rd hit (counting the kill): 2 and the Kunai's 1")


func test_hammer_stores_a_blow() -> void:
	var f := _fight(["spark"], ["hammer"])
	f._start_turn()  # (turn 2: nothing was dealt on turn 1)
	assert_eq(f.hammer, 1)
	assert_eq(f.card_damage(10), 13, "+30%")
	_chant(f, "F")
	f.cast(0, 0)
	assert_eq(f.hammer, 0, "spent")


func test_monochrome_prism() -> void:
	var f := _fight(["spark"], ["monochrome_prism"])
	_chant(f, "FF")
	assert_true(f.mono)
	assert_eq(f.card_damage(4), 6, "+50%")
	_chant(f, "FW")
	assert_true(not f.mono)


func test_tokens_give_a_temporary_marble() -> void:
	var f := _fight(["spark"], ["red_token"])
	_chant(f, "FFFFF")
	assert_eq(f.token_next, ["F"])
	f._start_turn()
	var temps := f.hand.filter(func(m): return m.has("temp"))
	assert_eq(temps.size(), 1, "a temporary Fire marble")
	f.chant.clear()
	f._start_turn()
	assert_true(f.hand.filter(func(m): return m.has("temp")).is_empty(), "unused: it fades")


func test_shopping_list_glove_and_hat() -> void:
	var f := _fight(["laser_beam", "circle_of_life"], ["shopping_list", "leather_glove", "magician_hat"])
	var base_rep := int(MarbleCards.card("laser_beam").p.get("rep", 1))
	assert_eq(int(f.card(0).p.rep), base_rep + 1, "3+ marbles: +1 Repeatable")
	assert_eq(int(f.card(1).p.dur), int(MarbleCards.card("circle_of_life").p.dur) + 1, "+1 Durability")
	assert_eq(f.power_now(), 3, "5 slots, 2 cards: 3 empty")


func test_blood_pact_power_in_a_fight() -> void:
	var f := _fight(["spark"], ["blood_pact"])
	assert_eq(f.power_now(), 3)
	f._hurt_player(4)
	assert_eq(f.power_now(), 2)


func test_mysterious_hand() -> void:
	var f := _fight(["burn_them_all"], ["mysterious_hand"])
	_chant(f, "FFFF")
	f.cast(0, 0)
	assert_eq(f.my_power, 1, "a 4-marble spell: +1 Power")


func test_collector_makes_carvings_stronger() -> void:
	var f := _fight(["spark"], ["collector"])
	f.chant.clear()
	f.chant.append({"c": "F", "sym": "sword", "src": -1, "uid": 0, "frozen": false, "hidden": false})
	f.do_chant()
	assert_eq(int(f.dmg_ops[0][1]), 5, "a Sword's 3, +50% (rounded)")


func test_switcheroo_replaces_the_first_broken_spell() -> void:
	var f := _fight(["circle_of_life", "spark"], ["switcheroo"])
	f.mrun.backpack = ["splash"]
	_chant(f, "AFW")
	f.cast(0, 0)
	assert_eq(f.pending_replace, 0, "Durability 1 ran out: it asks for a backpack card")
	f.replace_with(0)
	assert_eq(String(f.run.cards[0]), "splash")
	assert_eq(String(f.mrun.backpack[0]), "circle_of_life")
	f.hammered[1] = StageFight.HAMMER_BREAKS - 1
	f._on_broken(1)
	assert_eq(f.pending_replace, -1, "only the first one, each fight")


func test_circle_of_life_durability() -> void:
	for lv in 3:
		assert_eq(int(MarbleCards.card("circle_of_life", lv).p.dur), lv + 1, "Durability 1 / 2 / 3")


func test_coal_heart_and_pyrophiliac_do_not_loop() -> void:
	var f := _fight(["pyrophiliac"], ["coal_heart"])
	f.triggers["pyrophiliac"] = 0
	f._apply_burn(f.foes[0], 1)
	assert_true(f.run.hp > 60, "it healed, and the fight is still going (no endless Burn / heal)")
