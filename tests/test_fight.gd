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


func test_burn_takes_rightmost_once_then_is_gone() -> void:
	var f := _fight(["ashling"], [], "")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "FWAWFAAW")
	assert_eq(e.ignite(2, f.rng), 2)
	assert_eq(e.burn, 2)
	f.player.hp = 99
	f.pass_turn()  # its turn: the fire takes the rightmost A W, then the Burn is gone
	assert_eq(e.hp_text(), "FWAWFA")
	assert_eq(e.burn, 0)
	f.pass_turn()
	assert_eq(e.hp_text(), "FWAWFA", "nothing more burns")


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
	assert_eq(run.make_fight(["ashling"]).player.lasting, 4.0)
	run.upgrade_artifact("rain_chalice")
	assert_eq(run.make_fight(["ashling"]).player.lasting, 6.0, "Rain Chalice+ gives 6 Lasting Shield")
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


func test_act1_enemies_keep_their_designed_essence() -> void:
	var f := _fight(["yeti", "tomato_knight", "ashling"], [], "")
	assert_eq(f.enemies.map(func(e): return e.size()), [12, 15, 3], "exactly the HP of the roster, no extra Essence")


func test_bramble_back_thorns_prick_your_release() -> void:
	var f := _fight(["bramble_back"], [], "FA")
	f.player.shield = 99.0  # (its attack on the enemy turn is blocked: only the thorns get through)
	var hp0 := f.player.hp
	f.cast(_all(2))
	assert_eq(f.player.hp, hp0 - 2.0, "Thorns 2: hitting it with the Release costs 2 HP")


func test_cinder_hound_is_fireproof() -> void:
	var f := _fight(["cinder_hound"], [], "")
	f.enemies[0].ignite(3)
	assert_eq(f.enemies[0].burn, 0)


func test_winged_tortoise_armours_the_next_essence() -> void:
	var f := _fight(["winged_tortoise"], [], "")
	var e: EnemyState = f.enemies[0]
	f._do_move(e, {"kind": "armor", "pos": -1})
	f._do_move(e, {"kind": "armor", "pos": -1})
	assert_eq(e.armor.slice(0, 3), [true, true, false], "one more Essence behind the shell each time")


func test_giant_slime_bursts_into_two_different_slimes() -> void:
	var f := _fight(["giant_slime"], [], "F")
	_set_hp(f.enemies[0], "F")
	f.cast(_all(1))
	var ids: Array = f.enemies.map(func(e): return e.id)
	assert_eq(ids.size(), 2)
	assert_true(ids[0] != ids[1] and ids.all(func(id): return id.ends_with("_slime")), str(ids))
	assert_eq(f.enemies[0].size(), 5)


func test_tomato_knight_drops_its_shield_at_half() -> void:
	var f := _fight(["tomato_knight"], [], "FFWFFAFF")
	var e: EnemyState = f.enemies[0]
	e.set_armor(14)
	f.cast(_all(8))  # 15 -> 7 Essence: half or less
	assert_eq(e.size(), 7)
	assert_eq(e.phase, 2)
	assert_true(not e.armor.has(true), "the shield is gone")
	assert_eq(e.intent.kind, "attack")
	assert_eq(e.intent.get("hits", 1), 2, "it attacks twice from now on")


func test_rolling_bear_gains_power_every_turn() -> void:
	var f := _fight(["rolling_bear"], [], "")
	f.player.hp = 999
	f.end_player_turn()
	f.end_player_turn()
	assert_eq(f.enemies[0].dmg_bonus, 4, "+2 after every attack")


func test_act1_encounters_are_fixed_and_never_repeat_the_last_two() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for tier in EnemyDefs.ENCOUNTERS_ACT1:
		for enc in EnemyDefs.ENCOUNTERS_ACT1[tier]:
			for id in enc.ids:
				assert_true(EnemyDefs.E.has(id), id)
	var recent := []
	for i in 40:
		var enc := EnemyDefs.act1_encounter(2.0, rng, recent)
		assert_true(not (enc.name in recent.slice(maxi(0, recent.size() - 2))), "no repeat of the last two")
		recent.append(enc.name)
	var slimes := EnemyDefs.ENCOUNTERS_ACT1[2.5].filter(func(e): return e.name == "The Slime Trio")
	assert_eq(slimes[0].ids, ["purple_slime", "green_slime", "yellow_slime"], "always the same three")


func test_split_makes_a_twin() -> void:
	var f := _fight(["splitter_ooze"], [], "W")
	_set_hp(f.enemies[0], "WWFF")
	f.cast(_all(1))
	assert_eq(f.enemies.size(), 2)
	assert_eq(f.enemies[0].hp_text() + "|" + f.enemies[1].hp_text(), "W|FF")


func test_kindling_stone_burns_on_every_third_spell() -> void:
	var f := _fight(["ashling"], ["water_wall"], "")
	f.artifacts = ["kindling_stone"]
	var e: EnemyState = f.enemies[0]
	f.player.hp = 99
	var burns := []
	for i in 3:
		_set_hp(e, "AAAAAAAAAA")
		e.burn = 0
		f.player.stock.clear()
		for ch in "WW":
			f.player.add_element(ch)
		f.cast_chant(_all(2))
		f.resolve_spell("water_wall")
		burns.append(e.burn)
		f.finish_turn()
	assert_eq(burns, [0, 0, 1], "the 3rd spell cast puts 1 Burn on a random enemy")
	assert_eq(f.player.kindling_chants, 0, "and the count starts over")

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
	var f := _fight(["ashling"], ["sirens_call"], "WAAW")  # (W A, anything, W)
	_set_hp(f.enemies[0], "FWFAF")
	f.cast_chant(_all(4))
	f.resolve_spell("sirens_call", 0)
	assert_eq(f.enemies[0].hp_text(), "WAF", "up to 2 Fire, from the front")
	assert_eq(f.player.stock.filter(func(s): return s.el == "F").size(), 2)


func test_spell_slots_start_at_5_and_cap_at_8() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 3)
	assert_eq(run.active_slots(), 5)
	assert_eq(run.loadout.size(), 3, "Fire Ball, Water Wall, Tailwind")
	assert_true(not ("gust" in run.loadout), "Gust is not a starter")
	for a in ["spell_satchel", "broken_crown", "tangled_grimoire"]:
		run.gain_artifact(a)
	assert_eq(run.active_slots(), 8, "5 + 1 + 1 + 1")
	for a in Artifacts.ALL:
		if a.id in ["spell_satchel", "broken_crown", "tangled_grimoire"]:
			assert_eq(a.tier, "legendary", a.id)
			assert_eq(a.aspect, "Cursed", "%s: a spell slot always comes with a curse" % a.id)


func test_artifact_tiers() -> void:
	for a in Artifacts.ALL:
		assert_true(a.has("tier"), a.id)
		if a.tier == "legendary":
			assert_eq(a.pool, "boss", "%s: legendaries only drop from bosses" % a.id)
		if a.aspect == "Spell slots" or a.id in ["broken_crown", "spell_satchel", "tangled_grimoire"]:
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
	assert_true(not run.can_fuse("fog_of_war") and not run.can_fuse_pair("fog_of_war", "heat_haze"), "anti-spells can't be fused at all")
	assert_true(not ("fog_of_war" in run.fusable()))
	# (an old fused anti-spell, made before that rule, still works)
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


func test_fusion_wax_seals_one_essence_of_the_new_spell() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	var ids: Array = run.fusable()
	assert_true(ids.size() >= 2, "the starters can be fused")
	var fz := run.fuse_preview(ids[0], ids[1])
	assert_eq(fz.pattern, run.spell(ids[0]).pattern + run.spell(ids[1]).pattern, "the whole of both patterns")
	run.fuse_commit(fz, ids[0], ids[1])
	assert_true(fz.id in run.upgradable(), "the new spell can take the fusion's wax")
	var n: int = String(run.spell(fz.id).pattern).length()
	run.seal_spell(fz.id, run.sealable(fz.id)[1])  # the drop lands on its 2nd Essence
	assert_eq(String(run.spell(fz.id).pattern).length(), n - 1, "one Essence less to chant")
	assert_eq(run.spell(fz.id).seals, [1], "shown under a wax seal")
	assert_true(not ("resin" in run), "no purple resin any more")
	var back := RunState.from_save(str_to_var(var_to_str(run.to_save())), db)
	assert_eq(back.spell(fz.id).seals, [1], "the seal is saved with the run")



func test_newcomers_show_their_intent_before_acting() -> void:
	var f := _fight(["giant_slime"], [], "F")
	_set_hp(f.enemies[0], "F")
	f.player.hp = 99
	f.cast(_all(1))  # the Release kills it: two slimes pop out, then it's the enemies' turn
	assert_eq(f.enemies.size(), 2)
	assert_eq(f.player.hp, 99.0, "the new slimes only show their intent this turn")
	assert_true(f.enemies.all(func(e): return e.intent.kind == "attack"), "and that intent is still shown")
	f.end_player_turn()
	assert_eq(f.player.hp, 99.0 - 8.0, "next turn they attack (4 each)")


func test_loadout_drag_and_drop_switches_spells() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 4)
	run.learn_spell("inferno")
	run.learn_spell("tidecaller")
	run.toggle_active("tidecaller")  # (new spells go straight into the row while there's room: put one back)
	var row: Array = run.loadout.duplicate()
	var book: Array = run.spellbook.filter(func(id): return not (id in run.loadout))
	assert_true(run.drop_spell(row[0], true, row[1]))
	assert_eq(run.loadout.slice(0, 2), [row[1], row[0]], "two active spells switch places")
	assert_true(run.drop_spell(book[0], true, row[0]))
	assert_true(book[0] in run.loadout and not (row[0] in run.loadout), "a spellbook spell dropped on an active one takes its place")
	assert_true(run.drop_spell(book[0], false))
	assert_true(not (book[0] in run.loadout), "dragged down into the spellbook: out of the row")
	while run.loadout.size() < run.active_slots() and run.spellbook.any(func(id): return not (id in run.loadout)):
		run.toggle_active(run.spellbook.filter(func(id): return not (id in run.loadout))[0])
	var spare: Array = run.spellbook.filter(func(id): return not (id in run.loadout))
	if not spare.is_empty() and run.loadout.size() == run.active_slots():
		assert_true(not run.drop_spell(spare[0], true), "a full row has no empty space to drop into")


func test_shield_is_gone_next_turn_and_brittle_shrinks_it() -> void:
	var f := _fight(["ashling"], ["water_wall"], "WW")
	f.player.hp = 99
	f.enemies[0].def.moves = [{"kind": "mend", "el": "F", "n": 1, "who": "self"}]  # (it never attacks here)
	f.enemies[0].move_index = 0
	f._plan(f.enemies[0])
	f.cast_chant(_all(2))
	f.resolve_spell("water_wall")
	assert_eq(f.player.shield, 4.0)
	f.end_player_turn()
	assert_eq(f.player.shield, 0.0, "Shield is gone when your next turn starts")
	f.player.brittle_turns = 2
	assert_eq(f.player.gain_shield(4.0), 3.0, "Brittle: 25% less Shield (rounded down)")


func test_slot_artifacts_bring_their_curses() -> void:
	var run := RunState.new()
	run.setup(db, [], [], 6)
	for id in ["inferno", "tidecaller", "searing_brand", "frost_nova"]:
		run.learn_spell(id)
	var n := run.spellbook.size()
	run.gain_artifact("spell_satchel")
	assert_eq(run.spellbook.size(), n - 2, "the Hungry Satchel eats 2 spells")
	assert_true(run.curse_note.begins_with("It ate"), run.curse_note)
	var hp := run.player.max_hp
	run.gain_artifact("broken_crown")
	assert_eq(run.player.max_hp, hp - 15.0, "the Broken Crown costs 15 max HP")
	var before := {}
	for id in run.spellbook:
		before[id] = String(run.spell(id).pattern).length()
	run.gain_artifact("tangled_grimoire")
	var longer := run.spellbook.filter(func(id): return String(run.spell(id).pattern).length() == before[id] + 1)
	assert_eq(longer.size(), mini(4, run.spellbook.size()), "4 spells need 1 more Essence")
	assert_eq(run.active_slots(), 8)


func test_bramble_matron_walls() -> void:
	var f := _fight(["bramble_matron"], [], "")
	var e: EnemyState = f.enemies[0]
	assert_eq(e.size(), 13, "3 + 7 + 3")
	assert_eq([e.parts.count("L"), e.parts.count(""), e.parts.count("R")], [3, 7, 3])
	assert_eq(e.walls_standing(), 2)
	# rightmost effects take the right end of her row: the right wall, then (once it's down) her own Essence
	e.remove_right(5)
	assert_eq([e.parts.count("L"), e.parts.count(""), e.parts.count("R")], [3, 5, 0])
	assert_eq(e.walls_standing(), 1)
	# a wall down: her next intent is to regrow it (shown first), and on her turn she does
	f._plan(e)
	assert_eq(e.intent, {"kind": "regrow", "side": "R"})
	var bonus := e.dmg_bonus
	f._do_move(e, e.intent)
	assert_eq(e.parts.count("R"), 3, "the right wall grows back")
	# both walls up: she sings (Power +1), or attacks
	f._do_move(e, {"kind": "sing"})
	assert_eq(e.dmg_bonus, bonus + 1)
	assert_eq(e.power, 1)
	assert_true(e.describe_statuses().any(func(t): return t.begins_with("Power 1")), "Power shows as a status")
	# each standing wall attacks
	f.player.hp = 99
	f.player.shield = 0
	e.wall_step = {"L": 1, "R": 1}  # both walls on their 2nd move: 1 damage, 2 hits
	f._wall_turns(e)
	assert_eq(f.player.hp, 99.0 - 4.0 * (1 + e.dmg_bonus), "each wall attacks on its own: 2 walls x 2 hits")
	assert_eq(e.wall_step, {"L": 2, "R": 2})
	# her own Essence gone: she dies and the walls fall with her
	var own := []
	for i in e.size():
		if e.parts[i] == "":
			own.append(i)
	own.reverse()
	for i in own:
		e.pluck(i)
	assert_true(e.is_dead(), "dead with her walls still up")
	f._cleanup()
	assert_true(f.won, "the fight is over")


func test_all_enemy_spells_hit_each_part_of_the_matron() -> void:
	var f := _fight(["bramble_matron"], ["inferno"], "")
	var e: EnemyState = f.enemies[0]
	f._apply({"op": "strike", "from": "right", "n": 1, "target": "all"}, db.get_spell("inferno"), {})
	assert_eq([e.parts.count("L"), e.parts.count(""), e.parts.count("R")], [2, 6, 2], "the left wall, she and the right wall each lose 1")
	f._apply({"op": "random_hit", "n": 1, "target": "all"}, db.get_spell("inferno"), {})
	assert_eq([e.parts.count("L"), e.parts.count(""), e.parts.count("R")], [1, 5, 1], "random hits on every enemy: 1 from each part")


func test_matron_regrows_one_wall_per_turn() -> void:
	var f := _fight(["bramble_matron"], [], "")
	var e: EnemyState = f.enemies[0]
	e.remove_right(3)
	e.remove_left(3)
	assert_eq(e.walls_standing(), 0)
	f._plan(e)
	assert_eq(e.intent, {"kind": "regrow", "side": "L"}, "turn 1: the left wall")
	f._do_move(e, e.intent)
	assert_eq(e.walls_standing(), 1, "only one wall a turn")
	f._plan(e)
	assert_eq(e.intent, {"kind": "regrow", "side": "R"}, "turn 2: the right wall")
	f._do_move(e, e.intent)
	assert_eq(e.walls_standing(), 2)


func test_shield_of_silence_shields_a_silent_turn() -> void:
	var f := _fight(["ashling"], [], "F")
	f.artifacts = ["shield_of_silence"]
	f.enemies[0].def.moves = [{"kind": "attack", "n": 4}]
	f.enemies[0].dmg_bonus = 0
	f._plan(f.enemies[0])
	f.player.hp = 50
	f.pass_turn()
	assert_eq(f.player.hp, 50.0, "passed without chanting: +5 Shield, and it takes the 4")
	assert_eq(f.player.shield, 0.0, "(gone again once your next turn starts)")


func test_echo_chamber_casts_every_spell_twice_after_a_short_chant() -> void:
	var f := _fight(["ashling"], ["water_wall"], "WWF")
	f.artifacts = ["echo_chamber"]
	f.cast_chant(_all(2))  # WW: 2 Essence, short enough
	assert_true(f.player.echo_chamber_on)
	f.resolve_spell("water_wall")
	assert_eq(f.player.shield, 8.0, "Water Wall cast twice: 4 + 4")
	var g := _fight(["ashling"], ["water_wall"], "WWFAW")
	g.artifacts = ["echo_chamber"]
	g.cast_chant(_all(4))  # 4 Essence: too long
	assert_true(not g.player.echo_chamber_on)
	g.resolve_spell("water_wall")
	assert_eq(g.player.shield, 4.0, "once")


func test_echoed_voice_echoes_the_first_spell_each_turn() -> void:
	var f := _fight(["ashling"], ["water_wall", "tailwind"], "WWAA")
	f.player.passives["echo_first"] = 1
	f.cast_chant(_all(4))
	f.resolve_spell("water_wall")
	assert_eq(f.player.shield, 8.0, "the turn's first spell echoes: 4 + 4")
	assert_eq(db.get_spell("echo_chamber").name, "Echoed Voice")
	assert_eq(db.get_spell("echo_chamber").rarity, "legendary")


func test_storm_crown_refunds_an_air_each_chant() -> void:
	var f := _fight(["ashling"], [], "F")
	_set_hp(f.enemies[0], "WWWWWWWWWW")
	f.player.hp = 99
	f.player.passives["refund_air"] = 1
	var before := f.player.stock.size()
	f.cast(_all(1))  # chant the F: after the Release, an Air comes back
	assert_true(f.player.stock.any(func(s): return s.el == "A" and not s.temp), "an Air in the bag")
	assert_eq(db.get_spell("storm_crown").effects[0].key, "refund_air")


func test_the_triplet() -> void:
	assert_true("the_triplet" in EnemyDefs.elites(1), "a mini boss of act 1")
	assert_eq(EnemyDefs.ids_of("the_triplet"), ["triplet_fire", "triplet_water", "triplet_air"])
	assert_true(not ("triplet_fire" in EnemyDefs.elites(1)), "its members never come alone")
	var f := _fight(["triplet_fire", "triplet_water", "triplet_air"], ["water_wall", "tailwind"], "FFWWAA")
	for e in f.enemies:
		assert_eq(e.size(), 5)
	# out of step: on the first turn each one shows a different kind of move
	var kinds := f.enemies.map(func(e): return e.intent.kind)
	assert_eq(kinds, ["ignite_spell", "attack", "armor"])
	var fire: EnemyState = f.enemies[0]
	var water: EnemyState = f.enemies[1]
	var air: EnemyState = f.enemies[2]
	# the water one heals 1 on a hurt one (its own element), never past 5
	var heal: Dictionary = water.def.moves[2]
	f._do_move(water, heal)
	assert_eq([fire.size(), water.size(), air.size()], [5, 5, 5], "nobody hurt: nothing")
	air.pluck(0)
	f._do_move(water, heal)
	assert_eq(air.size(), 5, "the only hurt one gets it")
	assert_eq(air.elements[-1], "A", "of its own element")
	# Power and Armour land on one of the three at random
	var total_power := 0
	var armoured := 0
	for i in 5:
		f._do_move(fire, fire.def.moves[2])
		f._do_move(air, air.def.moves[2])
	for e in f.enemies:
		total_power += e.power
		armoured += e.armor.count(true)
	assert_eq(total_power, 5, "5 Power handed out")
	assert_true(f.enemies.filter(func(e): return e.power > 0).size() >= 2, "spread across them, not always itself")
	assert_eq(armoured, 5, "(5 can always fit: each has 5 Essence)")


func test_an_ignited_spell_burns_you_when_cast() -> void:
	var f := _fight(["triplet_fire"], ["water_wall"], "WW")
	var e: EnemyState = f.enemies[0]
	f._do_move(e, {"kind": "ignite_spell", "turns": 1})
	assert_true(f.player.ignited.has("water_wall"))
	f.player.hp = 50
	f.cast_chant(_all(2))
	f.resolve_spell("water_wall")
	assert_eq(f.player.hp, 45.0, "casting it burns you for 5, Shield or not")
	assert_eq(f.player.shield, 4.0, "the spell still works")


func test_enraged_bear() -> void:
	var f := _fight(["enraged_bear"], ["water_wall", "tailwind"], "WWWW")
	var e: EnemyState = f.enemies[0]
	assert_eq(e.size(), 12)
	assert_true("enraged_bear" in EnemyDefs.elites(1))
	# it just attacks
	f.player.hp = 50
	f._do_move(e, e.def.moves[0])
	assert_eq(f.player.hp, 50.0 - 4 - e.dmg_bonus)
	assert_eq(f.player.brittle_turns, 0, "no Brittle")
	# every separate Shield gain: Power +1
	var p0 := e.power
	f._apply({"op": "shield", "n": 4}, db.get_spell("water_wall"), {})
	f._apply({"op": "shield", "n": 3}, db.get_spell("water_wall"), {})
	assert_eq(e.power, p0 + 2, "two separate Shields: Power +2")


func test_attunement_gives_the_picked_essence_every_turn() -> void:
	var f := _fight(["ashling"], ["attunement"], "FWA")
	f.attune_chooser = func(_s): return "W"
	var before := f.player.next_draw.size()
	f.cast_chant(_all(3))
	f.resolve_spell("attunement")
	assert_eq(f.player.passives.get("attune_el", ""), "W", "the one you picked")
	assert_eq(f.player.next_draw.size(), before + 1, "it joins next turn's draw right away")
	assert_eq(f.player.next_draw[-1].el, "W")
	assert_true(SpellText.describe(db.get_spell("attunement")).contains("Gain 1 of that Essence each turn"))


func test_yin_yang_beast() -> void:
	var f := _fight(["yin_yang_beast"], ["fire_ball", "water_wall", "tailwind", "smolder"], "")
	var e: EnemyState = f.enemies[0]
	assert_eq(e.size(), 30)
	assert_eq(e.yin, "white")
	assert_true("yin_yang_beast" in EnemyDefs.BOSSES[1])
	assert_true(not ("gem_king" in EnemyDefs.E) and not ("hollow_stag" in EnemyDefs.E), "removed")
	# 1. Inversion: 3 spells flip, and it turns black
	assert_eq(e.intent.kind, "invert_spells")
	var anti_before := f.loadout.filter(func(s): return s.get("anti", false)).size()
	f._do_move(e, e.intent)
	assert_eq(e.yin, "black")
	var changed := 0
	for k in 4:
		if f.loadout[k].get("anti", false) != db.get_spell(f.loadout[k].id).get("anti", false):
			changed += 1
	assert_eq(changed, 3, "3 spells flipped")
	assert_true(not db.get_spell("fire_ball").get("anti", false), "the spell itself (outside the fight) is untouched")
	# 2. Roar: silences 2 spells, small hit
	f._plan(e)
	assert_eq(e.intent.kind, "silence")
	f.player.hp = 99
	f._do_move(e, e.intent)
	assert_eq(f.player.silenced.size(), 2)
	assert_eq(f.player.hp, 99.0 - 5 - e.dmg_bonus)
	# 3. Charge: 30, and each spell cast changes it (black: anti-spells lower it, spells raise it)
	f._plan(e)
	assert_eq(e.intent.kind, "charge")
	assert_eq(e.charge_dmg, 30)
	f._charge_react({})
	assert_eq(e.charge_dmg, 30, "the other colour (it's black, a spell is white): no change")
	f._charge_react({"anti": true})
	f._charge_react({"anti": true})
	assert_eq(e.charge_dmg, 40, "its own colour: +5 each")
	e.charge_dmg = 5
	f._do_move(e, e.intent)
	f._plan(e)
	assert_eq(e.intent.left, 2)
	f._do_move(e, e.intent)
	f._plan(e)
	assert_eq(e.intent.left, 1)
	f.player.hp = 99
	f.player.shield = 0
	f._do_move(e, e.intent)
	assert_eq(f.player.hp, 99.0 - 5 - e.dmg_bonus, "the hit lands")
	assert_eq(e.charge_dmg, -1)
	f._plan(e)
	assert_eq(e.intent.kind, "invert_spells", "and round again")
	# it dies: two cubs, one white and one black, out of step
	e.elements.clear()
	f._cleanup()
	var cubs := f.alive()
	assert_eq(cubs.size(), 2)
	assert_eq(cubs.map(func(c): return c.yin), ["white", "black"])
	assert_eq(cubs.map(func(c): return c.size()), [10, 10])
	assert_eq(cubs.map(func(c): return c.hp_text()), ["FFWWAAFFWW", "AWFAWFAWFA"], "two different rows")
	assert_eq(Chant.prefix_match(cubs[1].elements, "FFWWAAFFWW"), 1, "a chant for the white one takes just 1 off the black one")
	assert_eq(Chant.prefix_match(cubs[0].elements, "AWFAWFAWFA"), 1, "and the other way round, also just 1")
	assert_eq(cubs.map(func(c): return c.intent.kind), ["invert_spells", "invert_spells"], "both flip first")
	for c in cubs:
		f._plan(c)
	assert_eq(cubs.map(func(c): return c.intent.kind), ["charge", "silence"], "then the white one charges, the black one roars")
	assert_eq(cubs[1].intent.n, 2, "silencing 2 spells")
	assert_eq(cubs[1].intent.also.n, 2, "and hitting for 2")
	for k in 3:
		for c in cubs:
			f._plan(c)
	assert_eq(cubs.map(func(c): return c.intent.kind), ["silence", "charge"], "after the hit they swap")
	assert_true(not f.won)


func test_invoker() -> void:
	var f := _fight(["invoker"], ["fire_ball"], "")
	var e: EnemyState = f.enemies[0]
	assert_eq(e.size(), 20)
	assert_true("invoker" in EnemyDefs.BOSSES[1] and not ("woodcutter" in EnemyDefs.BOSSES[1]), "the Woodcutter is out for now")
	# 3 spells, no repeats
	assert_eq(e.conjured.size(), 3)
	var ids := e.conjured.map(func(s): return s.id)
	assert_true(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	# a chant that contains a pattern sets that spell off; otherwise the closest one
	e.conjured = [EnemyDefs.INVOKER_SPELLS[6].duplicate(true), EnemyDefs.INVOKER_SPELLS[0].duplicate(true), EnemyDefs.INVOKER_SPELLS[3].duplicate(true)]
	for i in 3:
		e.conjured[i].rank = i
		e.conjured[i].base = e.conjured[i].pattern
	assert_eq(f.invoke_picks(e, "FFFWWW"), [0, 1], "Sun Strike and Cold Snap both matched")
	assert_eq(f.invoke_picks(e, "AAF"), [2], "EMP: 2 of its 3 Air chanted, the closest")
	assert_eq(f.invoke_picks(e, ""), [0], "nothing chanted: all equally far, the tie goes to its rank")
	# his turn: Sun Strike hits for 10
	f.heard = "FFF"
	f.player.hp = 50
	f.player.shield = 0
	f._do_move(e, {"kind": "invoke"})
	assert_eq(f.player.hp, 40.0 - e.dmg_bonus)
	# second wind at 0 Essence: 20 more, then he chants a word that strips that Essence from his spells
	e.elements.clear()
	f._cleanup()
	assert_eq(f.alive().size(), 1, "not dead yet")
	assert_eq(e.phase, 2)
	assert_eq(e.size(), 10, "phase 2: 10 Essence")
	f._plan(e)
	assert_true(e.intent.has("word"))
	var w: String = e.intent.word
	f.heard = "Q"
	f._do_move(e, e.intent)
	assert_true(w in e.stripped)
	for sp in e.conjured:
		assert_true(not String(sp.pattern).contains(w), "every %s is gone from %s" % [w, sp.name])


func test_invoker_spell_effects() -> void:
	var f := _fight(["invoker"], ["fire_ball", "water_wall", "tailwind"], "FFWWAA")
	var e: EnemyState = f.enemies[0]
	f.player.hp = 99
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[3].cast)  # EMP
	assert_eq(f.player.stock.size(), 4, "2 Essence drained")
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[9].cast)  # Deafening Blast
	assert_eq(f.player.disarmed_turns, 1)
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[8].cast)  # Chaos Meteor
	assert_eq(f.player.ignited.size(), 3)
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[2].cast)  # Ice Wall
	assert_eq(e.armor.count(true), 3)
	e.burn = 3
	e.poison = 2
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[1].cast)  # Ghost Walk
	assert_eq([e.burn, e.poison], [0, 0])
	f._do_move(e, EnemyDefs.INVOKER_SPELLS[7].cast)  # Forge Spirit
	assert_eq(f.alive().size(), 2)


func test_yin_yang_inversion_prefers_short_to_anti_and_long_to_spell() -> void:
	# short spells (Fire Ball FF, Water Wall WW) turn anti far more often than long ones (Meteor FFFF)
	var short_flips := 0
	var long_flips := 0
	for sd in 60:
		var f := _fight(["yin_yang_beast"], ["fire_ball", "water_wall", "tailwind", "meteor"], "")
		f.rng.seed = sd
		var cands := f.shown_spells()
		var i := f._invert_pick(cands)
		if String(cands[i].pattern).length() >= 4:
			long_flips += 1
		elif String(cands[i].pattern).length() <= 2:
			short_flips += 1
	assert_true(short_flips > long_flips * 3, "short %d vs long %d" % [short_flips, long_flips])
	# a long anti-spell gets turned back into a spell before a short one does
	var g := _fight(["yin_yang_beast"], ["fire_ball", "meteor"], "")
	var pool := [g.shown_spells()[0].duplicate(true), g.shown_spells()[1].duplicate(true)]
	pool[0].anti = true
	pool[1].anti = true
	var back_long := 0
	for sd in 40:
		g.rng.seed = sd
		if g._invert_pick(pool) == 1:
			back_long += 1
	assert_true(back_long > 30, "the long anti-spell goes back first: %d / 40" % back_long)


func test_yin_yang_flips_change_the_pattern() -> void:
	var f := _fight(["yin_yang_beast"], ["meteor"], "")
	var e: EnemyState = f.enemies[0]
	var meteor: Dictionary = f.loadout[0]
	var size0 := e.size()
	# a spell turned anti: the beast absorbs 1 Essence of its pattern
	var anti := f._invert_spell(e, meteor)
	assert_true(anti.anti)
	assert_eq(String(anti.pattern).length(), String(meteor.pattern).length() - 1)
	assert_eq(e.size(), size0 + 1, "the beast took it into its own row")
	# turned back: natural form first, then 1 random Essence more
	var back := f._invert_spell(e, anti)
	assert_true(not back.get("anti", false))
	assert_eq(String(back.pattern).length(), String(meteor.pattern).length() + 1)
	# flipped anti again: from its natural form, minus 1 (not minus 1 from the longer one)
	var again := f._invert_spell(e, back)
	assert_eq(String(again.pattern).length(), String(meteor.pattern).length() - 1)
	# a one-Essence spell gives nothing up
	var one := meteor.duplicate(true)
	one.pattern = "F"
	assert_eq(String(f._invert_spell(e, one).pattern), "F")


func test_poison_spells_have_a_cooldown() -> void:
	for id in ["taint", "miasma", "brine", "frostbite", "blight_wind", "scalding_rain", "steam_vent", "frozen_tomb", "worlds_end"]:
		assert_true(int(db.get_spell(id).get("cooldown", 0)) > 0, id + " has a cooldown")
	assert_eq(db.get_spell("blight_wind").rarity, "legendary")
	assert_true(SpellText.card_text(db.get_spell("taint")).contains("Cooldown 1"))
	# Taint (Cooldown 1): cast this turn, not the next, then again
	var f := _fight(["ashling"], ["taint"], "AAA")
	f.cast_chant(_all(1))
	f.resolve_spell("taint", 0)
	assert_eq(f.enemies[0].poison, 1)
	f.end_player_turn()
	assert_true(f.player.cooldowns.has("taint"), "still cooling down on the next turn")
	assert_true(not f.usable_spells().any(func(sp): return sp.id == "taint"))
	f.end_player_turn()
	assert_true(not f.player.cooldowns.has("taint"), "ready again the turn after")


func test_unused_spells_are_stored_for_the_next_chant() -> void:
	var f := _fight(["ashling"], ["water_wall", "fire_ball"], "WWFF")
	_set_hp(f.enemies[0], "AAWAAWAA")  # (it survives the turn)
	f.enemies[0].def.moves = [{"kind": "mend", "el": "F", "n": 1, "who": "self"}]  # (it never attacks here)
	f.enemies[0].move_index = 0
	f._plan(f.enemies[0])
	f.player.hp = 99
	f.cast_chant(_all(4))
	f.resolve_spell("fire_ball", 0)
	f.finish_turn()  # Released with Water Wall still alive
	assert_true(f.stored.has("water_wall"), "stored")
	assert_true(not f.stored.has("fire_ball"), "(it was cast)")
	# next turn: any chant wakes it (even one without W W), with one charge
	f.player.stock.clear()
	for ch in "AA":
		f.player.add_element(ch)
	f.cast_chant(_all(2))
	assert_eq(f.charges.get("water_wall", 0), 1)
	f.resolve_spell("water_wall")
	assert_eq(f.player.shield, 4.0)
	assert_true(not f.stored.has("water_wall"), "used up once cast")


func test_stored_spell_still_feels_statuses_and_waits_out_a_pass() -> void:
	var f := _fight(["ashling"], ["water_wall"], "WW")
	f.stored["water_wall"] = true
	f.player.silenced["water_wall"] = 1
	f.player.stock.clear()
	f.player.add_element("A")
	f.cast_chant(_all(1))
	assert_eq(f.charges.get("water_wall", 0), 0, "silenced: it can't wake")
	assert_true(f.stored.has("water_wall"), "but it stays stored")


func test_tutorial_saving_a_spell_plays_out() -> void:
	# the "Saving a spell" lesson, step by step: store Water Wall while the Yeti flexes, use it when it attacks
	# (the same data as TutorialScreen.LESSONS[1]: keep them in step)
	var lesson := {"enemies": [{"id": "yeti", "hp": "AFWAFW", "moves": [{"kind": "empower", "n": 2}, {"kind": "attack", "n": 6}]}],
		"spells": ["fire_ball", "water_wall"], "stock": "WWFF", "draws": ["AFW", "AFA"]}
	var f := _fight(["yeti"], lesson.spells, lesson.stock)
	var e: EnemyState = f.enemies[0]
	_set_hp(e, lesson.enemies[0].hp)
	e.def.moves = lesson.enemies[0].moves
	e.def.erase("passives")
	e.move_index = 0
	e.dmg_bonus = 0
	f._plan(e)
	f.player.hp = 60
	f.player.next_draw.clear()
	for ch in lesson.draws[0]:
		f.player.next_draw.append({"el": ch, "temp": false})
	f.script_draws = lesson.draws.slice(1)
	assert_eq(e.intent.kind, "empower", "turn 1: it only flexes")
	f.cast_chant(_all(4))  # W W F F
	f.resolve_spell("fire_ball", 0)
	f.finish_turn()
	assert_true(f.stored.has("water_wall"))
	assert_eq(f.player.hp, 60.0, "no hit on turn 1")
	assert_eq(e.intent.kind, "attack", "turn 2: the attack")
	assert_eq("".join(f.player.stock.map(func(x): return x.el)), "AFW")
	f.cast_chant(_all(3))  # A F W
	f.resolve_spell("water_wall")
	assert_eq(f.player.shield, 4.0)
	f.finish_turn()
	assert_eq(f.player.hp, 56.0, "8 damage, 4 of it blocked")
	f.cast_chant([0, 1])  # A F: finishes it
	f.finish_turn()
	assert_true(f.won, "the lesson ends in a win")


func test_lasting_shield_stays_until_broken() -> void:
	var f := _fight(["ashling"], ["water_wall"], "WW")
	f.enemies[0].def.moves = [{"kind": "attack", "n": 5}]
	f.enemies[0].dmg_bonus = 0
	f._plan(f.enemies[0])
	f.player.hp = 50
	f.player.lasting = 6
	f.cast_chant(_all(2))
	f.resolve_spell("water_wall")  # 4 Shield
	f.finish_turn()  # the 5 hit: 4 from the Shield, 1 from the Lasting Shield
	assert_eq(f.player.hp, 50.0)
	assert_eq(f.player.shield, 0.0, "ordinary Shield gone")
	assert_eq(f.player.lasting, 5.0, "Lasting Shield stays, minus what it blocked")
	assert_eq(f.player.gain_shield(4.0, true), 4.0)
	assert_eq(f.player.lasting, 9.0)


func _knock(f: Fight, e: EnemyState) -> void:
	e.elements.clear()
	f._cleanup()


func test_handyman() -> void:
	var f := _fight(["handyman"], ["fire_ball", "water_wall", "tailwind"], "")
	assert_eq(f.enemies.map(func(e): return e.id), ["hand_sword", "hand_tweezer"], "he starts as two hands")
	assert_true("handyman" in EnemyDefs.BOSSES[1])
	var sword: EnemyState = f.enemies[0]
	assert_eq(sword.size(), 5)
	# a knocked-out hand isn't killed: no win, it skips its turn, and it's back whole next turn
	_knock(f, sword)
	assert_true(not f.over, "not won: the hand is only knocked out")
	assert_true(sword in f.enemies and sword.knocked)
	_knock(f, f.enemies[1])
	assert_true(not f.over, "both down at once still isn't a win")
	f._hands_back()
	assert_eq(sword.size(), 5, "back whole")
	assert_true(not sword.knocked)
	# 4 knockouts: two more hands
	_knock(f, f.enemies[0])
	_knock(f, f.enemies[1])
	assert_eq(f.hm.phase, 2)
	assert_eq(f.enemies.size(), 4)
	var ids := f.enemies.map(func(e): return e.id)
	assert_true("hand_hammer" in ids and "hand_crossbow" in ids)
	f._hands_back()
	# the hammer goes for the most-cast spell, and sticks to it: 3 hits break it
	f.cast_counts = {"water_wall": 3, "fire_ball": 1}
	var hammer: EnemyState = f.enemies.filter(func(e): return e.id == "hand_hammer")[0]
	f._do_move(hammer, {"kind": "hammer_spell"})
	assert_eq(f.hammer_target, "water_wall")
	f.cast_counts["fire_ball"] = 9
	f._do_move(hammer, {"kind": "hammer_spell"})
	assert_eq(f.hammer_target, "water_wall", "it sticks to its target")
	f._do_move(hammer, {"kind": "hammer_spell"})
	assert_true(f.broken.has("water_wall"), "3 hits: broken")
	assert_true(not f.shown_spells().any(func(s): return s.id == "water_wall"), "gone for the fight")
	# a Fleeting spell breaks at once
	f.loadout[0] = f.loadout[0].duplicate(true)
	f.loadout[0].fleeting = true
	f._do_move(hammer, {"kind": "hammer_spell"})
	assert_true(f.broken.has("fire_ball"), "Fleeting: first hit")
	# the crossbow: 2, 1, then it fires (knocked out: it starts over)
	var bow: EnemyState = f.enemies.filter(func(e): return e.id == "hand_crossbow")[0]
	assert_eq(bow.intent.kind, "charge")
	assert_eq(bow.intent.left, 2)
	f._do_move(bow, bow.intent)
	f._plan(bow)
	assert_eq(bow.intent.left, 1)
	_knock(f, bow)
	f._hands_back()
	assert_eq(bow.intent.left, 2, "knocked out: back to 2")
	# 8 more knockouts: the last two hands, 3 Essence each
	for k in 3:
		_knock(f, f.enemies[0])
		_knock(f, f.enemies[1])
		f._hands_back()
	assert_eq(f.hm.phase, 2, "7 so far")
	_knock(f, f.enemies[0])
	f._hands_back()
	assert_eq(f.hm.phase, 3)
	assert_eq(f.enemies.size(), 6)
	var last := f.enemies.filter(func(e): return e.id in ["hand_spear", "hand_shield"])
	assert_eq(last.map(func(e): return e.size()), [3, 3])
	# last stand: a knocked-out hand stays down; with all of them down he shows himself (1 Essence, 999)
	for e in f.enemies.duplicate():
		_knock(f, e)
	f._hands_back()
	assert_eq(f.alive().size(), 1, "only him")
	var body: EnemyState = f.alive()[0]
	assert_eq(body.id, "handyman")
	assert_eq(body.size(), 1)
	assert_eq(body.intent.n, 999)
	assert_true(body.fresh, "he shows his intent first: you get a turn to finish him")
	body.elements.clear()
	f._cleanup()
	assert_true(f.won, "and that's the fight")


func test_ashen_veil_leaves_you_vulnerable() -> void:
	var f := _fight(["ashling"], ["ashen_veil"], "FAA")
	_set_hp(f.enemies[0], "WWWWWW")  # (it survives)
	f.enemies[0].def.moves = [{"kind": "attack", "n": 4}]
	f.enemies[0].dmg_bonus = 0
	f._plan(f.enemies[0])
	f.player.hp = 50
	assert_true(SpellText.card_text(db.get_spell("ashen_veil")).contains("Vulnerable 2"))
	f.cast_chant(_all(3))
	f.resolve_spell("ashen_veil")
	assert_eq(f.player.vulnerable, 2)
	f.finish_turn()  # smoke: the 4 can't touch you
	assert_eq(f.player.hp, 50.0)
	assert_eq(f.player.vulnerable, 1)
	f.pass_turn()  # Vulnerable: 4 -> 6
	assert_eq(f.player.hp, 44.0)
	assert_eq(f.player.vulnerable, 0)
