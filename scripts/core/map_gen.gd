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
## A honeycomb of C_ROWS x C_COLS rooms, every tile filled (odd rows sit half a tile to the right), the boss above.
## Each move goes to a tile next to yours: one of the two above, or one beside you on the same row (never back down,
## never to a tile you stood on). The Curtain falls behind you: every CURTAIN_EVERY moves it swallows the lowest row
## still open (RunState.curtain_rows). If it swallows the row you stand on, the only way left is the boss.
## Going up keeps you ahead; every step sideways uses up some of that lead (8 rows, every 2 moves: 6 at most, so 8 to 14
## rooms an act; tools/curtain_sim.gd measures it).
## Row 1 is all fights; 2 merchants, 2 camps (An Abandoned Camp) and 3 elites are placed, a quarter of the rest are "?".
const C_ROWS := 8
const C_COLS := 5
const CURTAIN_EVERY := 2
const C_PLACE := [["shop", 2, 2, 6], ["rest", 2, 3, 7], ["elite", 3, 2, 7]]  # [type, how many, lowest row, highest row]
const C_EVENTS := 0.25


static func generate_curtain(rng: RandomNumberGenerator) -> Array:
	var rows := []
	for f in C_ROWS:
		var r := []
		for c in C_COLS:
			r.append({"type": "fight" if f == 0 else "", "next": [], "col": c})
		rows.append(r)
	for p in C_PLACE:
		var spots := []
		for f in range(p[2], p[3] + 1):
			for c in C_COLS:
				if rows[f][c].type == "" and not _hex_near(rows, f, c, p[0]):
					spots.append(Vector2i(f, c))
		for k in p[1]:
			if spots.is_empty():
				break
			var at: Vector2i = spots.pop_at(rng.randi() % spots.size())
			rows[at.x][at.y].type = p[0]
			spots = spots.filter(func(s: Vector2i): return not _hex_near(rows, s.x, s.y, p[0]))  # (two of a kind never side by side)
	for f in range(1, C_ROWS):
		for n in rows[f]:
			if n.type == "":
				n.type = "event" if rng.randf() < C_EVENTS else "fight"
	var boss_row := []
	boss_row.resize(C_COLS)
	boss_row[C_COLS / 2] = {"type": "boss", "next": [], "col": C_COLS / 2}
	rows.append(boss_row)
	return rows


## The two tiles above (row, col) on the honeycomb (odd rows sit half a tile to the right).
static func hex_up(row: int, col: int, cols: int) -> Array:
	var cand := [col - 1, col] if row % 2 == 0 else [col, col + 1]
	return cand.filter(func(c): return c >= 0 and c < cols)


## Is a tile of this type next to (row, col)?
static func _hex_near(rows: Array, row: int, col: int, type: String) -> bool:
	var near := [Vector2i(row, col - 1), Vector2i(row, col + 1)]
	for c in hex_up(row, col, C_COLS):
		near.append(Vector2i(row + 1, c))
	if row > 0:
		for c in ([col, col + 1] if row % 2 == 1 else [col - 1, col]):  # (the two below)
			near.append(Vector2i(row - 1, c))
	for p in near:
		if p.x >= 0 and p.x < rows.size() and p.y >= 0 and p.y < C_COLS and rows[p.x][p.y] != null and rows[p.x][p.y].type == type:
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
