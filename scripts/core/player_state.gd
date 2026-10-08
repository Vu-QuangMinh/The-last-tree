class_name PlayerState
extends RefCounted
## You: HP persists through the run; everything else resets each fight.
## Stock entries are {el, temp (conjured: vanishes at end of turn), frozen, hexed}.

const UNLIMITED := 1 << 20
const TOLL_CAP := 5  # under a Toll, your next chant holds at most this many Essence
const BASE_DRAW := 3
const START_ELEMENTS := 5

var hp := 50.0
var damage_taken := 0.0  # HP lost this fight (attacks and effects; healing doesn't undo it): 0 = Perfect
var max_hp := 50.0
# ---- per fight
var shield := 0.0
var aegis := 0
var thorns_turn := 0  # thorns that last until your next turn
var ethereal := false  # this enemy turn: no attack damage
var bleed := 0
var confuse_turns := 0
var blind_turns := 0
var toll := 0  # Toll: your next chant holds at most this many Essence (0 = no limit)
var frail_turns := 0  # Frail: you take 25% more attack damage
var brittle_turns := 0  # Brittle: the Shield you gain is 25% smaller
var dmg_taken_mult := 1.0  # from artifacts (Glass Heart)
var overload := 0
var stock: Array = []
var next_draw: Array = []  # [{el, temp}] shown in "Coming next"
var passives := {}  # key -> n (from Powers and artifacts)
var each_turn: Array = []  # [{spell, effects}]
var silenced := {}  # spell id -> turns
var disarmed_turns := 0  # Disarmed (the Invoker's Deafening Blast): your Release does nothing
var ignited := {}  # spell id -> turns: casting it burns you (the Ember Sprite)
var locks := {}  # spell id -> pattern
var used_powers := {}  # spell id -> true
# ---- per run (artifact counters that carry between fights)
var kindling_chants := 0  # Kindling Stone: spells cast since it last set an enemy alight
var kindling_charged := false
var echo_casts := 0  # Echo Shell: spells cast since it last charged
var echo_charged := false
var echo_chamber_on := false  # Echo Chamber: this turn's chant was short, so every spell is cast twice
var bottles: Array = []  # bottle ids you carry (see Bottles)
var echo_next := false  # Echo Draught: your next spell is cast twice (this fight)



## Gain Shield (it stays from turn to turn and builds up until attacks use it up). Brittle makes it 25% smaller.
func gain_shield(n: float) -> float:
	if brittle_turns > 0:
		n = floorf(n * 0.75)
	shield += n
	return n

func reset_fight() -> void:
	damage_taken = 0.0
	shield = 0.0
	aegis = 0
	thorns_turn = 0
	ethereal = false
	bleed = 0
	confuse_turns = 0
	blind_turns = 0
	toll = 0
	frail_turns = 0
	brittle_turns = 0
	echo_chamber_on = false
	overload = 0
	stock.clear()
	next_draw.clear()
	passives.clear()
	each_turn.clear()
	silenced.clear()
	ignited.clear()
	disarmed_turns = 0
	locks.clear()
	used_powers.clear()
	echo_next = false


func passive(key: String) -> int:
	return int(passives.get(key, 0))


## The chant has no length limit (only your bag limits it), except under a Toll: then the next chant holds at
## most TOLL_CAP Essence.
func chant_slots() -> int:
	return toll if toll > 0 else UNLIMITED


## Every element in the stock has its own uid, so the screen can follow one element as the stock changes.
var _next_uid := 0


func add_element(el: String, temp := false) -> void:
	_next_uid += 1
	stock.append({"el": el, "temp": temp, "frozen": false, "hexed": false, "uid": _next_uid})


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
	damage_taken += maxf(0.0, x)
	return x


## Damage from effects (bleed, hexes, burning hide, blood price): skips shield.
func take_effect(x: float) -> float:
	hp -= x
	damage_taken += maxf(0.0, x)
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
		out.append("Ethereal (no attack damage this turn)")
	if bleed > 0:
		out.append("Bleed %d" % bleed)
	if confuse_turns > 0:
		out.append("Confused: your chant is read backwards")
	if blind_turns > 0:
		out.append("Blind: some enemy Essence are hidden")
	if toll > 0:
		out.append("Toll: your next chant holds at most %d Essence" % toll)
	if frail_turns > 0:
		out.append("Frail %d (you take 25%% more damage)" % frail_turns)
	if brittle_turns > 0:
		out.append("Brittle %d (you gain 25%% less Shield)" % brittle_turns)
	if disarmed_turns > 0:
		out.append("Disarmed (your Release does nothing this turn)")
	if overload > 0:
		out.append("Overload: %d fewer Essence next turn" % overload)
	return out
