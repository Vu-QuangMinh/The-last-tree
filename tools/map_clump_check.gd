extends SceneTree
## How evenly fights and events are spread on generated maps: for N maps of each style, the size of the biggest group
## of touching fights / events, and how often a group of 4+ (fights) or 3+ (events) appears. Also the mix of room types.
## Usage: godot --headless --path . -s tools/map_clump_check.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	for curtain in [false, true]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		var n := 400
		var biggest := {"fight": 0.0, "event": 0.0}
		var big := {"fight": 0, "event": 0}
		var worst := {"fight": 0, "event": 0}
		var mix := {}
		var total := 0
		for i in n:
			var rows: Array = MapGen.generate_curtain(rng) if curtain else MapGen.generate(rng)
			for r in rows:
				for nd in r:
					if nd != null and nd.type != "boss":
						mix[nd.type] = mix.get(nd.type, 0) + 1
						total += 1
			for t in ["fight", "event"]:
				var m := _biggest(rows, t, curtain)
				biggest[t] += m
				worst[t] = maxi(worst[t], m)
				if m >= (4 if t == "fight" else 3):
					big[t] += 1
		print("%s map, %d maps:" % ["Curtain" if curtain else "Classic", n])
		for t in ["fight", "event"]:
			print("  %s: biggest group avg %.2f, worst %d, maps with a group of %d+: %d%%" % [t, biggest[t] / n, worst[t], 4 if t == "fight" else 3, roundi(100.0 * big[t] / n)])
		var parts := []
		for k in mix:
			parts.append("%s %d%%" % [k, roundi(100.0 * mix[k] / total)])
		print("  mix: ", ", ".join(parts))
	quit()


func _biggest(rows: Array, t: String, curtain: bool) -> int:
	var seen := {}
	var best := 0
	for level in rows.size():
		for col in rows[level].size():
			var nd = rows[level][col]
			if nd == null or nd.type != t or seen.has(Vector2i(level, col)):
				continue
			var size := 0
			var todo := [Vector2i(level, col)]
			seen[Vector2i(level, col)] = true
			while not todo.is_empty():
				var p: Vector2i = todo.pop_back()
				size += 1
				for q in MapGen.touching(rows, p.x, p.y, curtain):
					if not seen.has(q) and rows[q.x][q.y].type == t:
						seen[q] = true
						todo.append(q)
			best = maxi(best, size)
	return best
