extends TestCase
## FuseRules.merge: how two spells' effects melt into one.


func _strike(n: int, from: String, target: String) -> Dictionary:
	return {"op": "strike", "from": from, "n": n, "target": target}


func test_two_strikes_add_up() -> void:
	var out := FuseRules.merge([_strike(1, "right", "target"), _strike(2, "right", "target")])
	assert_eq(out.size(), 1, "one damage effect")
	assert_eq(out[0].op, "strike", "still a strike")
	assert_eq(int(out[0].n), 3, "1 + 2")


func test_less_controlled_aim_wins() -> void:
	var out := FuseRules.merge([_strike(1, "right", "target"), _strike(1, "right", "random")])
	assert_eq(out.size(), 1, "merged")
	assert_eq(out[0].target, "random", "target + random = random")


func test_strike_from_both_sides_goes_random_spot() -> void:
	var out := FuseRules.merge([_strike(1, "right", "target"), _strike(1, "left", "target")])
	assert_eq(out.size(), 1, "merged")
	assert_eq(out[0].op, "random_hit", "left + right = a random spot")


func test_barrage_beats_the_rest() -> void:
	var out := FuseRules.merge([_strike(2, "right", "target"), {"op": "barrage", "n": 3}])
	assert_eq(out.size(), 1, "merged")
	assert_eq(out[0].op, "barrage", "barrage is the least controlled")
	assert_eq(int(out[0].n), 5, "2 + 3")


func test_does_not_change_its_input() -> void:
	var src := [_strike(1, "right", "target"), _strike(2, "right", "target")]
	var before := str(src)
	FuseRules.merge(src)
	assert_eq(str(src), before, "merge leaves the originals alone")


func test_every_spell_pair_sample_merges() -> void:
	var db := SpellDB.load_from("res://data/spells.json")
	var tried := 0
	for a in ["fire_ball", "ember", "droplet", "tide_pool"]:
		for b in ["thorn_dart", "whisper", "updraft", "flare"]:
			var sa := db.get_spell(a)
			var sb := db.get_spell(b)
			if sa.is_empty() or sb.is_empty():
				continue
			var out := FuseRules.merge((sa.effects as Array) + (sb.effects as Array))
			tried += 1
			assert_true(not out.is_empty(), "%s + %s keeps some effect" % [a, b])
	assert_true(tried > 0, "at least one real pair was tried")
