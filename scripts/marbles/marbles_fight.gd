class_name MarblesFight
extends StageFight
## The Marbles mode (2026-11-21): one fight. The enemy side is Die on Stage's (StageFight: number HP, intents, the Act 1
## enemies as the user set them); your side is marbles and the user's new cards (MarbleCards).
##
## Your turn: you get marbles (3 from the bag; no free marble of each colour on the first turn since 2026-11-23;
## more with Tail Wind / Updraft / Aole's Last Wish). Chanted marbles go to the recycle bin (used_pile); an empty bag
## refills from it; with both empty there is nothing more to draw that turn (the user, 2026-11-22). Your storage row keeps
## the marbles you didn't chant, MAX_ROW at most. Put marbles in the chant (order counts, at most MAX_CHANT), press Chant: every
## card whose pattern is in the chant wakes, and the carved marbles its pattern counts work for it (_carve: Sword +3
## damage, Skull x1.5 damage, Shield +3 Shield, Wing x1.5 Shield for that card this turn; Coin +1 coin, Heart heal 2,
## Fist +1 Power, Ghost +1 Dodge now; Star: any colour; Spent was removed 2026-11-22). Every card wakes: once, or (Repeatable N) once per separate, non-overlapping copy, up to N.
## Cast each one (a target if it needs one). End turn: the chanted marbles are used; the ones you didn't chant stay in
## your storage row for your next turn (the user, 2026-11-22); the enemies act.
##
## Damage of a card, per hit: its number + your Power, then the chant's Sword / Skull in order, All-Out; Weakened
## halves it; then the enemy's Expose adds and its Armor takes off; Vulnerable +50%. (Hail doubles Power, Expose,
## Vulnerable and the carvings.) Heed My Call adds to every hit of yours.

const MAX_CHANT := 10  # (the main game's chant row: ten rings, the user 2026-11-22)
const MAX_ROW := 10  # (your storage row holds at most this many marbles; the rest wait in the bag, the user 2026-11-22)
const FIRST_TURN_EXTRA := []  # (no free marble of each colour on the first turn any more, the user 2026-11-23)
const SKULL := 1.5
const WING := 1.5
const SWORD := 3
const SHIELD_SYM := 3

var mrun: MarblesRun
var _damaged := {}  # the enemies the card being cast has damaged (for their Thorns)
var draw_pile: Array = []  # indices into mrun.bag
var used_pile: Array = []
var hand: Array = []  # this turn's marbles not in the chant: {c, sym, src (bag index, -1: not from the bag), uid, frozen, hidden}
var chant: Array = []  # the chant, in order (same dicts)
var chanted := false
var charges := {}  # card index -> casts left this turn
var casts := {}  # card index -> casts this turn
var dmg_ops: Array = []  # the chant's Sword / Skull marbles this turn, in reading order: ["add", n] / ["mul", x] (all your damage cards)
var shield_ops: Array = []  # its Shield / Wing marbles (all your Shield cards)
var _cur_ci := -1  # the card whose effect is running
var _note := -1  # (while the chant is read: the marble being read; its events carry it as "note")
var my_power := 0
var my_thorns := 0
var powers := {}  # Power card id -> its level (on for the rest of the fight)
var power_used := {}  # card index -> true (a Power is cast once)
var durab := {}  # card index -> Durability left this fight
var charge := {}  # card index -> charges (Geyser, Elize's Hesitation)
var grow := {}  # card index -> its growing number this fight (Wave, Fire Storm, Stream, Warm Up)
var cast_prev := {}  # card index -> true: cast last turn (Warm Up)
var next_extra := 0  # marbles more next turn
var dealt_turn := 0  # damage you dealt this turn (Carrot and Stick)
var water_casts := 0  # water-contained cards cast this turn (Cyclone)
var cast_any := false  # a spell has been cast this turn (Might of the First Apostle)
var triggers := {}  # card id -> its level: "each time ..." cards cast this turn (Water Gun, Set Fire to the Rain, Pyrophiliac, Adam's Fist, Sadistic Nature)
var moth: Foe = null  # Moth to Flame: every attack goes at it this turn
var bites := {}  # card index -> Bite's level (Curse of the Night turned it into a Bite for the fight)
var finger: Foe = null  # Adam's Finger's enemy
var thunder_k := 1  # Thunderstorm: hits this turn
var air_bonus := 0  # Air: your Burn cards' Burn +this
var dodges_gained := 0
var shield_lost := 0  # (Flame of Vengeance)
var extensions := 0
## The carnival artifacts (2026-11-27, see Artifacts): what they count during the fight.
var token_count := {"F": 0, "W": 0, "A": 0, "all": 0}  # marbles chanted this fight, by colour (the Tokens)
var token_next: Array = []  # temporary marbles the Tokens give next turn ("F", "W", "A", or "*": any colour)
var hammer := 0  # turns in a row without attacking (the Hammer: +30% each on your next attack)
var _hit_this_turn := false  # a card of yours dealt damage this turn (the Hammer)
var kunai_n := 0  # times you have dealt damage (the Kunai: every 3rd, 1 more)
var _kunai := false  # (the Kunai's own hit: it doesn't count)
var glow_done := false  # the Glow Stick has gone off this fight
var pact := 0  # the Blood Pact's Power left this fight
var thorn_heal := 0.0  # the Thorn Heart's healing not yet given (20% of your Thorns damage, whole points only)
var mono := false  # this turn's chant is of one colour only (the Monochrome Prism)
var encore := 0  # Ticket of Encore: the next card(s) you cast trigger a second time
var pending_replace := -1  # a card that replaces itself (Alchemy, Random Things Go!): the screen asks which backpack card
var hp_loan := 0  # A Daughter's Secret: max HP taken for this fight (given back by finish())
var _uid := 0
var _hail := false
var _casting := ""
var _depth := 0
var _no_heed := false
var _vs: Foe = null  # (card_text_vs: the enemy the card's damage numbers are worked out against)


func setup(p_run: MarblesRun, ids: Array) -> void:
	mrun = p_run
	for i in mrun.bag.size():
		draw_pile.append(i)
	_shuffle(draw_pile)
	burn = int(mrun.start.get("burn", 0))  # (an event's Burn, Stun for your next fight)
	stunned = int(mrun.start.get("stun", 0))
	super.setup(p_run, ids)
	block += int(mrun.start.get("shield", 0))  # (an event's Shield: the Mausoleum's blue light)
	if run.has_artifact("iron_ward"):
		block += 6
	if run.has_artifact("blood_pact"):
		pact = 3
	CombatLog.line("  [start, after event Shield / Iron Ward] YOU: %s" % _me_text())


func _me_extra() -> String:
	var pw := []
	for k in powers:
		pw.append("%s L%d" % [k, int(powers[k])])
	return ", Power %d (own %d), Thorns %d, Powers [%s], dmg carvings %s, shield carvings %s" % [power_now(), my_power, my_thorns, ", ".join(pw), str(dmg_ops), str(shield_ops)]


func _log_fight_start() -> void:
	super()
	for ci in run.cards.size():
		var c := card(ci)
		CombatLog.line("  card %d: %s [pattern %s]: %s" % [ci, String(c.get("name", "?")), String(c.get("pattern", "")), String(c.get("text", ""))])
	CombatLog.line("  bag: %d marbles" % mrun.bag.size())


# ------------------------------------------------------------------ the enemies: Die on Stage's (B, the user 2026-11-21)
## Marble mode's own changes to them (data/marble_enemies.json): every enemy's moves go in order, never at random;
## the Leech Bat and the Hush Moth as the user set them; the Mirror Fairy attacks or Dodges and Blinds you all fight.
const MARBLE_MOVES := {
	"leech_bat": [{"kind": "attack", "n": 3, "hits": 1}, {"kind": "attack", "n": 3, "hits": 2}, {"kind": "attack", "n": 3, "hits": 3}, {"kind": "power", "n": 1, "who": ""}],
	"hush_moth": [{"kind": "attack", "n": 5, "hits": 1}, {"kind": "silence", "turns": 1, "n": 1}],
	"mirror_fairy": [{"kind": "attack", "n": 6, "hits": 1}, {"kind": "block", "n": 3}],  # (no Dodge: 3 Shield, the user 2026-11-23)
	"green_slime": [{"kind": "attack", "n": 6, "hits": 1}, {"kind": "heal", "n": 2, "who": ""}],  # (it heals 2 only, the user 2026-11-23)
	"zephling": [{"kind": "attack", "n": 3, "hits": 1}, {"kind": "weak", "n": 1}],  # (no Dodge: it Weakens you for 1 turn, the user 2026-11-22)
	# the lings hit for 3 (the user 2026-11-22), their other move as before
	"ashling": [{"kind": "attack", "n": 3, "hits": 1}, {"kind": "power", "n": 1, "who": ""}],
	"iceling": [{"kind": "attack", "n": 3, "hits": 1}, {"kind": "block", "n": 2}],
}
const MARBLE_HP := {"leech_bat": 20, "hush_moth": 20, "ashling": 6, "iceling": 6, "zephling": 6}  # (the lings: 6, the user 2026-11-22)
const MARBLE_FLYERS := ["winged_tortoise", "leech_bat"]  # (the Hush Moth does not fly, the user 2026-11-23)
const LIFESTEAL := ["leech_bat"]  # (its attacks heal it by the HP you lose)
const BLINDERS := ["mirror_fairy"]  # (while it is in the fight your marbles come out as "?")
## Orb HP on intents: a pattern shown over the intent; chant it and the intent is cancelled. The Matron's summoning is
## the user's (WAWA); the bosses' are PLACEHOLDERS until the user sets them.
const MATRON_ORBS := "WAWA"
const WIZARD_ORBS := {"cold_snap": "WAW", "ghost_walk": "WWA", "ice_wall": "WWF", "emp": "AFA", "tornado": "AAW", "alacrity": "FAF",
	"sun_strike": "FFF", "forge_spirit": "FFW", "chaos_meteor": "FFA", "deafening_blast": "WAF"}
const CHARGE_ORBS := {30: "WAAW", 20: "AWA"}  # (the Yin Yang Beast's Charge, its Cubs')


static func hp_of(id: String, act := 0) -> int:
	if act == 1 and ACT1_HP.has(id):
		return int(ACT1_HP[id])
	var hp := int(MARBLE_HP.get(id, StageFight.base_hp(id)))
	return maxi(1, roundi(hp * ACT1_NERF)) if act == 1 and not (id in NO_NERF) else hp


## Act 1 is gentler (the user, 2026-11-22): every enemy there has 30% less HP and deals 30% less damage per hit
## (rounded, at least 1).
const ACT1_NERF := 0.7
## Act 1 HP set exactly (the user 2026-11-23: no 30% cut on top).
const ACT1_HP := {"bramble_back": 17, "greenseer": 15, "rolling_bear": 20}
const NO_NERF := ["ashling", "iceling", "zephling"]  # (the lings are set as they are: 6 HP, hits of 3, the user 2026-11-22)


static func _nerf_move(mv: Dictionary) -> void:
	if String(mv.get("kind", "")) == "attack" and mv.has("n"):
		mv.n = maxi(1, roundi(int(mv.n) * ACT1_NERF))
	if mv.get("also", null) is Dictionary:
		_nerf_move(mv.also)


func _spawn_def(d: Dictionary, at := -1) -> Foe:
	var f := super._spawn_def(d, at)
	f.random_moves = false
	if MARBLE_MOVES.has(f.id):
		f.moves = (MARBLE_MOVES[f.id] as Array).duplicate(true)
		f.move_i = 0
	if MARBLE_HP.has(f.id):
		f.max_hp = int(MARBLE_HP[f.id])
		f.hp = f.max_hp
	if mrun.act == 1 and not (f.id in NO_NERF):
		f.max_hp = maxi(1, roundi(f.max_hp * ACT1_NERF))
		f.hp = f.max_hp
		f.moves = f.moves.duplicate(true)  # (copies: the lists can be shared with the enemy data)
		f.moves2 = f.moves2.duplicate(true)
		for mv in f.moves + f.moves2:
			_nerf_move(mv)
	if mrun.act == 1 and ACT1_HP.has(f.id):
		f.max_hp = int(ACT1_HP[f.id])
		f.hp = f.max_hp
	f.es.flying = f.id in MARBLE_FLYERS
	return f


func _plan(f: Foe) -> void:
	f.random_moves = false
	super._plan(f)
	if String(f.intent.get("kind", "")) == "mirror":  # (no secret mirror in Marble mode: she Dodges)
		f.deflect = false
	for k in f.spells.size():
		var sp: Dictionary = f.spells[k]
		if not sp.has("orbs"):
			sp = sp.duplicate(true)  # (the Wizard's spells come from a constant: a copy of each)
			f.spells[k] = sp
			if String(sp.get("id", "")) == "matron_call":
				sp["orbs"] = MATRON_ORBS
			elif sp.get("charge", false):
				sp["orbs"] = String(CHARGE_ORBS.get(int(sp.n), "WAW"))
			else:
				sp["orbs"] = String(WIZARD_ORBS.get(String(sp.get("id", "")), "FWA"))


## The chant cancels every intent whose orb HP it holds.
func _cancel_intents() -> void:
	for i in foes.size():
		var f: Foe = foes[i]
		if f.dead():
			continue
		for k in range(f.spells.size() - 1, -1, -1):
			var sp: Dictionary = f.spells[k]
			if String(sp.get("orbs", "")) != "" and occurrences(String(sp.get("orbs", ""))) > 0:
				f.spells.remove_at(k)
				_ev({"type": "interrupted", "foe": i, "name": String(sp.get("name", "It"))})
		if f.spells.is_empty() and String(f.intent.get("kind", "")) in ["invoke", "charging"]:
			f.intent = {"kind": "hold"}


func targets_for(ci: int) -> Array:
	return targets(ci)


func has_target(ci: int) -> bool:
	return not needs_target(ci) or not targets(ci).is_empty()


var _lost := 0  # (the HP you lost to the last blow: a Leech Bat drinks it)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := mrun.rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ------------------------------------------------------------------ cards

## The card in slot ci now (a Bite, if Curse of the Night made it one).
func card(ci: int) -> Dictionary:
	if bites.has(ci):
		return MarbleCards.card("bite", int(bites[ci]))
	var c := mrun.card_at(ci)
	if String(c.get("id", "")) == "water_gun" and not c.has("parts"):  # (its X now: what it deals if cast now)
		c.text = String(c.text).replace("Deal %d damage" % int(c.p.x), "Deal %d damage" % _water_gun_x(int(c.p.x)))
	if String(c.get("id", "")) == "focus_fire" and not c.has("parts"):  # (its hits now: 1, plus the Winds read so far)
		var fh := focus_hits()
		c.text = String(c.text).replace(", 1 time.", ", %d %s." % [fh, "time" if fh == 1 else "times"])
	if not c.has("parts") and c.has("text"):
		c.text = _live_numbers(String(c.text), ci)
	if run.has_artifact("leather_glove") and c.has("p") and (c.p as Dictionary).has("dur"):
		c.p.dur = int(c.p.dur) + 1
	if run.has_artifact("shopping_list") and c.has("p") and String(c.get("pattern", "")).length() >= 3:
		c.p.rep = int(c.p.get("rep", 1)) + 1
		c.text = String(c.get("text", "")) + " +1 Repeatable (Shopping List)."
	return c


## Focus Fire's hits: 1, plus 1 for each Wind marble of the chant (once spoken; while it is read, the ones read so far).
func focus_hits() -> int:
	if not chanted:
		return 1
	var n := 1
	var upto := chant.size() if _note < 0 else mini(chant.size(), _note + 1)
	for k in upto:
		if String(chant[k].get("sym", "")) != "star" and String(chant[k].c) == "A":
			n += 1
	return n


static var _re_dmg: RegEx
static var _re_sh: RegEx
static var _re_burn: RegEx


## Every number on a card as it is now (the user 2026-11-22: "all numbers on all cards are variable"): its damage
## (carvings, your Power, a number that grows: Stream, Warm Up), its Shield (Shield / Wing marbles, Stream), its Burn
## (Air, Adam's Awakening). Per-marble numbers ("for each") stay as written. Durability: MarbleBridge (uses left).
func _live_numbers(words: String, ci: int) -> String:
	if _re_dmg == null:
		# (a sentence of its own: "deal ... to a random enemy" inside another sentence is not the card's own damage)
		_re_dmg = RegEx.create_from_string("(Deal )(\\d+)( damage)(?! for each)")
		_re_sh = RegEx.create_from_string("(Gain |damage and gain )(\\d+)( Shield)(?! for each)")
		_re_burn = RegEx.create_from_string("(Apply )(\\d+)( Burn)(?! for each)")
	var c := mrun.card_at(ci)
	var id := String(c.get("id", ""))
	var p: Dictionary = c.get("p", {})
	var was := _cur_ci
	var was_casting := _casting
	_cur_ci = ci
	_casting = id
	var was_hail := _hail
	_hail = id == "hail"  # (its words count your Power, carvings, Expose and Vulnerable double)
	var vs := _vs
	var grown := -1  # (a card whose number grows in the fight: its number now)
	match id:
		"stream":
			grown = int(grow.get(ci, int(p.get("x", 1))))
		"warm_up":
			grown = int(grow.get(ci, 0))
		"wave":
			grown = int(grow.get(ci, 1))
		"fire_storm":
			grown = int(grow.get(ci, int(p.get("x", 2))))
	var out := _swap_numbers(words, _re_dmg, func(n: int) -> int:
		var base := card_damage(grown if grown >= 0 else n)
		return shown_damage(base) if vs == null else damage_vs(vs, base))
	out = _swap_numbers(out, _re_sh, func(n: int) -> int: return card_shield_value(grown if grown >= 0 else n))
	out = _swap_numbers(out, _re_burn, func(n: int) -> int: return burn_value(grown if grown >= 0 else n))
	_hail = was_hail
	_cur_ci = was
	_casting = was_casting
	return out


## Each match's number (group 2) replaced by what `now` makes of it.
static func _swap_numbers(words: String, re: RegEx, now: Callable) -> String:
	var out := ""
	var last := 0
	for mt in re.search_all(words):
		out += words.substr(last, mt.get_start() - last)
		out += mt.get_string(1) + str(int(now.call(int(mt.get_string(2))))) + mt.get_string(3)
		last = mt.get_end()
	return out + words.substr(last)


## The card's words worked out against enemy `foe_idx` (aiming at it): "" when the card can't show it.
func card_text_vs(ci: int, foe_idx: int) -> String:
	if foe_idx < 0 or foe_idx >= foes.size() or bites.has(ci) or card(ci).is_empty() or card(ci).has("parts"):
		return ""
	_vs = foes[foe_idx]
	var t := String(card(ci).get("text", ""))
	_vs = null
	return t


## The Burn a card applies of n now (Air, Adam's Awakening; doubled by Burn Burn Burn): as _apply_burn / _burn.
func burn_value(n: int) -> int:
	if _casting in MarbleCards.BURN_CARDS:
		n += air_bonus
	if powers.has("adams_awakening"):
		n += power_now()
	return n * _burn_mult


## Water Gun's X: it starts at its number and grows by that much for each card with Water cast this turn (itself too,
## once it has been cast: its own hit uses the X it showed).
func _water_gun_x(step: int) -> int:
	return step + step * water_casts


func durability_left(ci: int) -> int:
	if durab.has(ci):
		return int(durab[ci])
	var c := card(ci)
	return int(c.p.get("dur", -1)) if not c.is_empty() else -1


## Can this card wake at all this turn?
func usable(ci: int) -> bool:
	var c := card(ci)
	if c.is_empty() or silenced.has(ci) or cocooned.has(ci) or int(hammered.get(ci, 0)) >= HAMMER_BREAKS:
		return false
	if durability_left(ci) == 0 or cooldown.has(ci) or power_used.has(ci):
		return false
	return true


func needs_target(ci: int) -> bool:
	return bool(card(ci).get("t", false))


func targets(ci: int) -> Array:
	var out := []
	for i in foes.size():
		var f: Foe = foes[i]
		if f.dead() or f.shielded():
			continue
		if card(ci).get("id", "") == "moth_to_flame" and f.burn <= 0 and int(card(ci).p.get("burn", 0)) <= 0:
			continue  # (a burning enemy only, unless it sets one alight first)
		out.append(i)
	return out


## The chant as letters ("*" for a Star marble: any colour).
func chant_letters() -> Array:
	var out := []
	for m in chant:
		out.append("*" if String(m.sym) == "star" else String(m.c))
	return out


## Separate, non-overlapping copies of a pattern in the chant (left to right).
func occurrences(pattern: String) -> int:
	var ch := chant_letters()
	if pattern == "":
		return 1 if chanted and not ch.is_empty() else 0  # (every marble sealed: it wakes on any chant)
	var n := 0
	var i := 0
	var L := pattern.length()
	while L > 0 and i + L <= ch.size():
		var ok := true
		for k in L:
			if ch[i + k] != "*" and ch[i + k] != pattern[k]:
				ok = false
				break
		if ok:
			n += 1
			i += L
		else:
			i += 1
	return n


## Which cards are awake: after Chant, and again whenever the chant changes (an Extension).
func _recount() -> void:
	if not chanted:
		return
	for ci in run.cards.size():
		var before := int(charges.get(ci, 0))
		if not usable(ci):
			charges.erase(ci)
			continue
		var c := card(ci)
		var rep := int(c.p.get("rep", 1))
		var n := maxi(0, mini(occurrences(String(c.pattern)), rep) - int(casts.get(ci, 0)))
		if n > 0:
			charges[ci] = n
			if before == 0 and casts.get(ci, 0) == 0 and _depth == 0 and not _first_wake:
				extensions += 1
				if powers.has("random_things_go"):
					my_power += int(MarbleCards.card("random_things_go", int(powers.random_things_go)).p.x)
					_ev({"type": "extension", "ci": ci})
		else:
			charges.erase(ci)


var _first_wake := false


## Where the copies of a pattern start in the chant (separate, non-overlapping, left to right: as occurrences()).
func occurrence_starts(pattern: String) -> Array:
	var ch := chant_letters()
	var out := []
	var L := pattern.length()
	var i := 0
	while L > 0 and i + L <= ch.size():
		var ok := true
		for k in L:
			if ch[i + k] != "*" and ch[i + k] != pattern[k]:
				ok = false
				break
		if ok:
			out.append(i)
			i += L
		else:
			i += 1
	return out


## The words of these cards as they are at this moment (a boost line shows each card's new number as it lands).
func _texts_of(cis: Array) -> Dictionary:
	var out := {}
	for ci in cis:
		out[ci] = String(card(int(ci)).get("text", ""))
	return out


## A carved marble is read (the chant is read left to right after you press Chant; the user 2026-11-22: a carving works
## the moment its marble is read, the reading pausing on it). Sword / Skull: all your damage cards this turn; Shield /
## Wing: all your Shield cards; Heart, Fist, Ghost, Coin: you, now. Its event carries the marble's place ("note"), and a
## line goes from the marble to everything it raised.
func _carve(m: Dictionary, pos: int, skull_on: Array, wing_on: Array) -> void:
	var dmg_cards := []
	var sh_cards := []
	for ci in run.cards.size():
		var t := String(card(ci).get("text", ""))
		if t.contains("damage") and (t.contains("Deal") or t.contains("deal")):
			dmg_cards.append(ci)
		if t.contains("Shield") and t.contains("ain"):
			sh_cards.append(ci)
	match String(m.get("sym", "")):
		"sword":
			dmg_ops.append(["add", roundi(_cv(SWORD))])
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "card", "cis": dmg_cards, "col": "dmg", "texts": _texts_of(dmg_cards)})
		"skull":
			if skull_on.is_empty():  # (one Skull a chant)
				skull_on.append(true)
				dmg_ops.append(["mul", 1.0 + _cv(SKULL - 1.0)])
				_ev({"type": "boost", "from": "chant", "k": pos, "to": "card", "cis": dmg_cards, "col": "dmg", "texts": _texts_of(dmg_cards)})
		"shield":
			shield_ops.append(["add", roundi(_cv(SHIELD_SYM))])
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "card", "cis": sh_cards, "col": "shield", "texts": _texts_of(sh_cards)})
		"wing":
			if wing_on.is_empty():
				wing_on.append(true)
				shield_ops.append(["mul", 1.0 + _cv(WING - 1.0)])
				_ev({"type": "boost", "from": "chant", "k": pos, "to": "card", "cis": sh_cards, "col": "shield", "texts": _texts_of(sh_cards)})
		"heart":
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "you", "col": "hp"})
			_heal(roundi(_cv(2.0)))
		"fist":
			my_power += roundi(_cv(1.0))
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "you", "col": "dmg"})
		"ghost":  # (gain 1 Dodge, then the marble is gone from your bag for good: the user 2026-11-23)
			m.gone = true
			dodge += roundi(_cv(1.0))  # (as _gain_dodge, without its own show: the ghost flying to your Dodge is the show)
			dodges_gained += roundi(_cv(1.0))
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "you", "col": "ghost"})
		"coin":
			run.leaves += roundi(_cv(1.0))
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "you", "col": "other"})


# ------------------------------------------------------------------ the chant

func put(h: int) -> bool:
	if chanted or h < 0 or h >= hand.size() or chant.size() >= MAX_CHANT or bool(hand[h].get("frozen", false)):
		return false
	chant.append(hand.pop_at(h))
	return true


## Put hand marble h into the chant at position k (k past the end: at the end).
func put_at(h: int, k: int) -> bool:
	if chanted or h < 0 or h >= hand.size() or chant.size() >= MAX_CHANT or bool(hand[h].get("frozen", false)):
		return false
	chant.insert(clampi(k, 0, chant.size()), hand.pop_at(h))
	return true


## Move a chant marble from position a to position b.
func move_chant(a: int, b: int) -> bool:
	if chanted or a < 0 or a >= chant.size():
		return false
	var m = chant.pop_at(a)
	chant.insert(clampi(b, 0, chant.size()), m)
	return true


## How far the chant built so far gets towards a pattern (the main game's rule, FightScreen._pattern_progress): all of
## it if it is in there, else the longest start of the pattern the chant ends with (a Star matches anything).
func progress(pattern: String) -> int:
	var ch := chant_letters()
	if pattern == "" or ch.is_empty():
		return 0
	if occurrences(pattern) > 0 and not chanted:
		return pattern.length()
	for k in range(mini(pattern.length() - 1, ch.size()), 0, -1):
		var ok := true
		for j in k:
			var c: String = ch[ch.size() - k + j]
			if c != "*" and c != pattern[j]:
				ok = false
				break
		if ok:
			return k
	return 0


func take(k: int) -> bool:
	if chanted or k < 0 or k >= chant.size():
		return false
	hand.append(chant.pop_at(k))
	return true


## Press Chant: the carved marbles work, left to right, and the cards wake.
func do_chant() -> void:
	if chanted or over or chant.is_empty():
		return
	chanted = true
	_ev({"type": "chant"})
	var skull_on := []
	var wing_on := []
	var focus := []  # (Focus Fire cards: each Wind read adds a hit, a yellow line to them)
	for ci in run.cards.size():
		if String(card(ci).get("id", "")) == "focus_fire" and usable(ci):
			focus.append(ci)
	for pos in chant.size():  # (read left to right: each carving works as its marble is read)
		_note = pos
		if not (String(chant[pos].get("sym", "")) in ["", "star"]):
			_carve(chant[pos], pos, skull_on, wing_on)
		if not focus.is_empty() and String(chant[pos].sym) != "star" and String(chant[pos].c) == "A":
			_ev({"type": "boost", "from": "chant", "k": pos, "to": "card", "cis": focus, "col": "other", "texts": _texts_of(focus)})
	_note = -1
	_chant_artifacts()
	_first_wake = true
	_recount()
	_first_wake = false
	_cancel_intents()
	if CombatLog.on:
		var woke := []
		for ci in charges:
			woke.append("%s x%d" % [String(card(int(ci)).get("name", "?")), int(charges[ci])])
		CombatLog.line("  chant spoken: %s | woke: %s | damage carvings %s, shield carvings %s" % [
			" ".join(chant.map(func(x): return String(x.c) + (":" + String(x.sym) if String(x.get("sym", "")) != "" else ""))),
			", ".join(woke) if not woke.is_empty() else "nothing", str(dmg_ops), str(shield_ops)])


## The Tokens count the chant's marbles (a temporary one next turn every 5 of a colour, every 7 of any); the Monochrome
## Prism checks it is of one colour.
func _chant_artifacts() -> void:
	var cols := {}
	for m in chant:
		var c := String(m.c)
		var star := String(m.get("sym", "")) == "star"
		if not star:
			cols[c] = true
			token_count[c] = int(token_count.get(c, 0)) + 1
			var tid: String = {"F": "red_token", "W": "blue_token", "A": "green_token"}.get(c, "")
			if tid != "" and run.has_artifact(tid) and int(token_count[c]) % 5 == 0:
				token_next.append(c)
				_art_ev(tid, "+1 %s next turn" % {"F": "Fire", "W": "Water", "A": "Wind"}[c])
		token_count.all = int(token_count.all) + 1
		if run.has_artifact("rainbow_token") and int(token_count.all) % 7 == 0:
			token_next.append("*")
			_art_ev("rainbow_token", "+1 any colour next turn")
	mono = run.has_artifact("monochrome_prism") and chant.size() >= 2 and cols.size() == 1
	if mono:
		_art_ev("monochrome_prism", "One colour: +50%!", -1, true)


## Infuse: a Star marble at the end of the chant (an Extension can follow).
func _infuse(n: int) -> void:
	for k in n:
		_uid += 1
		chant.append({"c": "A", "sym": "star", "src": -1, "uid": _uid})
	_recount()
	_cancel_intents()


# ------------------------------------------------------------------ casting

func can_cast(ci: int) -> bool:
	return not over and chanted and int(charges.get(ci, 0)) > 0 and pending_replace < 0


func cast(ci: int, target := -1) -> void:
	if not can_cast(ci):
		return
	var c := card(ci)
	if bool(c.t) and target >= 0 and not (target in targets(ci)):
		return
	charges[ci] = int(charges[ci]) - 1
	if int(charges[ci]) <= 0:
		charges.erase(ci)
	casts[ci] = int(casts.get(ci, 0)) + 1
	uses[ci] = int(uses.get(ci, 0)) + 1
	cast_prev[ci] = true
	_damaged.clear()
	if CombatLog.on:
		var cp: Dictionary = c.get("p", {})
		CombatLog.line("> CAST %s [card %d] on %s | card text now: \"%s\" | its numbers: %s | Power %d, damage carvings %s, shield carvings %s%s" % [
			String(c.name), ci, _fname(foes[target]) if target >= 0 and target < foes.size() else "(auto/none)", String(c.get("text", "")), str(cp),
			power_now(), str(dmg_ops), str(shield_ops), ", YOU ARE WEAKENED (%d): every hit is halved" % weak if weak > 0 else ""])
	_ev({"type": "cast", "ci": ci, "name": String(c.name), "target": target, "fx": fx_of(c)})
	if ignited.has(ci):  # (an enemy set it alight: casting it burns you)
		ignited.erase(ci)
		_hurt_player(IGNITE_DMG, true)
		if over:
			return
	if int(c.p.get("pain", 0)) > 0:  # (the Curse of Pain: casting it hurts you)
		_self_damage(int(c.p.pain))
		if over:
			return
	if c.p.has("dur"):
		durab[ci] = durability_left(ci) - 1
	if c.p.has("cd"):
		cooldown[ci] = int(c.p.cd) + 1  # (it ticks at the start of your turn: CD 1 = not next turn)
	if bool(c.power):
		powers[String(c.id)] = int(c.level)
		power_used[ci] = true
	if "W" in String(c.pattern):
		water_casts += 1
		for wg in run.cards.size():  # (Water Gun's X goes up: a line from this card to it)
			if wg != ci and String(card(wg).get("id", "")) == "water_gun":
				_ev({"type": "boost", "from": "card", "src": ci, "to": "card", "ci": wg, "col": "dmg"})
	var times := 1
	if String(c.id) == "knivels_innocence":
		times = int(c.level) + 1
	if encore > 0:  # (a Ticket of Encore: it triggers a second time; triggering costs no Durability)
		encore -= 1
		times += 1
		_ev({"type": "double_cast", "ci": ci})
	if powers.has("ludwigs_passion") and String(c.id) != "ludwigs_passion":
		var chance := int(MarbleCards.card("ludwigs_passion", int(powers.ludwigs_passion)).p.x)
		if mrun.rng.randi_range(1, 100) <= chance:
			times += 1
			_ev({"type": "double_cast", "ci": ci})
	_casting = String(c.id)
	if hammer > 0 and run.has_artifact("hammer") and String(c.id) in MarbleCards.DAMAGE_CARDS:
		_art_ev("hammer", "+%d%%!" % (30 * hammer), -1, hammer >= 2)
	for k in times:
		if over:
			break
		_effect(c, ci, target)
	_casting = ""
	# "each time you cast a water card" (cards cast earlier this turn; not the one that set it up)
	if "W" in String(c.pattern) and not over:
		if triggers.has("set_fire_to_the_rain") and String(c.id) != "set_fire_to_the_rain":
			_apply_burn(_random_foe(), int(MarbleCards.card("set_fire_to_the_rain", int(triggers.set_fire_to_the_rain)).p.x), false)
	_enemy_thorns()
	if _hit_this_turn and hammer > 0:
		hammer = 0  # (the Hammer's stored blow is spent)
	if run.has_artifact("mysterious_hand") and String(c.pattern).length() >= 4 and not over:
		my_power += 1
		_art_ev("mysterious_hand", "+1 Power")
	cast_any = true
	if String(c.id) == "a_brothers_cluelessness":
		var n := int(mrun.perm.get("a_brothers_cluelessness", 0)) + 1
		mrun.perm["a_brothers_cluelessness"] = n
		if n >= int(c.p.x):
			run.cards[ci] = "a_brothers_cleverness"
			mrun.levels["a_brothers_cleverness"] = int(mrun.levels.get("a_brothers_cluelessness", 0))
			durab.erase(ci)
			_ev({"type": "transform", "ci": ci})
	_check_end()


## The enemies hit by this card hurt you with their Thorns.
func _enemy_thorns() -> void:
	for f: Foe in _damaged.keys():
		if f.thorns > 0 and not over:
			CombatLog.line("    %s's Thorns %d hurt you for damaging it" % [_fname(f), f.thorns])
			_hurt_player(f.thorns)
			_ev({"type": "thorns", "foe": foes.find(f), "n": f.thorns})
	_damaged.clear()


## Self Replace: the card in slot ci goes to your backpack and the backpack card `b` takes its place (the screen asks).
func replace_with(b: int) -> void:
	if pending_replace < 0:
		return
	if b >= 0 and b < mrun.backpack.size():
		var ci := pending_replace
		var out := String(run.cards[ci])
		run.cards[ci] = mrun.backpack[b]
		mrun.backpack[b] = out
		durab.erase(ci)
		grow.erase(ci)
		power_used.erase(ci)
		_ev({"type": "replaced", "ci": ci})
	pending_replace = -1
	_recount()


func _random_foe() -> Foe:
	var live := alive().filter(func(x): return not x.shielded())
	return live[run.rng.randi() % live.size()] if not live.is_empty() else null


func _tgt(target: int) -> Foe:
	if moth != null and not moth.dead():
		return moth
	if target >= 0 and target < foes.size() and not foes[target].dead():
		return foes[target]
	return _random_foe()


func _all() -> Array:
	return alive().filter(func(x): return not x.shielded())


## Cards whose numbers don't say what they look like: [SpellFx op, where] ("you", "foe", "chant": your chant row).
## (2026-11-22: they fell back to "draw", the +1 marble show, though they give no marble.)
const CARD_FX := {
	"wave": ["shield", "you"], "knivels_innocence": ["shield", "you"], "still_lake": ["shield", "you"],
	"fire_storm": ["burn", "foe"], "stoke_the_fire": ["stoke", "foe"], "borrowed_warmth": ["siphon", "foe"],
	"steam_engine": ["passive", "you"], "primitive_engine": ["passive", "you"], "over_exertion": ["passive", "you"],
	"energize": ["passive", "you"], "refreshing_wind": ["cleanse", "you"], "alchemy": ["cleanse", "you"],
	"water_gun": ["strike", "foe"], "set_fire_to_the_rain": ["passive", "you"], "air": ["passive", "you"],
	"aoles_magic": ["infuse", "chant"], "aoles_grace": ["self_repaint", "chant"], "ludwigs_inspiration": ["transmute", "chant"],
}


## The main game's spell effect (SpellFx op) a card plays when cast, and where it goes: "foe" (its target), "all"
## (every enemy) or "you".
static func fx_of(c: Dictionary) -> Dictionary:
	var p: Dictionary = c.get("p", {})
	if bool(c.get("power", false)):
		return {}  # (a Power: the fight screen's own show, the card turning into a badge)
	if CARD_FX.has(String(c.get("id", ""))):
		var cf: Array = CARD_FX[String(c.id)]
		return {"op": String(cf[0]), "to": String(cf[1]), "n": int(p.get("x", 1))}
	var all := bool(p.get("all", false))
	if c.has("parts") and not c.parts.is_empty():
		return fx_of(MarbleCards.card(String(c.parts[0][0]), int(c.parts[0][1])))
	for pair in [["d", "strike"], ["burn", "burn"], ["stun", "stun"], ["weak", "weak"], ["expose", "expose"], ["vuln", "expose"]]:
		if p.has(pair[0]):
			return {"op": pair[1], "to": "all" if all else "foe", "n": int(p[pair[0]])}
	for pair in [["shield", "shield"], ["heal", "heal"], ["thorns", "thorns"], ["dodge", "aegis"], ["power", "thorns"]]:
		if p.has(pair[0]):
			return {"op": pair[1], "to": "you", "n": int(p[pair[0]])}
	if p.has("next"):
		return {"op": "draw", "to": "you", "n": int(p.next)}  # (more marbles next turn: one flies to the slot machine's tray)
	if bool(c.get("t", false)):
		return {"op": "strike", "to": "foe", "n": 1}
	return {"op": "passive", "to": "you", "n": 1}  # (nothing better known: a sparkle on you, never the +1 marble show)


## What a card does (`depth` > 0: activated by another card).
func _effect(c: Dictionary, ci: int, target: int) -> void:
	var was := _cur_ci
	_cur_ci = ci
	_effect_body(c, ci, target)
	_cur_ci = was


func _effect_body(c: Dictionary, ci: int, target: int) -> void:
	if c.has("parts"):  # (a fused card: what each of its two cards does, in order)
		for part in c.parts:
			if over:
				return
			_effect(MarbleCards.card(String(part[0]), int(part[1])), ci, target)
		return
	var p: Dictionary = c.p
	var id := String(c.id)
	var t: Foe = _tgt(target) if bool(c.t) else null
	var all := bool(p.get("all", false))
	match id:
		"steam_gun":
			_deal(t, int(p.x) * mrun.count_marbles("A"))
		"wave":  # (gain its Shield, starting at 1; then it increases by x: the user 2026-11-23)
			var wv := int(grow.get(ci, 1))
			_card_shield(wv, t)
			grow[ci] = wv + int(p.x)
		"steam_engine", "primitive_engine":
			var to := ci + 1 if id == "steam_engine" else ci - 1
			for k in int(p.x):
				_activate(to, target)
		"fire_storm":  # (apply its Burn, starting at x; then it increases by x)
			var fs := int(grow.get(ci, int(p.x)))
			_apply_burn(t, fs)
			grow[ci] = fs + int(p.x)
		"geyser", "elizes_hesitation":
			_add_charge(ci, 1, target)
		"pressure_cooker":
			_deal(t, int(p.d) * (2 if t != null and t.burn > 0 else 1))
		"chosen_one":
			var others := 0
			for k in run.cards.size():
				if k != ci and String(card(k).get("id", "")) in MarbleCards.DAMAGE_CARDS:
					others += 1
			_deal(t, int(p.d) * (int(p.x) if others == 0 else 1))
		"cyclone":
			_card_shield(int(p.x) * water_casts, t)
			_deal(t, int(p.x) * water_casts)
		"water_gun":  # (X damage: X = x + x for each card with Water cast this turn before this cast; see _water_gun_x)
			_deal(t, int(p.x) + int(p.x) * maxi(0, water_casts - 1))
		"set_fire_to_the_rain", "pyrophiliac", "adams_fist", "sadistic_nature":
			triggers[id] = int(c.level)
			if id == "pyrophiliac":
				_heal(int(p.heal))
			elif id == "adams_fist":
				_apply_burn(t, int(p.burn))
			elif id == "sadistic_nature":
				for f in (_all() if all else [t]):
					_debuff(f, "vuln", int(p.vuln))
		"rain":
			_cleanse()
			_card_shield(int(p.shield), t)
		"hail":
			_hail = true
			_deal(t, int(p.d))
			_hail = false
		"forest_fire":
			_apply_burn(t, int(p.burn))
			if t != null:
				for f: Foe in _all():
					if f != t:
						_burn(f, t.burn)
		"circle_of_life":
			var was := t != null and not t.dead()
			_deal(t, int(p.d) + int(mrun.perm.get("circle_of_life", 0)))
			if was and t.dead():
				mrun.perm["circle_of_life"] = int(mrun.perm.get("circle_of_life", 0)) + 10
		"backdraft":
			if t != null and t.burn > 0:
				var b := t.burn
				t.burn = 0
				_deal(t, int(p.x) * b)
		"stream":
			var s := int(grow.get(ci, int(p.x)))
			_card_shield(s, t)
			_deal(t, s)
			grow[ci] = s * 2
		"snuffing_the_candle":
			_deal(t, int(p.d))
			if t != null and not t.dead() and t.hp <= int(p.x):
				t.hp = 0
				_ev({"type": "execute", "foe": foes.find(t)})
				_on_death(t)
		"refreshing_wind":
			for to in ([ci - 1] if int(p.x) == 1 else [ci - 1, ci + 1]):
				if to >= 0 and to < run.cards.size() and card(to).p.has("dur"):
					durab[to] = durability_left(to) + 1
					_ev({"type": "boost", "from": "card", "src": ci, "to": "card", "ci": to, "col": "other"})
		"burn_them_all":
			for f: Foe in _all():
				_apply_burn(f, int(p.burn))
				f.burn *= 2
		"stick_and_carrot":
			_deal(t, int(p.d) + block)
		"desperate_drop":
			var n := _cleanse()
			for f: Foe in _all():
				_apply_burn(f, int(p.burn) * n)
		"implosion":
			_deal(t, int(p.x) * mrun.bag.size())
		"carrot_and_stick":
			_card_shield(int(p.shield) + dealt_turn / 2, t)
		"stoke_the_fire":
			if t != null:
				t.burn *= int(p.x)
				_ev({"type": "foe_burn", "foe": foes.find(t), "n": t.burn})
		"curse_of_the_night":
			for to in [ci - 1, ci + 1]:
				if to >= 0 and to < run.cards.size():
					bites[to] = int(c.level)
		"adams_finger":
			finger = t
		"glass_half_full":
			_deal(t, int(p.d))
			if mrun.rng.randf() < 0.5:
				_self_damage(int(p.self))
		"air":
			air_bonus += int(p.x)
			for to in run.cards.size():  # (your Burn cards: their Burn goes up)
				if to != ci and card(to).p.has("burn"):
					_ev({"type": "boost", "from": "card", "src": ci, "to": "card", "ci": to, "col": "dmg"})
		"warm_up":
			_deal(t, int(grow.get(ci, 0)))
			grow[ci] = 0
		"energize":
			var tos := []
			if int(p.get("y", 0)) > 0:
				tos = range(run.cards.size())
			else:
				tos = [ci - 1, ci + 1]
			for to in tos:
				if to != ci and to >= 0 and to < run.cards.size() and card(to).p.has("at"):
					_ev({"type": "boost", "from": "card", "src": ci, "to": "card", "ci": to, "col": "other"})
					_add_charge(to, int(p.x), -1)
		"freeze":
			for f: Foe in _all():
				_debuff(f, "stun", int(p.stun))
			if int(p.get("y", 0)) > 0:
				stunned = 1
				_ev({"type": "you_stunned_self"})
		"aoles_magic":
			_infuse(int(p.x))
		"rain_of_pain":
			_deal(t, int(p.d), int(p.hits) + int(p.x) * chant_letters().count("F"))
		"might_of_the_first_apostle":
			_apply_burn(t, int(p.burn))
			if not cast_any:
				my_power += int(p.power)
		"glass_cannon":
			var n := 0
			for m in chant:
				n += int(p.x) * (2 if String(m.sym) != "" else 1)
			_deal(t, n)
		"ludwigs_inspiration":
			var pool := []
			for k in chant.size():
				if String(chant[k].sym) == "":
					pool.append(k)
			_shuffle(pool)
			for k in mini(int(p.x), pool.size()):
				var m: Dictionary = chant[pool[k]]
				var sym := String(mrun.random_marble_symbol())
				m.sym = sym
				if int(m.src) >= 0:
					mrun.bag[int(m.src)].sym = sym  # (carved for good)
			_recount()
		"alchemy", "random_things_go":
			if id == "alchemy":  # (random bottles into your free bottle slots)
				var got := 0
				for b in mrun.bottle_offer(int(p.x)):
					if mrun.gain_bottle(String(b)):
						got += 1
				_ev({"type": "bottles", "n": got})
			if mrun.backpack.size() > 0:
				pending_replace = ci
		"over_exertion":
			for to in [ci - 1, ci + 1]:
				if to >= 0 and to < run.cards.size():
					_activate(to, target)
					silenced[to] = int(p.x) + 1
		"a_daughters_secret":
			hp_loan += int(p.x)
			run.max_hp -= int(p.x)
			run.hp = mini(run.hp, run.max_hp)
			if run.max_hp <= 0 or run.hp <= 0:
				run.hp = 0
				over = true
				won = false
				return
			_debuff(t, "stun", int(p.stun))
		"borrowed_warmth":
			if t != null and t.burn > 0:
				var b := t.burn
				t.burn = 0
				_heal(b * int(p.x) / 100)
		"iron_maiden":
			my_thorns += int(p.thorns)
			_deal(t, int(p.x) * my_thorns)
		"nilas_blades":
			_deal(t, int(p.d), 1 + int(p.x) * dodges_gained)
		"knivels_innocence":  # (gain x Shield, then x grows by 1 for the run; x starts at 1; no heal since 2026-11-22)
			var v := int(mrun.perm.get("knivels_innocence", 0)) + 1
			_card_shield(v, null)
			mrun.perm["knivels_innocence"] = v
		"heat_center":
			if t != null:
				var total := burn
				burn = 0
				for f: Foe in alive():
					if f != t:
						total += f.burn
						f.burn = 0
				_burn(t, total)
		"moth_to_flame":
			if int(p.get("burn", 0)) > 0:
				_apply_burn(t, int(p.burn))
			if t != null and t.burn > 0:
				moth = t
				_ev({"type": "moth", "foe": foes.find(t)})
		"still_lake":
			var n := 0
			for to in [ci - 1, ci + 1]:
				if to >= 0 and to < run.cards.size():
					silenced[to] = 2
					charges.erase(to)
					n += 1
			_card_shield(int(p.x) * n, null)
			_heal(int(p.x) * n)
		"aoles_grace":
			var pool := []
			for k in chant.size():
				if String(chant[k].sym) != "star":
					pool.append(k)
			_shuffle(pool)
			for k in mini(int(p.x), pool.size()):
				chant[pool[k]] = (chant[pool[k]] as Dictionary).duplicate()
				chant[pool[k]].sym = "star"  # (for this chant only: the marble in your bag keeps its colour)
			_recount()
		"focus_fire":
			for k in focus_hits():
				if k > 0:
					if t == null or t.dead() or over:
						break
					_ev({"type": "fx_again", "ci": ci})  # (its spell effect plays again for every repeat)
				_debuff(t, "expose", int(p.expose))
				_deal(t, int(p.d))
		"whim_of_the_pianist":
			_deal(t, int(p.x) * mrun.count_marbles("", true))
		_:
			_plain(c, t, all)


## A card that only does what its numbers say (in this order).
func _plain(c: Dictionary, t: Foe, all: bool) -> void:
	var p: Dictionary = c.p
	if bool(c.power) and String(c.id) in ["adams_awakening", "fervor_of_the_first_apostle", "flagellum_of_the_first_apostle", "adams_resolve", "aoles_last_wish"]:
		return  # (Powers that only work from now on: see _turn_powers and the hooks)
	var targets_now: Array = _all() if all else ([t] if t != null else [])
	if p.has("d"):
		for f in targets_now:
			_deal(f, int(p.d), int(p.get("hits", 1)))
	if p.has("burn"):
		for f in targets_now:
			_apply_burn(f, int(p.burn))
	for k in ["weak", "vuln", "expose", "stun"]:
		if p.has(k):
			for f in targets_now:
				_debuff(f, k, int(p[k]))
	if p.has("shield"):
		_card_shield(int(p.shield), t)
	if p.has("heal"):
		_heal(int(p.heal))
	if p.has("power") and not bool(c.power):
		my_power += int(p.power)
	if p.has("dodge"):
		_gain_dodge(int(p.dodge))
	if p.has("thorns") and not bool(c.power):
		my_thorns += int(p.thorns)
	if p.has("self"):
		_self_damage(int(p.self))
	if p.has("sburn"):
		burn += int(p.sburn)
	if p.has("svuln"):
		vulnerable = maxi(vulnerable, int(p.svuln) + 1)
	if p.has("next"):
		next_extra += int(p.next)


## Activate a card: what it does, without its marbles (and without using its Durability).
func _activate(ci: int, target: int) -> void:
	if ci < 0 or ci >= run.cards.size() or _depth > 3 or cocooned.has(ci):
		return
	var c := card(ci)
	if c.is_empty():
		return
	_depth += 1
	if _cur_ci >= 0 and _cur_ci != ci:
		_ev({"type": "boost", "from": "card", "src": _cur_ci, "to": "card", "ci": ci, "col": "other"})
	_ev({"type": "activate", "ci": ci})
	var tg := target if (target >= 0 and target < foes.size() and not foes[target].dead()) else foes.find(_random_foe())
	_effect(c, ci, tg)
	_depth -= 1


## A charge on a card (Geyser, Elize's Hesitation): at its number it fires and starts again.
func _add_charge(ci: int, n: int, target: int) -> void:
	var c := card(ci)
	charge[ci] = int(charge.get(ci, 0)) + n
	if int(charge[ci]) < int(c.p.at):
		return
	charge[ci] = 0
	if String(c.id) == "geyser":
		for f: Foe in _all():
			_deal(f, int(c.p.d))
	else:
		_debuff(_tgt(target), "stun", int(c.p.stun))


# ------------------------------------------------------------------ numbers

## Your Power now (Hot Blood adds 1 for each step of HP you are missing).
## An artifact of yours did something: the screen lights it up and shows `text` (at enemy `foe`, or at you when -1).
func _art_ev(id: String, text: String, foe := -1, big := false) -> void:
	CombatLog.line("    [artifact] %s: %s" % [id, text])
	_ev({"type": "art", "id": id, "text": text, "foe": foe, "big": big})


## The Collector: your carvings are 50% stronger.
func _cv(x: float) -> float:
	return x * 1.5 if run.has_artifact("collector") else x


func power_now() -> int:
	var n := my_power + pact
	if run.has_artifact("magician_hat"):  # (+1 for each empty active slot and each broken card; read straight from the counts: card() asks power_now)
		n += maxi(0, mrun.slots - run.cards.size())
		for ci in run.cards.size():
			if int(durab.get(ci, -1)) == 0 or int(hammered.get(ci, 0)) >= HAMMER_BREAKS:
				n += 1
	if powers.has("hot_blood") and run.max_hp > 0:
		var step := int(MarbleCards.card("hot_blood", int(powers.hot_blood)).p.x)
		var missing := 100 * (run.max_hp - run.hp) / run.max_hp
		n += missing / step
	return n


## A card's damage per hit before the enemy's side: its number, your Power, the chant's carvings in order, All-Out.
func card_damage(base: int) -> int:
	var x := float(base + power_now() * (2 if _hail else 1) + (1 if run.has_artifact("whetstone") else 0))
	for op in dmg_ops:
		if op[0] == "add":
			x += float(op[1]) * (2.0 if _hail else 1.0)
		else:
			x *= (1.0 + (float(op[1]) - 1.0) * (2.0 if _hail else 1.0))
	if powers.has("all_out"):
		x *= 1.0 + float(MarbleCards.card("all_out", int(powers.all_out)).p.x) / 100.0
	if hammer > 0 and run.has_artifact("hammer"):
		x *= 1.0 + 0.3 * hammer
	if mono:
		x *= 1.5
	return int(floor(x))


## A card's hits on an enemy.
func _deal(t: Foe, base: int, hits := 1) -> void:
	for k in hits:
		if t == null or t.dead() or over:
			return
		if CombatLog.on:
			var steps := "card number %d + Power %d%s%s" % [base, power_now() * (2 if _hail else 1), " + Whetstone 1" if run.has_artifact("whetstone") else "", " (Hail: Power and carvings doubled)" if _hail else ""]
			for op in dmg_ops:
				steps += " then %s %s" % ["+" if op[0] == "add" else "x", str(op[1])]
			if powers.has("all_out"):
				steps += " then All-Out x%s" % str(1.0 + float(MarbleCards.card("all_out", int(powers.all_out)).p.x) / 100.0)
			CombatLog.line("    damage %d/%d on %s: %s = %d (this is the number a card text shows, before enemy/weak modifiers)" % [k + 1, hits, _fname(t), steps, card_damage(base)])
		_hit_this_turn = true
		_hit(t, card_damage(base))


## Damage of yours that isn't a card's (Water Gun, Thunderstorm, Thorns): no Power, no carvings.
func _hit_plain(t: Foe, n: int) -> void:
	if t != null and not t.dead():
		CombatLog.line("    damage on %s: fixed %d (not a card hit: no Power, no carvings)" % [_fname(t), n])
		_hit(t, n)


## What a hit of n (a card's number, Power and carvings in) comes to: Heed My Call and your Weakened, then (against foe f)
## its Expose and Armor, its Vulnerable and the Flying cap. {n: final, own: after your side only, how: the steps, fly:
## the Flying cap applied}. Block is not here. The one place this is worked out: a hit, and the numbers on the cards.
func _hit_value(f: Foe, n: int) -> Dictionary:
	var how := "in %d" % n
	if powers.has("heed_my_call") and not _no_heed:
		var heed := int(MarbleCards.card("heed_my_call", int(powers.heed_my_call)).p.x)
		n += heed
		how += " + Heed My Call %d = %d" % [heed, n]
	if weak > 0:
		n = n / 2
		how += " -> YOU are Weakened (%d): halved = %d" % [weak, n]
	var own := n
	var fly := false
	if f != null:
		var plus := f.expose * (2 if _hail else 1) - f.armor
		n += plus
		if plus != 0:
			how += " -> foe Expose %d%s - Armor %d = %+d: %d" % [f.expose, " x2 (Hail)" if _hail else "", f.armor, plus, n]
		n = maxi(0, n)
		if f.vulnerable > 0:
			var before_v := n
			n = n + (n if _hail else n / 2)
			how += " -> foe Vulnerable (%d): %d %s = %d" % [f.vulnerable, before_v, "x2 (Hail)" if _hail else "+50%", n]
		if f.id in MARBLE_FLYERS and f.es.flying and n > 0:
			how += " -> foe is FLYING: any hit counts as 1 (was %d)" % n
			n = 1
			fly = true
	return {"n": n, "own": own, "how": how, "fly": fly}


## A card's damage number as it shows on the card: your side only (Power, carvings, Heed My Call, your Weakened).
func shown_damage(base: int) -> int:
	return int(_hit_value(null, base).n)


## The same against one enemy (the card while you aim at it): 0 when it can't be hit now.
func damage_vs(f: Foe, base: int) -> int:
	if f.ethereal > 0 or f.dodge > 0:
		return 0
	return int(_hit_value(f, base).n)


## A hit of yours on an enemy (everything goes through here).
func _hit(f: Foe, n: int) -> void:
	if f == null or f.dead():
		return
	if f.ethereal > 0 or f.shielded():
		CombatLog.line("    -> NO DAMAGE: %s is %s" % [_fname(f), "Ethereal" if f.ethereal > 0 else "behind her hedges"])
		_ev({"type": "immune", "foe": foes.find(f), "why": "Ethereal" if f.ethereal > 0 else "Behind her hedges"})
		return
	if f.dodge > 0:
		CombatLog.line("    -> NO DAMAGE: %s Dodges (Dodge %d -> %d)" % [_fname(f), f.dodge, f.dodge - 1])
		f.dodge -= 1
		_ev({"type": "immune", "foe": foes.find(f), "why": "Dodged"})
		return
	var r := _hit_value(f, n)
	var shown: int = r.own
	var how: String = r.how
	n = r.n
	if r.fly:
		f.fly_hits += 1
		if f.fly_hits >= FLY_HITS:
			f.es.flying = false
			f.landed = true
			f.fly_hits = 0
			f.stun += 1
			f.power += 1
			_ev({"type": "foe_falls", "foe": foes.find(f)})
	if f.deflect:
		CombatLog.line("    -> %s | foe DEFLECTS: %d goes back at YOU" % [how, n])
		f.deflect = false
		_ev({"type": "deflected", "foe": foes.find(f), "n": n})
		_hurt_player(n)
		return
	var soak := mini(f.block, n)
	CombatLog.line("    -> HIT %s: %s | final %d%s | its Block %d soaks %d | HP %d -> %d (lost %d)%s" % [
		_fname(f), how, n, "  [CHECK: card said %d, final is %d]" % [shown, n] if n != shown else "", f.block, soak, f.hp, maxi(0, f.hp - (n - soak)), n - soak,
		"  [CHECK: Block soaked part of the damage]" if soak > 0 else ""])
	f.block -= soak
	f.hp = maxi(0, f.hp - (n - soak))
	dealt_turn += n
	if n > 0:
		_damaged[f] = true
	_ev({"type": "hit", "foe": foes.find(f), "n": n - soak, "blocked": soak})
	if f.dead():
		_on_death(f)
		if run.has_artifact("dark_heart") and f.dead():
			_art_ev("dark_heart", "+3 HP")
			_heal(3)
	if n > 0 and run.has_artifact("kunai") and not _kunai and not over:
		kunai_n += 1
		if kunai_n % 3 == 0:
			var kt: Foe = f if not f.dead() else _random_foe()
			if kt != null:
				_kunai = true
				_art_ev("kunai", "+1", foes.find(kt))
				_hit(kt, 1 + power_now())  # (a hit of its own: Power here, Expose and Vulnerable in _hit_value)
				_kunai = false


## Burn from you: Air adds to your Burn cards', Adam's Awakening adds your Power; Adam's Fist answers.
func _apply_burn(t: Foe, n: int, from_card := true) -> void:
	if t == null or t.dead() or n <= 0:
		return
	var given := n
	if from_card and _casting in MarbleCards.BURN_CARDS:
		n += air_bonus
	if powers.has("adams_awakening"):
		n += power_now()
	CombatLog.line("    burn on %s: card number %d + Air %d + Adam's Awakening %d = %d (then x burn multiplier %d)" % [_fname(t), given, air_bonus if from_card and _casting in MarbleCards.BURN_CARDS else 0, power_now() if powers.has("adams_awakening") else 0, n, _burn_mult])
	if mono and from_card:
		n = int(floor(n * 1.5))
	_burn(t, n)
	if run.has_artifact("coal_heart"):
		_art_ev("coal_heart", "+2 HP")
		_heal(2)
	if triggers.has("adams_fist") and not t.dead():
		_hit_plain(t, int(MarbleCards.card("adams_fist", int(triggers.adams_fist)).p.x))


## A debuff on an enemy: weak, vuln, expose, stun (Sadistic Nature: +1 Power per stack).
func _debuff(t: Foe, kind: String, n: int) -> void:
	if t == null or t.dead() or n <= 0:
		return
	match kind:
		"weak":
			_weaken(t, n)
		"vuln":
			_vulnerable(t, n)
		"expose":
			if not _takes_status(t):
				return
			CombatLog.line("      status: %s Expose %d -> %d (each hit on it deals +Expose)" % [_fname(t), t.expose, t.expose + n])
			t.expose += n
			_ev({"type": "foe_expose", "foe": foes.find(t), "n": n})
		"stun":
			if int(t.get_meta("stun_free", -1)) >= turn:
				_ev({"type": "immune", "foe": foes.find(t), "why": "Stun immune"})
				return
			_stun(t, n)
			t.set_meta("stun_free", turn + 1)  # (after a stun it can't be stunned again for a turn)
	if triggers.has("sadistic_nature"):
		my_power += n


## Shield from a card: the chant's Shield / Wing in order; All-Out turns it into damage instead.
## A card's Shield of n with its Shield / Wing marbles (the card running: _cur_ci).
func card_shield_value(n: int) -> int:
	var x := float(n + (power_now() if n > 0 else 0))  # (Power adds to Shield too, not to heals: the user 2026-11-27)
	if mono and n > 0:
		x *= 1.5
	for op in shield_ops:
		x = x + float(op[1]) if op[0] == "add" else x * float(op[1])
	return int(floor(x))


func _card_shield(n: int, t: Foe) -> void:
	var s := card_shield_value(n)
	CombatLog.line("    card Shield: number %d with carvings %s = %d%s" % [n, str(shield_ops), s, " -> All-Out turns it into damage" if powers.has("all_out") and s > 0 else ""])
	if s <= 0:
		return
	if powers.has("all_out"):
		_hit_plain(t if t != null else _random_foe(), s)
		return
	_shield(s)


func _heal(n: int) -> void:
	var hp_was := run.hp
	var h := run.heal(n)
	CombatLog.line("    you heal: asked %d, healed %d (HP %d -> %d of %d)" % [n, h, hp_was, run.hp, run.max_hp])
	_ev({"type": "heal", "n": h})
	if triggers.has("pyrophiliac"):
		_apply_burn(_random_foe(), int(MarbleCards.card("pyrophiliac", int(triggers.pyrophiliac)).p.x), false)


func _gain_dodge(n: int) -> void:
	CombatLog.line("    you gain Dodge %d (Dodge %d -> %d)" % [n, dodge, dodge + n])
	dodge += n
	dodges_gained += n
	_ev({"type": "dodge_up", "n": n})


## You hurt yourself (Adam's Resolve: Power, and a heal).
func _self_damage(n: int) -> void:
	CombatLog.line("    you hurt yourself for %d (ignores Shield)" % n)
	_hurt_player(n, true)
	_ev({"type": "self_damage", "n": n})
	if powers.has("adams_resolve") and not over:
		var p: Dictionary = MarbleCards.card("adams_resolve", int(powers.adams_resolve)).p
		my_power += int(p.power)
		if p.has("heal"):
			_heal(int(p.heal))


## Cleanse: your debuffs gone. Returns how many kinds there were.
func _cleanse() -> int:
	var n := 0
	for on in [weak > 0, vulnerable > 0, expose > 0, burn > 0, stunned > 0, not silenced.is_empty(), not ignited.is_empty(), not _ignite_next.is_empty(), freeze_next > 0, confuse_next or confuse_fight]:
		if on:
			n += 1
	weak = 0
	vulnerable = 0
	expose = 0
	burn = 0
	stunned = 0
	silenced.clear()
	ignited.clear()
	_ignite_next.clear()
	freeze_next = 0
	confuse_next = false
	confuse_fight = false
	for m in hand:
		m.frozen = false
		m.hidden = false
	_ev({"type": "cleanse", "n": n})
	return n


# ------------------------------------------------------------------ you get hurt

func _hurt_player(n: int, through_block := false) -> void:
	var soak := 0 if through_block else mini(block, n + (n / 2 if vulnerable > 0 else 0))
	var before := run.hp
	super._hurt_player(n, through_block)
	_lost = before - run.hp
	if _lost > 0 and pact > 0:
		pact -= 1
		_art_ev("blood_pact", "-1 Power")
	if soak > 0 and powers.has("flame_of_vengeance"):
		shield_lost += soak
		var every := int(MarbleCards.card("flame_of_vengeance", int(powers.flame_of_vengeance)).p.x)
		while shield_lost >= every:
			shield_lost -= every
			my_thorns += 1


## Your Thorns answer an attack (Fervor: as Burn; Flagellum: with your Power).
func _on_attacked(f: Foe, _n: int) -> void:
	if f.id in LIFESTEAL and _lost > 0 and not f.dead():
		var h := mini(_lost, f.max_hp - f.hp)
		f.hp += h
		_ev({"type": "foe_heal", "foe": foes.find(f), "n": h})
	if run.has_artifact("glow_stick") and not glow_done and _lost > 0 and not f.dead():
		glow_done = true
		_art_ev("glow_stick", "10 Burn!", foes.find(f), true)
		_apply_burn(f, 10, false)
	var th := my_thorns
	if powers.has("flagellum_of_the_first_apostle"):
		th += power_now()
	if run.has_artifact("cactus_plushie"):
		th *= 2
	if th <= 0 or f.dead():
		return
	CombatLog.line("    your Thorns answer %s: Thorns %d%s" % [_fname(f), my_thorns, " + Power %d (Flagellum)" % power_now() if powers.has("flagellum_of_the_first_apostle") else ""])
	if powers.has("fervor_of_the_first_apostle"):
		_burn(f, th)
	else:
		_no_heed = true
		_hit_plain(f, th)
		_no_heed = false
	_ev({"type": "your_thorns", "foe": foes.find(f), "n": th})
	if run.has_artifact("thorn_heart"):
		thorn_heal += th * 0.2
		if thorn_heal >= 1.0:
			var hn := int(floor(thorn_heal))
			thorn_heal -= hn
			_art_ev("thorn_heart", "+%d HP" % hn)
			_heal(hn)


func _forced_target(attacker: Foe) -> Foe:
	if moth != null and not moth.dead() and moth != attacker:
		return moth
	return null


# ------------------------------------------------------------------ the turn

func _start_turn() -> void:
	turn += 1
	CombatLog.line("")
	CombatLog.line("=== TURN %d ===" % turn)
	if not powers.has("endless_well"):
		var kept := block / 2 if run.has_artifact("bulwark") else 0
		if kept > 0:
			_art_ev("bulwark", "Shield %d kept" % kept)
		block = kept
	if turn > 1 and run.has_artifact("hammer") and not _hit_this_turn:
		hammer += 1
		_art_ev("hammer", "Charging: +%d%%" % (30 * hammer))
	_hit_this_turn = false
	mono = false
	for k in [charges, casts]:
		k.clear()
	dmg_ops.clear()
	shield_ops.clear()
	triggers.clear()
	chanted = false
	dealt_turn = 0
	water_casts = 0
	cast_any = false
	moth = null
	no_shield = false
	for ci in cooldown.keys():
		cooldown[ci] = int(cooldown[ci]) - 1
		if int(cooldown[ci]) <= 0:
			cooldown.erase(ci)
	ignited = _ignite_next.duplicate()
	_ignite_next.clear()
	# last turn's chant: used (a Spent marble is gone from your bag for good); the marbles you didn't chant stay in
	# your storage row (a Frozen one thaws)
	var spent_idx := []
	for m in chant:
		if int(m.get("src", -1)) >= 0:
			if bool(m.get("gone", false)):
				spent_idx.append(int(m.src))
			else:
				used_pile.append(int(m.src))
	chant.clear()
	for m in hand:
		m.frozen = false
	for k in range(hand.size() - 1, -1, -1):  # (a temporary marble not used last turn: it fades away)
		if hand[k].has("temp") and int(hand[k].temp) < turn:
			hand.remove_at(k)
	if not spent_idx.is_empty():
		_drop_marbles(spent_idx)
	if burn > 0 and turn > 1:  # (from your second turn: an event's Burn doesn't bite before you have played)
		CombatLog.line("  your Burn %d bites (ignores Shield), then drops to %d" % [burn, burn - 1])
		_hurt_player(burn, true)
		_ev({"type": "you_burn", "n": burn})
		burn -= 1
		if over:
			return
	# Warm Up grows on every turn it wasn't cast
	for ci in run.cards.size():
		if String(card(ci).get("id", "")) == "warm_up" and turn > 1 and not cast_prev.has(ci):
			grow[ci] = int(grow.get(ci, 0)) + int(card(ci).p.x)
	cast_prev.clear()
	if turn > 1:
		_turn_powers()
		_check_end()
		if over:
			return
	# the draw
	var n := 3 + next_extra
	next_extra = 0
	if powers.has("aoles_last_wish"):
		n += 2
	if run.has_artifact("marble_sack"):
		n += 1
	if run.has_artifact("cursed_book"):
		n += 1
	for tc in token_next:  # (the Tokens' temporary marbles: here this turn only)
		_uid += 1
		var star: bool = String(tc) == "*"
		hand.append({"c": "A" if star else String(tc), "sym": "star" if star else "", "src": -1, "uid": _uid, "frozen": false, "hidden": false, "temp": turn})
	token_next.clear()
	if turn == 1:
		for g in mrun.start.get("gift", []):  # (an event's gift: marbles to start the fight with)
			_uid += 1
			var gc: String = String(g) if String(g) in ["F", "W", "A"] else ["F", "W", "A"][run.rng.randi() % 3]
			hand.append({"c": gc, "sym": "", "src": -1, "uid": _uid, "frozen": false, "hidden": false})
		for c in FIRST_TURN_EXTRA:
			_uid += 1
			hand.append({"c": c, "sym": "", "src": -1, "uid": _uid, "frozen": false, "hidden": false})
	for k in n:
		if hand.size() >= MAX_ROW:
			break  # (your row is full: the rest stay in the bag)
		if draw_pile.is_empty():  # (the bag is empty: it refills from the recycle bin, the used marbles; both empty: no more draws this turn)
			draw_pile = used_pile.duplicate()
			used_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		var i: int = draw_pile.pop_back()
		var m: Dictionary = mrun.bag[i]
		_uid += 1
		hand.append({"c": String(m.c), "sym": String(m.sym), "src": i, "uid": _uid, "frozen": false, "hidden": false})
	if freeze_next > 0 and not hand.is_empty():
		hand[run.rng.randi() % hand.size()].frozen = true
		freeze_next = 0
	var blinded := alive().any(func(x): return x.id in BLINDERS)
	if (confuse_next or confuse_fight or blinded) and not hand.is_empty():
		for m in hand:
			m.hidden = true  # (Blind: you can't see their colours until they are in the chant)
		confuse_next = false
	_ev({"type": "draw"})
	if CombatLog.on:
		CombatLog.line("  marbles in your row: %s" % " ".join(hand.map(func(x): return String(x.c) + (":" + String(x.sym) if String(x.get("sym", "")) != "" else "") + ("(frozen)" if bool(x.frozen) else ""))))
		_log_state("your turn begins")
	if stunned > 0:
		CombatLog.line("  YOU ARE STUNNED: this turn is skipped")
		stunned -= 1
		_ev({"type": "you_stunned"})
		end_turn()


## Next turn's draw as far as it is known now (the slot machine shows it, the user 2026-11-22): the marbles on top of
## the bag, in the order they come out. When the bag runs short it refills from the recycle bin, shuffled only then:
## those can't be known yet and aren't listed.
func next_draw_known() -> Array:
	var n := 3 + next_extra + (2 if powers.has("aoles_last_wish") else 0) + (1 if run.has_artifact("marble_sack") else 0) + (1 if run.has_artifact("cursed_book") else 0)
	_refill_for(n)
	var out := []
	for k in mini(n, draw_pile.size()):
		out.append(mrun.bag[int(draw_pile[draw_pile.size() - 1 - k])])
	return out


## The bag can't give next turn's draw: the recycle bin goes back into it now (shuffled, under what is left, which comes
## out first), so the slot machine always shows the whole draw (the user, 2026-11-22). This turn's chant joins the bin
## at the start of next turn as usual.
func _refill_for(n: int) -> void:
	if draw_pile.size() >= n or used_pile.is_empty():
		return
	var back := used_pile.duplicate()
	used_pile.clear()
	_shuffle(back)
	draw_pile = back + draw_pile


## A Spent marble is chanted: it leaves your bag for good (the piles' indices move down).
func _drop_marbles(idx: Array) -> void:
	idx.sort()
	idx.reverse()
	for i in idx:
		mrun.bag.remove_at(i)
		for pile in [draw_pile, used_pile]:
			pile.erase(i)
			for k in pile.size():
				if int(pile[k]) > i:
					pile[k] = int(pile[k]) - 1
		for hm in hand + chant:  # (the marbles out of the bag point at it by index too)
			if int(hm.get("src", -1)) > i:
				hm.src = int(hm.src) - 1


## Powers that work at the start of each of your turns.
func _turn_powers() -> void:
	if powers.has("adams_finger") and finger != null and not finger.dead():
		_burn(finger, int(MarbleCards.card("adams_finger", int(powers.adams_finger)).p.burn))
	if powers.has("thunderstorm"):
		var step := int(MarbleCards.card("thunderstorm", int(powers.thunderstorm)).p.x)
		for k in thunder_k:
			_hit_plain(_random_foe(), 1)
		thunder_k += step
	if powers.has("adams_awakening"):
		var p: Dictionary = MarbleCards.card("adams_awakening", int(powers.adams_awakening)).p
		if p.has("burn"):
			_apply_burn(_random_foe(), int(p.burn), false)
		if p.has("power"):
			my_power += int(p.power)
	for id in ["fervor_of_the_first_apostle", "flagellum_of_the_first_apostle"]:
		if powers.has(id):
			var p: Dictionary = MarbleCards.card(id, int(powers[id])).p
			my_thorns += int(p.get("thorns", 0))
			if id == "flagellum_of_the_first_apostle" and p.has("power"):
				my_power += int(p.power)


## Use bottle `b` of your run (its target: an enemy index, when it needs one).
func use_bottle(b: int, target := -1) -> void:
	if over or b < 0 or b >= mrun.bottles.size():
		return
	var id := String(mrun.bottles[b])
	var t: Foe = _tgt(target)
	mrun.bottles.remove_at(b)
	CombatLog.line("> BOTTLE %s used on %s" % [id, _fname(t)])
	_ev({"type": "bottle", "name": String(MarbleItems.bottle(id).get("name", id))})
	match id:
		"healing_draught":
			_heal(10)
		"fire_flask":
			_hit_plain(t, 8)
		"ember_jar":
			for f: Foe in _all():
				_burn(f, 4)
		"iron_tonic":
			_shield(8)
		"marble_pouch":
			for k in 2:
				if hand.size() >= MAX_ROW:
					break
				if draw_pile.is_empty():
					draw_pile = used_pile.duplicate()
					used_pile.clear()
					_shuffle(draw_pile)
				if draw_pile.is_empty():
					break
				var i: int = draw_pile.pop_back()
				_uid += 1
				hand.append({"c": String(mrun.bag[i].c), "sym": String(mrun.bag[i].sym), "src": i, "uid": _uid, "frozen": false, "hidden": false})
		"smoke_bomb":
			_gain_dodge(1)
		"weakening_salts":
			for f: Foe in _all():
				_weaken(f, 2)
	_enemy_thorns()
	_check_end()


## A ticket used in the fight (the user, 2026-11-27; see Tickets). `arg`: what the screen asked the player for:
## marbles (Marble / Greater Marble: the chosen ones), hand (Duplication / Removal: an index into `hand`), ci (Fixing:
## the card), swaps (Timeout: [[card index, backpack index], ...]). The ticket itself is taken off by the caller.
func use_ticket(id: String, arg: Dictionary = {}) -> void:
	if over:
		return
	CombatLog.line("> TICKET %s %s" % [id, str(arg)])
	_ev({"type": "bottle", "name": String(Tickets.get_def(id).get("name", id))})
	match id:
		"health":
			_heal(int(ceil(run.max_hp * Tickets.HEAL_PCT)))
		"shield":
			_shield(int(ceil(run.max_hp * Tickets.SHIELD_PCT)))
		"marble", "greater_marble":
			for m in arg.get("marbles", []):
				mrun.bag.append({"c": String(m.c), "sym": String(m.get("sym", ""))})
				_to_hand(mrun.bag.size() - 1)
		"duplication":
			var h := int(arg.get("hand", -1))
			if h >= 0 and h < hand.size():
				mrun.bag.append({"c": String(hand[h].c), "sym": String(hand[h].get("sym", ""))})
				_to_hand(mrun.bag.size() - 1)
		"removal":
			var h := int(arg.get("hand", -1))
			if h >= 0 and h < hand.size():
				var gone: Dictionary = hand.pop_at(h)
				if int(gone.get("src", -1)) >= 0:
					_drop_marbles([int(gone.src)])
				_draw_into_hand(1)
		"rehearsal":
			var n := 0
			for k in range(hand.size() - 1, -1, -1):
				var hm: Dictionary = hand[k]
				if bool(hm.get("frozen", false)):
					continue  # (a frozen marble stays where it is)
				hand.remove_at(k)
				n += 1
				if int(hm.get("src", -1)) >= 0:
					draw_pile.append(int(hm.src))
			_shuffle(draw_pile)
			_draw_into_hand(n)
		"fixing":
			var ci := int(arg.get("ci", -1))
			durab.erase(ci)
			hammered.erase(ci)
			_ev({"type": "replaced", "ci": ci})
		"encore":
			encore += 1
		"money":
			mrun.leaves *= 2
		"timeout":
			for sw in arg.get("swaps", []):
				var ci := int(sw[0])
				var b := int(sw[1])
				if ci >= 0 and ci < run.cards.size() and b >= 0 and b < mrun.backpack.size():
					var out := String(run.cards[ci])
					run.cards[ci] = mrun.backpack[b]
					mrun.backpack[b] = out
					for st in [durab, grow, power_used, charges, charge, cooldown, silenced, hammered]:
						st.erase(ci)
					_ev({"type": "replaced", "ci": ci})
			_recount()
	_check_end()


## Is card `ci` broken (Durability gone, or hammered to pieces)? The Ticket of Fixing mends it.
func broken(ci: int) -> bool:
	return durability_left(ci) == 0 or int(hammered.get(ci, 0)) >= HAMMER_BREAKS


## Marble `i` of the bag comes out now (into this turn's marbles).
func _to_hand(i: int) -> void:
	_uid += 1
	hand.append({"c": String(mrun.bag[i].c), "sym": String(mrun.bag[i].get("sym", "")), "src": i, "uid": _uid, "frozen": false, "hidden": false})


## Draw n more marbles from the bag now (the bin is shuffled back in when the bag runs out).
func _draw_into_hand(n: int) -> void:
	for k in n:
		if hand.size() >= MAX_ROW:
			break
		if draw_pile.is_empty():
			draw_pile = used_pile.duplicate()
			used_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		_to_hand(int(draw_pile.pop_back()))


## The Cactus Plushie: you can't gain Shield.
func _shield(n: int) -> void:
	if run.has_artifact("cactus_plushie") and n > 0:
		_art_ev("cactus_plushie", "No Shield")
		return
	super._shield(n)


## The fight is over: what it lent is given back (A Daughter's Secret's max HP).
func finish() -> void:
	var gone := []  # (a Ghost marble used on the last turn: gone from your bag too)
	for m in chant:
		if bool(m.get("gone", false)) and int(m.get("src", -1)) >= 0:
			gone.append(int(m.src))
			m.src = -1
	if not gone.is_empty():
		_drop_marbles(gone)
	if hp_loan > 0:
		run.max_hp += hp_loan
		hp_loan = 0
