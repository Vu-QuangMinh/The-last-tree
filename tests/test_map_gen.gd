extends TestCase
## MapGen: the Slay-the-Spire style act map.


func _map(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return MapGen.generate(rng)


func test_shape_and_boss() -> void:
	for sd in [1, 2, 3, 7, 42, 99, 12345]:
		var rows := _map(sd)
		assert_eq(rows.size(), MapGen.FLOORS + 1, "12 floors plus the boss row (seed %d)" % sd)
		var boss: Dictionary = rows[MapGen.FLOORS][MapGen.COLS / 2]
		assert_eq(boss.type, "boss", "boss sits in the middle column")
		for r in rows:
			assert_eq(r.size(), MapGen.COLS, "every row has 7 columns")


func test_floor_rules() -> void:
	for sd in [1, 5, 8, 21, 77]:
		var rows := _map(sd)
		for n in rows[0]:
			if n != null:
				assert_eq(n.type, "fight", "floor 1 is all fights (seed %d)" % sd)
		for n in rows[MapGen.TREASURE_FLOOR - 1]:
			if n != null:
				assert_eq(n.type, "treasure", "floor 6 is all treasure (seed %d)" % sd)
		for f in 4:
			for n in rows[f]:
				if n != null:
					assert_true(n.type != "elite", "no elite before floor 5")


func test_every_node_leads_to_the_boss() -> void:
	for sd in [3, 4, 9, 100]:
		var rows := _map(sd)
		var alive := {}  # "floor:col" -> true when the boss can be reached from it
		for c in MapGen.COLS:
			if rows[MapGen.FLOORS][c] != null:
				alive["%d:%d" % [MapGen.FLOORS, c]] = true
		for f in range(MapGen.FLOORS - 1, -1, -1):
			for c in MapGen.COLS:
				var n = rows[f][c]
				if n == null:
					continue
				assert_true(not n.next.is_empty(), "node %d:%d has a way up (seed %d)" % [f, c, sd])
				for nc in n.next:
					assert_true(rows[f + 1][nc] != null, "link %d:%d -> %d points at a node" % [f, c, nc])
					if alive.has("%d:%d" % [f + 1, nc]):
						alive["%d:%d" % [f, c]] = true
				assert_true(alive.has("%d:%d" % [f, c]), "node %d:%d reaches the boss (seed %d)" % [f, c, sd])


func test_same_seed_same_map() -> void:
	assert_eq(str(_map(55)), str(_map(55)), "generation is deterministic")


func test_reachable_from_the_start() -> void:
	var rows := _map(8)
	var start := MapGen.reachable(rows, -1, 0)
	assert_true(start.size() >= 2, "at least two starting points")
	for c in start:
		assert_true(rows[0][c] != null, "each start column holds a node")


func test_counts_add_up() -> void:
	var rows := _map(6)
	var total := 0
	for r in rows:
		for n in r:
			if n != null:
				total += 1
	var sum := 0
	var cnt := MapGen.counts(rows)
	for k in cnt:
		sum += int(cnt[k])
	assert_eq(sum, total, "counts() sees every node")
	assert_eq(int(cnt.get("boss", 0)), 1, "exactly one boss")
