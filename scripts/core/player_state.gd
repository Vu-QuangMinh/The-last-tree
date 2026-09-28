class_name PlayerState
extends RefCounted
## You: HP persists through the run; everything else resets each fight.
## Stock entries are {el, temp (conjured: vanishes at end of turn), frozen, hexed}.

const BASE_SLOTS := 8
const BASE_DRAW := 3
const START_ELEMENTS := 5

var hp := 50.0
var max_hp := 50.0
# ---- per fight
var shield := 0.0
var aegis := 0
var thorns_turn := 0  # thorns that last until your next turn
var ethereal := false  # this enemy turn: no attack damage, double effect damage
var bleed := 0
var confuse_turns := 0
var blind_turns := 0
var toll := 0  # fewer chant slots on your next turn
var frail_turns := 0  # Frail: you take 25% more attack damage
var dmg_taken_mult := 1.0  # from artifacts (Glass Heart)
var overload := 0
var stock: Array = []
var next_draw: Array = []  # [{el, temp}] shown in "Coming next"
var passives := {}  # key -> n (from Powers and artifacts)
var each_turn: Array = []  # [{spell, effects}]
var silenced := {}  # spell id -> turns
var locks := {}  # spell id -> pattern
var used_powers := {}  # spell id -> true
# ---- per run (artifact counters that carry between fights)
var kindling_chants := 0  # Kindling Stone: chants since it last charged
var kindling_charged := false


func reset_fight() -> void:
	shield = 0.0
	aegis = 0
	thorns_turn = 0
	ethereal = false
	bleed = 0
	confuse_turns = 0
	blind_turns = 0
	toll = 0
	frail_turns = 0
	overload = 0
	stock.clear()
	next_draw.clear()
	passives.clear()
	each_turn.clear()
	silenced.clear()
	locks.clear()
	used_powers.clear()


func passive(key: String) -> int:
	return int(passives.get(key, 0))


func chant_slots() -> int:
	return maxi(3, BASE_SLOTS + passive("chant_slots") - toll)


func add_element(el: String, temp := false) -> void:
	stock.append({"el": el, "temp": temp, "frozen": false, "hexed": false})


func count_usable(el: String) -> int:
	return stock.filter(func(s): return s.el == el and not s.frozen).size()


func heal(x: float) -> float:
	var h := clampf(x, 0.0, max_hp - hp)
	hp += h
	return h


## An enemy attack. Returns HP actually lost.
func take_attack(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if ethereal:
		return 0.0
	x = floorf(x * dmg_taken_mult * (1.25 if frail_turns > 0 else 1.0))
	if aegis > 0:
		aegis -= 1
		return 0.0
	var absorbed := minf(shield, x)
	shield -= absorbed
	x -= absorbed
	hp -= x
	return x


## Damage from effects (bleed, hexes, burning hide, blood price): skips shield, doubled while ethereal.
func take_effect(x: float) -> float:
	if ethereal:
		x *= 2.0
	hp -= x
	return x


func is_dead() -> bool:
	return hp <= 0.0


func describe_statuses() -> Array:
	var out := []
	if shield > 0.0:
		out.append("Shield %d" % shield)
	if aegis > 0:
		out.append("Aegis %d (blocks a whole hit)" % aegis)
	if thorns_turn + passive("thorns") > 0:
		out.append("Thorns %d" % (thorns_turn + passive("thorns")))
	if ethereal:
		out.append("Ethereal (no attack damage, double effect damage)")
	if bleed > 0:
		out.append("Bleed %d" % bleed)
	if confuse_turns > 0:
		out.append("Confused: your chant is read backwards")
	if blind_turns > 0:
		out.append("Blind: some enemy elements are hidden")
	if toll > 0:
		out.append("Toll: %d fewer chant slots" % toll)
	if frail_turns > 0:
		out.append("Frail %d (you take 25%% more damage)" % frail_turns)
	if overload > 0:
		out.append("Overload: %d fewer element next turn" % overload)
	return out
