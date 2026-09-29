class_name Chant
extends RefCounted
## Pure chant rules.
## Strike: an enemy loses the longest start (prefix) of its HP that appears unbroken anywhere in the chant.
## Spells: a pattern fires once per non-overlapping occurrence, scanning left to right. A "?" in a spell's
## pattern is a wildcard: any element fills it.


## Length of the longest prefix of `hp` (Array of element letters) that occurs contiguously in `chant`.
## "?" (blinded) elements still match normally: blindness only hides them from the player.
static func prefix_match(hp: Array, chant: String) -> int:
	var best := 0
	for k in range(1, mini(hp.size(), chant.length()) + 1):
		var s := "".join(hp.slice(0, k))
		if chant.contains(s):
			best = k
		else:
			break
	return best


## Start indices of non-overlapping occurrences of `pattern` in `chant`, left to right ("?" matches anything).
static func occurrences(pattern: String, chant: String) -> Array:
	var out := []
	var n := pattern.length()
	if n == 0:
		return out
	var i := 0
	while i + n <= chant.length():
		if matches_at(pattern, chant, i):
			out.append(i)
			i += n
		else:
			i += 1
	return out


static func matches_at(pattern: String, chant: String, at: int) -> bool:
	for k in pattern.length():
		var p := pattern[k]
		if p != "?" and p != chant[at + k]:
			return false
	return true


## Where the pattern first appears in the chant, or -1.
static func first_index(pattern: String, chant: String) -> int:
	var occ := occurrences(pattern, chant)
	return occ[0] if not occ.is_empty() else -1


## Whether a lock pattern appears unbroken in the chant.
static func breaks_lock(lock: String, chant: String) -> bool:
	return lock != "" and chant.contains(lock)
