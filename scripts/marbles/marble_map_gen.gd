class_name MarbleMapGen
extends RefCounted
## Marble mode (2026-11-21): the classic map, as the main game has it: PATHS paths up a COLS-column grid, FLOORS floors,
## the boss on top. Floor 1 fights, floor TREASURE_FLOOR treasure, the last floor a campfire; the rest rolled from
## WEIGHTS (no mini boss before floor 5, no campfire before floor 6 nor on the floor before the last, no mini boss /
## shop / campfire twice in a row on a path, the rooms a node branches into all different).
## Rows are Arrays of COLS entries: a node {type, next: [cols on the next row], col} or null; the boss row is last.

const FLOORS := 12
const COLS := 7
const PATHS := 6
const TREASURE_FLOOR := 6
const WEIGHTS := {"fight": 55.0, "elite": 16.0, "rest": 12.0, "shop": 7.0}
const NO_REPEAT := ["elite", "shop", "rest"]


static func make(rng: RandomNumberGenerator) -> Array:
	var rows := []
	for f in FLOORS:
		var r := []
		r.resize(COLS)
		rows.append(r)
	var first_start := -1
	for p in PATHS:
		var c := rng.randi() % COLS
		if p == 1:
			while c == first_start:
				c = rng.randi() % COLS
		if p == 0:
			first_start = c
		for f in FLOORS:
			if rows[f][c] == null:
				rows[f][c] = {"type": "", "next": [], "col": c}
			if f == FLOORS - 1:
				break
			var nc := clampi(c + rng.randi_range(-1, 1), 0, COLS - 1)
			if nc != c and rows[f][nc] != null and c in rows[f][nc].next:
				nc = c
			if not (nc in rows[f][c].next):
				rows[f][c].next.append(nc)
				rows[f][c].next.sort()
			c = nc
	var boss_row := []
	boss_row.resize(COLS)
	boss_row[COLS / 2] = {"type": "boss", "next": [], "col": COLS / 2}
	for n in rows[FLOORS - 1]:
		if n != null:
			n.next = [COLS / 2]
	for f in rows.size():
		for n in rows[f]:
			if n == null:
				continue
			var floor_no := f + 1
			if floor_no == 1:
				n.type = "fight"
			elif floor_no == TREASURE_FLOOR:
				n.type = "treasure"
			elif floor_no == FLOORS:
				n.type = "rest"
			else:
				var banned := {}
				for par in _parents(rows, f, n.col):
					if par.type in NO_REPEAT:
						banned[par.type] = true
					for sc in par.next:
						var sib = rows[f][sc]
						if sib != null and sib != n and sib.type != "" and sib.type != "fight":
							banned[sib.type] = true
				if floor_no < 5:
					banned["elite"] = true
				if floor_no < 6:
					banned["rest"] = true
				if floor_no == FLOORS - 1:
					banned["rest"] = true
				n.type = _roll_from(rng, WEIGHTS, banned)
	rows.append(boss_row)
	return rows


## The columns you can go to next from (floor, col) (floor -1: the start, any room of the first floor).
static func reachable(rows: Array, floor_idx: int, col: int) -> Array:
	if floor_idx < 0:
		var out := []
		for n in rows[0]:
			if n != null:
				out.append(n.col)
		return out
	return rows[floor_idx][col].next


## The fight pool of a floor: easy, medium, hard as you climb.
static func tier(floor_i: int) -> int:
	return 0 if floor_i < 4 else (1 if floor_i < 8 else 2)


static func _parents(rows: Array, f: int, c: int) -> Array:
	var out := []
	if f == 0:
		return out
	for n in rows[f - 1]:
		if n != null and c in n.next:
			out.append(n)
	return out


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
