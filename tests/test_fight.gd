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


func _all(n: int) -> Array:
	return range(n)


func test_chant_strikes_before_spells() -> void:
	# Fire Ball (FF): remove the rightmost element. Chant FF on FFWA: strike takes FF, then the ball takes A.
	var f := _fight(["ashling"], ["fire_ball"], "FF")
	_set_hp(f.enemies[0], "FFWA")
	f.cast(_all(2))
	assert_eq(f.enemies[0].hp_text(), "W")


func test_spell_fires_per_match() -> void:
	var f := _fight(["ashling", "ashling"], ["fire_ball"], "FFWFF")
	_set_hp(f.enemies[0], "AAAAA")
	_set_hp(f.enemies[1], "AAAAA")
	var chosen := []
	f.chooser = func(_s, cands): chosen.append(cands[0]); return cands[0]
	f.cast(_all(5))
	assert_eq(f.preview("FFWFF").spells.get("fire_ball", 0), 2)
	assert_eq(f.enemies[0].size(), 3, "two Fire Balls hit the first enemy")


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


func test_burn_ticks_at_enemy_turn_start() -> void:
	var f := _fight(["ashling"], [], "")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "FWA")
	e.burn = 2
	f.player.hp = 99
	f.pass_turn()
	assert_eq(e.hp_text(), "WA")
	assert_eq(e.burn, 1)


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
		e.burn = 0
		f.player.stock.clear()
		f.player.add_element("F")
		f.cast([0])  # Ember: Burn 1 on the target
		burns.append(e.burn if e.burn > 0 else -1)
	# burn is read after the enemy turn ticked it by 1: normal 1 -> 0, doubled 2 -> 1
	assert_eq(burns, [-1, -1, 1, -1], "3rd chant charges the stone and its Burn is doubled")
	assert_true(not f.player.kindling_charged)
	assert_eq(f.player.kindling_chants, 1)


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
	var f := _fight(["ashling"], ["fire_ball"], "FFFF")
	_set_hp(f.enemies[0], "WWWWWW")
	f.cast_chant(_all(4))
	assert_eq(f.charges.get("fire_ball", 0), 2, "two charges, nothing resolved yet")
	assert_eq(f.enemies[0].size(), 6)
	f.resolve_spell("fire_ball", 0)
	assert_eq(f.enemies[0].size(), 5)
	assert_eq(f.charges.get("fire_ball", 0), 1)
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
	# Soak (WW) exposes the target; with spells first, this turn's chant already gets the bonus
	var f := _fight(["ashling"], ["soak"], "WW")
	var e: EnemyState = f.enemies[0]
	_set_hp(e, "WWAAAAAF")
	f.player.hp = 99
	f.cast_chant(_all(2))
	assert_eq(e.size(), 8, "nothing struck before the spells")
	f.resolve_spell("soak", 0)
	f.finish_turn()
	assert_eq(e.hp_text(), "AAAAA", "WW strikes, and Exposed takes the last one too")


func test_trigger_cap_is_pattern_length() -> void:
	var f := _fight(["ashling"], ["water_wall", "droplet"], "WWWWWW")
	f.cast_chant(_all(6))
	assert_eq(f.charges.get("water_wall", 0), 2, "WW x3 in the chant, but WW triggers at most twice")
	assert_eq(f.charges.get("droplet", 0), 1, "W triggers at most once")


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


func test_upgrade_raises_numbers() -> void:
	var up := SpellDB.upgrade(db.get_spell("fire_ball"))
	assert_eq(up.name, "Fire Ball+")
	assert_eq(up.effects[0].n, 2)


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
