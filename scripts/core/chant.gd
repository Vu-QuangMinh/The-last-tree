class_name Chant
extends RefCounted
## Pure chant rules.
## Strike: an enemy loses the longest start (prefix) of its HP that appears unbroken anywhere in the chant.
## Spells: a pattern fires once per non-overlapping occurrence, scanning left to right. A "?" in a spell's
## pattern is a wildcard: any element fills it.


## Length of the longest prefix of `hp` (Array of element letters) that occurs contiguously in `chant`.
## A "?" in the HP is an Any Essence (painted by Expose): any chant element hits it.
## (Blinded elements are still their real letters: blindness only hides them from the player.)
static func prefix_match(hp: Array, chant: String) -> int:
	var best := 0
	for k in range(1, mini(hp.size(), chant.length()) + 1):
		if find_hp(hp.slice(0, k), chant) >= 0:
			best = k
		else:
			break
	return best


## Where the run of HP elements `seg` first appears in the chant ("?" in it matches anything), or -1.
static func find_hp(seg: Array, chant: String) -> int:
	return first_index("".join(seg), chant) if "?" in seg else chant.find("".join(seg))


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
