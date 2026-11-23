extends RefCounted

var bad := 0


func _fight(cards: Array) -> DiceFight:
	var r := DiceRun.new()
	r.setup(77)
	r.cards = cards
	r.hp = 100
	r.max_hp = 100
	var f := DiceFight.new()
	f.setup(r, ["ashling", "yellow_slime"])
	for x in f.foes:  # (big enough that no check kills it)
		x.max_hp = 100
		x.hp = 100
	return f


func _die(f: DiceFight, v: int) -> int:
	f.rolled.append({"die": -1, "face": -1, "value": v, "paint": "", "carve": "", "used": false, "rerolled": false, "frozen": false, "hidden": false})
	return f.rolled.size() - 1


func _play(f: DiceFight, ci: int, vals: Array, target := 0) -> void:
	for k in vals.size():
		var r := _die(f, int(vals[k]))
		if f.place(r, ci, k):
			f.fire(ci, target)


func _ok(what: String, cond: bool) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		bad += 1


func run(_t: SceneTree) -> void:
	var f := _fight(["fire_starter", "ignite", "fan_the_flames", "punch"])
	_ok("Fan the Flames dimmed with no Burn", not f.has_target(2))
	_play(f, 0, [3])
	_ok("Fire Starter: 3 Burn", f.foes[0].burn == 3)
	_play(f, 0, [2])
	_ok("Fire Starter repeatable: 5 Burn", f.foes[0].burn == 5)
	_ok("Fan the Flames usable now", f.has_target(2) and f.targets_for(2) == [0])
	_play(f, 2, [4])
	_ok("Fan the Flames: 9 Burn", f.foes[0].burn == 9)
	var hp: int = f.foes[0].hp
	_play(f, 1, [6])
	_ok("Ignite: Burn gone, 18 damage", f.foes[0].burn == 0 and hp - f.foes[0].hp == 18)

	f = _fight(["fire_fist", "overwhelm", "smite", "thousand_cuts"])
	_play(f, 0, [1])
	_play(f, 1, [2])
	_play(f, 2, [5])
	hp = f.foes[0].hp
	_play(f, 3, [3])
	_ok("Fire Fist: 3 hits = 3 Burn, Smite: + 1 Burn", f.foes[0].burn == 4)
	_ok("Overwhelm: 3 hits = 6 Shield", f.block == 6)

	f = _fight(["block", "taunt", "grit", "feint"])
	_play(f, 0, [5])
	_play(f, 1, [4])
	_ok("Taunt: Shield gone, enemies Vulnerable 3", f.block == 0 and f.foes[0].vulnerable == 3 and f.foes[1].vulnerable == 3)
	_play(f, 2, [3])
	_ok("Grit under Taunt: -3 HP, no Shield", f.run.hp == 97 and f.block == 0)

	f = _fight(["feint", "grit", "stack", "reroll"])
	_play(f, 1, [2])
	_ok("Grit: -2 HP, 8 Shield", f.run.hp == 98 and f.block == 8)
	_play(f, 0, [6])
	_ok("Feint: 1 Dodge", f.dodge == 1)
	var a := _die(f, 4)
	var b := _die(f, 5)
	f.place(a, 2, 0)
	f.place(b, 2, 1)
	_ok("Stack: one 9 back, the other spent", int(f.rolled[a].value) == 9 and not f.rolled[a].used and f.rolled[b].used)
	var c := _die(f, 3)
	f.place(c, 3, 0)
	_ok("Reroll: the die is back", not f.rolled[c].used and f.tweaks.get(3, 0) == 1)
	f.foes[0].intent = {"kind": "attack", "n": 3}
	f.foes[1].intent = {"kind": "attack", "n": 3}
	f.end_turn()
	_ok("Feint: both attackers Vulnerable", f.foes[0].vulnerable >= 1 and f.foes[1].vulnerable >= 1)

	f = _fight(["flurry", "punch", "hype_up", "smoke_screen"])
	_play(f, 0, [0])
	hp = f.foes[0].hp
	_play(f, 1, [3])
	_ok("Flurry at 0: +2 on a hit (3 + 2)", hp - f.foes[0].hp == 5)
	var h := _die(f, 2)
	f.place(h, 2, 0)
	_ok("Hype Up: 1 use, then spent", f.spent.has(2) and int(f.rolled[h].value) == 3)
	f.foes[0].burn = 2
	f.foes[1].burn = 1
	_play(f, 3, [3], -1)
	_ok("Smoke Screen: 3 x 2 burning = 6 Shield", f.block == 6)
	var up := DiceCards.card("fire_fist", "boost")
	_ok("Fire Fist boost: 2 slots, both MAX 1", int(up.slots) == 2 and not DiceCards.fits_card(up, 2, 1, [1, null]) and DiceCards.fits_card(up, 1, 1, [1, null]))
	f = _fight(["fire_fist", "overwhelm", "punch", "smite"])
	f.foes[0].block = 20
	_play(f, 0, [1])
	_play(f, 1, [2])
	_play(f, 2, [4])
	_ok("A hit on Shield still counts: Fire Fist 1 Burn, Overwhelm 2 Shield", f.foes[0].burn == 1 and f.block == 2)
	f = _fight(["smite", "redirect", "punch", "block"])
	f.foes[0].intent = {"kind": "attack", "n": 4}
	f.foes[1].intent = {"kind": "block", "n": 1}
	f.foes[1].hp = 0  # (alone: its Redirected attack strikes itself)
	_play(f, 0, [5], 0)
	_play(f, 1, [6], 0)
	f.end_turn()
	_ok("A Redirected attack is your hit: Smite gives it Burn", f.foes[0].smite == 0 and f.foes[0].burn >= 4)
	print("NEW MOVES: %d failed" % bad)
