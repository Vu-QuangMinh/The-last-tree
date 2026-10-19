extends SceneTree
## Fuses every pair of spells that can be fused (with the fusion rules, FuseRules) and flags the fused spells that read
## oddly or too long. Writes a report to user://fuse_audit.txt (and prints the summary).
## Usage: godot --headless --path . --script res://tools/fuse_audit.gd

const LONG_CHARS := 150
const LONG_SENTENCES := 4


func _init() -> void:
	var db := SpellDB.load_from("res://data/spells.json")
	var run := RunState.new()
	run.setup(db, [], [], 4)
	for s in db.all_spells:
		if not (s.id in run.spellbook):
			run.learn_spell(s.id)
	var ids: Array = run.fusable()
	var flags := {}  # flag -> [lines]
	var pairs := 0
	var lens := []
	for i in ids.size():
		for j in ids.size():
			if i == j or not run.can_fuse_pair(ids[i], ids[j]):
				continue
			if j < i:
				continue  # (one order per pair is enough to judge the wording)
			pairs += 1
			var a := run.spell(ids[i])
			var b := run.spell(ids[j])
			var fz := run.fuse_preview(ids[i], ids[j])
			var text := SpellText.card_text(fz)
			var flat := text.replace("\n", " ")
			lens.append(flat.length())
			var line := "%s + %s  ->  %s" % [a.name, b.name, flat]
			for f in _flags(fz, text):
				if not flags.has(f):
					flags[f] = []
				flags[f].append([flat.length(), line])
	lens.sort()
	var out := []
	out.append("%d pairs fused. Text length: median %d, 90th %d, max %d characters." % [pairs, lens[lens.size() / 2], lens[int(lens.size() * 0.9)], lens[-1]])
	for f in flags:
		var rows: Array = flags[f]
		rows.sort_custom(func(x, y): return x[0] > y[0])
		out.append("\n== %s: %d" % [f, rows.size()])
		for r in rows.slice(0, 12):
			out.append("  " + r[1])
	var fa := FileAccess.open("user://fuse_audit.txt", FileAccess.WRITE)
	fa.store_string("\n".join(out))
	fa.close()
	for l in out.slice(0, 1):
		print(l)
	for f in flags:
		print("%s: %d" % [f, flags[f].size()])
	print("report: ", ProjectSettings.globalize_path("user://fuse_audit.txt"))
	quit()


static func _flags(fz: Dictionary, text: String) -> Array:
	var out := []
	var effects: Array = fz.effects
	var lines := text.split("\n")
	var flat := text.replace("\n", " ")
	if flat.length() > LONG_CHARS or lines.size() > LONG_SENTENCES:
		out.append("LONG")
	# the same kind of effect still twice on the same kind of target (one enemy / several / you): it should have merged
	var seen := {}
	for e in effects:
		var scope := "you" if FuseRules._is_self(e) else ("wide" if e.get("target", "") in ["all", "two", "random2"] or e.op in ["barrage", "meteor_rain"] else "one")
		var k: String = e.op + "/" + scope + ("/" + String(e.key) if e.has("key") else "")
		if seen.has(k) and e.op != "passive":
			out.append("REPEAT")
			break
		seen[k] = true
	# "it" / "its" before any enemy has been named
	var named := false
	for ln in lines:
		if ln.contains("an enemy") or ln.contains("a random enemy") or ln.contains("2 ") and ln.contains("enemies"):
			named = true
		if not named and (ln.contains(" it ") or ln.contains(" it.") or ln.contains(" its ") or ln.begins_with("It")):
			out.append("ORPHAN_IT")
			break
	# an Execute after a hit on several enemies: it can finish several (strong: worth a look)
	var wide_hit := false
	for e in effects:
		if e.op in Fight.HIT_OPS and (e.get("target", "") in ["all", "two", "random2"] or e.op == "barrage"):
			wide_hit = true
		if e.op == "execute" and e.get("then", false) and wide_hit:
			out.append("EXEC_WIDE")
			break
	# its damage went random, but a later effect still makes you aim at an enemy
	var lost_aim := false
	for e in effects:
		if e.op == "barrage" or (e.op in ["strike", "random_hit"] and e.get("target", "") == "random"):
			lost_aim = true
		elif lost_aim and e.get("target", "") == "target" and not e.get("then", false):
			out.append("AIM_KEPT")
			break
	# Execute with no damage before it
	var dmg_before := false
	for e in effects:
		if e.op in Fight.HIT_OPS:
			dmg_before = true
		if e.op == "execute" and e.get("then", false) and not dmg_before:
			out.append("EXEC_ALONE")
	# you lose HP and heal in the same spell
	if effects.any(func(e): return e.op == "sacrifice") and effects.any(func(e): return e.op == "heal"):
		out.append("SELF_HURT_HEAL")
	# a cooldown and Durability on the same spell
	if int(fz.get("cooldown", 0)) > 0 and Fight.base_durability(fz) > 0:
		out.append("TWO_LIMITS")
	return out
