extends TestCase
## Chant rules and enemy HP operations.


func _enemy(hp: String) -> EnemyState:
	var e := EnemyState.new()
	e.setup({"id": "t", "name": "T", "hp": hp, "moves": [{"kind": "attack", "n": 1}]})
	return e


func _strike(e: EnemyState, chant: String) -> void:
	e.strike_prefix(Chant.prefix_match(e.elements, chant))


func test_user_examples_both_die_to_ffwa() -> void:
	var a := _enemy("FFW")
	var b := _enemy("FWA")
	_strike(a, "FFWA")
	_strike(b, "FFWA")
	assert_true(a.is_dead(), "FFW dies to FFWA")
	assert_true(b.is_dead(), "FWA dies to FFWA")


func test_user_example_fw_chant() -> void:
	var a := _enemy("FFW")
	var b := _enemy("FWA")
	_strike(a, "FW")
	_strike(b, "FW")
	assert_eq(a.hp_text(), "FW", "FFW hit by FW keeps FW")
	assert_eq(b.hp_text(), "A", "FWA hit by FW keeps A")


func test_armour_counts_for_matching_but_stays() -> void:
	var e := _enemy("FFW")
	e.set_armor(1)
	_strike(e, "FFW")
	assert_eq(e.hp_text(), "F", "F (F) W hit by FFW leaves F")


func test_prefix_breaks_at_first_miss() -> void:
	assert_eq(Chant.prefix_match(["W", "F", "F"], "FFW"), 1)
	assert_eq(Chant.prefix_match(["A", "A"], "FFW"), 0)


func test_occurrences_are_non_overlapping() -> void:
	assert_eq(Chant.occurrences("FF", "FFFF"), [0, 2])
	assert_eq(Chant.occurrences("FF", "FFF"), [0])
	assert_eq(Chant.occurrences("AF", "AFWAF"), [0, 3])


func test_burn_takes_the_rightmost_then_is_gone() -> void:
	var e := _enemy("FWAWFAW")
	e.burn = 2
	assert_true(e.is_lit(6) and e.is_lit(5) and not e.is_lit(4), "the 2 rightmost are marked to burn")
	assert_eq(e.burn_off(), ["A", "W"])
	assert_eq(e.burn, 0, "used up")
	assert_eq(e.hp_text(), "FWAWF")


func test_poison_grows_each_turn_and_kills_when_it_catches_up() -> void:
	var e := _enemy("FWAWF")
	e.armor = [true, true, true, true, true]  # (armour doesn't help)
	e.poison = 3
	assert_true(not e.is_dead(), "Poison 3, 5 Essence left")
	e.begin_turn()
	assert_eq(e.poison, 4, "+1 every turn")
	assert_eq(e.hp_text(), "FWAWF", "it doesn't eat Essence")
	assert_true(not e.is_dead())
	e.begin_turn()
	assert_true(e.is_dead(), "Poison 5 = 5 Essence left: it dies")


func test_poison_kills_the_moment_the_essence_drops_to_it() -> void:
	var e := _enemy("FWA")
	e.poison = 2
	assert_true(not e.is_dead())
	e.remove_right(1)  # (a spell or the Release takes one)
	assert_true(e.is_dead(), "Poison 2, 2 Essence left: dead at once")


func test_wildcard_matches_any_element() -> void:
	assert_eq(Chant.occurrences("F?F", "FWFAFFF"), [0, 4])
	assert_eq(Chant.occurrences("F?F", "FF"), [])
	assert_eq(Chant.first_index("A?", "FFAW"), 2)


func test_purge_removes_up_to_n() -> void:
	var e := _enemy("FWFWF")
	e.purge("F", 2)
	assert_eq(e.hp_text(), "WWF")


func test_lock_breaks_on_unbroken_match() -> void:
	assert_true(Chant.breaks_lock("FA", "WFAW"))
	assert_true(not Chant.breaks_lock("FA", "FWA"))


func test_map_follows_the_spire_rules() -> void:
	var rng := RandomNumberGenerator.new()
	for sd in 30:
		rng.seed = sd + 1
		var rows := MapGen.generate(rng)
		assert_eq(rows.size(), MapGen.FLOORS + 1, "12 floors and the boss")
		assert_eq(rows[-1][MapGen.COLS / 2].type, "boss")
		for f in rows.size() - 1:
			var hit := {}
			for n in rows[f]:
				if n == null:
					continue
				assert_true(not n.next.is_empty(), "every room leads somewhere")
				for c in n.next:
					assert_true(rows[f + 1][c] != null, "links go to real rooms")
					hit[c] = true
					# no elite / campfire / merchant twice in a row
					if n.type in MapGen.NO_REPEAT and f + 1 < MapGen.FLOORS:
						assert_true(rows[f + 1][c].type != n.type, "%s twice in a row" % n.type)
				var want := {1: "fight", MapGen.TREASURE_FLOOR: "treasure", MapGen.FLOORS: "rest"}
				if want.has(f + 1):
					assert_eq(n.type, want[f + 1])
				if f + 1 < 5:
					assert_true(not (n.type in ["elite", "rest"]), "no elites or campfires before floor 5")
			for n in rows[f + 1]:
				if n != null:
					assert_true(hit.has(n.col), "every room on floor %d can be reached" % (f + 2))


func test_element_letters_are_coloured() -> void:
	var s := Keywords.colorize("A chant of F F W hits the last A. A spell.")
	assert_true(s.contains("[b]F[/b]") and s.contains("[b]W[/b]"), s)
	assert_true(s.contains("last [color") , "A standing alone is Air: " + s)
	assert_true(s.begins_with("A chant") and s.contains(". A spell"), "the English article stays plain: " + s)
	var t := Keywords.colorize("F W A is in there, written F, W and A for short.")
	assert_eq(t.count("[b]A[/b]"), 2, "an A after another element letter is Air: " + t)


func test_any_essence_in_hp_matches_anything() -> void:
	assert_eq(Chant.prefix_match(["?", "W", "F"], "AW"), 2, "? takes the A, then W")
	assert_eq(Chant.prefix_match(["?", "?"], "F"), 1, "one chant element hits one Any")
	assert_eq(Chant.prefix_match(["F", "?"], "WFA"), 2, "F then Any")
	assert_eq(Chant.find_hp(["?", "W"], "FFWA"), 1, "found where the W follows")

