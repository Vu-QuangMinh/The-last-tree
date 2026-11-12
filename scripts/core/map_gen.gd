class_name MapGen
extends RefCounted
## One act's map, generated the way Slay the Spire does it:
##   * a 7-column grid, 12 floors, then the boss;
##   * 6 paths are walked from the bottom up, each step moving to the same column or a neighbouring one, never
##     crossing an existing path; the nodes and links they touch form the map (so paths split and merge);
##   * floor 1 is all fights, floor 6 is all treasure, floor 12 (before the boss) is all "?" rooms that are always An Abandoned Camp
##     (the old campfire room is gone: that event is its replacement);
##   * other rooms are rolled: fight 45%, ? 22%, elite 16%, merchant 5%, with rules:
##     no elites before floor 5, no elite / merchant right after the same kind on a path, and the rooms a node
##     branches into are all different kinds.
## Rows are Arrays of COLS entries: a node Dictionary {type, next: [cols on the next row], col} or null.

const FLOORS := 12
const COLS := 7
const PATHS := 6
const TREASURE_FLOOR := 6
const WEIGHTS := {"fight": 45.0, "event": 22.0, "elite": 16.0, "shop": 5.0}
const NO_REPEAT := ["elite", "shop"]
const CAMP_EVENT := "lost_camp"  # the floor before the boss


static func generate(rng: RandomNumberGenerator) -> Array:
	return _least_clumped(func() -> Array: return _generate_once(rng))


static func _generate_once(rng: RandomNumberGenerator) -> Array:
	var rows := []
	for f in FLOORS:
		var r := []
		r.resize(COLS)
		rows.append(r)
	var first_start := -1
	for p in PATHS:
		var c := rng.randi() % COLS
		if p == 1:
			while c == first_start:  # at least two different starting points
				c = rng.randi() % COLS
		if p == 0:
			first_start = c
		for f in FLOORS:
			if rows[f][c] == null:
				rows[f][c] = {"type": "", "next": [], "col": c}
			if f == FLOORS - 1:
				break
			var nc := clampi(c + rng.randi_range(-1, 1), 0, COLS - 1)
			# never cross a link that already goes the other way between these two columns
			if nc != c and rows[f][nc] != null and c in rows[f][nc].next:
				nc = c
			if not (nc in rows[f][c].next):
				rows[f][c].next.append(nc)
				rows[f][c].next.sort()
			c = nc
	# the boss sits alone above the last floor
	var boss_row := []
	boss_row.resize(COLS)
	boss_row[COLS / 2] = {"type": "boss", "next": [], "col": COLS / 2}
	for n in rows[FLOORS - 1]:
		if n != null:
			n.next = [COLS / 2]
	_assign_types(rows, rng)
	_unclump(rows)
	rows.append(boss_row)
	return rows


static func _parents(rows: Array, f: int, c: int) -> Array:
	var out := []
	if f == 0:
		return out
	for n in rows[f - 1]:
		if n != null and c in n.next:
			out.append(n)
	return out


static func _assign_types(rows: Array, rng: RandomNumberGenerator) -> void:
	for f in rows.size():
		for n in rows[f]:
			if n == null:
				continue
			var floor_no := f + 1
			if floor_no == 1:
				n.type = "fight"
				continue
			if floor_no == TREASURE_FLOOR:
				n.type = "treasure"
				continue
			if floor_no == FLOORS:
				n.type = "event"
				n["event"] = CAMP_EVENT
				n["forced"] = true  # (resolve_unknown keeps this event: no fight / treasure / merchant in its place)
				continue
			var parents := _parents(rows, f, n.col)
			var banned := {}
			for p in parents:
				if p.type in NO_REPEAT:
					banned[p.type] = true
				# siblings (other children of my parents) that already have a type
				for sc in p.next:
					var sib = rows[f][sc]
					if sib != null and sib != n and sib.type != "" and sib.type != "fight":
						banned[sib.type] = true
			if floor_no < 5:
				banned["elite"] = true
			n.type = _roll_from(rng, _spread(rows, f, n.col, WEIGHTS, banned), banned)


static func _roll(rng: RandomNumberGenerator, banned: Dictionary) -> String:
	var total := 0.0
	for t in WEIGHTS:
		if not banned.has(t):
			total += WEIGHTS[t]
	var r := rng.randf() * total
	for t in WEIGHTS:
		if banned.has(t):
			continue
		if r < WEIGHTS[t]:
			return t
		r -= WEIGHTS[t]
	return "fight"


## Columns you can step to on the next row (from the start: every node on floor 1).
static func reachable(rows: Array, floor_idx: int, col: int) -> Array:
	if floor_idx < 0:
		var out := []
		for n in rows[0]:
			if n != null:
				out.append(n.col)
		return out
	return rows[floor_idx][col].next


static func _roll_from(rng: RandomNumberGenerator, weights: Dictionary, banned: Dictionary) -> String:
	var total := 0.0
	for t in weights:
		if not banned.has(t):
			total += weights[t]
	var r := rng.randf() * total
	for t in weights:
		if banned.has(t):
			continue
		if r < weights[t]:
			return t
		r -= weights[t]
	return "fight"


## The rooms touching (level, col), as Vector2i(level, col): the rooms linked to it (below and above) and the rooms
## beside it on its floor. (The boss doesn't count.)
static func touching(rows: Array, level: int, col: int) -> Array:
	var out := []
	for c in [col - 1, col + 1]:
		if c >= 0 and c < rows[level].size() and rows[level][c] != null:
			out.append(Vector2i(level, c))
	if level > 0:
		for c in rows[level - 1].size():
			var nd = rows[level - 1][c]
			if nd != null and col in nd.next:
				out.append(Vector2i(level - 1, c))
	if level + 1 < rows.size():
		for c in rows[level][col].next:
			var nd = rows[level + 1][c]
			if nd != null and nd.type != "boss":
				out.append(Vector2i(level + 1, c))
	return out


## Fights and events spread out: no big clumps. A room that would join a group of touching rooms of its kind is less likely
## the bigger that group would get (each room already in it multiplies the chance by CLUMP_FADE), and never makes a group
## bigger than CLUMP_MAX. Small groups (2-3) still happen. tools/map_clump_check.gd measures it.
const CLUMP_MAX := {"fight": 4, "event": 3}
const CLUMP_FADE := 0.3


static func _spread(rows: Array, level: int, col: int, weights: Dictionary, banned: Dictionary) -> Dictionary:
	var w := weights.duplicate()
	var sizes := {}
	for t in CLUMP_MAX:
		if not w.has(t) or banned.has(t):
			continue
		var size := _group_if(rows, level, col, t)
		sizes[t] = size
		w[t] = 0.0 if size > CLUMP_MAX[t] else w[t] * pow(CLUMP_FADE, size - 1)
	# fights and events only trade places with each other: together they keep their share, so elites, merchants and
	# campfires come up exactly as often as before
	var before := 0.0
	var after := 0.0
	for t in sizes:
		before += weights[t]
		after += w[t]
	if after <= 0.0:  # (both would make too big a group: the one whose group stays smallest)
		for t in sizes:
			w[t] = 1.0 / sizes[t]
			after += w[t]
	for t in sizes:
		w[t] *= before / after
	return w


## A few maps are made and the one whose biggest group of fights / events is smallest is kept (MAP_TRIES).
const MAP_TRIES := 8


static func _least_clumped(make: Callable) -> Array:
	var best: Array = []
	var best_score := 1 << 30
	for i in MAP_TRIES:
		var rows: Array = make.call()
		var score := biggest_group(rows, "fight") + biggest_group(rows, "event")
		if score < best_score:
			best_score = score
			best = rows
	return best


## The size of the biggest group of touching `t` rooms on this map.
static func biggest_group(rows: Array, t: String) -> int:
	var seen := {}
	var best := 0
	for level in rows.size():
		for col in rows[level].size():
			var nd = rows[level][col]
			if nd == null or nd.type != t or seen.has(Vector2i(level, col)):
				continue
			var g := _group_of(rows, level, col, t)
			for q in g:
				seen[q] = true
			best = maxi(best, g.size())
	return best


## After the rooms are rolled: a group of fights (or events) still bigger than CLUMP_MAX gets rooms switched to the other
## kind, one at a time (the one touching most of its own kind first), where the switch doesn't make the other kind's group
## too big. The first floor and set rooms (the camp before the boss) are never switched.
static func _unclump(rows: Array) -> void:
	var other := {"fight": "event", "event": "fight"}
	for rnd in 200:
		var flipped := false
		for t in CLUMP_MAX:
			for level in rows.size():
				for col in rows[level].size():
					var nd = rows[level][col]
					if nd == null or nd.type != t or level == 0 or nd.get("forced", false):
						continue
					if _group_if(rows, level, col, t) <= CLUMP_MAX[t]:
						continue
					# this room is in a group that's too big: the best room of that group to switch
					var best := Vector2i(-1, -1)
					var best_k := -1
					for q in _group_of(rows, level, col, t):
						var qn = rows[q.x][q.y]
						if q.x == 0 or qn.get("forced", false):
							continue
						qn.type = other[t]
						var ok: bool = _group_if(rows, q.x, q.y, other[t]) <= CLUMP_MAX[other[t]]
						qn.type = t
						if not ok:
							continue
						var k := 0
						for r in touching(rows, q.x, q.y):
							if rows[r.x][r.y].type == t:
								k += 1
						if k > best_k:
							best_k = k
							best = q
					if best.x >= 0:
						rows[best.x][best.y].type = other[t]
						flipped = true
		if not flipped:
			return


## The rooms of the group of touching `t` rooms that (level, col) belongs to.
static func _group_of(rows: Array, level: int, col: int, t: String) -> Array:
	var seen := {Vector2i(level, col): true}
	var todo := [Vector2i(level, col)]
	var out := []
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		out.append(p)
		for q in touching(rows, p.x, p.y):
			if not seen.has(q) and rows[q.x][q.y].type == t:
				seen[q] = true
				todo.append(q)
	return out


## How big the group of touching `t` rooms would be if the room at (level, col) were a `t` too.
static func _group_if(rows: Array, level: int, col: int, t: String) -> int:
	var seen := {Vector2i(level, col): true}
	var todo := [Vector2i(level, col)]
	var size := 0
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		size += 1
		for q in touching(rows, p.x, p.y):
			if not seen.has(q) and rows[q.x][q.y].type == t:
				seen[q] = true
				todo.append(q)
	return size


## How many rooms of each kind this map has (for the legend).
static func counts(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		for n in r:
			if n != null:
				out[n.type] = out.get(n.type, 0) + 1
	return out
