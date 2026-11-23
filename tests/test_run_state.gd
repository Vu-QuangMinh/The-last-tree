extends TestCase
## RunState: setup, spell offers (rewards), save/load round trip.

var db := SpellDB.load_from("res://data/spells.json")


func _unlocked() -> Array:
	var out := []
	for s in db.all_spells:
		out.append(s.id)
	return out


func _run(seed_v: int) -> RunState:
	var r := RunState.new()
	r.setup(db, _unlocked(), [], seed_v)
	return r


func test_setup_gives_starters_and_the_second_chance() -> void:
	var r := _run(11)
	assert_true(not r.spellbook.is_empty(), "the starters are in the book")
	assert_true("seed_of_life" in r.artifacts, "every run starts with Seed of Life")
	assert_true(r.map.size() > 0, "a map was made")


func test_spell_offer_is_new_and_distinct() -> void:
	for sd in [1, 2, 3, 4, 5]:
		var r := _run(sd)
		var offer := r.spell_offer(3, "fight")
		assert_true(offer.size() > 0 and offer.size() <= 3, "1 to 3 spells offered (seed %d)" % sd)
		var ids := {}
		for s in offer:
			assert_true(not (s.id in r.spellbook), "%s is not already in the book" % s.id)
			assert_true(not s.get("starter", false), "never a starter")
			assert_true(not ids.has(s.id), "no spell twice in one offer")
			ids[s.id] = true


func test_spell_offer_only_from_unlocked() -> void:
	var r := RunState.new()
	r.setup(db, ["ember", "droplet", "whisper"], [], 5)
	for s in r.spell_offer(3, "fight"):
		assert_true(s.id in ["ember", "droplet", "whisper"], "%s was unlocked" % s.id)


func test_same_seed_same_offer() -> void:
	var a := _run(77).spell_offer(3, "fight").map(func(s): return s.id)
	var b := _run(77).spell_offer(3, "fight").map(func(s): return s.id)
	assert_eq(str(a), str(b), "the offer is deterministic for a seed")


func test_save_round_trip_keeps_the_run() -> void:
	var r := _run(21)
	var d := str_to_var(var_to_str(r.to_save())) as Dictionary  # (the format SaveManager.save_run really uses)
	var back := RunState.from_save(d, db)
	assert_eq(str(back.spellbook), str(r.spellbook), "spellbook survives")
	assert_eq(str(back.artifacts), str(r.artifacts), "artifacts survive")
	assert_eq(back.map.size(), r.map.size(), "map survives")
	var next_a := r.spell_offer(3, "fight").map(func(s): return s.id)
	var next_b := back.spell_offer(3, "fight").map(func(s): return s.id)
	assert_eq(str(next_b), str(next_a), "the next offer comes out the same (rng state saved)")
