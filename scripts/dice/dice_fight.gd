class_name DiceFight
extends RefCounted
## Die on Stage (2026-11-15): one fight. The enemies are the chant game's puppets (an EnemyState each, for the picture)
## with HP instead of a row of Essence: 3 HP per orb of their row, rounded up to an even number, then doubled (HP_MULT).
##
## Statuses (what we put on each other; the user, 2026-11-16): Burn, Power, Weakened, Vulnerable, Stunned, Thorns,
## Silence, Ethereal, Hammer (Fragile), Dodge (yours), Impervious (no status sticks). Shield / Block is not a status:
## it shows as a blue part of the HP bar. Poison and Bleed are Burn now.
##
## Enemy MECHANICS (to be learned; the user, 2026-11-16), each a dice version of the chant game's move:
##   Freeze: 1 of your dice is frozen next turn (rolled, but it can't be used).
##   Ignite: some of your cards are alight next turn: using one burns you for IGNITE_DMG.
##   Confuse: next turn 1 of your dice lands face down ("?"): you see it once you place it; one that doesn't fit the
##     slot bounces back (the Mirror Fairy's lasts the whole fight).
##   Lock: gone; those enemies Silence instead. Virus, Drain, Invert and Mimic: gone (2026-11-16); those moves are
##   left out of their enemies' cycles (the Corrector's Syntax Error keeps its Silence).
##   Steal a card (Violet Eyes): it goes into a Silk Cocoon (an enemy of its own); break the cocoon to get it back.
##   Hold (the cocoon): nothing.  Recharge (Red Sentinel): it rests.  Deflect: the next card that hits it hurts you
##   instead.  Summon / Alarm clock: it calls enemies (the clock counts first).
##   The Retainer (his own moves now): heals his lord 10, gives him +1 Power, or cleanses him and makes him Impervious.
##   The Bramble Matron: only summons; she can't be targeted while either of her two Briar Hedges stands.
##   The Pianist: as in the chant game, his piece plays in real time from the start (the screen: PianistSong); when it
##   ends, so do you. He has PIANO_PAGES pages of PAGE_HP each: empty one, and he turns the page.
##   Good Ol' Wizard: never attacks; he has WIZARD_SPELLS (2 a turn, 3 in his second phase) hung over him and casts
##     them all on his turn, unless you put a die of the spell's number on it (Interrupt).
##   Moves still unmatched (Shuffle) become an attack. Enemies with "moves2" switch to it at half HP.
##
## Your turn: roll your dice, put them in your cards' slots, End turn. Then each enemy in turn: its Block is gone, its
## Burn burns, it acts (unless Stunned). Then your turn: your Block is gone, your Burn burns, a new roll.
## Every change is told to the screen as an event ({type: ...}) in `events`, which it plays and empties.

const HP_MULT := 2  # enemy HP x2 (the user, 2026-11-15)
const HAMMER_BREAKS := 3  # (Hammer: the card you have used most is hit; this many hits break it for the fight)
const IGNITE_DMG := 5
const MAX_FOES := 5
const PAGE_HP := 30  # (the Pianist: each page of his score; 10 orbs x 3, not doubled: the music is the clock)
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
	var redirect := false  # (Redirect: its next attack goes at someone else)
	var smite := 0  # (Smite: your next hit on it also gives it that many times its damage in Burn)
	var deflect := false  # the next card that hits it hurts you instead
	var moves: Array = []
	var moves2: Array = []  # (from half HP)
	var phase := 1
	var move_i := 0
	var intent: Dictionary = {}
	var hedges: Array = []  # (the Bramble Matron: her Briar Hedges; she can't be targeted while one stands)
	var cocoon_card := -1  # (a Silk Cocoon: the card of yours inside it)
	var pages := 0  # (the Pianist: pages of his score still to play after this one)
	var spells: Array = []  # (Good Ol' Wizard: the spells hanging over him now)

	func dead() -> bool:
		return hp <= 0

	func shielded() -> bool:
		return hedges.any(func(h): return not h.dead())

var run: DiceRun
var foes: Array = []
var block := 0
var weak := 0  # you deal 50% less
var vulnerable := 0  # you take 50% more
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
var rolled: Array = []  # this turn's dice: {die, face, value, paint, carve, used, rerolled, frozen, hidden}
var dodge := 0  # Dodge: the next attack on you misses (one per point; the Wing carving)
var ethereal := false  # yours (Flee): no attack touches you until your next turn
var fled := {}  # move index -> {die, turns, value, paint, carve}: Flee keeps its die (that die isn't rolled) for that many turns
var skull := false  # the Skull carving rolled this turn: your cards deal double damage
var guard := false  # the Shield carving rolled this turn: your cards give double Shield
var _dmg_mult := 1  # while a card fires: its damage, Shield and Burn multipliers (Red, Blue, Orange paint; Skull, Shield)
var _shield_mult := 1
var _burn_mult := 1
var _damaged := {}  # the enemies the card firing now has damaged (for their Thorns)
var placed := {}  # card index -> Array of slot values (null = empty)
var placed_dice := {}  # card index -> Array of the `rolled` index in each slot (-1 = empty)
var placed_dice_last := {}  # (the dice of the move firing now: Flee keeps its own)
var ready := {}  # card index -> its slot values: full, waiting to fire (its target is being chosen)
var spent := {}  # card index -> true: a card that isn't repeatable and fired this turn
var tweaks := {}  # card index -> times a tweak move (Hype Up, Calm Down) was used this turn
var cooldown := {}  # card index -> your turns it still can't be used (Burn Burn Burn)
var flurry := 0  # this turn: each time an enemy takes damage, it takes this much more (Flurry)
var fire_fist := 0  # this turn: each time you damage an enemy, it gains this much Burn (Fire Fist)
var overwhelm := 0  # this turn: each time you damage an enemy, you gain this much Shield (Overwhelm)
var no_shield := false  # this turn: you can't gain Shield (Taunt)
var feint := false  # until your next turn: each enemy that attacks you gains 1 Vulnerable (Feint)
var intuition := 1  # this turn's number for Intuition (a new one each turn)
var gone := {}  # move index -> true: a Fragile move used up for this fight (Focus)
var revenge := {}  # {foe, mult, taken}: Revenge, waiting for your next turn
var _enemy_phase := false
var _in_flurry := false
var turn := 0
var over := false
var won := false
var events: Array = []


func setup(p_run: DiceRun, ids: Array) -> void:
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
	for f in foes:
		_plan(f)
	_start_turn()


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
		"poison", "bleed":
			out = {"kind": "burn", "n": int(m.get("n", 2))}  # (Poison is Burn now, 2026-11-16)
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
		"confuse":
			out = {"kind": "confuse", "fight": bool(m.get("fight", false))}
		"virus", "drain_essence", "invert", "mimic":
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
		events.append({"type": "phase2", "foe": foes.find(f)})
	if f.es.def.get("invokes", false):
		f.phase = 2 if f.hp * 2 <= f.max_hp else 1
		f.intent = {"kind": "invoke"}
		_new_spells(f)
	else:
		f.intent = f.moves[f.move_i % f.moves.size()]
		f.move_i += 1
	f.es.intent = {"kind": String(f.intent.kind)}  # (the puppet's poses read it)


## Good Ol' Wizard picks his spells for his next turn: 2 (3 in his second phase), all different.
func _new_spells(f: Foe) -> void:
	var pool := WIZARD_SPELLS.duplicate()
	f.spells.clear()
	for k in (3 if f.phase == 2 else 2):
		f.spells.append(pool.pop_at(run.rng.randi() % pool.size()))


func alive() -> Array:
	return foes.filter(func(f): return not f.dead())


# ------------------------------------------------------------------ your turn

func _start_turn() -> void:
	turn += 1
	block = 0
	placed.clear()
	placed_dice.clear()
	ready.clear()
	spent.clear()
	tweaks.clear()
	flurry = 0
	fire_fist = 0
	overwhelm = 0
	no_shield = false
	feint = false
	intuition = run.rng.randi_range(1, 6)
	for ci in cooldown.keys():
		cooldown[ci] = int(cooldown[ci]) - 1
		if int(cooldown[ci]) <= 0:
			cooldown.erase(ci)
	ethereal = false
	ignited = _ignite_next.duplicate()
	_ignite_next.clear()
	if burn > 0:
		_hurt_player(burn, true)
		events.append({"type": "you_burn", "n": burn})
		burn -= 1
		if over:
			return
	rolled.clear()
	skull = false
	guard = false
	var kept := {}  # (dice Flee holds: not rolled)
	for ci in fled.keys():
		fled[ci].turns = int(fled[ci].turns) - 1
		if int(fled[ci].turns) < 0:
			fled.erase(ci)
		else:
			kept[int(fled[ci].die)] = true
	for i in run.dice.size():
		if not kept.has(i):
			rolled.append(_rolled(i, run.roll(i)))
	if run.has_artifact("loaded_die") and not rolled.is_empty():  # (the lowest die is rolled again once)
		var low := 0
		for i in rolled.size():
			if int(rolled[i].value) < int(rolled[low].value):
				low = i
		rolled[low] = _rolled(int(rolled[low].die), run.roll(int(rolled[low].die)))
	if freeze_next > 0 and not rolled.is_empty():
		rolled[run.rng.randi() % rolled.size()].frozen = true
		freeze_next = 0
	if (confuse_next or confuse_fight) and not rolled.is_empty():
		var open := rolled.filter(func(d): return not d.frozen)
		if not open.is_empty():
			open[run.rng.randi() % open.size()].hidden = true
		confuse_next = false
	events.append({"type": "roll"})
	_carvings()
	if not revenge.is_empty() and not over:  # (Revenge: what you took comes back at it)
		var t: Foe = revenge.foe
		if t == null or t.dead():
			t = _target(-1)
		var back: int = int(revenge.taken) * int(revenge.mult)
		revenge = {}
		if t != null and back > 0:
			events.append({"type": "revenge", "foe": foes.find(t), "n": back})
			_hit(t, back)
			_check_end()
	if stunned > 0:
		stunned -= 1
		events.append({"type": "you_stunned"})
		end_turn()


## A die as rolled: die `i` showing its face `k` (k -1: a plain extra d6, the Dice carving's).
func _rolled(i: int, k: int) -> Dictionary:
	var f: Dictionary = run.face(i, k) if k >= 0 else DiceFace.make(run.rng.randi_range(1, 6))
	return {"die": i, "face": k, "value": int(f.v), "paint": String(f.get("paint", "")), "carve": String(f.get("carve", "")),
		"used": false, "rerolled": false, "frozen": false, "hidden": false}


## The carvings on the faces that were rolled: each does its thing now. (The Dice carving's extra d6 is plain.)
func _carvings() -> void:
	var total := 0
	for d in rolled:
		total += int(d.value)
	for d in rolled.duplicate():
		match String(d.carve):
			"heart":
				events.append({"type": "heal", "n": run.heal(3)})
			"dice":
				var extra := _rolled(int(d.die), -1)
				rolled.append(extra)
				events.append({"type": "extra_die"})
			"sword":
				var live := alive().filter(func(x): return not x.shielded())
				if not live.is_empty():
					var t: Foe = live[run.rng.randi() % live.size()]
					_hit(t, total)
			"wing":
				dodge += 1
				events.append({"type": "dodge_up"})
			"skull":
				skull = true
				events.append({"type": "skull"})
			"shield":
				guard = true
				events.append({"type": "guard"})
	_check_end()


## Purple paint: a die showing a purple face may be rolled again, once.
func can_reroll(r: int) -> bool:
	return not over and r >= 0 and r < rolled.size() and not rolled[r].used and not rolled[r].frozen and String(rolled[r].paint) == "purple" and not rolled[r].rerolled


func reroll(r: int) -> void:
	if not can_reroll(r):
		return
	var i: int = rolled[r].die
	var hid: bool = rolled[r].hidden
	rolled[r] = _rolled(i, run.roll(i)) if int(rolled[r].face) >= 0 else _rolled(i, -1)
	rolled[r].rerolled = true  # (whatever it shows now: once per turn)
	rolled[r].hidden = hid
	events.append({"type": "reroll", "r": r})


## Can die `r` (an index into `rolled`) be put in slot `k` of move `ci`? A face-down die (Confuse) may be tried on any
## slot: place() turns it over, and bounces it when it doesn't fit.
func can_place(r: int, ci: int, k: int) -> bool:
	if over or r < 0 or r >= rolled.size() or rolled[r].used or rolled[r].frozen or spent.has(ci) or ci >= run.cards.size():
		return false
	if silenced.has(ci) or cocooned.has(ci) or cooldown.has(ci) or fled.has(ci) or gone.has(ci) or int(hammered.get(ci, 0)) >= HAMMER_BREAKS:
		return false  # (Silenced, in a cocoon, cooling down, or broken by the Hammer)
	var c := run.card_at(ci)
	var filled: Array = placed.get(ci, [])
	if rolled[r].hidden:
		return k < int(c.get("slots", 1)) and (k >= filled.size() or filled[k] == null)
	if not DiceCards.fits_card(c, int(rolled[r].value), k, filled):
		return false
	if String(run.cards[ci]) == "counter_attack" and alive().all(func(f): return String(f.intent.get("kind", "")) != "attack"):
		return false  # (no enemy is attacking: nothing to counter)
	if not has_target(ci):
		return false  # (Fan the Flames: no enemy is burning)
	return true


## Put die `r` in slot `k` of move `ci`. Returns true when that filled the move: it is then READY (`ready`), and fires
## with fire() (the screen first lets you choose its target, when it has one), or gives its dice back with cancel().
## A face-down die is turned over first: one that doesn't fit bounces back to the tray (a "bounce" event). A tweak move
## (Hype Up, Calm Down) changes the die at once and gives it back (a "tweak" event; never ready).
func place(r: int, ci: int, k: int) -> bool:
	if not can_place(r, ci, k) or ready.has(ci):
		return false
	if rolled[r].hidden:
		rolled[r].hidden = false
		if not can_place(r, ci, k):
			events.append({"type": "bounce", "ci": ci, "r": r})
			return false
	var c := run.card_at(ci)
	if c.has("tweak"):
		var tw: Variant = c.tweak
		match str(tw):
			"opposite":  # (the face across from it: 7 - n on a d6, 11 - n on a d10...)
				var die_i: int = int(rolled[r].die)
				var sides: int = (run.dice[die_i] as Array).size() if die_i >= 0 and int(rolled[r].face) >= 0 else 6
				rolled[r].value = maxi(0, sides + 1 - int(rolled[r].value))
			"intuition":
				rolled[r].value = intuition
			"reroll":  # (a new roll of the same die: its paint and carving come with the new face)
				var di: int = int(rolled[r].die)
				rolled[r] = _rolled(di, run.roll(di)) if int(rolled[r].face) >= 0 else _rolled(di, -1)
			_:
				rolled[r].value = maxi(0, int(rolled[r].value) + int(tw))
		tweaks[ci] = int(tweaks.get(ci, 0)) + 1
		if int(tweaks[ci]) >= int(c.uses):
			spent[ci] = true
		events.append({"type": "tweak", "r": r, "by": int(c.tweak)})
		return false
	var slots := int(c.get("slots", 1))
	var filled: Array = placed.get(ci, [])
	var dice_in: Array = placed_dice.get(ci, [])
	while filled.size() < slots:
		filled.append(null)
		dice_in.append(-1)
	filled[k] = int(rolled[r].value)
	dice_in[k] = r
	placed[ci] = filled
	placed_dice[ci] = dice_in
	rolled[r].used = true
	if filled.any(func(v): return v == null):
		return false
	if c.get("merge", false):  # (Stack: the first die becomes the total and comes back; the second is spent)
		var total := 0
		for v in filled:
			total += int(v)
		rolled[int(dice_in[0])].value = total
		rolled[int(dice_in[0])].used = false
		placed.erase(ci)
		placed_dice.erase(ci)
		tweaks[ci] = int(tweaks.get(ci, 0)) + 1
		if int(tweaks[ci]) >= int(c.uses):
			spent[ci] = true
		events.append({"type": "tweak", "r": int(dice_in[0]), "by": 0})
		return false
	ready[ci] = filled
	return true


## The enemies a ready move can be aimed at (Counter Attack: only the attacking ones; never the Matron behind her
## hedges). Empty: it has no target.
func targets_for(ci: int) -> Array:
	if not bool(run.card_at(ci).get("target", false)):
		return []
	var id: String = run.cards[ci]
	var out := []
	for i in foes.size():
		var f: Foe = foes[i]
		if f.dead() or f.shielded():
			continue
		if id == "counter_attack" and String(f.intent.get("kind", "")) != "attack":
			continue
		if _needs_burn(ci) and f.burn <= 0:
			continue
		out.append(i)
	return out


## Fan the Flames (not boosted): only a burning enemy can be aimed at.
func _needs_burn(ci: int) -> bool:
	var c := run.card_at(ci)
	return c.get("needs_burn", false) and String(c.get("up", "")) != "boost"


## Has the move something it can be used on (Fan the Flames: a burning enemy; the card is dimmed when not)?
func has_target(ci: int) -> bool:
	if not _needs_burn(ci):
		return true
	return alive().any(func(f): return f.burn > 0 and not f.shielded())


## A ready move fires, at enemy `target` (-1: none / the first one). Upgraded with a second die ("per_die"): once for
## each die.
func fire(ci: int, target := -1) -> void:
	if not ready.has(ci):
		return
	var id: String = run.cards[ci]
	var c := run.card_at(ci)
	var filled: Array = ready[ci]
	var paints: Array = placed_dice.get(ci, []).map(func(r): return String(rolled[int(r)].paint) if int(r) >= 0 else "")
	placed_dice_last[ci] = placed_dice.get(ci, []).duplicate()
	ready.erase(ci)
	placed.erase(ci)
	placed_dice.erase(ci)
	if ignited.has(ci):  # (Ignite: using it burns you)
		events.append({"type": "ignite_burns", "n": IGNITE_DMG, "ci": ci})
		_hurt_player(IGNITE_DMG, true)
	_dmg_mult = (2 if "red" in paints else 1) * (2 if skull else 1)
	_shield_mult = (2 if "blue" in paints else 1) * (2 if guard else 1)
	_burn_mult = 2 if "orange" in paints else 1
	if "yellow" in paints:
		run.leaves += 3 * paints.count("yellow")
		events.append({"type": "gold", "n": 3 * paints.count("yellow")})
	_damaged.clear()
	uses[ci] = int(uses.get(ci, 0)) + 1
	var boost: bool = String(c.get("up", "")) == "boost"
	var alt: bool = String(c.get("up", "")) == "alt"
	if c.get("fragile", false):
		gone[ci] = true  # (Fragile: gone from this fight)
	if id == "flee":  # (the die stays in the move: it isn't rolled while it does)
		var r0: int = int(placed_dice_last.get(ci, [-1])[0])
		if r0 >= 0:
			var d0: Dictionary = rolled[r0]
			fled[ci] = {"die": int(d0.die), "turns": 1 if boost else 2, "value": int(d0.value), "paint": d0.paint, "carve": d0.carve}
	if c.get("per_die", false):
		for v in filled:
			if not over:
				_fire(id, [v], target, boost, alt)
	else:
		_fire(id, filled, target, boost, alt)
	for f: Foe in _damaged:  # (Thorns: each enemy this move hurt hurts you back, once)
		if f.thorns > 0 and not over:
			events.append({"type": "thorns", "foe": foes.find(f), "n": f.thorns})
			_hurt_player(f.thorns)
	_dmg_mult = 1
	_shield_mult = 1
	_burn_mult = 1
	if not bool(c.get("repeatable", false)) and not ("black" in paints):
		spent[ci] = true  # (a Black die doesn't use the move up)
	if c.has("cooldown"):
		cooldown[ci] = int(c.cooldown) + 1  # (not this turn, nor the next one(s))
	_check_end()


## A ready card is put back without firing: its dice go back to the tray.
func cancel(ci: int) -> void:
	for r in placed_dice.get(ci, []):
		if int(r) >= 0:
			rolled[int(r)].used = false
	ready.erase(ci)
	placed.erase(ci)
	placed_dice.erase(ci)


## Take a die back out of a card that isn't full yet (a two-slot card with one die in it).
func take_back(ci: int, k: int) -> void:
	var filled: Array = placed.get(ci, [])
	var dice_in: Array = placed_dice.get(ci, [])
	if ready.has(ci) or k >= filled.size() or filled[k] == null:
		return
	rolled[int(dice_in[k])].used = false
	filled[k] = null
	dice_in[k] = -1
	if filled.all(func(x): return x == null):
		placed.erase(ci)
		placed_dice.erase(ci)


## Good Ol' Wizard: can die `r` interrupt spell `k` of enemy `fi`? (A face-down die may be tried: interrupt() turns it.)
func can_interrupt(r: int, fi: int, k: int) -> bool:
	if over or r < 0 or r >= rolled.size() or rolled[r].used or rolled[r].frozen or fi < 0 or fi >= foes.size():
		return false
	var f: Foe = foes[fi]
	if f.dead() or k < 0 or k >= f.spells.size():
		return false
	return rolled[r].hidden or int(rolled[r].value) == int(f.spells[k].cut)


func interrupt(r: int, fi: int, k: int) -> bool:
	if not can_interrupt(r, fi, k):
		return false
	var f: Foe = foes[fi]
	if rolled[r].hidden:
		rolled[r].hidden = false
		if int(rolled[r].value) != int(f.spells[k].cut):
			events.append({"type": "bounce_spell", "foe": fi, "k": k, "r": r})
			return false
	rolled[r].used = true
	var sp: Dictionary = f.spells.pop_at(k)
	events.append({"type": "interrupted", "foe": fi, "name": String(sp.name)})
	return true


func _target(target: int) -> Foe:
	var live := alive().filter(func(x): return not x.shielded())
	if live.is_empty():
		return null
	if target >= 0 and target < foes.size() and not foes[target].dead() and not foes[target].shielded():
		return foes[target]
	return live[0]


func _fire(id: String, d: Array, target: int, boost := false, alt := false) -> void:
	var v: int = d[0]
	var total := 0
	for x in d:
		total += int(x)
	var t := _target(target)
	events.append({"type": "card", "id": id, "value": v})
	match id:
		"punch":
			_hit(t, v + (1 if boost else 0))
		"block":
			_shield(v + (2 if boost else 0))
		"counter_attack":
			if t != null and String(t.intent.get("kind", "")) != "attack":
				var att := alive().filter(func(f): return String(f.intent.get("kind", "")) == "attack" and not f.shielded())
				t = att[0] if not att.is_empty() else t
			_hit(t, maxi(0, (12 if boost else 10) - v))
		"thousand_cuts":
			for k in v + (2 if boost else 0):
				_hit(t if t != null and not t.dead() else _target(-1), 1)
		"discombobulate":
			_hit(t, 14 if boost else 10)
			_stun(t, 1)
		"high_knee":
			_hit(t, (3 if boost else 2) * v)
		"uppercut":
			_hit(t, v + (7 if boost else 4))
		"double_down":
			_hit(t, total + (4 if boost else 0))
		"odd_jab":
			_hit(t, v + (3 if boost else 1))
		"parry":
			_shield(maxi(0, v - 2))
			_weaken(t, 3 if boost else 1)
		"haymaker":
			_hit(t, 20 if boost else 14)
		"firebrand":
			_burn(t, v + (2 if boost else 0))
		"shield_bash":
			_shield(maxi(0, (8 if boost else 6) - v))
			_hit(t, block)
		"sweep":
			for f in alive():
				if not f.shielded():
					_hit(f, v + (2 if boost else 0))
		"mirror_guard":
			_shield((3 if boost else 2) * total)
		"burn_burn_burn":
			for f in alive():
				if not f.shielded():
					_burn(f, v)
			for f in alive():
				if f.burn > 0 and f.impervious <= 0:
					f.burn *= 2
					events.append({"type": "foe_burn", "foe": foes.find(f), "n": f.burn / 2})
		"self_immolate":
			_burn(t, (3 if boost else 2) * v)
			burn += v
			events.append({"type": "debuff", "foe": -1, "what": "Burn %d" % v})
		"flurry":
			flurry += maxi(0, (3 if boost else 2) - v)
			events.append({"type": "flurry", "n": flurry})
		"freeze_burn":
			_burn(t, maxi(0, (8 if boost else 6) - v))
		"elbow":
			_hit(t, (3 if boost else 2) * v)
		"finger_pistol":
			_hit(t, 15 if boost else 10)
		"spirit_bomb":
			_hit(t, (4 if boost else 3) * total)
		"lariat":
			_hit(t, (3 if boost else 2) * absi(int(d[0]) - int(d[1])))
		"body_slam":
			events.append({"type": "self_hit", "n": v})
			_hurt_player(v, true)
			if not over:
				_hit(t, (4 if boost else 3) * v)
		"headbutt":
			var self_dmg := maxi(0, (5 if boost else 6) - v)
			events.append({"type": "self_hit", "n": self_dmg})
			_hurt_player(self_dmg, true)
			if not over:
				_stun(t, 1)
		"eye_poke":
			for f in alive():
				if not f.shielded():
					_weaken(f, v + (1 if boost else 0))
		"flee":
			ethereal = true
			events.append({"type": "you_ethereal"})
		"jab":
			_hit(t, v)
			_vulnerable(t, 2 if boost else 1)
		"roundhouse_kick":
			var left := (3 if boost else 2) * v
			var to := t
			while left > 0 and to != null and not over:
				var before := to.hp + to.block
				_hit(to, left)
				left = maxi(0, left - before) if to.dead() else 0
				to = _target(-1) if left > 0 else null
		"whirlwind_punches":
			for f in alive():
				if not f.shielded():
					_hit(f, maxi(0, (9 if boost else 7) - v))
		"redirect":
			if t != null and String(t.intent.get("kind", "")) == "attack":
				t.redirect = true
				events.append({"type": "foe_redirect", "foe": foes.find(t)})
		"arm_bar":
			if t != null and t.weak > 0:
				_vulnerable(t, 5 if boost else 3)
			_hit(t, int(d[0]) + (int(d[1]) if alt else 0))
		"quick_feet":
			dodge += v if boost else 1
			events.append({"type": "dodge_up"})
		"faceplant":
			events.append({"type": "self_hit", "n": v})
			_hurt_player(v, true)
			dodge += 2 if boost else 1
			events.append({"type": "dodge_up"})
		"cover_up":
			_shield(total + (3 if boost else 0))
		"dance":
			_shield(maxi(0, (8 if boost else 6) - v))
		"bear_hug":
			var x := (3 if boost else 2) * maxi(0, int(d[0]) - int(d[1]))
			_shield(x)
			_hit(t, x)
		"focus":
			for k in (4 if boost else 3):
				rolled.append(_rolled(-1, -1))
			events.append({"type": "extra_dice", "n": 4 if boost else 3})
		"fire_starter":
			_burn(t, v + (1 if boost else 0))
		"ignite":
			if t != null and t.burn > 0:
				var b := t.burn
				t.burn = 0
				events.append({"type": "foe_burn_out", "foe": foes.find(t), "n": b})
				_hit(t, (3 if boost else 2) * b)
		"fan_the_flames":
			if t != null and (boost or t.burn > 0):
				_burn(t, v)
		"fire_fist":
			fire_fist += v
			events.append({"type": "buff", "what": "Fire Fist: +%d Burn per hit" % fire_fist})
		"smoke_screen":
			var lit := alive().filter(func(f): return f.burn > 0).size()
			_shield((v + (2 if boost else 0)) * lit)
		"smite":
			if t != null:
				t.smite = 2 if boost else 1
				events.append({"type": "buff", "what": "Smite marked"})
		"feint":
			dodge += 2 if boost else 1
			feint = true
			events.append({"type": "dodge_up"})
		"taunt":
			block = 0
			no_shield = true
			events.append({"type": "buff", "what": "No Shield this turn"})
			for f in alive():
				if not f.shielded():
					_vulnerable(f, 5 if boost else 3)
		"grit":
			events.append({"type": "self_hit", "n": v})
			_hurt_player(v, true)
			if not over:
				_shield(11 if boost else 8)
		"overwhelm":
			overwhelm += v + (1 if boost else 0)
			events.append({"type": "buff", "what": "Overwhelm: +%d Shield per hit" % overwhelm})
		"revenge":
			revenge = {"foe": t, "mult": 3 if boost else 2, "taken": 0}
			events.append({"type": "revenge_set", "foe": foes.find(t)})


func _vulnerable(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		t.vulnerable = maxi(t.vulnerable, n)
		events.append({"type": "foe_vulnerable", "foe": foes.find(t)})


func _stun(t: Foe, n: int) -> void:
	if t != null and not t.dead() and _takes_status(t):
		t.stun += n
		events.append({"type": "stun", "foe": foes.find(t)})


func _weaken(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		t.weak = maxi(t.weak, n)
		events.append({"type": "foe_weak", "foe": foes.find(t)})


## Burn on an enemy (doubled by an Orange die in the move).
func _burn(t: Foe, n: int) -> void:
	if t != null and not t.dead() and n > 0 and _takes_status(t):
		t.burn += n * _burn_mult
		events.append({"type": "foe_burn", "foe": foes.find(t), "n": n * _burn_mult})


## Impervious: no status sticks to it.
func _takes_status(f: Foe) -> bool:
	if f.impervious > 0:
		events.append({"type": "immune", "foe": foes.find(f), "why": "Impervious"})
		return false
	return true


## You gain Shield (doubled by a Blue die in the card, or the Shield carving this turn).
func _shield(n: int) -> void:
	if no_shield:  # (Taunt)
		return
	n *= _shield_mult
	block += n
	events.append({"type": "block", "n": n})


## You hit an enemy for n (a Red die in the card or the Skull carving: double; Weakened: half, rounded down). Its Block
## takes it first. Ethereal, or the Matron behind her hedges: nothing. Deflect: it comes back at you.
func _hit(f: Foe, n: int) -> void:
	if f == null or f.dead():
		return
	if f.ethereal > 0 or f.shielded():
		events.append({"type": "immune", "foe": foes.find(f), "why": "Ethereal" if f.ethereal > 0 else "Behind her hedges"})
		return
	if run.has_artifact("whetstone"):
		n += 1
	n *= _dmg_mult
	if weak > 0:
		n = n / 2
	if f.vulnerable > 0:
		n = n + n / 2
	if f.deflect:  # (Deflect: this one comes back at you)
		f.deflect = false
		events.append({"type": "deflected", "foe": foes.find(f), "n": n})
		_hurt_player(n)
		return
	var soak := mini(f.block, n)
	f.block -= soak
	f.hp = maxi(0, f.hp - (n - soak))
	if n > 0:
		_damaged[f] = true  # (Thorns: a hit, even one its Shield took)
	events.append({"type": "hit", "foe": foes.find(f), "n": n - soak, "blocked": soak})
	_on_hit(f, n)
	if f.dead():
		_on_death(f)
	elif flurry > 0 and n > 0 and not _in_flurry:  # (Flurry: one more blow, after each damage; it doesn't feed itself)
		_in_flurry = true
		var keep := _dmg_mult
		_dmg_mult = 1
		_hit(f, flurry)
		_dmg_mult = keep
		_in_flurry = false


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
	if f.pages > 0:  # (the Pianist: that page is played out; he turns to the next, at full)
		f.pages -= 1
		f.hp = f.max_hp
		f.es.page += 1
		events.append({"type": "page_turn", "foe": foes.find(f), "left": f.pages})
		return
	events.append({"type": "dies", "foe": foes.find(f)})
	if f.cocoon_card >= 0:  # (the Silk Cocoon breaks: your card comes back)
		cocooned.erase(f.cocoon_card)
		events.append({"type": "card_back", "ci": f.cocoon_card})
		f.cocoon_card = -1


func end_turn() -> void:
	if over:
		return
	for ci in silenced.keys():  # (Silence: the turn of yours it covered is over: before the enemies act, so a new Silence covers your next turn)
		silenced[ci] = int(silenced[ci]) - 1
		if int(silenced[ci]) <= 0:
			silenced.erase(ci)
	_enemy_phase = true
	flurry = 0  # ("this turn": your turn is over)
	fire_fist = 0
	overwhelm = 0
	for f: Foe in foes.duplicate():
		var i := foes.find(f)
		if f.dead() or over:
			continue
		f.block = 0
		f.ethereal = 0  # (Ethereal lasts until its own next turn)
		f.deflect = false
		f.impervious = maxi(0, f.impervious - 1)
		f.vulnerable = maxi(0, f.vulnerable - 1)
		if f.burn > 0:
			f.hp = maxi(0, f.hp - f.burn)
			events.append({"type": "burn", "foe": i, "n": f.burn})
			f.burn -= 1
			if f.dead():
				_on_death(f)
				continue
		if f.stun > 0:
			f.stun -= 1
			events.append({"type": "foe_stunned", "foe": i})
		else:
			_act(f, f.intent)
		f.redirect = false
		f.weak = maxi(0, f.weak - 1)
		if not f.dead():
			_plan(f)
	_enemy_phase = false
	weak = maxi(0, weak - 1)
	vulnerable = maxi(0, vulnerable - 1)
	_check_end()
	if not over:
		_start_turn()


func _act(f: Foe, m: Dictionary) -> void:
	var i := foes.find(f)
	match String(m.kind):
		"attack":
			for h in int(m.get("hits", 1)):
				var n: int = int(m.n) + f.power
				if f.weak > 0:
					n = n / 2
				if run.has_artifact("leather_armor"):
					n = maxi(0, n - 1)
				if f.redirect:  # (Redirect: the blow goes at someone else: any of them, itself too)
					var others := alive()
					var to: Foe = others[run.rng.randi() % others.size()]
					var soak := mini(to.block, n)
					to.block -= soak
					to.hp = maxi(0, to.hp - (n - soak))
					events.append({"type": "redirected", "foe": i, "to": foes.find(to), "n": n - soak})
					_on_hit(to, n)  # (it counts as your hit: Smite)
					if to.dead():
						_on_death(to)
					continue
				if feint and h == 0:  # (Feint: it attacked you, hit or not: it is Vulnerable now)
					_vulnerable(f, 1)
				if ethereal:  # (Flee: you are Ethereal: it passes through)
					events.append({"type": "dodged", "foe": i})
					continue
				if dodge > 0:  # (the Wing carving: this one misses)
					dodge -= 1
					events.append({"type": "dodged", "foe": i})
					continue
				events.append({"type": "attack", "foe": i, "n": n})
				_hurt_player(n)
				if over:
					return
		"block":
			f.block += int(m.n)
			events.append({"type": "foe_block", "foe": i, "n": int(m.n)})
		"heal":
			var who: Foe = _lord(f) if String(m.get("who", "")) == "lord" else null
			if who == null:
				var hurt := alive().filter(func(x): return x.hp < x.max_hp)
				who = f if hurt.is_empty() or f.hp < f.max_hp else hurt[0]
			var h := mini(int(m.n), who.max_hp - who.hp)
			who.hp += h
			events.append({"type": "foe_heal", "foe": foes.find(who), "n": h})
		"weak":
			weak = maxi(weak, int(m.n))
			events.append({"type": "debuff", "foe": i, "what": "Weakened"})
		"burn":
			burn += int(m.n)
			events.append({"type": "debuff", "foe": i, "what": "Burn %d" % int(m.n)})
		"silence":
			var free := []
			for ci in run.cards.size():
				if not silenced.has(ci):
					free.append(ci)
			for k in mini(int(m.n), free.size()):
				var ci: int = free.pop_at(run.rng.randi() % free.size())
				silenced[ci] = int(m.turns)
			events.append({"type": "debuff", "foe": i, "what": "Silenced"})
		"thorns":
			f.thorns += int(m.n)
			events.append({"type": "foe_thorns", "foe": i, "n": int(m.n)})
		"ethereal":
			f.ethereal = 1
			events.append({"type": "foe_ethereal", "foe": i})
		"hammer":
			var most := -1
			for ci in run.cards.size():
				if int(hammered.get(ci, 0)) < HAMMER_BREAKS and (most < 0 or int(uses.get(ci, 0)) > int(uses.get(most, 0))):
					most = ci
			if most >= 0:
				hammered[most] = int(hammered.get(most, 0)) + 1
				events.append({"type": "debuff", "foe": i, "what": "Hammered: %s %d/%d" % [run.card_at(most).name, hammered[most], HAMMER_BREAKS]})
		"vulnerable":
			vulnerable = maxi(vulnerable, int(m.n))
			events.append({"type": "debuff", "foe": i, "what": "Vulnerable"})
		"stun":
			stunned = 1
			events.append({"type": "debuff", "foe": i, "what": "Stunned"})
		"power":
			if String(m.get("who", "")) == "wizard_team":  # (Alacrity: him and his Forge Spirits)
				for x in alive():
					if x == f or x.id.begins_with("forge_spirit"):
						x.power += int(m.n)
						events.append({"type": "foe_power", "foe": foes.find(x), "n": int(m.n)})
			else:
				var to: Foe = _lord(f) if String(m.get("who", "")) == "lord" else f
				if to == null:
					to = f
				to.power += int(m.n)
				events.append({"type": "foe_power", "foe": foes.find(to), "n": int(m.n)})
		"cleanse":  # (the Retainer: his lord's statuses are gone, and none sticks to him until his next turn)
			var lord: Foe = _lord(f) if _lord(f) != null else f
			lord.burn = 0
			lord.weak = 0
			lord.stun = 0
			lord.impervious = 2
			events.append({"type": "foe_cleansed", "foe": foes.find(lord)})
		"cleanse_self":
			f.burn = 0
			f.weak = 0
			f.stun = 0
			events.append({"type": "foe_cleansed", "foe": i})
		"freeze":
			freeze_next = 1
			events.append({"type": "debuff", "foe": i, "what": "Freeze: 1 die next turn"})
		"ignite":
			var cards := []
			for ci in run.cards.size():
				if not _ignite_next.has(ci):
					cards.append(ci)
			for k in mini(int(m.n), cards.size()):
				_ignite_next[cards.pop_at(run.rng.randi() % cards.size())] = true
			events.append({"type": "debuff", "foe": i, "what": "Ignite"})
		"confuse":
			if m.get("fight", false):
				confuse_fight = true
			else:
				confuse_next = true
			events.append({"type": "debuff", "foe": i, "what": "Confused"})
		"hold":
			pass  # (a cocoon: it just hangs there)
		"recharge":
			events.append({"type": "foe_rests", "foe": i})
		"deflect":
			f.deflect = true
			events.append({"type": "foe_deflect", "foe": i})
		"steal_card":
			_steal_card(f)
		"summon":
			_summon(f, m)
		"clock":
			events.append({"type": "foe_clock", "foe": i, "n": int(m.n)})
		"play":
			pass  # (he plays on: the piece itself is the threat, see piece_ended)
		"invoke":
			for sp in f.spells:
				if over or f.dead():
					break
				events.append({"type": "casts", "foe": i, "name": String(sp.name)})
				_act(f, sp.cast)
			f.spells.clear()
	if m.has("also") and not over:
		_act(f, m.also)


## The Retainer's lord (the Samurai), alive.
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
	events.append({"type": "spawn", "foe": foes.size() - 1, "from": foes.find(f)})
	events.append({"type": "debuff", "foe": foes.find(f), "what": "%s is taken into a cocoon" % run.card_at(ci).name})


func _summon(f: Foe, m: Dictionary) -> void:
	var ids: Array = m.get("ids", ["forge_spirit"])
	for k in int(m.get("n", 1)):
		if alive().size() >= MAX_FOES:
			break
		var c := _spawn_def(EnemyDefs.get_def(String(ids[run.rng.randi() % ids.size()])))
		_plan(c)
		events.append({"type": "spawn", "foe": foes.size() - 1, "from": foes.find(f)})
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
	events.append({"type": "piece_ends"})


func _hurt_player(n: int, through_block := false) -> void:
	if vulnerable > 0 and not through_block:
		n = n + n / 2
	var soak := 0 if through_block else mini(block, n)
	block -= soak
	run.hp = maxi(0, run.hp - (n - soak))
	if _enemy_phase and not revenge.is_empty():  # (Revenge: it is counted)
		revenge.taken = int(revenge.taken) + (n - soak)
	if run.hp <= 0:
		over = true
		won = false


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
			s = "Weaken"
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
		"vulnerable":
			s = "Vulnerable"
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
		"invoke":
			s = "✨ Casts his spells"
	if m.has("also"):
		s += "  " + intent_text(m.also, f)
	return s
