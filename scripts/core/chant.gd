class_name Chant
extends RefCounted
## Pure chant rules.
## Strike: an enemy loses the longest start (prefix) of its HP that appears unbroken anywhere in the chant.
## Spells: a pattern fires once per non-overlapping occurrence, scanning left to right.


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


## Start indices of non-overlapping occurrences of `pattern` in `chant`, left to right.
static func occurrences(pattern: String, chant: String) -> Array:
	var out := []
	if pattern == "":
		return out
	var i := chant.find(pattern)
	while i >= 0:
		out.append(i)
		i = chant.find(pattern, i + pattern.length())
	return out


## Whether a lock pattern appears unbroken in the chant.
static func breaks_lock(lock: String, chant: String) -> bool:
	return lock != "" and chant.contains(lock)
