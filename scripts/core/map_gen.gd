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
			n.type = _roll(rng, banned)


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
## Placed first, on every map: [type, [lowest level, highest level] for each one]. Campfires: one in each third of the
## map; merchants: one in each half; treasure (a free artifact, as in a treasure room) and tailwinds (a free move: no room,
## and the Curtain doesn't count it) anywhere past the start. Plus one pair of portals (see _place_portals).
const C_SURE := [["rest", [[4, 8], [10, 14], [16, 20]]], ["shop", [[3, 10], [12, 19]]], ["treasure", [[5, 12], [12, 19]]],
	["wind", [[2, 7], [7, 12], [12, 16], [16, 20]]]]
## The rest of the rooms are rolled; a kind in C_SPECIAL never touches another of its kind, and none comes too early.
const C_WEIGHTS := {"fight": 52.0, "event": 28.0, "elite": 14.0, "shop": 2.0, "rest": 3.0}
const C_FROM_LEVEL := {"elite": 5, "shop": 3, "rest": 4}
const C_SPECIAL := ["elite", "shop", "rest", "treasure", "portal", "wind"]
const FREE_TILES := ["wind", "portal"]  # (no room on these: see RunState.free_step)


## The level a lane starts on, and how many tiles it has.
static func lane_start(lane: int) -> int:
	return absi(lane - C_LANES / 2)


static func lane_len(lane: int) -> int:
	return C_LONG - absi(lane - C_LANES / 2)


static func generate_curtain(rng: RandomNumberGenerator) -> Array:
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
			n.type = _roll_from(rng, C_WEIGHTS, banned)
	rows.append([{"type": "boss", "next": [], "col": 0, "lane": C_LANES / 2, "x": 0.0}])
	return rows


## One pair of portals on the same level, at the two edges of the map (the whirlpools of Ship of Fools): through one
## and out of the other, to the far side without losing any height. Each keeps "link": [level, col] of the other.
static func _place_portals(rows: Array, rng: RandomNumberGenerator) -> void:
	var pairs := []
	for level in range(6, 17):
		for lanes in [[0, C_LANES - 1], [1, C_LANES - 2]]:
			var a := at_lane(rows, level, lanes[0])
			var b := at_lane(rows, level, lanes[1])
			if a.x >= 0 and b.x >= 0:
				pairs.append([a, b])
	if pairs.is_empty():
		return
	var pick: Array = pairs[rng.randi() % pairs.size()]
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


## How many rooms of each kind this map has (for the legend).
static func counts(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		for n in r:
			if n != null:
				out[n.type] = out.get(n.type, 0) + 1
	return out
