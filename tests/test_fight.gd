extends TestCase
## Fight resolution order and enemy tricks.

var db := SpellDB.load_from("res://data/spells.json")


func _fight(enemy_ids: Array, spells: Array, stock: String) -> Fight:
	var f := Fight.new(db, PlayerState.new())
	f.rng.seed = 7
	f.loadout = spells.map(func(id): return db.get_spell(id))
	f.start(enemy_ids, 1, 1)
	f.player.stock.clear()
	for ch in stock:
		f.player.add_element(ch)
	return f


func _set_hp(e: EnemyState, hp: String) -> void:
	e.elements.clear()
	for ch in hp:
		e.elements.append(ch)
	e.armor.resize(e.elements.size())
	e.armor.fill(false)
	e.lit.clear()


func _all(n: int) -> Array:
	return range(n)


func test_chant_strikes_before_spells() -> void:
	# Fire Ball (FF): remove the rightmost element. Chant FF on FFWA: strike takes FF, then the ball takes A.
	var f := _fight(["ashling"], ["fire_ball"], "FF")
	_set_hp(f.enemies[0], "FFWA")
	f.cast(_all(2))
	assert_eq(f.enemies[0].hp_text(), "W")


func test_spell_fires_once_per_turn() -> void:
	var f := _fight(["ashling", "ashling"], ["fire_ball"], "FFWFF")
	_set_hp(f.enemies[0], "AAAAA")
	_set_hp(f.enemies[1], "AAAAA")
	var chosen := []
	f.chooser = func(_s, cands): chosen.append(cands[0]); return cands[0]
	f.cast(_all(5))
	assert_eq(f.preview("FFWFF").spells.get("fire_ball", 0), 1, "FF twice in the chant, but a spell triggers once")
	assert_eq(f.enemies[0].size(), 4, "one Fire Ball")


func test_power_leaves_row_for_the_fight() -> void:
	var f := _fight(["ashling"], ["kindle"], "F")
	_set_hp(f.enemies[0], "WWWWWW")
	var sp := db.get_spell("kindle")
	f.player.stock.clear()
	for ch in sp.pattern:
		f.player.add_element(ch)
	f.cast(_all(sp.pattern.length()))
	assert_true(f.player.used_powers.has("kindle"), "power is used")
	assert_true(f.usable_spells().is_empty(), "slot stays empty")


func test_confuse_reads_backwards() -> void:
	var f := _fight(["ashling"], [], "WF")
	_set_hp(f.enemies[0], "FWAAAA")
	f.player.confuse_turns = 1
	f.cast(_all(2))
	assert_eq(f.enemies[0].hp_text(), "AAAA", "WF read as FW")


func test_steal_adds_to_enemy_hp() -> void:
	var f := _fight(["pickpocket_imp"], [], "W")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "AAAAAA")
	f.player.hp = 99
	f.player.max_hp = 99
	f.pass_turn()  # imp's first move is steal 1
	assert_eq(e.hp_text(), "AAAAAAW")


func test_lock_blocks_until_broken() -> void:
	var f := _fight(["ashling"], ["fire_ball"], "FFWA")
	_set_hp(f.enemies[0], "AAAAAAAA")
	f.player.locks["fire_ball"] = "WA"
	assert_true(f.usable_spells().is_empty())
	f.cast(_all(4))  # FFWA: lock broken first (WA), then fire ball fires
	assert_true(not f.player.locks.has("fire_ball"))
	assert_eq(f.enemies[0].size(), 6, "chant can't strike (no leading W... A matches 1), ball takes 1")


func test_warded_ignores_short_chants() -> void:
	var f := _fight(["warded_golem"], [], "FFW")
	f.cast(_all(3))
	assert_eq(f.enemies[0].size(), 6)


func test_burn_takes_leftmost_each_enemy_turn_and_lasts() -> void:
	var f := _fight(["ashling"], [], "")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "FWAWFAAW")
	assert_eq(e.ignite(2, f.rng), 2)
	assert_eq(e.burn, 2)
	f.player.hp = 99
	f.pass_turn()  # its turn: the fire takes F W first, then Burn drops to 1
	assert_eq(e.hp_text(), "AWFAAW")
	assert_eq(e.burn, 1)
	f.pass_turn()
	assert_true(e.hp_text().begins_with("WFAAW"), "Burn 1 takes just the A: " + e.hp_text())
	assert_eq(e.burn, 0)


func test_burned_out_enemy_never_attacks() -> void:
	var f := _fight(["ashling"], [], "")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "FW")
	e.burn = 2  # all of it is burning
	f.player.hp = 30.0
	f.pass_turn()
	assert_true(f.won, "burned away at the start of its turn")
	assert_eq(f.player.hp, 30.0, "so it never got to attack")


func test_damage_taken_counts_hp_lost_not_blocked_or_healed() -> void:
	var p := PlayerState.new()
	p.reset_fight()
	p.shield = 5.0
	p.take_attack(4.0)  # fully blocked
	assert_eq(p.damage_taken, 0.0, "blocked hits don't count")
	p.take_effect(2.0)
	p.heal(2.0)
	assert_eq(p.damage_taken, 2.0, "healing doesn't undo it")
	p.reset_fight()
	assert_eq(p.damage_taken, 0.0, "a new fight starts clean")


func test_upgraded_artifact_uses_its_plus_number() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.gain_artifact("rain_chalice")
	assert_true("rain_chalice" in run.upgradable_artifacts())
	assert_eq(run.make_fight(["ashling"]).player.shield, 4.0)
	run.upgrade_artifact("rain_chalice")
	assert_eq(run.make_fight(["ashling"]).player.shield, 6.0, "Rain Chalice+ gives 6 Shield")
	assert_true(not ("rain_chalice" in run.upgradable_artifacts()), "only once")
	assert_eq(Artifacts.view("rain_chalice", true).name, "Rain Chalice+")


func test_trade_two_of_a_tier_for_one_above() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.gain_artifact("iron_bark")
	assert_true(run.tradeable_artifacts().is_empty(), "one common isn't a pair")
	run.gain_artifact("healing_sap")
	assert_eq(run.tradeable_artifacts().size(), 2)
	var offer := run.trade_offer("common")
	assert_true(not offer.is_empty() and offer.all(func(a): return a.tier == "rare" and a.get("aspect", "") != "Cursed"))
	run.trade_artifacts("iron_bark", "healing_sap", offer[0].id)
	assert_eq(run.artifacts, ["seed_of_life", offer[0].id], "the starting Seed of Life is never part of a trade")


func test_prefight_essence_matches_the_fight() -> void:
	for seed in [3, 11, 29]:
		var run := RunState.new()
		run.setup(db, [], [], seed)
		run.act = 2  # deeper: enemies get extra random Essence
		var ids := run.encounter_ids()
		var shown := []
		for i in ids.size():
			shown.append("".join(run.encounter_hp(i)))
		var f := run.make_fight(ids)
		var real := f.enemies.map(func(e): return e.hp_text())
		assert_eq(real, shown, "seed %d: what the preview shows is what you fight" % seed)


func test_withered_idol_gives_2_elements_costs_a_slot() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	var slots := run.active_slots()
	run.gain_artifact("withered_idol")
	assert_eq(run.active_slots(), slots - 1)
	var f := run.make_fight(["ashling"])
	assert_eq(f.player.next_draw.size(), PlayerState.BASE_DRAW + 2)


func test_annihilate_wipes_one_element_and_is_fleeting() -> void:
	var f := _fight(["ashling", "gale_sprite"], ["annihilate"], "FWAAWF")
	_set_hp(f.enemies[0], "FWFAWF")
	_set_hp(f.enemies[1], "AFAW")
	f.element_chooser = func(_s, counts):
		assert_eq(counts, {"F": 4, "W": 3, "A": 3})
		return "F"
	f.cast_chant(_all(6))
	assert_eq(f.charges.get("annihilate", 0), 1, "F W A (any) W F")
	f.resolve_spell("annihilate")
	assert_eq(f.enemies[0].hp_text() + "|" + f.enemies[1].hp_text(), "WAW|AAW", "every Fire is gone")
	assert_true(not f.active_spells().any(func(s): return s.id == "annihilate"), "Fleeting: gone for the fight")
	assert_true(SpellText.card_text(db.get_spell("annihilate")).begins_with("Annihilate 1 kind of Essence on all enemies"))


func test_echo_shell_charges_every_10th_spell() -> void:
	var f := _fight(["ashling"], ["droplet"], "")
	f.artifacts = ["echo_shell"]
	var shields := []
	for i in 11:
		f.player.stock.clear()
		f.player.add_element("W")
		f.player.shield = 0.0
		f.cast_chant([0])
		f.resolve_all()  # Droplet: +2 Shield
		shields.append(f.player.shield)
		f.charges.clear()
		f.chant.clear()
	assert_eq(shields[9], 2.0, "the 10th cast charges it")
	assert_eq(shields[10], 4.0, "the 11th is cast twice")
	assert_true(not f.player.echo_charged)
	assert_eq(Artifacts.charge_state("echo_shell", f.player)[0], false)


func test_bottles_work_like_tiny_spells() -> void:
	var f := _fight(["ashling"], [], "")
	_set_hp(f.enemies[0], "FWAWFA")
	f.player.bottles = ["liquid_fire", "fire_flask", "grimoire_ink"]
	f.use_bottle(0, 0)
	assert_eq(f.enemies[0].burn, 3)
	var fires := f.player.stock.filter(func(s): return s.el == "F").size()
	f.use_bottle(0)  # the Fire Flask is now first
	assert_eq(f.player.stock.filter(func(s): return s.el == "F").size(), fires + 2)
	f.spellbook = [db.get_spell("meteor")]
	f.use_bottle(0)
	assert_true(f.loadout.any(func(s): return s.id == "meteor"), "Grimoire Ink adds a spellbook spell")
	assert_true(f.player.bottles.is_empty(), "each bottle is used up")


func test_arcane_barrage_removes_3_random_essence() -> void:
	var f := _fight(["ashling", "gale_sprite"], ["arcane_barrage"], "WFA")
	_set_hp(f.enemies[0], "FFFF")
	_set_hp(f.enemies[1], "WWWW")
	f.cast_chant(_all(3))
	f.resolve_spell("arcane_barrage")
	assert_eq(f.enemies[0].size() + f.enemies[1].size(), 5, "3 of the 8 gone")
	assert_eq(SpellText.card_text(db.get_spell("arcane_barrage")), "Remove 3 random Essence from random enemies.")


func test_seals_shorten_a_spell_down_to_every_chant() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.seal_spell("fire_ball", 1)
	assert_eq(run.spell("fire_ball").pattern, "F")
	assert_eq(run.spell("fire_ball").full_pattern, "FF")
	assert_eq(run.spell("fire_ball").name, "Fire Ball", "the name doesn't change")
	run.seal_spell("fire_ball", 0)
	assert_eq(run.spell("fire_ball").pattern, "")
	assert_true(not ("fire_ball" in run.upgradable()), "nothing left to seal")
	var f := run.make_fight(["ashling"])
	f.player.stock.clear()
	f.player.add_element("W")
	f.cast_chant([0])
	assert_eq(f.charges.get("fire_ball", 0), 1, "a fully sealed spell wakes on any chant")


func test_absorb_heals_only_when_it_defeats() -> void:
	var f := _fight(["ashling"], ["leech"], "FAW")
	assert_eq(db.get_spell("leech").name, "Absorb")
	f.player.hp = 20
	_set_hp(f.enemies[0], "WWWWWW")
	f.cast_chant(_all(3))
	f.resolve_spell("leech")
	assert_eq(f.player.hp, 20.0, "2 of 6 removed: it lives, no heal")
	var g := _fight(["ashling"], ["leech"], "FAW")
	g.player.hp = 20
	_set_hp(g.enemies[0], "WW")
	g.cast_chant(_all(3))
	g.resolve_spell("leech")
	assert_eq(g.player.hp, 25.0, "it's defeated: heal 5")
	# the upgraded one too, and no heal animation is even played when nothing is defeated
	var h := _fight(["ashling"], [], "FAW")
	h.loadout = [SpellDB.upgrade(db.get_spell("leech"))]
	var events := []
	h.anim = func(ev): events.append(ev.get("op", ev.type))
	h.player.hp = 20
	_set_hp(h.enemies[0], "WWWWWW")
	h.cast_chant(_all(3))
	h.resolve_spell("leech")
	assert_eq(h.player.hp, 20.0, "Absorb+: it lives, no heal")
	assert_true(not ("heal" in events), "no heal animation either: %s" % [events])


func test_split_makes_a_twin() -> void:
	var f := _fight(["splitter_ooze"], [], "W")
	_set_hp(f.enemies[0], "WWFF")
	f.cast(_all(1))
	assert_eq(f.enemies.size(), 2)
	assert_eq(f.enemies[0].hp_text() + "|" + f.enemies[1].hp_text(), "W|FF")


func test_kindling_stone_charges_every_third_chant() -> void:
	var f := _fight(["ashling"], ["ember"], "")
	f.artifacts = ["kindling_stone"]
	var e: EnemyState = f.enemies[0]
	f.player.hp = 99
	var burns := []
	for i in 4:
		_set_hp(e, "AAAAAAAAAA")
		f.player.stock.clear()
		f.player.add_element("F")
		f.cast_chant([0])
		f.resolve_all()  # Ember: Burn 1 on the target
		burns.append(e.burn)
		f.finish_turn()
	# Burn lasts (dropping by 1 each enemy turn): 1 -> 0, 1 -> 0, doubled 2 -> 1, then 1 + 1 = 2
	assert_eq(burns, [1, 1, 2, 2], "3rd chant charges the stone and its Burn is doubled")
	assert_true(not f.player.kindling_charged)
	assert_eq(f.player.kindling_chants, 1)


func test_lens_refunds_about_a_quarter_of_its_element() -> void:
	var f := _fight(["ashling"], [], "")
	f.artifacts = ["flame_lens"]
	var fire := 0
	var water := 0
	for i in 200:
		for el in f._lens_refunds(["F", "F", "W", "F", "A", "F"]):
			if el == "F":
				fire += 1
			else:
				water += 1
	assert_eq(water, 0, "only Fire comes back")
	assert_true(fire > 140 and fire < 260, "about 25%% of 800 Fire: got %d" % fire)


func test_every_fight_starts_with_one_of_each_element() -> void:
	for seed in 40:
		var f := Fight.new(db, PlayerState.new())
		f.rng.seed = seed
		f.loadout = [db.get_spell("fire_ball")]
		f.start(["ashling"], 1, 1)
		var els: Array = f.player.stock.map(func(s): return s.el)
		assert_eq(els.size(), PlayerState.START_ELEMENTS)
		for el in ["F", "W", "A"]:
			assert_true(el in els, "seed %d: start hand %s has no %s" % [seed, "".join(els), el])


func test_early_enemies_have_three_essence() -> void:
	for id in ["ashling", "puddle_slime", "gale_sprite", "frost_hex"]:
		assert_true(EnemyDefs.get_def(id).hp.length() >= 3, "%s has only 2 Essence" % id)


func test_emblems_give_three_on_turn_three() -> void:
	var f := Fight.new(db, PlayerState.new())
	f.rng.seed = 3
	f.artifacts = ["fire_emblem", "wind_emblem"]
	f.start(["warded_golem"], 1, 1)
	f.player.hp = 999
	f.player.max_hp = 999
	var fire_next := func(): return f.player.next_draw.filter(func(d): return d.el == "F").size()
	var wind_next := func(): return f.player.next_draw.filter(func(d): return d.el == "A").size()
	assert_eq(f.player.next_draw.size(), 3, "turn 2 draw is normal")
	f.pass_turn()
	assert_eq(f.turn, 2)
	assert_eq(f.player.next_draw.size(), 9, "turn 3 draw shows 3 + 3 Fire + 3 Wind in Coming next")
	assert_true(fire_next.call() >= 3 and wind_next.call() >= 3)
	var before := f.player.stock.size()
	f.pass_turn()
	assert_eq(f.player.stock.size() - before, 9, "all of it arrives on turn 3")
	f.pass_turn()
	assert_eq(f.player.next_draw.size(), 3, "only once per fight")


func test_spells_wait_for_the_player_after_the_chant() -> void:
	var f := _fight(["ashling"], ["fire_ball", "flare"], "FF")
	_set_hp(f.enemies[0], "WWWWWW")
	f.cast_chant(_all(2))
	assert_eq(f.charges.size(), 2, "two spells alive, nothing resolved yet")
	assert_eq(f.enemies[0].size(), 6)
	f.resolve_spell("fire_ball", 0)
	assert_eq(f.enemies[0].size(), 5)
	assert_eq(f.charges.get("fire_ball", 0), 0)
	assert_eq(f.charges.get("flare", 0), 1)
	f.player.hp = 99
	f.end_player_turn()
	assert_true(f.charges.is_empty(), "leftover charges fizzle at end of turn")
	assert_eq(f.enemies[0].size(), 5)


func test_move_lets_you_place_an_element() -> void:
	var f := _fight(["ashling"], ["updraft"], "A")
	_set_hp(f.enemies[0], "FWAWW")
	f.mover = func(_s, _e): return [2, 0]  # pick up the A, put it first
	f.cast_chant([0])
	f.resolve_spell("updraft", 0)
	assert_eq(f.enemies[0].hp_text(), "AFWWW")


func test_redirect_turns_an_attack_on_itself() -> void:
	var f := _fight(["stone_knight"], ["decoy"], "AWAW")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "FFFFFFFF")
	f.pass_turn()  # armour turn; next intent: attack 8
	assert_eq(e.intent.kind, "attack")
	f.player.hp = 40
	f.player.stock.clear()
	for ch in "AWAW":
		f.player.add_element(ch)
	f.redirector = func(_s, src, _c): return f.enemies.find(src)
	f.cast(_all(4))
	assert_eq(f.player.hp, 40.0, "the attack went elsewhere")
	assert_eq(e.size(), 8 - 3, "8 damage turned on itself = 3 elements")


func test_spells_resolve_before_the_damage_step() -> void:
	# Spritz (WW) paints 2 Essence Any; with spells first, this turn's chant already hits them
	var f := _fight(["ashling"], ["soak"], "WW")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "AAWWF")
	f.player.hp = 99
	f.painter = func(_s):
		var i: int = e.elements.find_custom(func(x): return x != "?")
		return [0, i]
	f.cast_chant(_all(2))
	assert_eq(e.size(), 5, "nothing struck before the spells")
	f.resolve_spell("soak", 0)
	assert_eq(e.hp_text(), "??WWF", "the two leftmost were painted Any")
	f.finish_turn()
	assert_eq(e.hp_text(), "WWF", "WW hits the two Any Essence")


func test_expose_paints_anywhere_and_upgrades_add_one() -> void:
	var f := _fight(["ashling", "ashling"], ["spray"], "WA")
	var a: EnemyState = f.enemies[0]
	var b: EnemyState = f.enemies[1]
	_set_hp(a, "FFF")
	_set_hp(b, "FFF")
	var picks := [[0, 2], [1, 1]]
	f.painter = func(_s): return picks.pop_front()
	f.cast_chant(_all(2))
	f.resolve_spell("spray")
	assert_eq(a.hp_text(), "FF?", "one on the first enemy, at the end")
	assert_eq(b.hp_text(), "F?F", "one on the second, in the middle")
	var up := SpellDB.upgrade(f.db.get_spell("spray"))
	assert_eq(up.effects[0].n, 3, "Spray+ paints 3")


func test_every_spell_triggers_once_per_turn() -> void:
	var f := _fight(["ashling"], ["water_wall", "droplet"], "WWWWWW")
	f.cast_chant(_all(6))
	assert_eq(f.charges.get("water_wall", 0), 1, "WW x3 in the chant, but it triggers once")
	assert_eq(f.charges.get("droplet", 0), 1)


func test_infuse_is_retroactive() -> void:
	# Spark Word (WA) puts a Fire into the chant; placed first, FWA becomes FFWA and Fire Ball (FF) comes alive
	var f := _fight(["ashling"], ["spark_word", "fire_ball"], "FWA")
	_set_hp(f.enemies[0], "WWWWWWWW")
	f.placer = func(_s, _el): return 0  # FWA -> F FWA = FFWA
	f.cast_chant(_all(3))
	assert_true(not f.charges.has("fire_ball"), "no FF yet")
	f.resolve_spell("spark_word")
	assert_eq(f.chant_string(), "FFWA")
	assert_eq(f.charges.get("fire_ball", 0), 1, "the new FF brings Fire Ball to life")


func test_rearrange_moves_a_chant_element_and_recounts() -> void:
	# Tempest (AAA): FWFA has no FF; moving the second F next to the first makes FFWA and wakes Fire Ball (FF)
	var f := _fight(["ashling"], ["tempest", "fire_ball"], "AAAFWF")
	_set_hp(f.enemies[0], "WWWWWWWW")
	f.arranger = func(_s): return [5, 4]  # AAAFWF -> AAAFFW
	f.cast_chant(_all(6))
	assert_true(not f.charges.has("fire_ball"), "no FF yet")
	f.resolve_spell("tempest")
	assert_eq(f.chant_string(), "AAAFFW")
	assert_eq(f.charges.get("fire_ball", 0), 1, "the new FF brings Fire Ball to life")
	assert_eq(SpellText.card_text(db.get_spell("tempest")), "Gain 2 random Essence next turn.\nRearrange 1.")


func test_changing_the_chant_never_puts_a_live_spell_to_sleep() -> void:
	# Tempest (AAA) and Fire Ball (FF) both wake on AAAFF; moving the last F to the front (FAAAF) breaks up FF,
	# but Fire Ball stays alive
	var f := _fight(["ashling"], ["tempest", "fire_ball"], "AAAFF")
	_set_hp(f.enemies[0], "WWWWWWWW")
	f.arranger = func(_s): return [4, 0]  # AAAFF -> FAAAF
	f.cast_chant(_all(5))
	assert_eq(f.charges.get("fire_ball", 0), 1)
	f.resolve_spell("tempest")
	assert_eq(f.chant_string(), "FAAAF")
	assert_eq(f.charges.get("fire_ball", 0), 1, "Fire Ball keeps its charge")
	assert_true(not f.charges.has("tempest"), "the spell just cast is used up")


func test_duplicate_copies_an_element_in_the_chant() -> void:
	var f := _fight(["ashling"], ["resonance"], "AFW")
	f.chant_picker = func(_s): return 1  # the F
	f.cast_chant(_all(3))
	f.resolve_spell("resonance")
	assert_eq(f.chant_string(), "AFFW")


func test_strike_steps_left_to_right() -> void:
	var f := _fight(["ashling"], [], "WFFW")
	_set_hp(f.enemies[0], "FFWAAA")
	f.player.hp = 99
	var steps := []
	f.anim = func(ev):
		if ev.type == "chant_step":
			steps.append([ev.pos, ev.hits.map(func(h): return h[1])])
	f.cast(_all(4))
	# FFW is found at chant positions 1-3: HP element 0 falls at step 1, 1 at step 2, 2 at step 3
	assert_eq(steps, [[0, []], [1, [0]], [2, [1]], [3, [2]]])


func test_grimoire_adds_two_spells() -> void:
	var f := _fight(["ashling"], ["grimoire"], "WFWA")
	f.spellbook = [db.get_spell("fire_ball"), db.get_spell("water_wall"), db.get_spell("tailwind"), db.get_spell("grimoire")]
	f.cast_chant(_all(4))
	f.resolve_spell("grimoire")
	assert_eq(f.loadout.size(), 3, "Grimoire + 2 spells")
	assert_eq(f.active_spells().size(), 2, "the Power left the row: net +1")


func test_rewards_follow_rarity() -> void:
	var run := RunState.new()
	var all: Array = db.all_spells.map(func(s): return s.id)
	run.setup(db, all, [], 9)
	for s in run.spell_offer(3, "elite"):
		assert_eq(s.rarity, "rare")
	for s in run.spell_offer(3, "boss"):
		assert_eq(s.rarity, "legendary")
	var rares := 0
	for i in 200:
		for s in run.spell_offer(3, "fight"):
			assert_true(s.rarity != "legendary")
			if s.rarity == "rare":
				rares += 1
	assert_true(rares > 120 and rares < 240, "about 30%% rares, got %d of 600" % rares)


func test_reward_offers_mix_kinds() -> void:
	var run := RunState.new()
	var all: Array = db.all_spells.map(func(s): return s.id)
	run.setup(db, all, [], 5)
	for i in 60:
		var offer := run.spell_offer(3)
		var kinds := {}
		for s in offer:
			kinds[s.kind] = true
		assert_true(kinds.size() >= 2, "offer %d has kinds %s" % [i, kinds.keys()])


func test_gust_plucks_the_chosen_element() -> void:
	var f := _fight(["ashling"], ["gust"], "AF")
	_set_hp(f.enemies[0], "WWFAW")
	f.picker = func(_s, _e): return 3  # the Wind in the middle
	f.cast_chant(_all(2))
	f.resolve_spell("gust", 0)
	assert_eq(f.enemies[0].hp_text(), "WWFW")


func test_keywords_colour_words_and_numbers() -> void:
	var s := Keywords.colorize("Burn 2 on the target; gain 3 Shield.")
	assert_true(s.contains("[b]Burn[/b]") and s.contains("[b]2[/b]") and s.contains("[b]Shield[/b]"), s)
	assert_eq(Keywords.glossary("Burn 2 and Burn 1").size(), 1, "each keyword explained once")


func test_steal_any_puts_the_chosen_element_in_your_bag() -> void:
	var f := _fight(["ashling"], ["tide_thief"], "WAW")
	_set_hp(f.enemies[0], "FFAWF")
	f.picker = func(_s, _e): return 2  # the A
	f.cast_chant(_all(3))
	var before := f.player.stock.size()
	f.resolve_spell("tide_thief", 0)
	assert_eq(f.enemies[0].hp_text(), "FFWF")
	assert_eq(f.player.stock.size(), before + 1)
	assert_eq(f.player.stock[-1].el, "A", "stolen into the bag, not the chant")
	assert_eq(f.chant_string(), "WAW")


func test_steal_a_specific_element() -> void:
	var f := _fight(["ashling"], ["sirens_call"], "WWF")
	_set_hp(f.enemies[0], "FWFAF")
	f.cast_chant(_all(3))
	f.resolve_spell("sirens_call", 0)
	assert_eq(f.enemies[0].hp_text(), "WAF", "up to 2 Fire, from the front")
	assert_eq(f.player.stock.filter(func(s): return s.el == "F").size(), 2)


func test_spell_slots_start_at_5_and_cap_at_8() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 3)
	assert_eq(run.active_slots(), 5)
	assert_eq(run.loadout.size(), 3, "Fire Ball, Water Wall, Tailwind")
	assert_true(not ("gust" in run.loadout), "Gust is not a starter")
	for a in ["spell_pouch", "spell_satchel", "broken_crown"]:
		run.gain_artifact(a)
	assert_eq(run.active_slots(), 8, "5 + 1 + 1 + 2 = 9, capped at 8")


func test_artifact_tiers() -> void:
	for a in Artifacts.ALL:
		assert_true(a.has("tier"), a.id)
		if a.tier == "legendary":
			assert_eq(a.pool, "boss", "%s: legendaries only drop from bosses" % a.id)
		if a.aspect == "Spell slots" or a.id == "broken_crown":
			assert_true(a.tier in ["rare", "legendary"], "%s adds slots, so it can't be common" % a.id)
	var rng := RandomNumberGenerator.new()
	for i in 20:
		for k in Artifacts.keepsakes(rng, 3):
			assert_eq(k.tier, "common")


func test_fuse_keeps_every_element_first_card_first() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.learn_spell("inferno")  # F?F
	var prev := run.fuse_preview("water_wall", "inferno")  # WW then F?F
	assert_eq(prev.pattern, "WWF?F", "the first card's pattern, then all of the second's")
	assert_eq(prev.size, 5)
	assert_eq(prev.effects.size(), 2, "does both spells' effects")
	var other := run.fuse_preview("inferno", "water_wall")
	assert_eq(other.pattern, "F?FWW", "the order sets the pattern")
	assert_eq(other.name, prev.name, "but not the name")
	assert_true(not prev.name.contains("+"), "a real name: " + prev.name)
	var shot := run.fuse_preview("water_wall", "inferno", 2)
	assert_eq(shot.pattern, "WW?F", "the shot Essence is gone and the rest close up")
	assert_eq(shot.size, 4)
	run.fuse_commit(prev, "water_wall", "inferno")
	assert_true(not ("water_wall" in run.spellbook) and not ("inferno" in run.spellbook), "both used up")
	assert_true(prev.id in run.spellbook)
	assert_true(not run.can_fuse(prev.id), "fused spells can't be fused again")


func test_thermal_burst_hits_two_different_enemies() -> void:
	var f := _fight(["ashling", "gale_sprite", "puddle_slime"], ["thermal_burst"], "FFWF")
	for i in 3:
		_set_hp(f.enemies[i], "WWWWW")
	var asked := []
	f.chooser = func(_s, cands): asked.append(cands.duplicate()); return cands[-1]
	f.cast_chant(_all(4))
	f.resolve_spell("thermal_burst", 0)
	assert_eq(f.enemies[0].size(), 3, "first target: -2 from the front")
	assert_eq(f.enemies[2].size(), 3, "second target: a different enemy")
	assert_eq(f.enemies[1].size(), 5)
	assert_true(not (0 in asked[0]), "the second pick can't be the first target again")
	assert_eq(SpellText.card_text(db.get_spell("thermal_burst")), "Remove the 2 leftmost Essence of 2 different enemies.")


func test_anti_spell_comes_alive_unless_its_pattern_is_chanted() -> void:
	var f := _fight(["ashling"], ["calm_waters"], "")  # Calm Waters: W anti-spell (10 Shield, Aegis 1, heal 4)
	_set_hp(f.enemies[0], "AAAAAAAA")
	f.player.hp = 30
	f.player.stock.clear()
	f.player.add_element("F")
	f.cast_chant([0])  # F: no W, so it comes alive like any spell
	assert_eq(f.charges.get("calm_waters", 0), 1, "alive after the chant")
	f.resolve_all()
	assert_eq(f.player.shield, 10.0, "cast like a spell")
	var g := _fight(["ashling"], ["calm_waters"], "")
	_set_hp(g.enemies[0], "AAAAAAAA")
	g.player.stock.clear()
	g.player.add_element("W")
	g.cast_chant([0])  # W: breaks it
	assert_true(g.anti_broken.has("calm_waters"))
	assert_true(not g.charges.has("calm_waters"), "broken: no charge")
	var h := _fight(["ashling"], ["calm_waters"], "")
	_set_hp(h.enemies[0], "AAAAAAAA")
	h.player.hp = 30
	h.pass_turn()  # no chant at all: it still goes off at the end of the turn
	assert_true(h.lines.any(func(l): return l.contains("Calm Waters takes effect")))


func test_conjure_splits_into_ephemeral_spells_that_merge_back() -> void:
	var f := _fight(["ashling"], ["summoning_word"], "A")  # Summoning Word: A, Conjure 1
	_set_hp(f.enemies[0], "AAAAAAAAAAAA")
	f.player.hp = 99
	f.cast_chant([0])
	f.resolve_spell("summoning_word")
	var eph := f.loadout.filter(func(s): return s.get("ephemeral", false))
	assert_eq(eph.size(), 1, "it appears right away")
	assert_true(f.conjuring.has("summoning_word"), "the conjuring spell turned into it")
	assert_true(not f.shown_spells().any(func(s): return s.id == "summoning_word"), "and is gone from the row")
	var sp: Dictionary = eph[0]
	assert_eq(sp.expires_turn, f.turn + 1, "it lasts until the end of next turn")
	# casting it (the last of its group) merges it back into Summoning Word
	f.charges[sp.id] = 1
	f.resolve_spell(sp.id, 0)
	assert_true(not f.loadout.any(func(s): return s.id == sp.id), "gone once cast")
	assert_true(not f.conjuring.has("summoning_word"), "and Summoning Word is back")
	assert_true(f.shown_spells().any(func(s): return s.id == "summoning_word"))
	# uncast ones expire at the end of the NEXT turn
	var g := _fight(["ashling"], ["summoning_word"], "A")
	_set_hp(g.enemies[0], "AAAAAAAAAAAA")
	g.player.hp = 99
	g.cast_chant([0])
	g.resolve_spell("summoning_word")
	g.finish_turn()  # end of this turn: still here
	assert_eq(g.loadout.filter(func(s): return s.get("ephemeral", false)).size(), 1, "survives the first turn's end")
	g.pass_turn()  # end of the next turn: it expires and merges back
	assert_eq(g.loadout.filter(func(s): return s.get("ephemeral", false)).size(), 0, "expired")
	assert_true(not g.conjuring.has("summoning_word"))


func test_seed_of_life_restores_the_fight_start_and_breaks() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.gain_artifact("seed_of_life")
	run.player.hp = 33.0
	run.player.bottles = ["fire_flask"]
	var f := run.make_fight(["ashling"])
	f.player.hp = 0.0
	f.player.bottles.clear()
	assert_true(run.can_revive())
	run.revive()
	assert_eq(run.player.hp, 33.0, "HP as it was going in")
	assert_eq(run.player.bottles, ["fire_flask"], "bottles as they were")
	assert_true("broken_seed_of_life" in run.artifacts and not ("seed_of_life" in run.artifacts))
	assert_true(not run.can_revive(), "only once")
	assert_true(run.shop_stock().any(func(it): return it.kind == "mend_seed" and it.price == 100))
	run.mend_seed()
	assert_true("seed_of_life" in run.artifacts)


func test_fusing_keeps_wax_seals_in_place() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.learn_spell("inferno")  # F?F
	run.seal_spell("water_wall", 1)  # W[W]
	var prev := run.fuse_preview("water_wall", "inferno")
	assert_eq(prev.pattern, "WF?F", "the sealed W is still not needed")
	assert_eq(prev.full_pattern, "WWF?F")
	assert_eq(prev.seals, [1], "the seal stays on the second W")
	var shot := run.fuse_preview("water_wall", "inferno", 0)  # shoot the first W
	assert_eq(shot.full_pattern, "WF?F")
	assert_eq(shot.seals, [0], "the seal slides left with its Essence")
	assert_eq(shot.pattern, "F?F")
	run.fuse_commit(shot, "water_wall", "inferno")
	var s := run.spell(shot.id)
	assert_eq(s.pattern, "F?F")
	assert_eq(s.full_pattern, "WF?F")
	assert_eq(s.seals, [0])


func test_saved_run_comes_back_the_same() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 9)
	run.learn_spell("inferno")
	run.seal_spell("water_wall", 1)
	run.gain_artifact("echo_shell")
	run.player.hp = 33.0
	run.player.bottles = ["fire_flask"]
	run.amber = 77
	run.move_to(run.map[0].find_custom(func(n): return n != null))
	var text := var_to_str(run.to_save())  # what goes in the file
	var back := RunState.from_save(str_to_var(text), db)
	assert_eq(back.spellbook, run.spellbook)
	assert_eq(back.seals, run.seals)
	assert_eq(back.artifacts, run.artifacts)
	assert_eq(back.player.hp, 33.0)
	assert_eq(back.player.bottles, ["fire_flask"])
	assert_eq(back.amber, 77)
	assert_eq(back.row, run.row)
	assert_eq(back.col, run.col)
	assert_true(back.map == run.map, "the same map")
	assert_eq(back.rng.randi(), run.rng.randi(), "the dice pick up where they left off")


func test_fused_anti_spell_breaks_on_either_pattern() -> void:
	var run := RunState.new()
	run.setup(db, ["fog_of_war", "heat_haze"], [], 4)
	run.learn_spell("fog_of_war")  # FW
	run.learn_spell("heat_haze")  # FA
	assert_true(not run.can_fuse_pair("fog_of_war", "fire_ball"), "an anti-spell can't fuse with a spell")
	assert_true(run.can_fuse_pair("fog_of_war", "heat_haze"))
	var fz := run.fuse_preview("fog_of_war", "heat_haze", 0)
	assert_true(fz.get("anti", false))
	assert_eq(fz.patterns, ["FW", "FA"], "both patterns kept whole (nothing shot out)")
	assert_eq(fz.effects.size(), 2, "both spells' effects")
	var f := _fight(["ashling"], [], "")
	f.loadout = [fz]
	assert_eq(f._occ(fz, "AFA"), [0], "the second pattern alone breaks it")
	assert_eq(f._occ(fz, "WFW"), [0], "the first pattern alone breaks it")
	assert_eq(f._occ(fz, "AAWW"), [], "neither: it stays whole")


func test_undo_restores_the_fight_before_a_spell() -> void:
	var f := _fight(["ashling", "gale_sprite"], ["fire_ball", "water_wall"], "FFWW")
	_set_hp(f.enemies[0], "FWAF")
	_set_hp(f.enemies[1], "W")
	f.cast_chant(_all(4))
	var hp0: String = f.enemies[0].hp_text()
	var snap := f.snapshot()
	f.resolve_spell("fire_ball", 1)  # kills the Gale Sprite (its only Essence)
	f.resolve_spell("water_wall")
	assert_eq(f.enemies.size(), 1, "the Gale Sprite is gone")
	assert_eq(f.player.shield, 4.0)
	f.restore(snap)
	assert_eq(f.enemies.size(), 2, "undo brings it back")
	assert_eq(f.enemies[1].hp_text(), "W")
	assert_eq(f.enemies[0].hp_text(), hp0)
	assert_eq(f.player.shield, 0.0, "and the Shield is gone again")
	assert_eq(f.charges.get("fire_ball", 0), 1, "the spell is awake again")
	assert_eq(f.charges.get("water_wall", 0), 1)


func test_fusion_drips_resin_heated_into_seals() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	var ids: Array = run.fusable()
	assert_true(ids.size() >= 2, "the starters can be fused")
	var fz := run.fuse_preview(ids[0], ids[1])
	assert_eq(fz.pattern, run.spell(ids[0]).pattern + run.spell(ids[1]).pattern, "the whole of both patterns")
	run.fuse_commit(fz, ids[0], ids[1])
	assert_eq(run.resin, 1, "one piece of purple resin per fusion")
	assert_true(not run.use_purple_seal(fz.id, 0), "resin can't seal anything until it's heated")
	assert_eq(run.heat_resin(), 1, "the campfire heats it")
	assert_eq(run.resin, 0)
	assert_eq(run.purple_seals, 1, "it's a purple seal now")
	var n: int = String(run.spell(fz.id).pattern).length()
	assert_true(run.use_purple_seal(fz.id, 0), "the seal is applied")
	assert_eq(run.purple_seals, 0, "and used up")
	assert_eq(String(run.spell(fz.id).pattern).length(), n - 1, "one Essence less to chant")
	run.resin = 2
	run.purple_seals = 1
	var back := RunState.from_save(JSON.parse_string(JSON.stringify(run.to_save())), db)
	assert_eq(int(back.resin), 2, "resin is saved with the run")
	assert_eq(int(back.purple_seals), 1, "so are held seals")
