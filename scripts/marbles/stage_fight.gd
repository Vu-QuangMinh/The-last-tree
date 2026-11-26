class_name StageFight
extends RefCounted
## Marble mode (2026-11-21): the enemy side of a fight, taken from Die on Stage's fight (the user chose its enemies, "B",
## for every one). The enemies are the main game's puppets (an EnemyState each, for the picture) with HP instead of a
## row of Essence: 3 HP per orb of their row, rounded up to an even number. Their moves (ENEMY_MOVES, _simple_move),
## intents (_plan, intent_text) and what they do (_act); Burn, Power, Weakened, Vulnerable, Stun, Thorns, Silence,
## Ethereal, Hammer, Dodge, Impervious, Expose, Armor; summons, flyers, the Wizard's and the Matron's spells, Charges.
## Your side (marbles, the chant, the cards: _start_turn, _hit and the rest) is MarblesFight's.
## Every change is told to the screen as an event ({type: ...}) in `events`, which it plays and empties.

const HP_MULT := 1  # enemy HP x1 (doubled 2026-11-15; halved back, the user 2026-11-17: too spongy)
const HAMMER_BREAKS := 3  # (Hammer: the card you have used most is hit; this many hits break it for the fight)
const IGNITE_DMG := 5
const MAX_FOES := 5
const PAGE_HP := 15  # (halved with the rest, 2026-11-17) (the Pianist: each page of his score; 10 orbs x 3, not doubled: the music is the clock)
const MATRON_CALLS := ["ashling", "iceling", "zephling", "purple_slime", "green_slime", "yellow_slime"]
## Good Ol' Wizard's ten spells (his first set, git 4c956db), as Die on Stage moves; `cut`: the die number that
## interrupts it.
const WIZARD_SPELLS := [
	{"id": "cold_snap", "name": "Cold Snap", "cut": 2, "text": "Apply 3 Vulnerable to you, and 1 damage to you 3 times.", "cast": {"kind": "vulnerable", "n": 3, "also": {"kind": "attack", "n": 1, "hits": 3}}},
	{"id": "ghost_walk", "name": "Ghost Walk", "cut": 1, "text": "He is Ethereal for 1 turn.", "cast": {"kind": "ethereal"}},
	{"id": "ice_wall", "name": "Ice Wall", "cut": 3, "text": "He gains 9 Block.", "cast": {"kind": "block", "n": 9}},
	{"id": "emp", "name": "EMP", "cut": 4, "text": "3 damage to you, and Silence 1 of your cards.", "cast": {"kind": "attack", "n": 3, "hits": 1, "also": {"kind": "silence", "n": 1, "turns": 1}}},
	{"id": "tornado", "name": "Tornado", "cut": 3, "text": "Freeze 1 of your dice, and 3 damage to you.", "cast": {"kind": "freeze", "also": {"kind": "attack", "n": 3, "hits": 1}}},
	{"id": "alacrity", "name": "Alacrity", "cut": 2, "text": "He and his Forge Spirits gain 2 Power.", "cast": {"kind": "power", "n": 2, "who": "wizard_team"}},
	{"id": "sun_strike", "name": "Sun Strike", "cut": 6, "text": "10 damage to you.", "cast": {"kind": "attack", "n": 10, "hits": 1}},
	{"id": "forge_spirit", "name": "Forge Spirit", "cut": 5, "text": "He summons a Forge Spirit.", "cast": {"kind": "summon", "ids": ["forge_spirit"], "n": 1}},
	{"id": "chaos_meteor", "name": "Chaos Meteor", "cut": 6, "text": "1 damage to you 5 times, and apply 5 Burn to you.", "cast": {"kind": "attack", "n": 1, "hits": 5, "also": {"kind": "burn", "n": 5}}},
	{"id": "deafening_blast", "name": "Deafening Blast", "cut": 5, "text": "5 damage to you, and you are Weakened.", "cast": {"kind": "attack", "n": 5, "hits": 1, "also": {"kind": "weak", "n": 1}}},
]

class Foe:
	var es: EnemyState  # the chant game's enemy: its picture, name and def
	var id := ""
	var hp := 0
	var max_hp := 0
	var block := 0
	var burn := 0
	var stun := 0
	var power := 0
	var weak := 0
	var thorns := 0  # each card that damages it hurts you this much
	var ethereal := 0  # nothing you do can damage it until its next turn
	var impervious := 0  # no status sticks to it until its next turn
	var vulnerable := 0  # it takes 50% more (Jab, Arm Bar)
	var expose := 0  # (the Marbles mode) each hit on it deals this much more; it never goes down
	var armor := 0  # (the Marbles mode) each hit on it deals this much less (Expose's opposite)
	var redirect := false  # (Redirect: its next attack goes at someone else)
	var smite := 0  # (Smite: your next hit on it also gives it that many times its damage in Burn)
	var dodge := 0  # (Dodge: your next hit on it misses, one per point; the Zephling)
	var random_moves := false  # (its move each turn is picked at random, not in turn: ENEMY_MOVES)
	var fly_hits := 0  # (a flyer, FLYERS: hits taken in the air; FLY_HITS of them knock it down)
	var landed := false  # (knocked down: stunned a turn, then it takes off again)
	var deflect := false  # the next card that hits it hurts you instead
	var moves: Array = []
	var moves2: Array = []  # (from half HP)
	var phase := 1
	var move_i := 0
	var intent: Dictionary = {}
	var hedges: Array = []  # (the Bramble Matron: her Briar Hedges; she can't be targeted while one stands)
	var cocoon_card := -1  # (a Silk Cocoon: the card of yours inside it)
	var pages := 0  # (the Pianist: pages of his score still to play after this one)
	var spells: Array = []  # (Good Ol' Wizard: the spells hanging over him now; the Bramble Matron: her summoning)
	var regen := 0  # (the Giant Slime: it heals this much at the start of its turns...)
	var regen_turns := 0  # (... for this many more turns)

	func dead() -> bool:
		return hp <= 0

	func shielded() -> bool:
		return hedges.any(func(h): return not h.dead())

var run: MarblesRun
var foes: Array = []
var block := 0
var weak := 0  # you deal 50% less
var vulnerable := 0  # you take 50% more
var expose := 0  # (the Marbles mode) each attack hit on you deals this much more; only a Cleanse takes it off
var burn := 0  # yours: at the start of your turn you lose that much HP, then it drops by 1
var silenced := {}  # card index -> turns it can't take dice
var hammered := {}  # card index -> Hammer hits (HAMMER_BREAKS: broken for the fight)
var uses := {}  # card index -> times it fired this fight (the Hammer hits the most used)
var ignited := {}  # card index -> true: using it this turn burns you for IGNITE_DMG
var cocooned := {}  # card index -> the Silk Cocoon (Foe) it is in
var stunned := 0  # your next turn is skipped
var freeze_next := 0  # dice frozen at your next roll
var confuse_next := false  # one die face down at your next roll
var confuse_fight := false  # (the Mirror Fairy's: every roll, the whole fight)
var _ignite_next := {}  # card index -> true: alight from your next turn
var dodge := 0  # Dodge: the next attack on you misses (one per point; the Wing carving)
var ethereal := false  # yours (Flee): no attack touches you until your next turn
var _shield_mult := 1
var _burn_mult := 1
var cooldown := {}  # card index -> your turns it still can't be used (Burn Burn Burn)
var flurry := 0  # this turn: each time an enemy takes damage, it takes this much more (Flurry)
var fire_fist := 0  # this turn: each time you damage an enemy, it gains this much Burn (Fire Fist)
var overwhelm := 0  # this turn: each time you damage an enemy, you gain this much Shield (Overwhelm)
var no_shield := false  # this turn: you can't gain Shield (Taunt)
var feint := false  # until your next turn: each enemy that attacks you gains 1 Vulnerable (Feint)
var _enemy_phase := false
var turn := 0
var over := false
var won := false
var events: Array = []
var snapshots := false  # (the old fight screen's bridge, MarbleBridge: every event carries the numbers as they are then)


## Every event goes through here: with `snapshots` on, it carries what you and the enemies look like at that moment, so
## a screen that plays the events one by one can show each change as it lands.
func _ev(e: Dictionary) -> void:
	var nv: Variant = get("_note")
	if nv != null and int(nv) >= 0 and not e.has("note"):
		e["note"] = int(nv)  # (MarblesFight: it happened as that chant marble was read)
	if snapshots:
		e["_snap"] = snap()
	events.append(e)


func snap() -> Dictionary:
	var fs := []
	for f: Foe in foes:
		fs.append({"hp": f.hp, "max_hp": f.max_hp, "block": f.block, "burn": f.burn, "stun": f.stun, "power": f.power,
			"weak": f.weak, "thorns": f.thorns, "expose": f.expose, "armor": f.armor, "vulnerable": f.vulnerable,
			"ethereal": f.ethereal, "dodge": f.dodge, "intent": f.intent.duplicate(true),
			"fly": FLY_HITS - f.fly_hits if f.es.flying else 0})  # (a flyer in the air: hits left before it falls)
	return {"hp": run.hp, "max_hp": run.max_hp, "block": block, "burn": burn, "weak": weak, "vulnerable": vulnerable, "expose": expose, "dodge": dodge,
		"stunned": stunned, "leaves": run.leaves, "foes": fs}


## ---- combat log (CombatLog) ----

func _fname(f: Foe) -> String:
	return "#%d %s" % [foes.find(f), f.es.name] if f != null else "-"


## Extra things about you that a subclass wants in the journal.
func _me_extra() -> String:
	return ""


func _me_text() -> String:
	return "HP %d/%d, Shield %d, Burn %d, Weak %d, Vulnerable %d, Expose %d, Dodge %d, Stunned %d%s" % [run.hp, run.max_hp, block, burn, weak, vulnerable, expose, dodge, stunned, _me_extra()]


func _foe_text(f: Foe) -> String:
	return "%s HP %d/%d, Block %d, Burn %d, Stun %d, Power %d, Weak %d, Thorns %d, Vuln %d, Expose %d, Armor %d, Dodge %d, Ethereal %d, Impervious %d%s%s | sign: %s" % [
		_fname(f), f.hp, f.max_hp, f.block, f.burn, f.stun, f.power, f.weak, f.thorns, f.vulnerable, f.expose, f.armor, f.dodge,
		f.ethereal, f.impervious, ", FLYING (%d hits left)" % (FLY_HITS - f.fly_hits) if f.es.flying else "", ", DEFLECT" if f.deflect else "",
		intent_text(f.intent, f) if not f.intent.is_empty() else "-"]


func _log_state(label: String) -> void:
	if not CombatLog.on:
		return
	CombatLog.line("  [%s] YOU: %s" % [label, _me_text()])
	for f: Foe in foes:
		if not f.dead():
			CombatLog.line("  [%s] %s" % [label, _foe_text(f)])


func _log_fight_start() -> void:
	CombatLog.line("Act %d. Foes: %s" % [run.act, ", ".join(foes.map(func(f): return "%s (%s)" % [f.es.name, f.id]))])
	CombatLog.line("Artifacts: %s" % [", ".join(run.artifacts) if not run.artifacts.is_empty() else "none"])
	_log_state("start")


func setup(p_run: MarblesRun, ids: Array) -> void:
	run = p_run
	for id in ids:
		var d: Dictionary = EnemyDefs.get_def(id)
		if d.has("walls"):  # (the Bramble Matron: a Briar Hedge on each side of her)
			var left := _spawn_def(_hedge_def(d))
			var her := _spawn_def(d)
			var right := _spawn_def(_hedge_def(d))
			her.hedges = [left, right]
		else:
			_spawn_def(d)
	var lings := 0  # (the elemental spirits come in twos: their attacks take turns, one attacks while the other doesn't)
	for f in foes:
		if f.id in LINGS:
			f.move_i = lings % 2
			if lings > 0 or foes.filter(func(x): return x.id in LINGS).size() > 1:
				f.random_moves = false  # (the Zephling too: in a pair it takes turns like the others)
			lings += 1
	for f in foes:
		_plan(f)
	if CombatLog.on:
		CombatLog.line("")
		CombatLog.line("##### FIGHT %d (%s) #####" % [CombatLog.fight_number(), Time.get_datetime_string_from_system()])
		_log_fight_start()
	_start_turn()


## Die on Stage's own moves for some enemies (the user, 2026-11-17), instead of the chant game's: {id: [moves, "cycle" /
## "random"]}. A cycle goes in order and starts over; random picks one each turn.
const ENEMY_MOVES := {
	"ashling": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "power", "n": 1, "who": ""}], "cycle"],
	"iceling": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "block", "n": 4}], "cycle"],
	"zephling": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "foe_dodge", "n": 1}], "random"],
	"bramble_back": [[{"kind": "attack", "n": 2, "hits": 1}, {"kind": "thorns", "n": 2}], "random"],
	"hush_moth": [[{"kind": "attack", "n": 7, "hits": 1}, {"kind": "silence", "turns": 1, "n": 1}], "random"],
	"winged_tortoise": [[{"kind": "attack", "n": 2, "hits": 1}, {"kind": "attack", "n": 4, "hits": 1}], "cycle"],
	"mirror_fairy": [[{"kind": "attack", "n": 6, "hits": 1}, {"kind": "mirror"}], "random"],
	"greenseer": [[{"kind": "summon", "ids": ["purple_slime", "green_slime", "yellow_slime"], "n": 1}, {"kind": "attack", "n": 6, "hits": 1}], "cycle"],
	"rolling_bear": [[{"kind": "attack", "n": 7, "hits": 1}, {"kind": "foe_dodge", "n": 1}, {"kind": "power", "n": 1, "who": ""}], "random"],
	"giant_slime": [[{"kind": "attack", "n": 7, "hits": 1}, {"kind": "slime_pick"}], "cycle"],
	"enraged_bear": [[{"kind": "attack", "n": 7, "hits": 1}], "cycle"],
	"triplet_fire": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "power", "n": 2, "who": "random_team"}], "random"],
	"triplet_water": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "heal", "n": 5, "who": ""}], "random"],
	"triplet_air": [[{"kind": "attack", "n": 5, "hits": 1}, {"kind": "expose", "n": 1}], "random"],  # (no Dodge: it Exposes you, the user 2026-11-24)
	"purple_slime": [[{"kind": "attack", "n": 6, "hits": 1}, {"kind": "weak", "n": 1}], "cycle"],
	"green_slime": [[{"kind": "attack", "n": 6, "hits": 1}, {"kind": "heal", "n": 6, "who": ""}], "cycle"],
	"yellow_slime": [[{"kind": "attack", "n": 6, "hits": 1}, {"kind": "vulnerable", "n": 1}], "cycle"],
	# the Yin Yang Beast (the user, 2026-11-17): 3 x 3, Silence 2, or a Charge (a card: 30 damage in 2 turns, each 1 on
	# it takes 10 off); at 0 it splits into two Cubs (YY_CUBS), each 2 x 2, Silence 1, or a Charge of 20
	"yin_yang_beast": [[{"kind": "attack", "n": 3, "hits": 3}, {"kind": "silence", "turns": 1, "n": 2}, {"kind": "charge", "n": 30, "slots": 3}], "random"],
	"yin_yang_clone": [[{"kind": "attack", "n": 2, "hits": 2}, {"kind": "silence", "turns": 1, "n": 1}, {"kind": "charge", "n": 20, "slots": 2}], "random"],
}
## A Charge (a boss's big blow, a card over it like the Wizard's spells): it hits for its "n" after CHARGE_TURNS of your
## turns; each die of CHARGE_MAX or less you put on it takes CHARGE_CUT off (all its slots full: it's gone).
const CHARGE_TURNS := 2
const CHARGE_CUT := 10
const CHARGE_MAX := 1
## The Yin Yang Beast at 0 HP: two Cubs, one white and one black.
const YY_CUBS := ["white", "black"]


const LINGS := ["ashling", "iceling", "zephling"]
## The Giant Slime's other move (one at random each time): what the small slimes do, for 3 turns.
const GIANT_SLIME_PICKS := [{"kind": "weak", "n": 3}, {"kind": "vulnerable", "n": 3}, {"kind": "regen", "n": 4, "turns": 3}]
## The Greenseer heals first whenever one of his side is hurt (the user, 2026-11-17).
const GREENSEER_HEAL := {"kind": "heal", "n": 6, "who": ""}
## The Bramble Matron's summoning: a card over her, cut by a die of 6; cut, she tries again next turn.
const MATRON_SPELL := {"id": "matron_call", "name": "Summon", "cut": 6, "text": "She calls a creature onto the stage.", "cast": {"kind": "summon", "ids": MATRON_CALLS, "n": 1}}
## The Enraged Rolling Bear gains this much Power each time you gain Shield.
const BEAR_RAGE := 1


## Die on Stage HP set by hand (the user), instead of from the Essence row.
const ENEMY_HP := {"bramble_back": 30, "yin_yang_beast": 35, "yin_yang_clone": 15}
## Flyers (the user, 2026-11-17): in the air every hit on it does only 1 damage; FLY_HITS hits knock it down: it is
## stunned for a turn, then takes off again.
const FLYERS := ["winged_tortoise"]
const FLY_HITS := 3


## An enemy's HP in the new fight (what _spawn_def gives it; MarblesFight's own changes included by MarblesFight.hp_of).
static func base_hp(id: String) -> int:
	var d: Dictionary = EnemyDefs.get_def(id)
	var orbs := String(d.get("hp", "AAAA")).length()
	var hp := (orbs * 3 + (orbs * 3) % 2) * HP_MULT
	if ENEMY_HP.has(id):
		hp = int(ENEMY_HP[id])
	if id == "pianist":
		hp = PAGE_HP
	return hp


func _hedge_def(matron: Dictionary) -> Dictionary:
	return {"id": "briar_hedge", "name": "Briar Hedge", "act": int(matron.get("act", 1)), "hp": "AAA" if int(matron.walls) <= 3 else "AAAA",
		"moves": matron.get("wall_moves", [{"kind": "attack", "n": 2}]), "member": true}


## A new enemy at the end of the row (a summon comes in here too). Returns it.
func _spawn_def(d: Dictionary, at := -1) -> Foe:
	var f := Foe.new()
	f.id = String(d.id)
	f.es = EnemyState.new()
	f.es.setup(d)
	f.es.is_boss = d.get("boss", false) or f.id in EnemyDefs.BOSSES.get(run.act, [])
	f.es.is_elite = d.get("elite", false)
	var orbs := String(d.get("hp", "AAAA")).length()
	f.max_hp = (orbs * 3 + (orbs * 3) % 2) * HP_MULT  # (3 HP per orb, up to the next even number; then doubled, 2026-11-15)
	f.hp = f.max_hp
	f.moves = _moves_of(d, "moves")
	f.moves2 = _moves_of(d, "moves2")
	f.move_i = int(d.get("start", 0))
	if ENEMY_HP.has(f.id):
		f.max_hp = int(ENEMY_HP[f.id])
		f.hp = f.max_hp
	f.es.flying = f.id in FLYERS
	if ENEMY_MOVES.has(f.id):
		f.moves = (ENEMY_MOVES[f.id][0] as Array).duplicate(true)
		f.random_moves = String(ENEMY_MOVES[f.id][1]) == "random"
	if f.id == "pianist":
		f.pages = d.get("pages", []).size() - 1
		f.max_hp = PAGE_HP
		f.hp = PAGE_HP
	if f.id == "samurai_retainer":  # (his own moves, the user 2026-11-16: heal his lord, Power, cleanse + Impervious)
		f.moves = [{"kind": "heal", "n": 10, "who": "lord"}, {"kind": "power", "n": 1, "who": "lord"}, {"kind": "cleanse", "who": "lord"}]
	if d.has("walls"):  # (she only summons now)
		f.moves = [{"kind": "summon", "ids": MATRON_CALLS, "n": 1}]
	if at >= 0 and at <= foes.size():
		foes.insert(at, f)
	else:
		foes.append(f)
	return f


func _moves_of(d: Dictionary, key: String) -> Array:
	var out := []
	for m in d.get(key, []):
		var sm := _simple_move(m)
		if not sm.is_empty():  # (a move that is gone: left out of the cycle)
			out.append(sm)
	if key == "moves" and out.is_empty():
		out.append({"kind": "attack", "n": 4, "hits": 1})
	return out


## A chant game move, as a Die on Stage move (and the move it comes with, "also").
func _simple_move(m: Dictionary) -> Dictionary:
	var bonus: int = EnemyDefs.attack_bonus(run.act)
	var out := {}
	match String(m.kind):
		"attack":
			out = {"kind": "attack", "n": int(m.get("n", 4)) + bonus, "hits": int(m.get("hits", 1))}
		"armor", "guard":
			out = {"kind": "block", "n": 6 + 2 * run.act}
		"mend":
			out = {"kind": "heal", "n": 3 * int(m.get("n", 1)), "who": "lord" if String(m.get("who", "")) == "samurai" else ""}
		"weak":
			out = {"kind": "weak", "n": int(m.get("turns", m.get("n", 1)))}
		"burn":
			out = {"kind": "burn", "n": int(m.get("n", 2))}  # (the chant game's Poison and Bleed are Burn now, 2026-11-21)
		"silence":
			out = {"kind": "silence", "turns": int(m.get("turns", 1)), "n": 99 if m.get("all", false) else int(m.get("n", 1))}
		"lock":
			out = {"kind": "silence", "turns": 1, "n": 1}  # (Lock is gone: Silence instead, 2026-11-16)
		"grow_thorns":
			out = {"kind": "thorns", "n": int(m.get("n", 2))}
		"ethereal":
			out = {"kind": "ethereal"}
		"hammer_spell":
			out = {"kind": "hammer"}
		"vulnerable":
			out = {"kind": "vulnerable", "n": int(m.get("n", 1))}
		"stun":
			out = {"kind": "stun", "n": 1}
		"empower":
			out = {"kind": "power", "n": int(m.get("n", 1)), "who": "lord" if String(m.get("who", "")) == "samurai" else ""}
		"freeze":
			out = {"kind": "freeze"}  # (one die, whatever its n: limited to 1, 2026-11-16)
		"ignite_spell":
			out = {"kind": "ignite", "n": 99 if m.get("all", false) else int(m.get("n", 1))}
		"blind":
			out = {"kind": "confuse", "fight": bool(m.get("fight", false))}  # (the chant game's Blind: here a die face down)
		"drain_essence":
			return _simple_move(m.also) if m.has("also") else {}  # (gone, 2026-11-16: only what came with it stays)
		"hold":
			out = {"kind": "hold"}
		"recharge":
			out = {"kind": "recharge"}
		"deflect":
			out = {"kind": "deflect"}
		"steal_spell":
			out = {"kind": "steal_card"}
		"summon":
			var ids: Array = m.get("ids", m.get("list", [m.get("id", "forge_spirit")]))
			out = {"kind": "summon", "ids": ids, "n": int(m.get("n", 1))}
		"summon_clock":
			out = {"kind": "clock", "n": int(m.get("n", 1))}
		"play":
			out = {"kind": "play"}
		"invoke":
			out = {"kind": "invoke"}
		_:
			out = {"kind": "attack", "n": 4 + 2 * run.act + bonus, "hits": 1}
	if m.has("also") and String(m.also.get("kind", "")) != "":
		var also := _simple_move(m.also)
		if not also.is_empty():
			out["also"] = also
	return out


func _plan(f: Foe) -> void:
	if f.phase == 1 and not f.moves2.is_empty() and f.hp * 2 <= f.max_hp:
		f.phase = 2  # (half HP: its second set of moves)
		f.moves = f.moves2
		f.move_i = 0
		_ev({"type": "phase2", "foe": foes.find(f)})
	if f.landed and f.stun <= 0:  # (knocked down and its stun is over: it flies back up)
		f.intent = {"kind": "take_off"}
		f.es.intent = {"kind": "take_off"}
		return
	if f.es.def.has("walls"):  # (the Bramble Matron: nobody else on the stage: she summons (a 6 cuts it); else she grows their Thorns)
		if alive().any(func(x): return x != f):
			f.spells.clear()
			f.intent = {"kind": "thorns_team", "n": 2}
		else:
			f.spells = [MATRON_SPELL.duplicate(true)]
			f.intent = {"kind": "invoke"}
		f.es.intent = {"kind": String(f.intent.kind)}
		return
	if f.id == "greenseer" and alive().any(func(x): return x.hp < x.max_hp):
		f.intent = GREENSEER_HEAL
		f.es.intent = {"kind": "heal"}
		return
	if not f.spells.is_empty() and f.spells[0].get("charge", false):  # (a Charge on its way: it keeps charging)
		f.intent = {"kind": "charging"}
		f.es.intent = {"kind": "attack"}
		return
	if f.es.def.get("invokes", false):
		f.phase = 2 if f.hp * 2 <= f.max_hp else 1
		f.intent = {"kind": "invoke"}
		_new_spells(f)
	elif f.random_moves:
		var from: Array = f.moves
		if f.id == "yin_yang_clone":  # (the Cubs are never in sync: not the same move as the other one this turn)
			var taken := alive().filter(func(x): return x != f and x.id == f.id).map(func(x): return "charge" if String(x.intent.get("kind", "")) == "charging" else String(x.intent.get("kind", "")))
			var other := from.filter(func(m): return not (String(m.kind) in taken))
			if not other.is_empty():
				from = other
		if f.dodge > 0:  # (it still has its Dodge: another move)
			var rest := from.filter(func(m): return String(m.kind) != "foe_dodge")
			if not rest.is_empty():
				from = rest
		f.intent = from[run.rng.randi() % from.size()]
	else:
		if f.dodge > 0 and String(f.moves[f.move_i % f.moves.size()].kind) == "foe_dodge":
			f.move_i += 1  # (it still has its Dodge: on to its next move, the user 2026-11-24)
		f.intent = f.moves[f.move_i % f.moves.size()]
		f.move_i += 1
	if String(f.intent.get("kind", "")) == "charge":  # (it starts a Charge: its card hangs over it)
		f.spells = [{"id": "charge", "name": "Charge", "charge": true, "n": int(f.intent.n), "slots": int(f.intent.slots),
			"placed": 0, "turns": CHARGE_TURNS}]
		f.intent = {"kind": "charging"}
	if String(f.intent.get("kind", "")) == "slime_pick":  # (the Giant Slime: which one, decided now so it shows)
		f.intent = GIANT_SLIME_PICKS[run.rng.randi() % GIANT_SLIME_PICKS.size()]
	f.deflect = String(f.intent.get("kind", "")) == "mirror"  # (the Mirror Fairy's "?": her mirror is up now, for your turn)
	f.es.intent = {"kind": String(f.intent.kind)}  # (the puppet's poses read it)


## Good Ol' Wizard picks his spells for his next turn: 2 (3 in his second phase), all different.
func _new_spells(f: Foe) -> void:
	var pool := WIZARD_SPELLS.duplicate()
	f.spells.clear()
	for k in (3 if f.phase == 2 else 2):
		f.spells.append(pool.pop_at(run.rng.randi() % pool.size()))


## The damage a Charge card will still do (its n, less CHARGE_CUT for each die on it).
static func charge_left(sp: Dictionary) -> int:
	return maxi(0, int(sp.get("n", 0)) - CHARGE_CUT * int(sp.get("placed", 0)))


func alive() -> Array:
	return foes.filter(func(f): return not f.dead())


# ------------------------------------------------------------------ your turn

func _target(target: int) -> Foe:
	var live := alive().filter(func(x): return not x.shielded())
	if live.is_empty():
		return null
	if target >= 0 and target < foes.size() and not foes[target].dead() and not foes[target].shielded():
		return foes[target]
	return live[0]


func _vulnerable(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		CombatLog.line("      status: %s Vulnerable %d -> %d (it takes +50%%)" % [_fname(t), t.vulnerable, maxi(t.vulnerable, n)])
		t.vulnerable = maxi(t.vulnerable, n)
		_ev({"type": "foe_vulnerable", "foe": foes.find(t)})


func _stun(t: Foe, n: int) -> void:
	if t != null and not t.dead() and _takes_status(t):
		CombatLog.line("      status: %s Stun %d -> %d" % [_fname(t), t.stun, t.stun + n])
		t.stun += n
		_ev({"type": "stun", "foe": foes.find(t)})


func _weaken(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		CombatLog.line("      status: %s Weak %d -> %d (it deals 50%% less)" % [_fname(t), t.weak, maxi(t.weak, n)])
		t.weak = maxi(t.weak, n)
		_ev({"type": "foe_weak", "foe": foes.find(t)})


## Burn on an enemy (doubled by an Orange die in the move).
func _burn(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		CombatLog.line("      status: %s Burn %d -> %d (given %d x burn multiplier %d)" % [_fname(t), t.burn, t.burn + n * _burn_mult, n, _burn_mult])
		t.burn += n * _burn_mult
		_ev({"type": "foe_burn", "foe": foes.find(t), "n": n * _burn_mult})


## Impervious: no status sticks to it.
func _takes_status(f: Foe) -> bool:
	if f.impervious > 0:
		CombatLog.line("      status refused: %s is Impervious (%d)" % [_fname(f), f.impervious])
		_ev({"type": "immune", "foe": foes.find(f), "why": "Impervious"})
		return false
	return true


## You gain Shield (doubled by a Blue die in the card, or the Shield carving this turn).
func _shield(n: int) -> void:
	if no_shield:  # (Taunt)
		CombatLog.line("      you gain Shield %d: refused (Taunt: no Shield this turn)" % n)
		return
	CombatLog.line("      you gain Shield %d x shield multiplier %d = %d  (Shield %d -> %d)" % [n, _shield_mult, n * _shield_mult, block, block + n * _shield_mult])
	n *= _shield_mult
	block += n
	_ev({"type": "block", "n": n})
	if n > 0:
		for x: Foe in alive():
			if x.id == "enraged_bear":  # (every Shield you gain makes it angrier)
				x.power += BEAR_RAGE
				_ev({"type": "foe_power", "foe": foes.find(x), "n": BEAR_RAGE})


## A HIT: a move of yours (or an attack you Redirected) striking an enemy for n, whether its Shield takes it or not
## (Burn doesn't hit). Smite, Fire Fist and Overwhelm go off.
func _on_hit(f: Foe, n: int) -> void:
	if n <= 0:
		return
	if f.smite > 0 and not f.dead():
		var sm := f.smite
		f.smite = 0
		_burn(f, sm * n)
	if fire_fist > 0 and not f.dead():
		_burn(f, fire_fist)
	if overwhelm > 0:
		_shield(overwhelm)


func _on_death(f: Foe) -> void:
	CombatLog.line("    >> %s reaches 0 HP%s" % [_fname(f), " (next page: back to full HP)" if f.pages > 0 else " and dies"])
	if f.pages > 0:  # (the Pianist: that page is played out; he turns to the next, at full)
		f.pages -= 1
		f.hp = f.max_hp
		f.es.page += 1
		_ev({"type": "page_turn", "foe": foes.find(f), "left": f.pages})
		return
	_ev({"type": "dies", "foe": foes.find(f)})
	f.spells.clear()
	if f.id == "yin_yang_beast":  # (it falls apart into two Cubs, a white and a black one)
		for yin in YY_CUBS:
			var d: Dictionary = EnemyDefs.get_def("yin_yang_clone").duplicate(true)
			d["yin"] = yin
			var c := _spawn_def(d)
			c.es.yin = yin
			c.move_i = YY_CUBS.find(yin)
			_plan(c)
			_ev({"type": "spawn", "foe": foes.size() - 1, "from": foes.find(f)})
	if f.cocoon_card >= 0:  # (the Silk Cocoon breaks: your card comes back)
		cocooned.erase(f.cocoon_card)
		_ev({"type": "card_back", "ci": f.cocoon_card})
		f.cocoon_card = -1


func end_turn() -> void:
	if over:
		return
	for ci in silenced.keys():  # (Silence: the turn of yours it covered is over: before the enemies act, so a new Silence covers your next turn)
		silenced[ci] = int(silenced[ci]) - 1
		if int(silenced[ci]) <= 0:
			silenced.erase(ci)
	_log_state("you end the turn: what the signs show")
	CombatLog.line("--- ENEMY PHASE (turn %d) ---" % turn)
	_enemy_phase = true
	flurry = 0  # ("this turn": your turn is over)
	fire_fist = 0
	overwhelm = 0
	for f: Foe in foes.duplicate():
		var i := foes.find(f)
		if f.dead() or over:
			continue
		CombatLog.line("! %s starts its turn (Block %d is dropped; Vulnerable %d -> %d; Impervious %d -> %d)" % [_fname(f), f.block, f.vulnerable, maxi(0, f.vulnerable - 1), f.impervious, maxi(0, f.impervious - 1)])
		f.block = 0
		f.ethereal = 0  # (Ethereal lasts until its own next turn)
		f.deflect = false
		f.impervious = maxi(0, f.impervious - 1)
		f.vulnerable = maxi(0, f.vulnerable - 1)
		if f.regen_turns > 0:
			f.regen_turns -= 1
			var hh := mini(f.regen, f.max_hp - f.hp)
			CombatLog.line("    regen: %s heals %d (HP %d -> %d)" % [_fname(f), hh, f.hp, f.hp + hh])
			f.hp += hh
			_ev({"type": "foe_heal", "foe": i, "n": hh})
		if f.burn > 0:
			CombatLog.line("    burn: %s loses %d HP (HP %d -> %d), Burn then drops %d -> %d" % [_fname(f), f.burn, f.hp, maxi(0, f.hp - f.burn), f.burn, f.burn - 1])
			f.hp = maxi(0, f.hp - f.burn)
			_ev({"type": "burn", "foe": i, "n": f.burn})
			f.burn -= 1
			if f.dead():
				_on_death(f)
				continue
		if f.stun > 0:
			CombatLog.line("    %s is Stunned: skips its action (Stun %d -> %d)" % [_fname(f), f.stun, f.stun - 1])
			f.stun -= 1
			_ev({"type": "foe_stunned", "foe": i})
		else:
			_act(f, f.intent)
		f.redirect = false
		f.weak = maxi(0, f.weak - 1)
		if not f.dead():
			_plan(f)
	_enemy_phase = false
	weak = maxi(0, weak - 1)
	vulnerable = maxi(0, vulnerable - 1)
	CombatLog.line("--- enemy phase over: your Weak/Vulnerable tick down by 1 ---")
	_log_state("after enemy phase")
	_check_end()
	if not over:
		_ev({"type": "your_turn"})  # (the enemies are done: what follows is your new turn's)
		_start_turn()


func _act(f: Foe, m: Dictionary) -> void:
	var i := foes.find(f)
	CombatLog.line("  ! %s does: %s  (sign now says: %s)" % [_fname(f), String(m.kind), intent_text(m, f)])
	match String(m.kind):
		"attack":
			for h in int(m.get("hits", 1)):
				var n: int = int(m.n) + f.power
				var how := "hit %d/%d: base %d + its Power %d = %d" % [h + 1, int(m.get("hits", 1)), int(m.n), f.power, n]
				if f.weak > 0:
					n = n / 2
					how += " -> it is Weakened (%d): halved = %d" % [f.weak, n]
				if run.has_artifact("leather_armor"):
					n = maxi(0, n - 1)
					how += " -> your Leather Armor -1 = %d" % n
				CombatLog.line("    attack %s" % how)
				var forced := _forced_target(f)  # (a subclass may send every attack at one enemy: the Marbles mode's Moth to Flame)
				if f.redirect or forced != null:  # (Redirect: the blow goes at someone else: any of them, itself too)
					var others := alive()
					var to: Foe = forced if forced != null else others[run.rng.randi() % others.size()]
					var soak := mini(to.block, n)
					CombatLog.line("    redirected onto %s: Block %d soaks %d, HP %d -> %d" % [_fname(to), to.block, soak, to.hp, maxi(0, to.hp - (n - soak))])
					to.block -= soak
					to.hp = maxi(0, to.hp - (n - soak))
					_ev({"type": "redirected", "foe": i, "to": foes.find(to), "n": n - soak})
					_on_hit(to, n)  # (it counts as your hit: Smite)
					if to.dead():
						_on_death(to)
					continue
				if feint and h == 0:  # (Feint: it attacked you, hit or not: it is Vulnerable now)
					_vulnerable(f, 1)
				if ethereal:  # (Flee: you are Ethereal: it passes through)
					CombatLog.line("    -> misses: you are Ethereal")
					_ev({"type": "dodged", "foe": i})
					continue
				if dodge > 0:  # (the Wing carving: this one misses)
					CombatLog.line("    -> misses: you Dodge (Dodge %d -> %d)" % [dodge, dodge - 1])
					dodge -= 1
					_ev({"type": "dodged", "foe": i})
					continue
				if expose > 0:
					CombatLog.line("    your Expose %d: %d -> %d" % [expose, n, n + expose])
					n += expose
				_ev({"type": "attack", "foe": i, "n": n})
				_hurt_player(n)
				if over:
					return
				_on_attacked(f, n)
				if over:
					return
		"block":
			f.block += int(m.n)
			_ev({"type": "foe_block", "foe": i, "n": int(m.n)})
		"heal":
			var who: Foe = _lord(f) if String(m.get("who", "")) == "lord" else null
			if who == null:
				var hurt := alive().filter(func(x): return x.hp < x.max_hp)
				who = f if hurt.is_empty() or f.hp < f.max_hp else hurt[0]
			var h := mini(int(m.n), who.max_hp - who.hp)
			who.hp += h
			_ev({"type": "foe_heal", "foe": foes.find(who), "n": h})
		"weak":  # (+1: it ticks down at the end of this enemy turn; n is your turns)
			weak = maxi(weak, int(m.n) + 1)
			_ev({"type": "debuff", "foe": i, "what": "Weakened"})
		"take_off":
			f.es.flying = true
			f.landed = false
			f.fly_hits = 0
			_ev({"type": "foe_takes_off", "foe": i})
		"foe_dodge":
			var dodger: Foe = alive()[run.rng.randi() % alive().size()] if String(m.get("who", "")) == "random_team" else f
			if dodger.dodge <= 0:  # (one Dodge at most: no more while it has one, the user 2026-11-24)
				dodger.dodge = 1
				_ev({"type": "foe_dodge_up", "foe": foes.find(dodger)})
		"mirror":
			pass  # (her mirror was up during your turn: nothing more)
		"regen":
			f.regen = int(m.n)
			f.regen_turns = int(m.turns)
			_ev({"type": "foe_regen", "foe": i, "n": int(m.n), "turns": int(m.turns)})
		"thorns_team":
			for x: Foe in alive():
				if x != f:
					x.thorns += int(m.n)
					_ev({"type": "foe_thorns", "foe": foes.find(x), "n": int(m.n)})
		"burn":
			burn += int(m.n)
			_ev({"type": "debuff", "foe": i, "what": "Burn %d" % int(m.n)})
		"silence":
			var free := []
			for ci in run.cards.size():
				if not silenced.has(ci):
					free.append(ci)
			for k in mini(int(m.n), free.size()):
				var ci: int = free.pop_at(run.rng.randi() % free.size())
				silenced[ci] = int(m.turns)
			_ev({"type": "debuff", "foe": i, "what": "Silenced"})
		"thorns":
			f.thorns += int(m.n)
			_ev({"type": "foe_thorns", "foe": i, "n": int(m.n)})
		"ethereal":
			f.ethereal = 1
			_ev({"type": "foe_ethereal", "foe": i})
		"hammer":
			var most := -1
			for ci in run.cards.size():
				if int(hammered.get(ci, 0)) < HAMMER_BREAKS and (most < 0 or int(uses.get(ci, 0)) > int(uses.get(most, 0))):
					most = ci
			if most >= 0:
				hammered[most] = int(hammered.get(most, 0)) + 1
				_ev({"type": "debuff", "foe": i, "what": "Hammered: %s %d/%d" % [run.card_at(most).name, hammered[most], HAMMER_BREAKS]})
		"expose":
			expose += int(m.n)
			_ev({"type": "debuff", "foe": i, "what": "Exposed"})
		"vulnerable":  # (+1: it ticks down at the end of this enemy turn; n is the enemy turns it covers)
			vulnerable = maxi(vulnerable, int(m.n) + 1)
			_ev({"type": "debuff", "foe": i, "what": "Vulnerable"})
		"stun":
			stunned = 1
			_ev({"type": "debuff", "foe": i, "what": "Stunned"})
		"power":
			if String(m.get("who", "")) == "wizard_team":  # (Alacrity: him and his Forge Spirits)
				for x in alive():
					if x == f or x.id.begins_with("forge_spirit"):
						x.power += int(m.n)
						_ev({"type": "foe_power", "foe": foes.find(x), "n": int(m.n)})
			else:
				var to: Foe = _lord(f) if String(m.get("who", "")) == "lord" else f
				if String(m.get("who", "")) == "random_team":
					to = alive()[run.rng.randi() % alive().size()]
				if to == null:
					to = f
				to.power += int(m.n)
				_ev({"type": "foe_power", "foe": foes.find(to), "n": int(m.n)})
		"cleanse":  # (the Retainer: his lord's statuses are gone, and none sticks to him until his next turn)
			var lord: Foe = _lord(f) if _lord(f) != null else f
			lord.burn = 0
			lord.weak = 0
			lord.stun = 0
			lord.impervious = 2
			_ev({"type": "foe_cleansed", "foe": foes.find(lord)})
		"cleanse_self":
			f.burn = 0
			f.weak = 0
			f.stun = 0
			_ev({"type": "foe_cleansed", "foe": i})
		"freeze":
			freeze_next = 1
			_ev({"type": "debuff", "foe": i, "what": "Freeze: 1 die next turn"})
		"ignite":
			var cards := []
			for ci in run.cards.size():
				if not _ignite_next.has(ci):
					cards.append(ci)
			for k in mini(int(m.n), cards.size()):
				_ignite_next[cards.pop_at(run.rng.randi() % cards.size())] = true
			_ev({"type": "debuff", "foe": i, "what": "Ignite"})
		"confuse":
			if m.get("fight", false):
				confuse_fight = true
			else:
				confuse_next = true
			_ev({"type": "debuff", "foe": i, "what": "Confused"})
		"hold":
			pass  # (a cocoon: it just hangs there)
		"recharge":
			_ev({"type": "foe_rests", "foe": i})
		"deflect":
			f.deflect = true
			_ev({"type": "foe_deflect", "foe": i})
		"steal_card":
			_steal_card(f)
		"summon":
			_summon(f, m)
		"clock":
			_ev({"type": "foe_clock", "foe": i, "n": int(m.n)})
		"play":
			pass  # (he plays on: the piece itself is the threat, see piece_ended)
		"charging":
			if not f.spells.is_empty():
				var sp: Dictionary = f.spells[0]
				sp.turns = int(sp.turns) - 1
				if int(sp.turns) > 0:
					_ev({"type": "charging", "foe": i})
				else:
					f.spells.clear()
					var hit := charge_left(sp)
					if hit > 0:
						_ev({"type": "casts", "foe": i, "name": "Charge"})
						_act(f, {"kind": "attack", "n": hit, "hits": 1})
		"invoke":
			for sp in f.spells:
				if over or f.dead():
					break
				_ev({"type": "casts", "foe": i, "name": String(sp.name)})
				_act(f, sp.cast)
			f.spells.clear()
	if String(m.kind) != "attack" and CombatLog.on:
		CombatLog.line("    result: YOU: %s | %s" % [_me_text(), _foe_text(f)])
	if m.has("also") and not over:
		_act(f, m.also)


## The Retainer's lord (the Samurai), alive.
## Hooks for a subclass (the Marbles mode): every enemy attack goes at this enemy instead of you (null: you).
func _forced_target(_attacker: Foe) -> Foe:
	return null


## Hook: an enemy's attack has just hit you (your Thorns answer here in the Marbles mode).
func _on_attacked(_attacker: Foe, _n: int) -> void:
	pass


func _lord(_f: Foe) -> Foe:
	for x in alive():
		if x.id == "samurai":
			return x
	return null


## Violet Eyes: one of your cards goes into a Silk Cocoon, a new enemy; break it to get the card back.
func _steal_card(f: Foe) -> void:
	var free := []
	for ci in run.cards.size():
		if not cocooned.has(ci) and int(hammered.get(ci, 0)) < HAMMER_BREAKS:
			free.append(ci)
	if free.is_empty() or alive().size() >= MAX_FOES:
		return
	var ci: int = free[run.rng.randi() % free.size()]
	var c := _spawn_def(EnemyDefs.get_def("spider_cocoon"))
	c.cocoon_card = ci
	_plan(c)
	cocooned[ci] = c
	_ev({"type": "spawn", "foe": foes.size() - 1, "from": foes.find(f)})
	_ev({"type": "debuff", "foe": foes.find(f), "what": "%s is taken into a cocoon" % run.card_at(ci).name})


func _summon(f: Foe, m: Dictionary) -> void:
	var ids: Array = m.get("ids", ["forge_spirit"])
	for k in int(m.get("n", 1)):
		if alive().size() >= MAX_FOES:
			break
		var c := _spawn_def(EnemyDefs.get_def(String(ids[run.rng.randi() % ids.size()])))
		_plan(c)
		_ev({"type": "spawn", "foe": foes.size() - 1, "from": foes.find(f)})
	if f.es.def.get("call_once", false):  # (the Bug Hunter: it calls once; then only its strikes)
		var strike: Dictionary = f.moves[0].duplicate()
		strike.erase("also")
		f.moves = [strike]
		f.move_i = 0


## The Pianist's piece has ended before he did: The End.
func piece_ended() -> void:
	if over:
		return
	run.hp = 0
	over = true
	won = false
	_ev({"type": "piece_ends"})


func _hurt_player(n: int, through_block := false) -> void:
	var incoming := n
	if vulnerable > 0 and not through_block:
		n = n + n / 2
	var soak := 0 if through_block else mini(block, n)
	CombatLog.line("    YOU are hurt: incoming %d%s%s | Shield %d soaks %d (Shield %d -> %d) | HP %d -> %d (lost %d)" % [
		incoming, " -> Vulnerable +50%% = %d" % n if n != incoming else "", " (ignores Shield)" if through_block else "",
		block, soak, block, block - soak, run.hp, maxi(0, run.hp - (n - soak)), n - soak])
	block -= soak
	run.hp = maxi(0, run.hp - (n - soak))
	if run.hp <= 0:
		over = true
		won = false


## Your turn begins (MarblesFight: the draw).
func _start_turn() -> void:
	pass


## A hit of yours on an enemy (MarblesFight).
func _hit(_f: Foe, _n: int) -> void:
	pass


func _check_end() -> void:
	if alive().is_empty():
		over = true
		won = true


## What an intent says, short: "Attack 7", "Attack 3 x2", "Block 8"...
static func intent_text(m: Dictionary, f: Foe = null) -> String:
	var s := ""
	match String(m.get("kind", "")):
		"attack":
			var n: int = int(m.n) + (f.power if f != null else 0)
			if f != null and f.weak > 0:
				n = n / 2
			s = "⚔ %d" % n + (" x%d" % int(m.hits) if int(m.get("hits", 1)) > 1 else "")
		"block":
			s = "🛡 %d" % int(m.n)
		"heal":
			s = "❤ +%d" % int(m.n) + (" (his lord)" if String(m.get("who", "")) == "lord" else "")
		"weak":
			s = "Weaken" + (" %d" % int(m.n) if int(m.get("n", 1)) > 1 else "")
		"foe_dodge":
			s = "🪽 Dodge"
		"take_off":
			s = "🪽 Take off"
		"mirror":
			s = "?"
		"regen":
			s = "❤ +%d x%d turns" % [int(m.n), int(m.turns)]
		"thorns_team":
			s = "🌵 Thorns +%d to all" % int(m.n)
		"burn":
			s = "🔥 Burn %d" % int(m.n)
		"silence":
			s = "🔇 Silence"
		"thorns":
			s = "🌵 Thorns +%d" % int(m.n)
		"ethereal":
			s = "👻 Ethereal"
		"hammer":
			s = "🔨 Hammer"
		"expose":
			s = "Expose %d" % int(m.n)
		"vulnerable":
			s = "Vulnerable" + (" %d" % int(m.n) if int(m.get("n", 1)) > 1 else "")
		"stun":
			s = "💫 Stun"
		"power":
			s = "💪 +%d" % int(m.n) + (" (his lord)" if String(m.get("who", "")) == "lord" else "")
		"cleanse":
			s = "✨ Cleanse + Impervious (his lord)"
		"cleanse_self":
			s = "✨ Cleanse"
		"freeze":
			s = "❄ Freeze 1 die"
		"ignite":
			s = "🔥 Ignite %s" % ("all" if int(m.n) >= 99 else "%d card%s" % [int(m.n), "" if int(m.n) == 1 else "s"])
		"confuse":
			s = "🌀 Confuse" + (" (all fight)" if m.get("fight", false) else "")
		"hold":
			s = "…"
		"recharge":
			s = "💤 Recharging"
		"deflect":
			s = "🗡 Deflect"
		"steal_card":
			s = "🕸 Steal a card"
		"summon":
			s = "📯 Summon"
		"clock":
			s = "⏰ %d" % int(m.n)
		"play":
			s = "🎹 Plays on" + (" (%d pages left)" % f.pages if f != null and f.pages > 0 else "")
		"charging":
			var cs: Dictionary = f.spells[0] if f != null and not f.spells.is_empty() else {}
			s = "💥 Charging %d" % charge_left(cs) + (" (%d turn%s)" % [int(cs.turns), "" if int(cs.turns) == 1 else "s"] if not cs.is_empty() else "")
		"invoke":
			s = "📯 Summon (a 6 stops it)" if f != null and f.es.def.has("walls") else "✨ Casts his spells"
	if m.has("also"):
		s += "  " + intent_text(m.also, f)
	return s
