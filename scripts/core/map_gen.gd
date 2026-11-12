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
	return _least_clumped(func() -> Array: return _generate_once(rng), false)


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
	_unclump(rows, false)
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
			n.type = _roll_from(rng, _spread(rows, f, n.col, WEIGHTS, banned, false), banned)


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


# ------------------------------------------------------------------ the Curtain map (a setting: Ship of Fools style)
## Ship of Fools' map turned on its side: flat-topped hexagons in C_LANES lanes side by side, the middle lane the
## longest (C_LONG tiles), each lane out one tile shorter (12, 11, 10, 9): a long hexagon, the boss above its top tip.
## The map is kept by LEVEL: tiles on lanes next to each other sit half a tile apart, so a level is half a tile high
## and a lane only has a tile on every other level. rows[level] holds that level's tiles, left to right; each tile
## keeps its "lane" and "x" (its lane, 0 = the middle). The boss is alone on the last level.
## Each move goes forward to a tile that touches yours: straight up (2 levels) or up-left / up-right (1 level). The
## tiles at or below your level are behind you for good.
## The Curtain closes in from the boss's side: every CURTAIN_EVERY moves it swallows one more level from the top
## (RunState.curtain_from). When it reaches a tile you could go to, you may go to the boss instead; when it covers all
## of them, the boss is the only way on. So the slower you climb (more steps sideways), the more rooms you see; the
## Curtain decides how many (tools/curtain_sim.gd measures it).
const C_LANES := 7
const C_LONG := 12
const CURTAIN_EVERY := 2
## Placed first, on every map: [type, [lowest level, highest level] for each one]. Campfires (a real campfire: rest or
## cook in full, not An Abandoned Camp, which is an event of its own): one in each third of the
## map; merchants: one in each half; treasure (a free artifact, as in a treasure room) and tailwinds (a free move: no room,
## and the Curtain doesn't count it) anywhere past the start. Plus one pair of portals (see _place_portals).
const C_SURE := [["rest", [[4, 8], [10, 14], [16, 20]]], ["shop", [[3, 10], [12, 19]]], ["treasure", [[5, 12], [12, 19]]],
	["wind", [[2, 7], [7, 12], [12, 16], [16, 20]]]]
## Events ("?"): C_EVENTS[0] to C_EVENTS[1] of them on every map, placed (not rolled), never two touching, so they break
## up the fights. Everything left after them is rolled: mostly fights; a kind in C_SPECIAL never touches another of its
## kind, and none comes too early. (Events are not rolled, and fights are not switched to events to break up a big group
## of fights as on the classic map: the map wants its fights, so a group of more than CLUMP_MAX fights can happen here.)
const C_EVENTS := [10, 12]
const C_WEIGHTS := {"fight": 80.0, "elite": 11.0, "shop": 2.0, "rest": 3.0}
const C_FROM_LEVEL := {"elite": 5, "shop": 3, "rest": 4}
const C_SPECIAL := ["elite", "shop", "rest", "treasure", "portal", "wind"]
const FREE_TILES := ["wind", "portal"]  # (no room on these: see RunState.free_step)


## The level a lane starts on, and how many tiles it has.
static func lane_start(lane: int) -> int:
	return absi(lane - C_LANES / 2)


static func lane_len(lane: int) -> int:
	return C_LONG - absi(lane - C_LANES / 2)


static func generate_curtain(rng: RandomNumberGenerator) -> Array:
	return _least_clumped(func() -> Array: return _curtain_once(rng), true)


static func _curtain_once(rng: RandomNumberGenerator) -> Array:
	var top := 2 * (C_LONG - 1)  # (the middle lane's last level)
	var rows := []
	for level in top + 1:
		rows.append([])
	for lane in C_LANES:
		for i in lane_len(lane):
			rows[lane_start(lane) + 2 * i].append({"type": "", "next": [], "lane": lane, "x": float(lane - C_LANES / 2)})
	for level in rows.size():
		rows[level].sort_custom(func(a, b): return a.lane < b.lane)
		for c in rows[level].size():
			rows[level][c].col = c
	rows[0][0].type = "fight"
	_place_portals(rows, rng)
	for sure in C_SURE:
		for span in sure[1]:
			var spots := []
			for level in range(span[0], mini(span[1], top) + 1):
				for n in rows[level]:
					if n.type == "" and not _hex_near(rows, level, n.col, sure[0]):
						spots.append(n)
			if not spots.is_empty():
				spots[rng.randi() % spots.size()].type = sure[0]
	var events := rng.randi_range(C_EVENTS[0], C_EVENTS[1])
	for k in events:
		var spots := []
		for level in range(1, top + 1):
			for n in rows[level]:
				if n.type == "" and not _hex_near(rows, level, n.col, "event"):
					spots.append(n)
		if spots.is_empty():
			break
		spots[rng.randi() % spots.size()].type = "event"
	for level in rows.size():
		for n in rows[level]:
			if n.type != "":
				continue
			var banned := {}
			for k in C_FROM_LEVEL:
				if level < C_FROM_LEVEL[k]:
					banned[k] = true
			for t in C_SPECIAL:
				if _hex_near(rows, level, n.col, t):
					banned[t] = true
			n.type = _roll_from(rng, _spread(rows, level, n.col, C_WEIGHTS, banned, true), banned)
	_keep_rest_rules(rows, rng)
	rows.append([{"type": "boss", "next": [], "col": 0, "lane": C_LANES / 2, "x": 0.0}])
	return rows


# ------------------------------------------------------------------ the Curtain map: fights before a rest
## Every path from the start to a campfire or a merchant goes through at least MIN_FIGHTS fights first, and every path
## from one campfire to another goes through at least MIN_FIGHTS fights in between. Mini bosses count as fights.
## Tailwinds and portals are left out of it: a player who uses them to get there sooner may.
const MIN_FIGHTS := 4
const FIGHT_ROOMS := ["fight", "elite"]


## The fewest fights on a walk forward from `from` to each tile, before stepping on it: {Vector2i(level, col): n}
## (`from` counts if it is a fight). Walks through a tailwind or a portal are not counted.
static func _fewest_fights(rows: Array, from: Vector2i) -> Dictionary:
	var best := {from: 0}
	for level in range(from.x, rows.size()):
		for nd in rows[level]:
			var at := Vector2i(level, nd.col)
			if not best.has(at) or nd.type == "boss" or (at != from and nd.type in FREE_TILES):
				continue
			var after: int = best[at] + (1 if nd.type in FIGHT_ROOMS else 0)
			for q in hex_up(rows, level, nd.col):
				if not best.has(q) or after < best[q]:
					best[q] = after
	return best


## The campfires and merchants that break the rules above, as Vector2i(level, col).
static func rest_rule_breaks(rows: Array) -> Array:
	var bad := []
	var from_start := _fewest_fights(rows, Vector2i(0, 0))
	for q in from_start:
		if rows[q.x][q.y].type in ["rest", "shop"] and from_start[q] < MIN_FIGHTS:
			bad.append(q)
	for level in rows.size():
		for nd in rows[level]:
			if nd.type != "rest":
				continue
			var a := Vector2i(level, nd.col)
			var from_a := _fewest_fights(rows, a)
			for q in from_a:
				if q != a and rows[q.x][q.y].type == "rest" and from_a[q] < MIN_FIGHTS and not (q in bad):
					bad.append(q)
	return bad


## A campfire or merchant that breaks the rules moves to the nearest fight (by level) where nothing breaks them any more;
## one more than the map must have (C_SURE) just becomes a fight.
static func _keep_rest_rules(rows: Array, rng: RandomNumberGenerator) -> void:
	for round in 40:
		var bad := rest_rule_breaks(rows)
		if bad.is_empty():
			return
		var p: Vector2i = bad[rng.randi() % bad.size()]
		var kind: String = rows[p.x][p.y].type
		var must := 0
		for sure in C_SURE:
			if sure[0] == kind:
				must = sure[1].size()
		if counts(rows).get(kind, 0) > must:
			rows[p.x][p.y].type = "fight"
			continue
		var spots := []
		for level in range(C_FROM_LEVEL.get(kind, 1), rows.size()):
			for nd in rows[level]:
				if nd.type == "fight" and not _hex_near(rows, level, nd.col, kind):
					spots.append(Vector2i(level, nd.col))
		for i in range(spots.size() - 1, 0, -1):  # (shuffled with the map's own dice, so a seed always makes the same map)
			var j := rng.randi() % (i + 1)
			var keep: Vector2i = spots[i]
			spots[i] = spots[j]
			spots[j] = keep
		spots.sort_custom(func(a: Vector2i, b: Vector2i): return absi(a.x - p.x) < absi(b.x - p.x))
		var moved := false
		for q in spots:
			rows[p.x][p.y].type = "fight"
			rows[q.x][q.y].type = kind
			if rest_rule_breaks(rows).size() < bad.size():
				moved = true
				break
			rows[q.x][q.y].type = "fight"
			rows[p.x][p.y].type = kind
		if not moved:
			return


## One pair of portals, far apart: in opposite quarters of the board (one in the first part of the map near one edge,
## the other in the last part near the other edge; which way round is random). Through one and out of the other, both
## ways: forward past half the map, or back toward the start (the tiles you stood on can't be entered again).
## Each keeps "link": [level, col] of the other.
const PORTAL_EARLY := [3, 8]  # (the levels of the first part of the map ...)
const PORTAL_LATE := [14, 19]  # (... and of the last part)
const PORTAL_LANES := [[0, 1], [5, 6]]  # (the lanes near each edge)


static func _place_portals(rows: Array, rng: RandomNumberGenerator) -> void:
	var flip := rng.randi() % 2
	var ends := []
	for k in 2:
		var span: Array = PORTAL_EARLY if k == 0 else PORTAL_LATE
		var lanes: Array = PORTAL_LANES[(k + flip) % 2]
		var spots := []
		for level in range(span[0], span[1] + 1):
			for lane in lanes:
				var p := at_lane(rows, level, lane)
				if p.x >= 0:
					spots.append(p)
		if spots.is_empty():
			return
		ends.append(spots[rng.randi() % spots.size()])
	var pick: Array = ends
	for k in 2:
		var me: Vector2i = pick[k]
		var other: Vector2i = pick[1 - k]
		rows[me.x][me.y].type = "portal"
		rows[me.x][me.y].link = [other.x, other.y]


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


## The tile on this lane at this level, as Vector2i(level, col) (or (-1, -1): none).
static func at_lane(rows: Array, level: int, lane: int) -> Vector2i:
	if level < 0 or level >= rows.size():
		return Vector2i(-1, -1)
	for n in rows[level]:
		if int(n.get("lane", -1)) == lane and n.type != "boss":
			return Vector2i(level, n.col)
	return Vector2i(-1, -1)


## The tiles you can step forward to from (level, col): up-left and up-right (a level up, the lanes beside) and
## straight up (two levels up, the same lane).
static func hex_up(rows: Array, level: int, col: int) -> Array:
	var lane: int = rows[level][col].lane
	var out := []
	for p in [at_lane(rows, level + 1, lane - 1), at_lane(rows, level + 2, lane), at_lane(rows, level + 1, lane + 1)]:
		if p.x >= 0:
			out.append(p)
	return out


## Is a tile of this type touching (level, col)? (Its six neighbours: the three above and the three below.)
static func _hex_near(rows: Array, level: int, col: int, type: String) -> bool:
	var lane: int = rows[level][col].lane
	for d in [[1, -1], [2, 0], [1, 1], [-1, -1], [-2, 0], [-1, 1]]:
		var p := at_lane(rows, level + d[0], lane + d[1])
		if p.x >= 0 and rows[p.x][p.y].type == type:
			return true
	return false


## The rooms touching (level, col), as Vector2i(level, col): on the Curtain map its six hexagon neighbours; on the classic
## map the rooms linked to it (below and above) and the rooms beside it on its floor. (The boss doesn't count.)
static func touching(rows: Array, level: int, col: int, curtain: bool) -> Array:
	var out := []
	if curtain:
		var lane: int = rows[level][col].lane
		for d in [[1, -1], [2, 0], [1, 1], [-1, -1], [-2, 0], [-1, 1]]:
			var p := at_lane(rows, level + d[0], lane + d[1])
			if p.x >= 0:
				out.append(p)
		return out
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


static func _spread(rows: Array, level: int, col: int, weights: Dictionary, banned: Dictionary, curtain: bool) -> Dictionary:
	var w := weights.duplicate()
	var sizes := {}
	for t in CLUMP_MAX:
		if not w.has(t) or banned.has(t):
			continue
		var size := _group_if(rows, level, col, t, curtain)
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


static func _least_clumped(make: Callable, curtain: bool) -> Array:
	var best: Array = []
	var best_score := 1 << 30
	for i in MAP_TRIES:
		var rows: Array = make.call()
		var score := biggest_group(rows, "fight", curtain) + biggest_group(rows, "event", curtain)
		if curtain:
			score += 1000 * rest_rule_breaks(rows).size()  # (a map that breaks the fights-before-a-rest rules only if no try keeps them)
		if score < best_score:
			best_score = score
			best = rows
	return best


## The size of the biggest group of touching `t` rooms on this map.
static func biggest_group(rows: Array, t: String, curtain: bool) -> int:
	var seen := {}
	var best := 0
	for level in rows.size():
		for col in rows[level].size():
			var nd = rows[level][col]
			if nd == null or nd.type != t or seen.has(Vector2i(level, col)):
				continue
			var g := _group_of(rows, level, col, t, curtain)
			for q in g:
				seen[q] = true
			best = maxi(best, g.size())
	return best


## After the rooms are rolled: a group of fights (or events) still bigger than CLUMP_MAX gets rooms switched to the other
## kind, one at a time (the one touching most of its own kind first), where the switch doesn't make the other kind's group
## too big. The first floor and set rooms (the camp before the boss) are never switched.
static func _unclump(rows: Array, curtain: bool) -> void:
	var other := {"fight": "event", "event": "fight"}
	for round in 200:
		var flipped := false
		for t in CLUMP_MAX:
			for level in rows.size():
				for col in rows[level].size():
					var nd = rows[level][col]
					if nd == null or nd.type != t or level == 0 or nd.get("forced", false):
						continue
					if _group_if(rows, level, col, t, curtain) <= CLUMP_MAX[t]:
						continue
					# this room is in a group that's too big: the best room of that group to switch
					var best := Vector2i(-1, -1)
					var best_k := -1
					for q in _group_of(rows, level, col, t, curtain):
						var qn = rows[q.x][q.y]
						if q.x == 0 or qn.get("forced", false):
							continue
						qn.type = other[t]
						var ok: bool = _group_if(rows, q.x, q.y, other[t], curtain) <= CLUMP_MAX[other[t]]
						qn.type = t
						if not ok:
							continue
						var k := 0
						for r in touching(rows, q.x, q.y, curtain):
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
static func _group_of(rows: Array, level: int, col: int, t: String, curtain: bool) -> Array:
	var seen := {Vector2i(level, col): true}
	var todo := [Vector2i(level, col)]
	var out := []
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		out.append(p)
		for q in touching(rows, p.x, p.y, curtain):
			if not seen.has(q) and rows[q.x][q.y].type == t:
				seen[q] = true
				todo.append(q)
	return out


## How big the group of touching `t` rooms would be if the room at (level, col) were a `t` too.
static func _group_if(rows: Array, level: int, col: int, t: String, curtain: bool) -> int:
	var seen := {Vector2i(level, col): true}
	var todo := [Vector2i(level, col)]
	var size := 0
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		size += 1
		for q in touching(rows, p.x, p.y, curtain):
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
