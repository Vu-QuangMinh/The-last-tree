extends RefCounted
## Every Marbles card cast in a real MarblesFight, and what it did checked (see tools/marbles_cards_test.gd).

var bad := 0
var done := {}


func _ok(what: String, cond: bool) -> void:
	if not cond:
		print("  FAIL " + what)
		bad += 1


## A fight with these cards (in this order) against two big Icelings.
func _f(cards: Array, levels := {}) -> MarblesFight:
	var r := MarblesRun.new()
	r.setup(11)
	r.cards = cards.duplicate()
	for id in levels:
		r.levels[id] = levels[id]
	r.hp = 60
	r.max_hp = 100
	var f := MarblesFight.new()
	f.setup(r, ["iceling", "iceling"])
	for x in f.foes:
		x.max_hp = 200
		x.hp = 200
		x.block = 0
		x.moves = [{"kind": "hold"}]  # (they stand still: only the cards are checked)
		x.random_moves = false
		x.intent = {"kind": "hold"}
	f.block = 0
	return f


## Chant these marbles ("F W A", "*" a star; a carving as "F:sword").
func _chant(f: MarblesFight, marbles: Array) -> void:
	f.hand.clear()
	f.chant.clear()
	f.chanted = false
	for m in marbles:
		var parts := String(m).split(":")
		var sym := parts[1] if parts.size() > 1 else ""
		var c := parts[0]
		if c == "*":
			c = "A"
			sym = "star"
		f.chant.append({"c": c, "sym": sym, "src": -1, "uid": 0, "frozen": false, "hidden": false})
	f.do_chant()


func _pat(f: MarblesFight, ci: int) -> Array:
	var out := []
	for ch in String(f.card(ci).pattern):
		out.append(ch)
	return out


## Chant card ci's pattern and cast it at enemy 0.
func _cast(f: MarblesFight, ci := 0, target := 0, extra: Array = []) -> void:
	_chant(f, _pat(f, ci) + extra)
	f.cast(ci, target)


func _hp(f: MarblesFight, i := 0) -> int:
	return int(f.foes[i].hp)


func run() -> void:
	var f: MarblesFight
	# ---------- the rules
	f = _f(["flicker"])
	_chant(f, ["F", "W", "F", "F"])
	_ok("Repeatable 2: three F, two casts", int(f.charges.get(0, 0)) == 2)
	f = _f(["spark"])
	_chant(f, ["F", "*"])
	_ok("a Star counts as any colour", int(f.charges.get(0, 0)) == 1)
	f = _f(["spark"])
	_chant(f, ["F", "W", "F"])
	_ok("order counts: F W F has no FF", int(f.charges.get(0, 0)) == 0)
	# carvings work as the chant is read, left to right (2026-11-22): for all your damage / Shield cards this turn
	f = _f(["spark"])
	_chant(f, ["F:skull", "F:sword", "W:sword"])
	_ok("skull, sword, sword: 10 -> 10 x 1.5 + 3 + 3 = 21", f.card_damage(10) == 21)
	_ok("each carving's events carry its marble's place (the screen plays them as it reads it)", f.events.filter(func(e): return String(e.type) == "boost").all(func(e): return e.has("note")))
	f = _f(["spark"])
	_chant(f, ["F:sword", "F:skull"])
	_ok("sword then skull: (10 + 3) x 1.5 = 19", f.card_damage(10) == 19)
	var sf := _f(["spark"])
	_chant(sf, ["F:sword", "F"])
	_ok("Spark's card says Deal 6 damage once a Sword is read", String(sf.card(0).text).begins_with("Deal 6 damage"))
	sf.cast(0, 0)
	_ok("and deals 6", _hp(sf) == 194)
	f._cur_ci = -1
	f = _f(["spark"])
	_chant(f, ["F:skull", "F:skull"])
	f._cur_ci = 0
	_ok("Skull doesn't stack", f.card_damage(10) == 15)
	f = _f(["spark"])
	var hp0 := f.mrun.hp
	_chant(f, ["W:heart", "F", "F"])
	_ok("every carving in the chant works, counted by a card or not", f.mrun.hp == hp0 + 2)
	f = _f(["spark"])
	_chant(f, ["F:heart", "F"])
	_ok("a counted Heart heals 2", f.mrun.hp == hp0 + 2 and f.events.any(func(e): return String(e.type) == "boost" and String(e.col) == "hp"))
	f = _f(["splash"])
	_chant(f, ["W:shield", "W:wing"])
	f.cast(0)
	_ok("Shield marble +3 then Wing x1.5: (2+3)*1.5 = 7", f.block == 7)
	f = _f(["spark"])
	f.foes[0].expose = 2
	f.foes[0].armor = 1
	_cast(f)
	_ok("Expose +2, Armor -1: 3 -> 4", _hp(f) == 196)
	f = _f(["spark"])
	f.weak = 2
	_cast(f)
	_ok("Weakened: half", _hp(f) == 199)
	f = _f(["spark"])
	f.foes[0].vulnerable = 1
	_cast(f)
	_ok("Vulnerable: +50%", _hp(f) == 196)
	# the draw: first turn 1 of each + 3; marbles come back only when the bag is empty
	f = _f(["spark"])
	_ok("first turn: 6 marbles", f.hand.size() == 6)
	_ok("first turn: one of each colour", f.hand.filter(func(m): return int(m.src) < 0).size() == 3)
	f.end_turn()
	_ok("then 3 more: the marbles you didn't chant stay in your row", f.hand.size() == 9)
	for k in 2:  # (two marbles from the bag into the chant)
		var at := -1
		for h in f.hand.size():
			if int(f.hand[h].src) >= 0:
				at = h
				break
		f.put(at)
	f.do_chant()
	f.end_turn()
	_ok("chanted marbles are used, the rest stay: 9 - 2 + 3", f.hand.size() == 10 and f.used_pile.size() == 2)
	f.end_turn()  # (the bag had 9: 3 + 3 + 3 drawn; it refills from the recycle bin: the 2 used ones; the row holds 10)
	_ok("the row is full (10): nothing drawn", f.hand.size() == 10 and f.used_pile.size() == 2)
	f.hand.clear()
	f.end_turn()
	_ok("an empty bag refills from the recycle bin (2 used marbles)", f.hand.size() == 2 and f.used_pile.is_empty())
	f.hand.clear()
	f.end_turn()
	_ok("bag and recycle bin both empty: nothing is drawn", f.hand.is_empty())
	# ---------- list 1
	f = _f(["flicker"]); _cast(f); _ok("Flicker: Burn 1", f.foes[0].burn == 1); done.flicker = 1
	f = _f(["drop"]); _cast(f); _ok("Drop: heal 1", f.run.hp == 61); done.drop = 1
	f = _f(["sharp_wind"]); _cast(f); _ok("Sharp Wind: Expose 1", f.foes[0].expose == 1); done.sharp_wind = 1
	f = _f(["spark"], {"spark": 2}); _cast(f); _ok("Spark+2: 7", _hp(f) == 193); done.spark = 1
	f = _f(["steam_gun"]); _cast(f); _ok("Steam Gun: 1 per Wind owned (3)", _hp(f) == 197); done.steam_gun = 1
	f = _f(["firelance"]); _cast(f); _ok("Firelance: Burn 3", f.foes[0].burn == 3); done.firelance = 1
	f = _f(["smoke_screen"]); _cast(f); _ok("Smoke Screen: 1 Shield, Weakened", f.block == 1 and f.foes[0].weak == 1); done.smoke_screen = 1
	f = _f(["splash"]); _cast(f); _ok("Splash: 2 Shield", f.block == 2); done.splash = 1
	f = _f(["wave"]); _cast(f); _ok("Wave: grows to 2, gains 2", f.block == 2)
	f.end_turn(); f.block = 0; _cast(f); _ok("Wave: then 3", f.block == 3); done.wave = 1
	f = _f(["heat_wave"]); _cast(f); _ok("Heat Wave: Burn 2 on all", f.foes[0].burn == 2 and f.foes[1].burn == 2); done.heat_wave = 1
	f = _f(["sea_sickness"]); _cast(f); _ok("Sea Sickness: all Weakened", f.foes[1].weak == 1); done.sea_sickness = 1
	f = _f(["tail_wind"]); _cast(f); f.end_turn(); _ok("Tail Wind: 4 marbles next turn", f.hand.size() == 4); done.tail_wind = 1
	f = _f(["laser_beam"]); _cast(f); _ok("Laser Beam: 10, 3 to you", _hp(f) == 190 and f.run.hp == 57); done.laser_beam = 1
	f = _f(["steam_engine", "spark"]); _cast(f); _ok("Steam Engine: Spark on its right fires", _hp(f) == 197)
	_ok("Steam Engine: CD 1", f.cooldown.has(0)); done.steam_engine = 1
	f = _f(["fire_storm"]); _cast(f); _ok("Fire Storm: Burn 2", f.foes[0].burn == 2)
	f.end_turn(); f.foes[0].burn = 0; _cast(f); _ok("Fire Storm: then 4", f.foes[0].burn == 4); done.fire_storm = 1
	f = _f(["geyser"])
	for k in 3:
		_cast(f)
		if k < 2:
			_ok("Geyser: nothing before 3", _hp(f) == 200)
			f.end_turn()
			f.foes[0].hp = 200
			f.foes[1].hp = 200
	_ok("Geyser: 20 to all at 3", _hp(f) == 180 and _hp(f, 1) == 180); done.geyser = 1
	f = _f(["hot_spring"]); _cast(f); _ok("Hot Spring: heal 3", f.run.hp == 63); done.hot_spring = 1
	f = _f(["elemental_core"], {"elemental_core": 1}); _cast(f); _ok("Elemental Core+1: 4, 4, 2", _hp(f) == 196 and f.block == 4 and f.run.hp == 62); done.elemental_core = 1
	f = _f(["pressure_cooker"]); f.foes[0].burn = 1; _cast(f); _ok("Pressure Cooker: double on a burning one", _hp(f) == 194); done.pressure_cooker = 1
	f = _f(["chosen_one"]); _cast(f); _ok("Chosen One alone: x3", _hp(f) == 191)
	f = _f(["chosen_one", "spark"]); _cast(f); _ok("Chosen One with Spark: 3", _hp(f) == 197); done.chosen_one = 1
	f = _f(["updraft"]); _cast(f); _ok("Updraft: 2 Shield", f.block == 2); f.end_turn(); _ok("Updraft: +1 marble", f.hand.size() == 4); done.updraft = 1
	f = _f(["alcohol"]); _cast(f); _ok("Alcohol: Power 1, Burn 3 on you", f.my_power == 1 and f.burn == 3); done.alcohol = 1
	f = _f(["splash", "cyclone"]); _chant(f, ["W", "W", "F", "W"]); f.cast(0); f.cast(1, 0)
	_ok("Cyclone: 2 water cards this turn: 4 Shield, 4 damage", f.block == 6 and _hp(f) == 196); done.cyclone = 1
	f = _f(["heat_armor"]); _cast(f); _ok("Heat Armor: Thorns 2", f.my_thorns == 2); done.heat_armor = 1
	f = _f(["water_gun", "splash"]); _chant(f, ["W", "W", "F", "W", "W"]); f.cast(0, 0)
	_ok("Water Gun alone: 2 damage", _hp(f) == 198)
	f = _f(["splash", "water_gun"]); _chant(f, ["W", "W", "W", "W", "F"]); f.cast(0); f.cast(1, 0)
	_ok("Water Gun after a card with Water: 2 + 2 = 4 damage", _hp(f) == 196); done.water_gun = 1
	f = _f(["water_gun", "splash"]); _chant(f, ["W", "W", "F", "W", "W"])
	_ok("Water Gun shows X = 2 at first", String(f.card(0).text).begins_with("Deal 2 damage"))
	f.cast(1)
	_ok("a card with Water: it shows 4", String(f.card(0).text).begins_with("Deal 4 damage"))
	f.cast(0, 0)
	_ok("cast: it deals the 4 it showed, then shows 6", _hp(f) == 196 and String(f.card(0).text).begins_with("Deal 6 damage"))
	f = _f(["ocean"]); _cast(f); _ok("Ocean: 5", f.block == 5); done.ocean = 1
	f = _f(["rain"]); f.weak = 2; _cast(f); _ok("Rain: cleanse + 2 Shield", f.weak == 0 and f.block == 2); done.rain = 1
	f = _f(["set_fire_to_the_rain", "splash"]); _chant(f, ["W", "A", "F", "W", "W"]); f.cast(0); f.cast(1)
	_ok("Set Fire to the Rain: Burn 1", f.foes[0].burn + f.foes[1].burn == 1); done.set_fire_to_the_rain = 1
	f = _f(["mist"]); _cast(f); _ok("Mist: all Weakened + 2 Shield", f.foes[1].weak == 1 and f.block == 2); done.mist = 1
	f = _f(["hail"]); f.my_power = 1; f.foes[0].expose = 1; _cast(f); _ok("Hail: (3 + 2 Power) + 2 Expose = 7", _hp(f) == 193); done.hail = 1
	f = _f(["forest_fire"]); f.foes[0].burn = 3; _cast(f); _ok("Forest Fire: 4 on it, spread 4", f.foes[0].burn == 4 and f.foes[1].burn == 4); done.forest_fire = 1
	f = _f(["circle_of_life"]); f.foes[0].hp = 5; _cast(f); _ok("Circle of Life: a kill: +10 for good", int(f.mrun.perm.get("circle_of_life", 0)) == 10)
	_ok("Circle of Life: Durability 1", f.durability_left(0) == 0); done.circle_of_life = 1
	f = _f(["backdraft"]); f.foes[0].burn = 4; _cast(f); _ok("Backdraft: 4 Burn gone: 8 damage", _hp(f) == 192 and f.foes[0].burn == 0); done.backdraft = 1
	f = _f(["heed_my_call", "spark"]); _chant(f, ["A", "W", "F", "F", "F"]); f.cast(0); f.cast(1, 0)
	_ok("Heed My Call: +1 a hit", _hp(f) == 196); done.heed_my_call = 1
	f = _f(["stream"]); _cast(f); _ok("Stream: 1 and 1", _hp(f) == 199 and f.block == 1); f.end_turn(); f.block = 0; _cast(f)
	_ok("Stream: then 2 and 2", _hp(f) == 197 and f.block == 2); done.stream = 1
	f = _f(["cold_feet"]); _cast(f); _ok("Cold Feet: Stun, you Vulnerable", f.foes[0].stun == 1 and f.vulnerable > 0); done.cold_feet = 1
	f = _f(["snuffing_the_candle"]); f.foes[0].hp = 10; _cast(f); _ok("Snuffing: 10 - 2 = 8: executed", f.foes[0].dead()); done.snuffing_the_candle = 1
	f = _f(["gaze_of_the_princess", "refreshing_wind"]); f.durab[0] = 0; _cast(f, 1); _ok("Refreshing Wind: +1 Durability on the left", f.durability_left(0) == 1); done.refreshing_wind = 1
	f = _f(["thousand_cuts"]); _cast(f); _ok("Thousand Cuts: 1 x4", _hp(f) == 196); done.thousand_cuts = 1
	f = _f(["burn_them_all"]); _cast(f); _ok("Burn Them All: 5 then doubled", f.foes[0].burn == 10 and f.foes[1].burn == 10); done.burn_them_all = 1
	f = _f(["spark", "primitive_engine"]); _cast(f, 1); _ok("Primitive Engine: the card on its left", _hp(f) == 197); done.primitive_engine = 1
	f = _f(["all_out", "splash"]); _chant(f, ["F", "F", "F", "A", "W", "W"]); f.cast(0); f.cast(1, 0)
	_ok("All-Out: no Shield, the Shield card deals 2 x1.3", f.block == 0 and _hp(f) + _hp(f, 1) < 400); done.all_out = 1
	f = _f(["stick_and_carrot"]); f.block = 6; _cast(f); _ok("Stick and Carrot: your Shield as damage", _hp(f) == 194); done.stick_and_carrot = 1
	f = _f(["adams_awakening", "firelance"]); f.my_power = 2; _chant(f, ["F", "F", "A", "W", "F", "A"]); f.cast(0); f.cast(1, 0)
	_ok("Adam's Awakening: Burn + Power", f.foes[0].burn == 5); done.adams_awakening = 1
	f = _f(["flame_of_vengeance"]); _cast(f); f.block = 10; f._hurt_player(10); _ok("Flame of Vengeance: 10 Shield lost: 2 Thorns", f.my_thorns == 2); done.flame_of_vengeance = 1
	f = _f(["desperate_drop"]); f.weak = 1; f.burn = 2; _cast(f); _ok("Desperate Drop: 2 cleansed: Burn 6 on all", f.foes[1].burn == 6); done.desperate_drop = 1
	f = _f(["fervor_of_the_first_apostle"]); _cast(f); f.my_thorns = 2; f._on_attacked(f.foes[0], 3); _ok("Fervor: Thorns as Burn", f.foes[0].burn == 2 and _hp(f) == 200); done.fervor_of_the_first_apostle = 1
	f = _f(["implosion"]); _cast(f); _ok("Implosion: 1 per marble owned (9)", _hp(f) == 191); done.implosion = 1
	f = _f(["gaze_of_the_princess"]); _cast(f); _ok("Gaze: Stun", f.foes[0].stun == 1)
	f.end_turn(); _cast(f); _ok("after a stun: immune a turn", f.foes[0].stun == 0); done.gaze_of_the_princess = 1
	f = _f(["spark", "carrot_and_stick"]); _chant(f, ["F", "F", "W", "W", "F", "F"]); f.cast(0, 0); f.cast(1); _ok("Carrot and Stick: half of 3 = 1", f.block == 1); done.carrot_and_stick = 1
	f = _f(["ludwigs_passion"], {"ludwigs_passion": 2}); _cast(f); _ok("Ludwig's Passion: a Power", f.powers.has("ludwigs_passion")); done.ludwigs_passion = 1
	f = _f(["thunderstorm"]); _cast(f); f.end_turn(); f.end_turn(); _ok("Thunderstorm: 1, then 2 hits", _hp(f) + _hp(f, 1) <= 397); done.thunderstorm = 1
	f = _f(["stoke_the_fire"]); f.foes[0].burn = 3; _cast(f); _ok("Stoke the Fire: doubled", f.foes[0].burn == 6); done.stoke_the_fire = 1
	f = _f(["spark", "curse_of_the_night", "drop"]); _cast(f, 1); _ok("Curse of the Night: neighbours are Bites", f.card(0).id == "bite" and f.card(2).id == "bite"); done.curse_of_the_night = 1
	f = _f(["aoles_last_wish"]); _cast(f); f.end_turn(); _ok("Aole's Last Wish: 5 marbles", f.hand.size() == 5); done.aoles_last_wish = 1
	# ---------- list 2
	f = _f(["adams_finger"]); _cast(f); f.end_turn(); _ok("Adam's Finger: Burn 1 each turn", f.foes[0].burn >= 1); done.adams_finger = 1
	f = _f(["glass_half_full"]); _cast(f); _ok("Glass Half Full: 5", _hp(f) == 195); done.glass_half_full = 1
	f = _f(["air", "flicker"]); _chant(f, ["A", "F"]); f.cast(0); f.cast(1, 0); _ok("Air: Burn cards +1", f.foes[0].burn == 2); done.air = 1
	f = _f(["adams_fist"]); _cast(f); _ok("Adam's Fist: Burn 1 and 2 damage", f.foes[0].burn == 1 and _hp(f) == 198); done.adams_fist = 1
	f = _f(["sadistic_nature"]); _cast(f); _ok("Sadistic Nature: Vulnerable, +1 Power", f.foes[0].vulnerable > 0 and f.my_power == 1); done.sadistic_nature = 1
	f = _f(["warm_up"]); f.end_turn(); f.end_turn(); _cast(f); _ok("Warm Up: 2 turns unused: 10", _hp(f) == 190); done.warm_up = 1
	f = _f(["elizes_hesitation"])
	for k in 3:
		_cast(f)
		if k < 2:
			f.end_turn()
	_ok("Elize's Hesitation: Stun at 3", f.foes[0].stun == 1); done.elizes_hesitation = 1
	f = _f(["full_glass"]); _cast(f); _ok("Full Glass: 5, 1 to you", _hp(f) == 195 and f.run.hp == 59); done.full_glass = 1
	f = _f(["nilas_quickstep"]); _cast(f); _ok("Nila's Quickstep: Dodge and Power", f.dodge == 1 and f.my_power == 1); done.nilas_quickstep = 1
	f = _f(["geyser", "energize"]); _cast(f, 1); _ok("Energize: Geyser charged", int(f.charge.get(0, 0)) == 1); done.energize = 1
	f = _f(["freeze"]); _cast(f); _ok("Freeze!: all stunned, you too", f.foes[1].stun == 1 and f.stunned == 1); done.freeze = 1
	f = _f(["aoles_magic", "spark"]); _chant(f, ["A", "A", "F"]); f.cast(0); _ok("Aole's Magic: a Star: Spark wakes", int(f.charges.get(1, 0)) == 1); done.aoles_magic = 1
	f = _f(["rain_of_pain"]); _cast(f); _ok("Rain of Pain: 1 x (2 + 3 Fire)", _hp(f) == 195); done.rain_of_pain = 1
	f = _f(["pyrophiliac"]); _cast(f); _ok("Pyrophiliac: heal, Burn 1", f.foes[0].burn + f.foes[1].burn == 1); done.pyrophiliac = 1
	f = _f(["sun_burn"]); _cast(f); _ok("Sun Burn: Expose 2", f.foes[0].expose == 2); done.sun_burn = 1
	f = _f(["might_of_the_first_apostle"]); _cast(f); _ok("Might: Burn 3, first: +1 Power", f.foes[0].burn == 3 and f.my_power == 1); done.might_of_the_first_apostle = 1
	f = _f(["hot_blood"]); _cast(f); _ok("Hot Blood: 40% missing: +2 Power", f.power_now() == 2); done.hot_blood = 1
	f = _f(["glass_cannon"]); _chant(f, ["F", "W:sword", "A"]); f.cast(0, 0); _ok("Glass Cannon: 3 + 6 + 3 (+3 Sword)", _hp(f) == 185); done.glass_cannon = 1
	f = _f(["ludwigs_inspiration"]); _cast(f); _ok("Ludwig's Inspiration: 2 carved", f.chant.filter(func(m): return String(m.sym) != "").size() == 2); done.ludwigs_inspiration = 1
	f = _f(["alchemy"]); f.mrun.backpack = ["spark"]; _cast(f); f.replace_with(0); _ok("Alchemy: replaces itself", f.run.cards[0] == "spark" and f.mrun.backpack[0] == "alchemy"); done.alchemy = 1
	f = _f(["toxic_wind"]); _cast(f); _ok("Toxic Wind: all three on all", f.foes[1].expose == 1 and f.foes[1].weak == 1 and f.foes[1].vulnerable > 0); done.toxic_wind = 1
	f = _f(["spark", "over_exertion", "spark"]); _cast(f, 1); _ok("Over Exertion: both neighbours fire, then Silenced", _hp(f) == 194 and f.silenced.has(0) and f.silenced.has(2)); done.over_exertion = 1
	f = _f(["a_daughters_secret"]); _cast(f); _ok("A Daughter's Secret: max HP -20, Stun", f.run.max_hp == 80 and f.foes[0].stun == 1)
	f.finish(); _ok("given back after the fight", f.run.max_hp == 100); done.a_daughters_secret = 1
	f = _f(["random_things_go", "aoles_magic", "spark"]); _chant(f, ["W", "F", "A", "A", "A", "F"]); f.cast(0); f.cast(1); _ok("Random Things Go!: an Extension: +1 Power", f.my_power == 1); done.random_things_go = 1
	f = _f(["borrowed_warmth"]); f.foes[0].burn = 6; _cast(f); _ok("Borrowed Warmth: heal half of 6", f.run.hp == 63); done.borrowed_warmth = 1
	f = _f(["endless_well", "splash"]); _chant(f, ["W", "W", "W", "W", "W"]); f.cast(0); f.cast(1); f.end_turn(); _ok("Endless Well: Shield stays", f.block > 0); done.endless_well = 1
	f = _f(["iron_maiden"]); _cast(f); _ok("Iron Maiden: Thorns 1, 3 damage", f.my_thorns == 1 and _hp(f) == 197); done.iron_maiden = 1
	f = _f(["embracing_the_pain"]); _cast(f); _ok("Embracing the Pain: 2 to you, 6 Shield", f.run.hp == 58 and f.block == 6); done.embracing_the_pain = 1
	f = _f(["nilas_blades"]); f.dodges_gained = 2; _cast(f); _ok("Nila's Blades: 5 x3", _hp(f) == 185); done.nilas_blades = 1
	f = _f(["knivels_innocence"], {"knivels_innocence": 1}); _cast(f); _ok("Knivel's Innocence+1: cast twice: 1 then 2", f.block == 3); done.knivels_innocence = 1
	f = _f(["flagellum_of_the_first_apostle"]); _cast(f); f.my_thorns = 1; f.my_power = 2; f._on_attacked(f.foes[0], 1); _ok("Flagellum: Thorns + Power", _hp(f) == 197); done.flagellum_of_the_first_apostle = 1
	f = _f(["a_brothers_cluelessness"]); f.mrun.perm["a_brothers_cluelessness"] = 9; _cast(f); _ok("A Brother's Cluelessness: 10th cast: Cleverness", f.run.cards[0] == "a_brothers_cleverness"); done.a_brothers_cluelessness = 1
	f = _f(["heat_center"]); f.foes[1].burn = 3; f.burn = 2; _cast(f); _ok("Heat Center: every Burn on it", f.foes[0].burn == 5 and f.burn == 0 and f.foes[1].burn == 0); done.heat_center = 1
	f = _f(["moth_to_flame"]); f.foes[0].burn = 1; _cast(f); _ok("Moth to Flame: attacks go at it", f._forced_target(f.foes[1]) == f.foes[0]); done.moth_to_flame = 1
	f = _f(["spark", "still_lake", "drop"]); _cast(f, 1); _ok("Still Lake: 2 Silenced: 4 Shield, heal 4", f.block == 4 and f.run.hp == 64 and f.silenced.has(0)); done.still_lake = 1
	f = _f(["aoles_grace"]); _chant(f, ["A", "W", "A"]); f.cast(0); _ok("Aole's Grace: 2 Stars", f.chant.filter(func(m): return m.sym == "star").size() == 2); done.aoles_grace = 1
	f = _f(["focus_fire"]); _cast(f); _ok("Focus Fire: 3 times Expose 1 + 1 (2 + 3 + 4)", f.foes[0].expose == 3 and _hp(f) == 191); done.focus_fire = 1
	f = _f(["bite"]); _cast(f); _ok("Bite: 4 and heal 2", _hp(f) == 196 and f.run.hp == 62); done.bite = 1
	f = _f(["gone_like_the_wind"]); _cast(f); _ok("Gone Like the Wind: Dodge 1", f.dodge == 1); done.gone_like_the_wind = 1
	f = _f(["adams_resolve", "laser_beam"]); _chant(f, ["F", "F", "F", "F"]); f.cast(0); f.cast(1, 0); _ok("Adam's Resolve: hurt yourself: +1 Power", f.my_power == 1); done.adams_resolve = 1
	f = _f(["whim_of_the_pianist"]); f.mrun.bag[0].sym = "coin"; f.mrun.bag[1].sym = "heart"; _cast(f); _ok("Whim: 4 per carved marble (2)", _hp(f) == 192); done.whim_of_the_pianist = 1
	f = _f(["a_brothers_cleverness"]); _cast(f); _ok("A Brother's Cleverness: Dodge 2", f.dodge == 2); done.a_brothers_cleverness = 1
	# every card has a check
	for id in MarbleCards.C:
		if not done.has(id):
			print("  NO CHECK " + id)
			bad += 1
	print("MARBLES CARDS: %d failed (%d cards)" % [bad, MarbleCards.C.size()])
