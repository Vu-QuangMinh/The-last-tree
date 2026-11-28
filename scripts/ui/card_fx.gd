class_name CardFx
extends RefCounted
## Every marble card's own effect (the user, 2026-11-27): what it DOES picks its family (how it moves and feels), its
## NAME picks its motif (what it is made of). Attacks wind up, fly at the enemy shaking and hit hard; debuffs sink
## onto the enemy; self-buffs are calm and radiate from you; Powers are slow and grand; chant tricks weave round the
## card. Built from the Vfx toolkit, like SpellFx. Casting the same card again straight away (a Repeatable stack)
## plays a short version, so fights never drag.
##   play() returns the seconds until the effect lands (the fight waits that long before applying it).

## id -> [family, motif, flags]. flags: "big" (a heavier hit), "self" (it hurts you too), "line" (flies straight).
const CARDS := {
	"flicker": ["bolt", "flame", ""], "drop": ["aura", "water", ""], "sharp_wind": ["hex", "wind", ""],
	"spark": ["bolt", "ember", ""], "steam_gun": ["bolt", "steam", "line"], "firelance": ["bolt", "flame", "line"],
	"smoke_screen": ["hex", "smoke", ""], "splash": ["aura", "water", ""], "wave": ["aura", "water", ""],
	"heat_wave": ["sweep", "ember", ""], "sea_sickness": ["sweep", "bubble", ""], "paper_cut": ["shuriken", "paper", ""],
	"tail_wind": ["accent", "wind", ""], "laser_beam": ["beam", "laser", "big self"], "steam_engine": ["weave", "gear", ""],
	"fire_storm": ["storm", "flame", ""], "geyser": ["rise", "water", "big"], "hot_spring": ["aura", "steam", ""],
	"elemental_core": ["bolt", "prism", ""], "pressure_cooker": ["bolt", "steam", "big"], "chosen_one": ["smite", "light", "big"],
	"updraft": ["accent", "wind", ""], "alcohol": ["aura", "bubble", ""], "cyclone": ["storm", "water", ""],
	"heat_armor": ["aura", "ember", ""], "water_gun": ["bolt", "water", "line"], "ocean": ["aura", "water", "big"],
	"rain": ["shower", "water", ""], "set_fire_to_the_rain": ["shower", "ember", ""], "mist": ["sweep", "steam", ""],
	"hail": ["fall", "ice", ""], "forest_fire": ["bolt", "leaf", ""], "circle_of_life": ["storm", "leaf", ""],
	"backdraft": ["implode", "flame", "big"], "heed_my_call": ["radiate", "rune", ""], "stream": ["bolt", "water", "line"],
	"cold_feet": ["hex", "ice", ""], "snuffing_the_candle": ["bolt", "smoke", ""], "refreshing_wind": ["weave", "wind", ""],
	"thousand_cuts": ["slash", "wind", ""], "burn_them_all": ["sweep", "flame", "big"], "primitive_engine": ["weave", "gear", ""],
	"all_out": ["radiate", "ember", ""], "stick_and_carrot": ["bolt", "shield", "big"], "adams_awakening": ["radiate", "flame", ""],
	"flame_of_vengeance": ["radiate", "thorn", ""], "desperate_drop": ["sweep", "ember", "big"],
	"fervor_of_the_first_apostle": ["radiate", "light", ""], "implosion": ["implode", "prism", "big"],
	"gaze_of_the_princess": ["hex", "star", ""], "carrot_and_stick": ["aura", "shield", ""], "ludwigs_passion": ["radiate", "note", ""],
	"thunderstorm": ["radiate", "lightning", ""], "stoke_the_fire": ["storm", "flame", ""], "curse_of_the_night": ["radiate", "shadow", ""],
	"aoles_last_wish": ["radiate", "star", ""], "adams_finger": ["radiate", "flame", ""], "glass_half_full": ["bolt", "glass", "self"],
	"air": ["weave", "wind", ""], "adams_fist": ["bolt", "flame", "big"], "sadistic_nature": ["hex", "blood", ""],
	"warm_up": ["bolt", "ember", ""], "elizes_hesitation": ["hex", "star", ""], "full_glass": ["bolt", "glass", "self"],
	"nilas_quickstep": ["aura", "wind", ""], "energize": ["weave", "lightning", ""], "freeze": ["sweep", "ice", "big"],
	"aoles_magic": ["weave", "star", ""], "rain_of_pain": ["fall", "flame", ""], "pyrophiliac": ["aura", "flame", ""],
	"sun_burn": ["smite", "sun", ""], "might_of_the_first_apostle": ["bolt", "light", "big"], "hot_blood": ["radiate", "blood", ""],
	"glass_cannon": ["bolt", "glass", "big line"], "ludwigs_inspiration": ["weave", "note", ""], "alchemy": ["weave", "prism", ""],
	"toxic_wind": ["sweep", "poison", ""], "over_exertion": ["weave", "gear", ""], "a_daughters_secret": ["hex", "shadow", "self"],
	"random_things_go": ["radiate", "prism", ""], "borrowed_warmth": ["drain", "flame", ""], "endless_well": ["radiate", "water", ""],
	"iron_maiden": ["aura", "thorn", ""], "embracing_the_pain": ["aura", "shield", "self"], "nilas_blades": ["slash", "blade", ""],
	"knivels_innocence": ["aura", "shield", ""], "flagellum_of_the_first_apostle": ["radiate", "thorn", ""],
	"a_brothers_cluelessness": ["aura", "shield", ""], "heat_center": ["implode", "flame", ""], "moth_to_flame": ["hex", "moth", ""],
	"still_lake": ["weave", "water", ""], "aoles_grace": ["weave", "star", ""], "focus_fire": ["slash", "ember", ""],
	"bite": ["slash", "jaws", ""], "gone_like_the_wind": ["aura", "wind", ""], "adams_resolve": ["radiate", "flame", ""],
	"whim_of_the_pianist": ["fall", "note", ""], "insight_of_the_pianist": ["weave", "note", ""], "a_brothers_cleverness": ["aura", "wind", ""],
}

## motif -> [shape, colour, its light colour]. What a card is made of.
const MOTIFS := {
	"ember": [Vfx.SPARK, Color(1.0, 0.55, 0.15), Color(1.0, 0.8, 0.4)],
	"flame": [Vfx.GLOW, Color(1.0, 0.45, 0.1), Color(1.0, 0.75, 0.3)],
	"steam": [Vfx.SMOKE, Color(0.92, 0.93, 0.97, 0.75), Color(0.85, 0.95, 1.0)],
	"smoke": [Vfx.SMOKE, Color(0.28, 0.26, 0.3, 0.8), Color(1.0, 0.6, 0.3)],
	"water": [Vfx.DROP, Color(0.3, 0.65, 1.0), Color(0.6, 0.9, 1.0)],
	"bubble": [Vfx.BUBBLE, Color(0.55, 0.95, 0.85), Color(0.75, 1.0, 0.9)],
	"wind": [Vfx.CHEVRON, Color(0.8, 1.0, 0.92), Color(0.85, 1.0, 0.95)],
	"paper": [Vfx.SHARD, Color(0.97, 0.94, 0.85), Color(1.0, 1.0, 0.95)],
	"glass": [Vfx.CRYSTAL, Color(0.75, 0.95, 1.0), Color(0.9, 1.0, 1.0)],
	"blade": [Vfx.SHARD, Color(0.82, 0.86, 0.95), Color(0.9, 0.95, 1.0)],
	"ice": [Vfx.CRYSTAL, Color(0.6, 0.88, 1.0), Color(0.8, 0.95, 1.0)],
	"star": [Vfx.STAR, Color(1.0, 0.82, 0.4), Color(1.0, 0.92, 0.65)],
	"light": [Vfx.STAR, Color(1.0, 0.88, 0.5), Color(1.0, 0.97, 0.8)],
	"sun": [Vfx.GLOW, Color(1.0, 0.7, 0.25), Color(1.0, 0.9, 0.55)],
	"laser": [Vfx.SPARK, Color(1.0, 0.3, 0.2), Color(1.0, 0.75, 0.6)],
	"rune": [Vfx.RUNE, Color(0.85, 0.6, 1.0), Color(0.9, 0.8, 1.0)],
	"note": [Vfx.RUNE, Color(0.95, 0.75, 1.0), Color(1.0, 0.9, 1.0)],
	"thorn": [Vfx.THORN, Color(0.5, 0.78, 0.28), Color(0.65, 0.95, 0.4)],
	"leaf": [Vfx.DROP, Color(0.5, 0.85, 0.3), Color(1.0, 0.65, 0.2)],
	"jaws": [Vfx.DROP, Color(0.9, 0.12, 0.16), Color(1.0, 0.85, 0.85)],
	"blood": [Vfx.DROP, Color(0.9, 0.12, 0.16), Color(1.0, 0.35, 0.35)],
	"shadow": [Vfx.SMOKE, Color(0.25, 0.1, 0.35, 0.85), Color(0.7, 0.4, 1.0)],
	"poison": [Vfx.BUBBLE, Color(0.5, 0.95, 0.25), Color(0.7, 1.0, 0.4)],
	"moth": [Vfx.FLAKE, Color(0.95, 0.9, 0.75), Color(1.0, 0.8, 0.45)],
	"lightning": [Vfx.SPARK, Color(1.0, 0.95, 0.55), Color(1.0, 1.0, 0.8)],
	"gear": [Vfx.CROSS, Color(0.85, 0.65, 0.35), Color(1.0, 0.85, 0.55)],
	"shield": [Vfx.SHIELD, Color(0.4, 0.7, 1.0), Color(0.65, 0.85, 1.0)],
	"prism": [Vfx.STAR, Color(1.0, 0.6, 0.3), Color(0.9, 0.95, 1.0)],
}
const PRISM := [Color(1.0, 0.5, 0.2), Color(0.3, 0.65, 1.0), Color(0.6, 1.0, 0.8)]

static var _last := {}  # id -> when it last played (ms): a quick repeat plays the short version


static func has(id: String) -> bool:
	return CARDS.has(id)


static func family(id: String) -> String:
	return String(CARDS.get(id, ["", "", ""])[0])


## What each motif is made of, as textures (Kenney's Particle Pack, CC0; see Vfx.fx_tex): its body (what flies and
## blooms), whether that body is light (additive) or matter, its impact bloom, what it leaves behind, and its colours.
##   tint: the body's colour ("fire" bodies use the fire ramp instead); light: its glow; after: the aftermath kind.
const KITS := {
	"fire": {"body": ["flame_01", "flame_02", "flame_03", "flame_04"], "add": true, "bloom": ["fire_01", "fire_02"], "after": "embers", "tint": Color(1, 0.55, 0.15), "light": Color(1.0, 0.55, 0.15), "fire": true},
	"steam": {"body": ["smoke_04", "smoke_05", "smoke_06"], "add": false, "bloom": ["smoke_07", "smoke_08"], "after": "steam", "tint": Color(0.95, 0.96, 1.0, 0.8), "light": Color(0.85, 0.95, 1.0)},
	"smoke": {"body": ["smoke_01", "smoke_02", "smoke_04"], "add": false, "bloom": ["smoke_07", "smoke_08"], "after": "soot", "tint": Color(0.25, 0.22, 0.24, 0.85), "light": Color(1.0, 0.6, 0.3)},
	"water": {"body": ["circle_05", "light_03"], "add": true, "bloom": ["muzzle_02", "muzzle_03"], "after": "drips", "tint": Color(0.35, 0.7, 1.0), "light": Color(0.55, 0.85, 1.0)},
	"bubble": {"body": ["circle_05"], "add": true, "bloom": ["smoke_09", "smoke_10"], "after": "bubbles", "tint": Color(0.5, 0.95, 0.8), "light": Color(0.7, 1.0, 0.9)},
	"poison": {"body": ["circle_05", "smoke_06"], "add": true, "bloom": ["smoke_09", "smoke_10"], "after": "bubbles", "tint": Color(0.5, 0.95, 0.25), "light": Color(0.7, 1.0, 0.4)},
	"wind": {"body": ["twirl_01", "twirl_02", "twirl_03"], "add": true, "bloom": ["twirl_03", "slash_03"], "after": "streaks", "tint": Color(0.82, 1.0, 0.93, 0.85), "light": Color(0.85, 1.0, 0.95)},
	"paper": {"body": ["light_03"], "add": true, "bloom": ["scratch_01", "slash_02"], "after": "paper", "tint": Color(1.0, 0.98, 0.9), "light": Color(1.0, 1.0, 0.95)},
	"glass": {"body": ["star_04", "light_03"], "add": true, "bloom": ["star_09", "flare_01"], "after": "shards", "tint": Color(0.8, 0.97, 1.0), "light": Color(0.85, 1.0, 1.0)},
	"ice": {"body": ["star_04", "light_03"], "add": true, "bloom": ["star_09", "magic_03"], "after": "shards", "tint": Color(0.65, 0.9, 1.0), "light": Color(0.75, 0.95, 1.0)},
	"light": {"body": ["star_06", "light_03"], "add": true, "bloom": ["star_09", "light_01"], "after": "glints", "tint": Color(1.0, 0.9, 0.55), "light": Color(1.0, 0.95, 0.7)},
	"rune": {"body": ["magic_05", "light_03"], "add": true, "bloom": ["magic_03", "light_01"], "after": "runes", "tint": Color(0.85, 0.6, 1.0), "light": Color(0.85, 0.65, 1.0)},
	"leaf": {"body": ["twirl_02", "light_03"], "add": true, "bloom": ["dirt_02", "twirl_03"], "after": "leaves", "tint": Color(0.55, 0.9, 0.35), "light": Color(0.7, 1.0, 0.45)},
	"thorn": {"body": ["scratch_01", "light_03"], "add": true, "bloom": ["dirt_01", "scorch_03"], "after": "leaves", "tint": Color(0.55, 0.85, 0.3), "light": Color(0.65, 0.95, 0.4)},
	"blood": {"body": ["circle_05"], "add": false, "bloom": ["dirt_01", "dirt_03"], "after": "drips", "tint": Color(0.75, 0.05, 0.1), "light": Color(1.0, 0.3, 0.3)},
	"shadow": {"body": ["smoke_02", "smoke_05"], "add": false, "bloom": ["smoke_09", "smoke_10"], "after": "soot", "tint": Color(0.22, 0.08, 0.3, 0.85), "light": Color(0.7, 0.4, 1.0)},
	"moth": {"body": ["light_03"], "add": true, "bloom": ["light_01", "star_07"], "after": "glints", "tint": Color(1.0, 0.85, 0.55), "light": Color(1.0, 0.8, 0.45)},
	"lightning": {"body": ["spark_01", "spark_02", "spark_03", "spark_04"], "add": true, "bloom": ["spark_02", "star_09"], "after": "arcs", "tint": Color(1.0, 0.95, 0.6), "light": Color(1.0, 1.0, 0.75)},
	"gear": {"body": ["magic_02", "light_03"], "add": true, "bloom": ["magic_04", "star_07"], "after": "glints", "tint": Color(1.0, 0.75, 0.4), "light": Color(1.0, 0.85, 0.55)},
	"shield": {"body": ["circle_02", "light_03"], "add": true, "bloom": ["circle_03", "light_01"], "after": "glints", "tint": Color(0.45, 0.75, 1.0), "light": Color(0.6, 0.85, 1.0)},
}
## motif -> its kit (several motifs share one material).
const KIT_OF := {"ember": "fire", "flame": "fire", "sun": "fire", "laser": "fire", "steam": "steam", "smoke": "smoke",
	"water": "water", "bubble": "bubble", "poison": "poison", "wind": "wind", "paper": "paper", "glass": "glass", "blade": "glass",
	"ice": "ice", "star": "light", "light": "light", "prism": "light", "rune": "rune", "note": "rune", "leaf": "leaf",
	"thorn": "thorn", "blood": "blood", "jaws": "blood", "shadow": "shadow", "moth": "moth", "lightning": "lightning",
	"gear": "gear", "shield": "shield"}


## Plays card `id`'s effect from `from` (the card) to `dests` ({body, row, feet?} per enemy hit, or your panel), with
## `player` your middle and `chant` the chant row's. `n` is its number (damage, Shield...): bigger hits hit harder.
## `back` (optional): a layer drawn BEHIND the enemies, for glows and smoke that give depth.
static func play(layer: Control, id: String, from: Vector2, dests: Array, player: Vector2, chant: Vector2, n: int,
		shake: Callable, stop := Callable(), back: Control = null) -> float:
	var def: Array = CARDS.get(id, ["bolt", "ember", ""])
	var now := Time.get_ticks_msec()
	var quick := now - int(_last.get(id, -100000)) < 1400
	_last[id] = now
	var v := Vfx.make(layer)
	v.shaker = shake
	v.stopper = stop
	var fx := _Fx.new()
	fx.v = v
	fx.m = String(def[1])
	fx.kit = KITS[KIT_OF.get(fx.m, "fire")]
	fx.quick = quick
	fx.big = String(def[2]).contains("big")
	fx.line = String(def[2]).contains("line")
	fx.k = (1.3 if fx.big else 1.0) * (1.0 + 0.05 * clampi(n - 3, 0, 8)) * (0.75 if quick else 1.0)
	fx.back_layer = back
	var foes: Array = []
	for d in dests:
		var body: Vector2 = d.body
		foes.append({"at": body, "feet": d.get("feet", body + Vector2(0, 110))})
	var you := player + Vector2(0, -20)
	var t := 0.0
	match String(def[0]):
		"bolt": t = fx.fire_bolt(from, dests) if id == "spark" else fx.bolt(from, foes)
		"slash": t = fx.slashes(from, foes, 4 if fx.m == "wind" else 2)
		"shuriken": t = fx.shuriken(from, foes)
		"fall": t = fx.fall(from, foes)
		"smite": t = fx.smite(from, foes)
		"rise": t = fx.rise(from, foes)
		"beam": t = fx.beam(from, foes)
		"storm": t = fx.storm(from, foes)
		"implode": t = fx.implode(from, foes)
		"drain": t = fx.drain(from, foes, you)
		"sweep": t = fx.sweep(from, foes)
		"hex": t = fx.hex(from, foes)
		"aura": t = fx.water_aura(from, player) if id == "splash" else fx.aura(from, you)
		"shower": t = fx.shower(from, you)
		"radiate": t = fx.power_rise(from, player) if id == "heed_my_call" else fx.radiate(from, you)
		"weave": t = fx.weave(from, chant)
		"accent": t = fx.accent(from)
	if String(def[2]).contains("self"):
		fx.backlash(from, you, t)
	return t


## The pieces, with what every card shares (its motif and its kit, how big, a quick repeat).
class _Fx:
	var v: Vfx
	var vb: Vfx  # (behind the enemies: made when first needed, as an empty Vfx frees itself)
	var back_layer: Control
	var m := "ember"
	var kit: Dictionary = {}
	var k := 1.0
	var quick := false
	var big := false
	var line := false

	func bk() -> Vfx:
		if vb == null or not is_instance_valid(vb):
			vb = Vfx.make(back_layer, 0) if back_layer != null else v
			vb.shaker = v.shaker
		return vb

	func shape() -> int:
		return int(MOTIFS[m][0])

	func col() -> Color:
		return PRISM[randi() % 3] if m == "prism" else MOTIFS[m][1]

	func lit() -> Color:
		return kit.light if not kit.is_empty() else MOTIFS[m][2]

	func n(count: int) -> int:
		return maxi(1, int(count * (0.6 if quick else 1.0)))

	func slow() -> float:  # (a quick repeat runs faster)
		return 0.7 if quick else 1.0

	# ------------------------------------------------------------- the kit's pieces

	## One piece of the kit's body (a lick of flame, a puff of steam, a ball of light...).
	func kbody(at: Vector2, vel: Vector2, sz: float, life: float, delay := 0.0, back := false) -> Vfx.Item:
		var tint: Color = kit.tint
		if m == "prism":
			tint = PRISM[randi() % 3]
		var p := (bk() if back else v).sprite(kit.body, at, vel, tint, life, sz, bool(kit.add), delay)
		p.rot = randf() * TAU
		p.spin = randf_range(-2.0, 2.0)
		p.drag = 2.0
		if kit.get("fire", false):
			p.ramp = fire_ramp()
			p.grav = Vector2(0, -randf_range(120, 260))
		elif not bool(kit.add):
			p.size0 = sz * 0.4
			p.grav = Vector2(0, -randf_range(30, 80))
		return p

	## A streak of light along its flight (sparks, glints, cut air).
	func kstreak(at: Vector2, vel: Vector2, delay := 0.0) -> Vfx.Item:
		var s := v.sprite(STREAKS, at, vel, lit(), randf_range(0.18, 0.38), randf_range(16, 28), true, delay)
		s.face_vel = true
		s.drag = 3.2
		s.grav = Vector2(0, 650)
		s.grow = 0.0
		s.size0 = s.size1
		return s

	## Solid debris thrown out (shards, drops, scraps, leaves) in the motif's own shape, falling under gravity.
	func kdebris(at: Vector2, vel: Vector2, delay := 0.0) -> Vfx.Item:
		var b := bit(at, vel, randf_range(0.5, 0.9), randf_range(8, 13), delay)
		if not (shape() in [Vfx.SMOKE, Vfx.GLOW, Vfx.SPARK, Vfx.STAR, Vfx.RUNE]) and m != "flame" and m != "sun":
			b.grav = Vector2(0, 1000)
		return b

	## What stays a moment after: embers drifting, steam rising, drips, bubbles, glints, scraps, leaves...
	func kafter(at: Vector2, dir: Vector2, count: int, delay := 0.0) -> void:
		var kind := String(kit.after)
		for i in n(count):
			var p: Vector2 = at + SpellFx._jit(55)
			var dl := delay + randf() * 0.3
			match kind:
				"embers":
					ember(p, Vector2(randf_range(-140, 140) + dir.x * 70.0, randf_range(-240, -40)), dl)
				"soot":
					if i % 3 == 0:
						soot(p, Vector2(randf_range(-40, 40), -randf_range(40, 100)), randf_range(90, 140), randf_range(1.0, 1.5), dl, true, 0.7)
				"steam":
					if i % 2 == 0:
						var st := v.sprite(SMOKES, p, Vector2(randf_range(-30, 30), -randf_range(60, 130)), Color(1, 1, 1, 0.5), randf_range(0.9, 1.4), randf_range(70, 120), false, dl)
						st.size0 = 20.0
						st.hold = 0.2
				"drips", "bubbles":
					var dr := v.part(p, Vector2(randf_range(-160, 160), -randf_range(150, 380)), col(), randf_range(0.6, 1.0), randf_range(7, 11), Vfx.BUBBLE if kind == "bubbles" else Vfx.DROP, dl)
					dr.add = false
					dr.size1 = dr.size0
					if kind == "bubbles":
						dr.vel *= 0.4
						dr.wobble = 40.0
						dr.drag = 1.5
					else:
						dr.grav = Vector2(0, 1100)
				"streaks":
					var w := v.sprite(STREAKS, p, Vector2(dir.x * randf_range(200, 420) + randf_range(-60, 60), randf_range(-80, 80)), Color(lit(), 0.8), randf_range(0.3, 0.5), randf_range(20, 32), true, dl)
					w.face_vel = true
					w.drag = 2.0
				"paper", "shards", "leaves":
					var sc := kdebris(p, Vector2(randf_range(-120, 120), -randf_range(120, 320)), dl)
					sc.grav = Vector2(0, 420 if kind != "shards" else 900)
					sc.wobble = 50.0 if kind != "shards" else 0.0
					sc.drag = 1.0
				"glints":
					var g := v.sprite(["star_04", "star_07"], p + Vector2(0, -randf_range(0, 80)), Vector2(0, -randf_range(10, 40)), Color(lit(), 0.95), randf_range(0.3, 0.5), randf_range(24, 40), true, dl)
					g.size0 = 4.0
					g.spin = 0.0
				"runes":
					var ru := v.part(p, Vector2(randf_range(-15, 15), -randf_range(50, 130)), lit(), randf_range(1.0, 1.6), randf_range(8, 12), Vfx.RUNE, dl)
					ru.wobble = 30.0
					ru.size1 = ru.size0 * 0.6
				"arcs":
					if i % 2 == 0:
						var a := v.sprite(["spark_05", "spark_06"], p, Vector2.ZERO, Color(lit(), 0.9), 0.12, randf_range(50, 90), true, dl)
						a.grow = 0.0
						a.size0 = a.size1

	## Light on the stage floor at its feet, and a shockwave lying flat on it.
	func floor_hit(feet: Vector2, sz: float, delay := 0.0) -> void:
		var pool := v.sprite("light_01", feet, Vector2.ZERO, Color(lit(), 0.6), 0.7, sz, true, delay)
		pool.aspect = 0.22
		pool.spin = 0.0
		var wave := v.sprite("circle_03", feet, Vector2.ZERO, Color(lit(), 0.6), 0.45, sz * 1.15, true, delay)
		wave.aspect = 0.25
		wave.size0 = 40.0
		wave.spin = 0.0

	## The wind-up at the card: the kit's stuff curls in, a twirl closes on it (a quick repeat: a blink).
	func wind_up(at: Vector2) -> float:
		if quick:
			v.sprite("light_03", at, Vector2.ZERO, Color(lit(), 0.7), 0.15, 90)
			return 0.04
		var t := 0.2
		for i in 12:
			var ang := randf() * TAU
			var r := randf_range(90.0, 180.0)
			var e := v.part(at + Vector2.from_angle(ang) * r, (-Vector2.from_angle(ang) * r / t).rotated(0.6), lit(), t * randf_range(0.8, 1.1), randf_range(3, 6), Vfx.SPARK, randf() * 0.05)
			e.stretch = 0.4
		var tw := v.sprite(["twirl_01", "twirl_02"], at, Vector2.ZERO, Color(lit(), 0.8), t + 0.05, 150, true)
		tw.size0 = 190.0
		tw.size1 = 40.0
		tw.grow = 0.0
		tw.spin = 9.0
		kbody(at, Vector2(0, -50), 60, t + 0.1)
		return t

	## The blow landing, lopsided along its flight: a white-hot pop, the kit's bloom, its body thrown forward,
	## streaks and debris, a dim glow and smoke BEHIND the enemy, light pooled on the floor, the aftermath, a freeze
	## and a shake as big as the hit. (`scale` < 1: a lighter hit, e.g. one of several.)
	func burst(at: Vector2, feet: Vector2, dir: Vector2, scale := 1.0) -> void:
		var kk := k * scale
		var fl := v.sprite("star_06", at, Vector2.ZERO, Color(1, 1, 0.95, 1), 0.1, 150 * kk)  # (sprite sizes are half-widths)
		fl.grow = 0.0
		fl.size0 = 150 * kk
		fl.size1 = 60 * kk
		var bl := v.sprite(kit.bloom, at + dir * 20.0, dir * 50.0, Color(kit.tint, 1.0), 0.55, 160 * kk, bool(kit.add) or bool(kit.get("fire", false)))
		bl.size0 = 60.0
		bl.spin = randf_range(-1.5, 1.5)
		if kit.get("fire", false):
			bl.ramp = fire_ramp()
		if String(kit.bloom[0]).begins_with("muzzle"):  # (a splash: thrown up, not round)
			bl.rot = 0.0
			bl.spin = 0.0
		for i in n(int(8 * scale) + 1):
			var a := dir.angle() + randf_range(-1.1, 1.1) + (0.0 if i % 3 else PI * randf_range(0.6, 1.0))
			kbody(at + SpellFx._jit(20), Vector2.from_angle(a) * randf_range(160, 480) * kk, randf_range(40, 70) * kk, randf_range(0.35, 0.6), randf() * 0.05)
		for i in n(int(14 * scale) + 2):
			kstreak(at, Vector2.from_angle(dir.angle() + randf_range(-0.9, 0.9)) * randf_range(380, 950) * kk)
		for i in n(int(10 * scale) + 1):
			kdebris(at + SpellFx._jit(14), Vector2.from_angle(dir.angle() + randf_range(-1.2, 1.2)) * randf_range(200, 560) * kk, randf() * 0.04)
		bk().sprite("light_02", at, Vector2.ZERO, Color(lit(), 0.5), 0.8, 260 * kk).spin = 0.4
		if kit.get("fire", false) or String(kit.after) == "soot":
			for i in n(int(5 * scale) + 1):
				soot(at + Vector2(randf_range(-90, 90), randf_range(-70, 10)), Vector2(randf_range(-60, 60) + dir.x * 40.0, -randf_range(40, 110)), randf_range(80, 120) * kk, randf_range(1.2, 1.8), 0.1 + randf() * 0.15, true, 0.75)
		floor_hit(feet, 190 * kk)
		kafter(at, dir, int(18 * scale) + 2, 0.05)
		v.hitstop((0.06 + 0.02 * kk) * (0.5 if quick or scale < 1.0 else 1.0))
		v.shake((7.0 + 4.0 * kk) * (0.6 if quick else 1.0) * clampf(scale, 0.5, 1.0))

	# ------------------------------------------------------------- the families

	## A shaky bolt of the kit flying at each enemy, its body churning, trailing streaks (fire: soot), and it bursts.
	func bolt(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from)
		var dur := (0.7 if line else 0.78) * slow()  # (slow enough to follow: out fast, slow at the bend, fast in)
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			var bend := swing(from, at)
			var dir := (at - ((from + at) / 2.0 + bend)).normalized()  # (the way it is going when it lands)
			var mv := v.move(from, at, dur, 0.0, lit(), 0.0, t0,
				func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
					var hp := it.pos + it.dir.orthogonal() * sin(it.age * 55.0) * 6.0
					kbody(hp + SpellFx._jit(10), -it.dir * 40.0, randf_range(60, 90) * k, randf_range(0.16, 0.26))
					var core := vv.sprite("light_03", hp, Vector2.ZERO, Color(1, 1, 1, 0.9), 0.07, 34)
					core.grow = 0.0
					if kit.get("fire", false) and randf() < 0.5:
						soot(hp - it.dir * 24.0, -it.dir * 50.0 + Vector2(0, -20), randf_range(35, 55), randf_range(0.7, 1.1), 0.0, false, 0.5)
					if randf() < 0.5:
						kstreak(hp, -it.dir * randf_range(150, 320) + SpellFx._jit(90)),
				func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, dir))
			mv.bend = bend
			mv.swoop = true
		return t0 + dur

	## Every attack's projectile curves round before it hits (the user, 2026-11-27): it swings out upward, on the
	## side AWAY from where it is heading (the longer way round), then comes in on the target. The control point
	## of its curve, from the middle of the straight line.
	static func swing(from: Vector2, to: Vector2) -> Vector2:
		var d := to - from
		var side := d.orthogonal().normalized()
		if side.y > 0.0:  # (always out over the top, never down into the floor)
			side = -side
		return side * d.length() * randf_range(0.7, 0.85)

	## PAPER CUT (the user, 2026-11-28): a folded-paper throwing star, spinning fast, flies the fireball's arc (out fast,
	## slow at the bend, fast in), leaving a faint dust trail, and slices into the enemy: a cut across it. No other paper.
	func shuriken(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from) * 0.7
		var dur := 0.78 * slow()
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			var bend := swing(from, at)
			var dir := (at - ((from + at) / 2.0 + bend)).normalized()
			var mv := v.move(from, at, dur, 0.0, lit(), 0.0, t0,
				func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
					_paper_star(vv, it.pos, it.age * 26.0, 1.4),  # (only the star and its dust trail: the user, 2026-11-28)
				func(vv: Vfx, p: Vector2) -> void:
					var cut := vv.sprite(["slash_02", "slash_03"], p, Vector2.ZERO, Color(1, 1, 0.95, 0.95), 0.24, 230, true)
					cut.rot = dir.angle() + PI / 2.0 + randf_range(-0.3, 0.3)
					cut.spin = 0.0
					cut.size0 = 150.0
					var sc2 := vv.sprite("scratch_01", p, Vector2.ZERO, Color(1, 1, 0.95, 0.85), 0.28, 170, true)
					sc2.rot = dir.angle() + PI / 2.0
					sc2.spin = 0.0
					var pop := vv.sprite("star_06", p, Vector2.ZERO, Color(1, 1, 0.95, 0.9), 0.1, 110)  # (a small white pop, no scraps)
					pop.grow = 0.0
					pop.size1 = 40.0
					floor_hit(feet, 150)
					vv.hitstop(0.05)
					vv.shake(5.0))
			mv.bend = bend
			mv.swoop = true
		return t0 + dur

	## The paper star at `at`, turned `ang`: four folded blades (cream, with dark creases) round a small hole, and a
	## faint blur of where it just was.
	func _paper_star(vv: Vfx, at: Vector2, ang: float, sc: float) -> void:
		for b in 4:
			var a := ang + b * PI / 2.0
			var blade := vv.part(at + Vector2.from_angle(a) * 9.0 * sc, Vector2.ZERO, Color(0.98, 0.95, 0.86), 0.05, 20.0 * sc, Vfx.SHARD)
			blade.add = false
			blade.rot = a
			blade.size1 = blade.size0
			blade.hold = 0.6
		var hole := vv.part(at, Vector2.ZERO, Color(0.35, 0.3, 0.25, 0.9), 0.05, 3.0 * sc, Vfx.DOT)
		hole.add = false
		hole.size1 = hole.size0
		var g := vv.part(at, Vector2.ZERO, Color(1, 1, 0.95, 0.35), 0.12, 34.0 * sc)
		g.size1 = 6.0

	## Real cuts: textured slashes across the enemy at uneven angles and beats, each throwing its stuff along the
	## cut; Bite: two jaws snap shut.
	func slashes(from: Vector2, foes: Array, count: int) -> float:
		var t0 := wind_up(from) * 0.6
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			if m == "jaws":
				var top := v.sprite("slash_04", at + Vector2(0, -150), Vector2(0, 900), Color(1, 0.92, 0.9), 0.2, 230, true, t0)
				top.rot = 0.0
				top.spin = 0.0
				top.drag = 6.0
				var bot := v.sprite("slash_01", at + Vector2(0, 150), Vector2(0, -900), Color(1, 0.92, 0.9), 0.2, 230, true, t0)
				bot.rot = 0.0
				bot.spin = 0.0
				bot.drag = 6.0
				v.emit(at, 0.01, t0 + 0.14, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.UP))
				continue
			var beat := 0.0
			for i in mini(count, 6):
				var ang := randf_range(-0.6, 0.6) + (PI / 2.0 if i % 2 == 1 else 0.0) + randf_range(-0.3, 0.3)
				beat += randf_range(0.05, 0.1) * slow()
				var dl := t0 + beat
				var cut := v.sprite(["slash_01", "slash_02", "slash_03"], at + SpellFx._jit(25), Vector2.ZERO, Color(lit(), 0.95), 0.22, randf_range(230, 300) * k, true, dl)
				cut.rot = ang
				cut.spin = randf_range(-3, 3)
				cut.size0 = cut.size1 * 0.7
				cut.grow = 0.3
				if m == "wind" or m == "paper":
					var sc := v.sprite("scratch_01", at + SpellFx._jit(20), Vector2.ZERO, Color(lit(), 0.8), 0.25, 200, true, dl)
					sc.rot = ang
					sc.spin = 0.0
				v.emit(at, 0.01, dl, Callable(), func(_vv: Vfx, p: Vector2) -> void:
					for j in n(6):
						kdebris(p + SpellFx._jit(30), Vector2.from_angle(ang + randf_range(-0.4, 0.4)) * randf_range(220, 520))
					kstreak(p, Vector2.from_angle(ang) * 700.0)
					v.hitstop(0.025)
					v.shake(3.0 + 1.5 * k))
			v.emit(at, 0.01, t0 + beat + 0.05, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.from_angle(randf() * TAU), 0.75))
		return t0 + 0.1

	## The kit rains down on the enemy from the sky, each piece landing with a splash on the floor, then a burst.
	func fall(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from)
		var drop := 0.34 * slow()
		var last := 0.0
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			var dl := t0
			for i in n(7):
				dl += randf_range(0.03, 0.08)
				var start: Vector2 = at + Vector2(randf_range(-180, 80), -620)
				var tgt: Vector2 = at + Vector2(randf_range(-70, 70), randf_range(-40, 60))
				var mv := v.move(start, tgt, drop, 0.0, lit(), 0.0, dl,
					func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
						kbody(it.pos, Vector2(0, -60), randf_range(36, 52), 0.14)
						if randf() < 0.4:
							kstreak(it.pos, Vector2(0, -300)),
					func(vv: Vfx, p: Vector2) -> void:
						var rp := vv.sprite("circle_03", Vector2(p.x, feet.y), Vector2.ZERO, Color(lit(), 0.6), 0.3, 120, true)
						rp.aspect = 0.25
						rp.spin = 0.0
						for j in 4:
							kdebris(p, Vector2(randf_range(-260, 260), randf_range(-340, -80)))
						vv.shake(2.5))
				mv.accel = true
			last = maxf(last, dl + drop)
			v.emit(at, 0.01, dl + drop + 0.05, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.DOWN))
		return last + 0.05

	## A shaft of light from the sky onto the enemy (Chosen One, Sun Burn).
	func smite(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from) + (0.0 if quick else 0.12)
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			var top := Vector2(at.x + 30, at.y - 330)
			var sh := v.sprite("trace_07", top, Vector2.ZERO, Color(lit(), 0.85), 0.6, 520 * k, true, t0 - 0.1)
			sh.rot = 0.0
			sh.spin = 0.0
			sh.aspect = 1.6
			sh.size0 = 120.0
			sh.hold = 0.3
			var core := v.sprite("trace_06", top, Vector2.ZERO, Color(1, 1, 1, 0.95), 0.35, 420 * k, true, t0)
			core.rot = 0.0
			core.spin = 0.0
			core.aspect = 1.8
			bk().sprite("light_01", at + Vector2(0, -120), Vector2.ZERO, Color(lit(), 0.5), 0.9, 500, true, t0 - 0.1).spin = 0.1
			v.emit(at, 0.01, t0, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.DOWN))
		return t0 + 0.05

	## It bursts out of the floor under the enemy (Geyser): jets thrown up, again and again, then the blow.
	func rise(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from) + 0.1
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			var rp := v.sprite("circle_03", feet, Vector2.ZERO, Color(lit(), 0.7), 0.4, 260, true, t0 - 0.12)
			rp.aspect = 0.25
			rp.spin = 0.0
			for j in 5:
				var js := randf_range(120, 160) * k
				var jet := v.sprite(["muzzle_01", "muzzle_02", "muzzle_04", "muzzle_05"], feet + Vector2(randf_range(-50, 50), -js * 1.4 * 0.75), Vector2(0, -60), Color(kit.tint, 0.95), 0.35, js, true, t0 + j * 0.07)
				jet.rot = randf_range(-0.12, 0.12)
				jet.spin = 0.0
				jet.aspect = 1.4  # (its base on the floor: the texture's jet starts low in the picture)
			for j in n(16):
				kdebris(feet + Vector2(randf_range(-40, 40), -10), Vector2(randf_range(-160, 160), -randf_range(600, 1000)), t0 + randf() * 0.3)
			v.emit(at, 0.01, t0 + 0.08, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.UP))
		return t0 + 0.1

	## A searing beam straight to the enemy (Laser Beam): a white core in a glowing sheath, sparks peeling off it.
	func beam(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from) + (0.0 if quick else 0.1)
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			v.beam(from, at, Color(lit(), 0.6), 0.5, 50.0 * k, 0.0, t0)
			v.beam(from, at, Color(1, 1, 1, 0.95), 0.4, 14.0 * k, 3.0, t0)
			for j in 6:
				kbody(from.lerp(at, (j + 0.5) / 6.0), Vector2.ZERO, 90, 0.4, t0 + j * 0.015)
			v.emit(from, 0.35, t0, func(_vv: Vfx, _it: Vfx.Item, _d: float) -> void:
				kstreak(from.lerp(at, randf()), (at - from).orthogonal().normalized() * randf_range(-300, 300)))
			v.emit(at, 0.01, t0 + 0.03, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, (p - from).normalized()))
		return t0 + 0.05

	## A vortex round the enemy: twirls spin and tighten, its stuff whirls in, then slams.
	func storm(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from)
		var turn := 0.5 * slow()
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			for j in 2:
				var tw := v.sprite(["twirl_01", "twirl_02", "twirl_03"], at, Vector2.ZERO, Color(lit(), 0.85), turn + 0.1, 380 - j * 90, true, t0 + j * 0.06)
				tw.size0 = 420.0 - j * 90.0
				tw.size1 = 120.0
				tw.grow = 0.0
				tw.aspect = 0.6
				tw.spin = 9.0 if j == 0 else -7.0
			for i in n(14):
				var a0 := i * TAU / 14.0 + randf_range(-0.2, 0.2)
				var r0 := randf_range(160, 230)
				v.emit(at, turn, t0 + randf() * 0.06, func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
					var tt := it.t()
					var r := lerpf(r0, 30.0, tt * tt)
					var ang := a0 + tt * 7.0
					kbody(at + Vector2(cos(ang) * r, sin(ang) * r * 0.6), Vector2.ZERO, 40.0 * (1.0 - tt * 0.4), 0.1))
			v.emit(at, 0.01, t0 + turn, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.DOWN))
		return t0 + turn

	## Everything is pulled into the enemy (a darkness gathers, a ring closes), then bursts.
	func implode(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from)
		var pull := 0.4 * slow()
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			for i in n(20):
				var ang := randf() * TAU
				var r := randf_range(180, 330)
				kbody(at + Vector2.from_angle(ang) * r, -Vector2.from_angle(ang) * r / pull, randf_range(40, 60), pull, t0 + randf() * 0.05)
			var ring := v.sprite("circle_02", at, Vector2.ZERO, Color(lit(), 0.8), pull, 60, true, t0)
			ring.size0 = 520.0
			ring.size1 = 40.0
			ring.grow = 0.0
			ring.spin = 0.0
			var dark := v.sprite("smoke_09", at, Vector2.ZERO, Color(0.05, 0.02, 0.08, 0.6), pull + 0.1, 120, false, t0)
			dark.size0 = 360.0
			dark.grow = 0.0
			dark.spin = 3.0
			v.emit(at, 0.01, t0 + pull, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.UP))
		return t0 + pull

	## Its stuff is drawn out of the enemy and flows to you (Borrowed Warmth).
	func drain(from: Vector2, foes: Array, you: Vector2) -> float:
		var t0 := wind_up(from)
		for f in foes:
			var at: Vector2 = f.at
			bk().sprite("light_02", at, Vector2.ZERO, Color(lit(), 0.5), 0.7, 360, true, t0)
			for i in n(12):
				var mv := v.move(at + SpellFx._jit(50), you + SpellFx._jit(60), randf_range(0.45, 0.6), randf_range(-80, 180), lit(), 0.0, t0 + i * randf_range(0.03, 0.05),
					func(_vv: Vfx, it: Vfx.Item, _d: float) -> void: kbody(it.pos, Vector2.ZERO, 40, 0.18))
				mv.accel = true
		v.sprite("light_01", you, Vector2.ZERO, Color(lit(), 0.5), 0.7, 380, true, t0 + 0.5)
		v.shake(3.0, t0)
		return t0

	## A wall of the kit sweeps across every enemy in turn, each answering with a burst.
	func sweep(from: Vector2, foes: Array) -> float:
		var t0 := wind_up(from)
		var sorted := foes.duplicate()
		sorted.sort_custom(func(a, b): return Vector2(a.at).x < Vector2(b.at).x)
		var x0 := from.x
		if not sorted.is_empty():
			x0 = minf(from.x, Vector2(sorted[0].at).x - 300.0)
		for i in sorted.size():
			var at: Vector2 = sorted[i].at
			var feet: Vector2 = sorted[i].feet
			var dl := t0 + 0.08 * i * slow()
			v.emit(at, 0.3, dl, func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
				var x := lerpf(x0, at.x + 140.0, it.t())
				kbody(Vector2(x, at.y + randf_range(-170, 110)), Vector2(randf_range(300, 600), randf_range(-60, 60)), randf_range(70, 120), 0.4))
			v.emit(at, 0.01, dl + 0.26, Callable(), func(_vv: Vfx, p: Vector2) -> void: burst(p, feet, Vector2.RIGHT, 0.7))
		if big:
			v.flash(Color(lit(), 0.12), 0.35, t0 + 0.2)
		return t0 + 0.26 + 0.08 * maxi(0, sorted.size() - 1)

	## A curse sinks onto the enemy: motes of the kit spiral down on it, a sigil lies on the floor under it and a mark
	## presses in; no big blow. Moth to Flame: moths circle it and settle.
	func hex(from: Vector2, foes: Array) -> float:
		var fly := 0.5 * slow()
		for f in foes:
			var at: Vector2 = f.at
			var feet: Vector2 = f.feet
			for i in n(10):
				var a0 := randf() * TAU
				v.move(from + SpellFx._jit(30), at + Vector2.from_angle(a0) * 80.0, fly * randf_range(0.8, 1.0), randf_range(-40, 200), lit(), 0.0, i * randf_range(0.02, 0.04),
					func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
						if randf() < 0.6:
							kbody(it.pos, Vector2.ZERO, 34, 0.2))
			if m == "moth":
				for i in 7:
					var a0 := i * TAU / 7.0 + randf_range(-0.3, 0.3)
					var sp := randf_range(4.0, 6.0)
					v.emit(at, 1.0, fly, func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
						var ang := a0 + it.age * sp
						var r := lerpf(160.0, 60.0, it.t())
						var w := v.part(at + Vector2(cos(ang) * r, sin(ang) * r * 0.5 - 40), Vector2.ZERO, col(), 0.08, 12.0, Vfx.FLAKE)
						w.aspect = 0.5 + 0.5 * absf(sin(it.age * 30.0 + a0))
						w.size1 = 12.0)
				bk().sprite("light_01", at, Vector2.ZERO, Color(1.0, 0.6, 0.2, 0.5), 1.1, 360, true, fly)
			var sig := v.sprite(["magic_01", "magic_02"], feet, Vector2.ZERO, Color(lit(), 0.8), 1.0, 260, true, fly - 0.1)
			sig.aspect = 0.3
			sig.size0 = 30.0
			sig.spin = 1.2
			sig.hold = 0.4
			var mark := v.sprite(["magic_03", "magic_04"], at, Vector2.ZERO, Color(lit(), 0.9), 0.5, 200, true, fly - 0.05)
			mark.size0 = 360.0
			mark.grow = 0.0
			mark.size1 = 160.0
			mark.spin = 0.5
			bk().sprite("light_02", at, Vector2.ZERO, Color(lit(), 0.45), 0.7, 360, true, fly)
			kafter(at, Vector2.ZERO, 10, fly)
			v.shake(2.5, fly)
		return fly

	## Calm: blobs of the kit arc gently from the card to you; a swirl turns on the floor round you, soft ripples
	## spread, and the kit's aftermath rises round you at its own pace. No shake.
	func aura(from: Vector2, you: Vector2) -> float:
		var t := 0.0
		for i in n(7):
			var dl := i * randf_range(0.03, 0.06)
			var dur := randf_range(0.42, 0.58)
			v.move(from + SpellFx._jit(30), you + Vector2(randf_range(-140, 140), randf_range(-20, 10)), dur, randf_range(60, 200), lit(), 0.0, dl,
				func(_vv: Vfx, it: Vfx.Item, _d: float) -> void: kbody(it.pos, Vector2.ZERO, 30, 0.18))
			t = maxf(t, dl + dur)
		t *= 0.8
		var ring := v.sprite("circle_02", you, Vector2.ZERO, Color(lit(), 0.8), 1.2, 500 * k, true, t)
		ring.aspect = 0.3
		ring.size0 = 60.0
		ring.spin = 0.0
		ring.hold = 0.2
		var ring2 := v.sprite("circle_04", you, Vector2.ZERO, Color(lit(), 0.55), 1.4, 400 * k, true, t + 0.28)
		ring2.aspect = 0.3
		ring2.size0 = 30.0
		ring2.spin = 0.0
		var sw := v.sprite(["twirl_02", "twirl_03"], you + Vector2(0, -10), Vector2.ZERO, Color(lit(), 0.7), 1.3, 450 * k, true, t)
		sw.aspect = 0.4
		sw.spin = 2.0
		sw.hold = 0.3
		v.sprite("light_02", you + Vector2(0, -30), Vector2.ZERO, Color(lit(), 0.35), 1.4, 500, true, t).spin = 0.3
		if m == "shield" or m == "water":
			var dome := v.sprite("circle_02", you + Vector2(0, -60), Vector2.ZERO, Color(lit(), 0.5), 0.9, 320, true, t + 0.1)
			dome.aspect = 0.7
			dome.spin = 0.0
		for i in n(12):
			kbody(you + Vector2(randf_range(-170, 170), randf_range(-10, 20)), Vector2(randf_range(-30, 30), -randf_range(60, 150)), randf_range(30, 50), randf_range(0.8, 1.2), t + randf() * 0.4)
		kafter(you, Vector2.ZERO, 14, t)
		return t

	## Calm: the kit falls softly round you from above (Rain), rippling on the floor.
	func shower(from: Vector2, you: Vector2) -> float:
		var t := SpellFx._stream(v, from, you + Vector2(0, -320), Vector2(100, 20), lit(), n(6), 0.0, 0.35)
		v.emit(you, 0.9, t, func(vv: Vfx, _it: Vfx.Item, d: float) -> void:
			if randf() > 36.0 * d:
				return
			var x := randf_range(-240, 240)
			var mv := vv.move(you + Vector2(x, -360), you + Vector2(x + randf_range(-20, 20), randf_range(-10, 20)), randf_range(0.3, 0.45), 0.0, lit(), 0.0, 0.0,
				func(_v2: Vfx, it: Vfx.Item, _d: float) -> void: kbody(it.pos, Vector2(0, -40), 26, 0.12),
				func(v2: Vfx, p: Vector2) -> void:
					var rp := v2.sprite("circle_03", p, Vector2.ZERO, Color(lit(), 0.6), 0.35, 70, true)
					rp.aspect = 0.3
					rp.spin = 0.0)
			mv.accel = true)
		v.sprite("light_02", you, Vector2.ZERO, Color(lit(), 0.3), 1.2, 520, true, t).spin = 0.2
		var ring := v.sprite("circle_02", you, Vector2.ZERO, Color(lit(), 0.6), 1.0, 460, true, t + 0.4)
		ring.aspect = 0.3
		ring.spin = 0.0
		kafter(you, Vector2.ZERO, 10, t + 0.3)
		return t

	## A Power: slow and grand. The stage dims a touch; two magic circles draw on the floor under you as motes spiral
	## in; then a pillar of light rises, the kit's aftermath floats up and soft waves roll out. It lingers.
	func radiate(from: Vector2, you: Vector2) -> float:
		var pc := lit()
		v.flash(Color(0.05, 0.0, 0.1, 0.22), 1.2, 0.0, false)
		SpellFx._stream(v, from, you, Vector2(80, 20), pc, n(6), 0.0, 0.4)
		var c1 := v.sprite("magic_02", you, Vector2.ZERO, Color(pc, 0.85), 1.9, 300)
		c1.aspect = 0.32
		c1.size0 = 20.0
		c1.spin = 0.5
		c1.hold = 0.55
		var c2 := v.sprite("magic_01", you, Vector2.ZERO, Color(pc.darkened(0.2), 0.8), 1.8, 190, true, 0.12)
		c2.aspect = 0.32
		c2.size0 = 10.0
		c2.spin = -0.9
		c2.hold = 0.55
		for i in 16:
			var a0 := randf() * TAU
			var r0 := randf_range(260, 420)
			v.emit(you, 0.45, randf() * 0.25, func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
				var tt := it.t()
				var r := lerpf(r0, 20.0, tt * tt)
				var ang := a0 + tt * 3.0
				var mo := vv.part(you + Vector2(cos(ang) * r, sin(ang) * r * 0.45 - 30.0), Vector2.ZERO, Color(pc, 0.9), 0.12, 5.0)
				mo.size1 = 1.0)
		var t := 0.5
		var pillar := v.sprite("trace_07", you + Vector2(0, -210), Vector2.ZERO, Color(pc, 0.75), 1.3, 260, true, t)
		pillar.aspect = 2.4
		pillar.rot = 0.0
		pillar.size0 = 60.0
		pillar.spin = 0.0
		pillar.hold = 0.35
		v.sprite("light_01", you + Vector2(0, -60), Vector2.ZERO, Color(pc, 0.45), 1.4, 460, true, t).spin = 0.2
		var gl := v.sprite("star_08", you + Vector2(0, -40), Vector2.ZERO, Color(1, 1, 1, 0.95), 0.35, 200, true, t)
		gl.size0 = 40.0
		gl.spin = 0.6
		for w in (1 if quick else 2):
			var wv := v.sprite("circle_01", you, Vector2.ZERO, Color(pc, 0.5 - w * 0.15), 1.5, 520 - w * 120, true, t + w * 0.35)
			wv.aspect = 0.3
			wv.size0 = 80.0
			wv.spin = 0.0
		for i in n(10):
			kbody(you + Vector2(randf_range(-160, 160), randf_range(-10, 20)), Vector2(randf_range(-20, 20), -randf_range(50, 120)), randf_range(30, 46), randf_range(1.0, 1.5), t + randf() * 0.5)
		kafter(you, Vector2.ZERO, 14, t)
		if m == "lightning":
			for i in 3:
				var zap := v.sprite(["spark_05", "spark_06"], you + Vector2(randf_range(-160, 160), -200), Vector2.ZERO, Color(pc, 0.95), 0.18, 300, true, t + 0.15 + i * 0.25)
				zap.rot = 0.0
				zap.spin = 0.0
				zap.aspect = 1.4
		v.shake(3.0, t)
		return t

	## A chant trick: a twirl and a circle turn round the card, its stuff flows along the chant, a ripple there.
	func weave(from: Vector2, chant: Vector2) -> float:
		var turn := 0.45 * slow()
		var tw := v.sprite(["twirl_01", "twirl_02"], from, Vector2.ZERO, Color(lit(), 0.85), turn + 0.2, 220, true)
		tw.spin = 7.0
		var mg := v.sprite("magic_02" if m == "gear" else "magic_01", from, Vector2.ZERO, Color(lit(), 0.8), turn + 0.3, 200, true)
		mg.spin = 4.0 if m == "gear" else 1.5
		mg.size0 = 40.0
		for i in n(12):
			var a0 := i * TAU / 12.0
			v.emit(from, turn, 0.0, func(_vv: Vfx, it: Vfx.Item, _d: float) -> void:
				var ang := a0 + it.age * 8.0
				kbody(from + Vector2(cos(ang) * 120.0, sin(ang) * 80.0), Vector2.ZERO, 26, 0.12))
		var t := turn * 0.7
		for i in n(12):
			var dl := t + i * randf_range(0.015, 0.03)
			v.move(from + SpellFx._jit(20), chant + Vector2(randf_range(-260, 260), randf_range(-15, 15)), 0.32, randf_range(40, 160), lit(), 0.0, dl,
				func(_vv: Vfx, it: Vfx.Item, _d: float) -> void: kbody(it.pos, Vector2.ZERO, 28, 0.16))
		t += 0.32
		var rp := v.sprite("circle_02", chant, Vector2.ZERO, Color(lit(), 0.7), 0.6, 600, true, t)
		rp.aspect = 0.18
		rp.size0 = 80.0
		rp.spin = 0.0
		v.sprite("light_02", chant, Vector2.ZERO, Color(lit(), 0.35), 0.7, 420, true, t).aspect = 0.4
		kafter(chant, Vector2.ZERO, 8, t)
		return t

	## More marbles next turn: a gust round the card (the marble's own flight follows).
	func accent(from: Vector2) -> float:
		var tw := v.sprite(["twirl_01", "twirl_03"], from, Vector2.ZERO, Color(lit(), 0.85), 0.5, 260, true)
		tw.spin = 8.0
		for i in n(10):
			kstreak(from + SpellFx._jit(40), Vector2.from_angle(randf_range(-0.5, 0.5) - PI / 2.0) * randf_range(300, 600))
			kbody(from + SpellFx._jit(50), Vector2.from_angle(randf_range(-0.6, 0.6) - PI / 2.0) * randf_range(150, 350), 34, 0.45)
		return 0.0

	## It hurts you as well: a red crackle snaps back onto you.
	func backlash(from: Vector2, you: Vector2, t: float) -> void:
		var red := Color(1.0, 0.25, 0.25)
		v.beam(from, you, Color(red, 0.7), 0.25, 8.0, 18.0, t + 0.08)
		var arc := v.sprite(["spark_02", "spark_03"], you, Vector2.ZERO, Color(red, 0.95), 0.3, 200, true, t + 0.1)
		arc.size0 = 120.0
		v.sprite("light_01", you, Vector2.ZERO, Color(red, 0.5), 0.4, 260, true, t + 0.1)
		v.shake(4.0, t + 0.1)

	## One small piece of the motif drawn as a shape (a drop, a shard, a scrap of paper...): solid, so it reads on
	## the bright painted stage. Fire motifs: a lick of textured flame.
	func bit(at: Vector2, vel: Vector2, life: float, sz: float, delay := 0.0) -> Vfx.Item:
		var s := shape()
		sz *= 1.5
		life *= 1.25
		if m == "flame" or m == "sun":
			return flame(at, vel, sz * 1.2, life, delay)
		var p := v.part(at, vel, col(), life, sz, s, delay)
		if not (s in [Vfx.GLOW, Vfx.SPARK, Vfx.STAR, Vfx.RUNE]) or m == "laser":
			p.add = false
			p.col1 = Color(p.col, 0.0)
			p.hold = 0.5
		match s:
			Vfx.SMOKE:
				p.size1 = sz * 2.2
				p.drag = 2.0
			Vfx.SPARK, Vfx.CHEVRON:
				p.stretch = 0.6
				p.drag = 3.0
				p.rot = vel.angle()
			Vfx.SHARD, Vfx.CRYSTAL, Vfx.DROP, Vfx.THORN:
				p.spin = randf_range(-9, 9)
				p.size1 = sz
			Vfx.FLAKE:
				p.wobble = 60.0
				p.spin = randf_range(-5, 5)
				p.size1 = sz
			_:
				p.spin = randf_range(-3, 3)
		return p

	# ------------------------------------------------------------- textured, layered (the showcase)

	static func ramp(cols: Array, offs: Array) -> Gradient:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(offs)
		g.colors = PackedColorArray(cols)
		return g

	const FLAMES := ["flame_01", "flame_02", "flame_03", "flame_04"]
	const SMOKES := ["smoke_01", "smoke_02", "smoke_04", "smoke_05", "smoke_06", "smoke_07", "smoke_08"]
	const STREAKS := ["trace_01", "trace_02", "trace_03", "trace_04"]

	static func fire_ramp() -> Gradient:  # white-hot, yellow, orange, deep red, gone
		return ramp([Color(1, 1, 0.9, 1), Color(1, 0.85, 0.35, 1), Color(1, 0.45, 0.1, 0.9), Color(0.7, 0.12, 0.04, 0.5), Color(0.25, 0.04, 0.02, 0)],
			[0.0, 0.12, 0.4, 0.72, 1.0])

	static func smoke_ramp(a: float) -> Gradient:  # soot that thins out
		return ramp([Color(0.16, 0.12, 0.11, 0.0), Color(0.18, 0.14, 0.12, a), Color(0.3, 0.27, 0.26, a * 0.6), Color(0.4, 0.38, 0.37, 0)],
			[0.0, 0.15, 0.6, 1.0])

	## A lick of flame (textured), turning and rising as it burns out.
	func flame(at: Vector2, vel: Vector2, sz: float, life: float, delay := 0.0, back := false) -> Vfx.Item:
		var f := (bk() if back else v).sprite(FLAMES, at, vel, Color.WHITE, life, sz, true, delay)
		f.ramp = fire_ramp()
		f.rot = randf() * TAU
		f.spin = randf_range(-2.5, 2.5)
		f.grav = Vector2(0, -randf_range(120, 260))
		f.drag = 2.0
		return f

	## A slow puff of soot (drawn as matter, so it darkens what is behind it: that contrast is the depth).
	func soot(at: Vector2, vel: Vector2, sz: float, life: float, delay := 0.0, back := false, a := 0.8) -> Vfx.Item:
		var p := (bk() if back else v).sprite(SMOKES, at, vel, Color.WHITE, life, sz, false, delay)
		p.ramp = smoke_ramp(a)
		p.size0 = sz * 0.35
		p.rot = randf() * TAU
		p.spin = randf_range(-0.6, 0.6)
		p.drag = 1.6
		p.grav = Vector2(randf_range(-10, 10), -randf_range(40, 90))
		return p

	## A glowing ember that drifts up, wavering, and winks out at its own pace.
	func ember(at: Vector2, vel: Vector2, delay := 0.0) -> Vfx.Item:
		var e := v.part(at, vel, Color(1.0, randf_range(0.55, 0.85), 0.25), randf_range(0.8, 1.7), randf_range(2.5, 5.0), Vfx.DOT, delay)
		e.drag = 1.4
		e.grav = Vector2(0, -randf_range(30, 90))
		e.wobble = randf_range(20, 60)
		e.hold = randf_range(0.2, 0.6)
		return e

	## SPARK: a churning, smoking fireball. Embers are sucked into the card, it flies in an arc trailing soot and
	## sparks, and bursts lopsided along its flight: a white-hot pop, a blooming fireball, flames thrown forward,
	## soot rolling up behind the enemy, light pooled on the floor, embers drifting for a second after.
	func fire_bolt(from: Vector2, dests: Array) -> float:
		var orange := Color(1.0, 0.5, 0.12)
		var t0 := 0.05 if quick else 0.22
		if not quick:
			for i in 16:  # the wind-up: embers drawn in on a curve, uneven
				var ang := randf() * TAU
				var r := randf_range(90.0, 190.0)
				var e := v.part(from + Vector2.from_angle(ang) * r, (-Vector2.from_angle(ang) * r / t0).rotated(0.6), Color(1, 0.7, 0.3), t0 * randf_range(0.8, 1.1), randf_range(3, 6), Vfx.SPARK, randf() * 0.05)
				e.stretch = 0.4
			var tw := v.sprite(["twirl_01", "twirl_02"], from, Vector2.ZERO, Color(orange, 0.8), t0 + 0.05, 150, true)
			tw.size0 = 190.0
			tw.size1 = 40.0
			tw.grow = 0.0
			tw.spin = 9.0
			flame(from + Vector2(0, 10), Vector2(0, -60), 70, t0 + 0.1)
		var dur := 0.78 * (0.7 if quick else 1.0)
		for d in dests:
			var at: Vector2 = d.body
			var feet: Vector2 = d.get("feet", at + Vector2(0, 110))
			var bend := swing(from, at)
			var dir := (at - ((from + at) / 2.0 + bend)).normalized()
			var mv := v.move(from, at, dur, 0.0, orange, 0.0, t0,
				func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
					var wob := it.dir.orthogonal() * sin(it.age * 55.0) * 6.0
					var hp := it.pos + wob
					flame(hp + SpellFx._jit(10), -it.dir * 40.0, randf_range(70, 100), randf_range(0.18, 0.28))  # its churning body
					var core := vv.sprite("light_03", hp, Vector2.ZERO, Color(1, 0.95, 0.8, 0.9), 0.07, 34)
					core.grow = 0.0
					if randf() < 0.55:
						soot(hp - it.dir * 24.0, -it.dir * 50.0 + Vector2(0, -20), randf_range(50, 85), randf_range(0.7, 1.1), 0.0, false, 0.55)
					if randf() < 0.5:
						var sp := vv.sprite(STREAKS, hp, -it.dir * randf_range(150, 320) + SpellFx._jit(90), Color(1, 0.75, 0.35), randf_range(0.2, 0.35), randf_range(14, 22))
						sp.face_vel = true
						sp.aspect = 1.0
						sp.drag = 3.0,
				func(_vv: Vfx, p: Vector2) -> void: _fire_burst(p, feet, dir))
			mv.bend = bend
			mv.swoop = true
		return t0 + dur

	func _fire_burst(at: Vector2, feet: Vector2, dir: Vector2) -> void:
		var kk := k
		var flash := v.sprite("star_06", at, Vector2.ZERO, Color(1, 1, 0.92, 1), 0.1, 160 * kk)  # 1: the white-hot pop (a frame or two)
		flash.grow = 0.0
		flash.size0 = 160 * kk
		flash.size1 = 60 * kk
		var pop := v.sprite("light_01", at, Vector2.ZERO, Color(1, 0.9, 0.6, 0.9), 0.18, 160 * kk)
		pop.size0 = 60.0
		var ball := v.sprite(["fire_01", "fire_02"], at + dir * 20.0, dir * 60.0, Color.WHITE, 0.55, 230 * kk)  # 2: the fireball blooms
		ball.ramp = fire_ramp()
		ball.size0 = 60.0
		ball.spin = randf_range(-1.5, 1.5)
		for i in n(9):  # 3: flames thrown forward, lopsided along its flight
			var a := dir.angle() + randf_range(-1.1, 1.1) + (0.0 if i % 3 else PI * randf_range(0.6, 1.0))
			flame(at + SpellFx._jit(20), Vector2.from_angle(a) * randf_range(180, 520) * kk, randf_range(60, 110) * kk, randf_range(0.35, 0.6), randf() * 0.05)
		for i in n(16):  # sparks, mostly forward
			var a := dir.angle() + randf_range(-0.9, 0.9)
			var sp := v.sprite(STREAKS, at, Vector2.from_angle(a) * randf_range(400, 1000) * kk, Color(1, 0.8, 0.4), randf_range(0.18, 0.4), randf_range(16, 30))
			sp.face_vel = true
			sp.drag = 3.5
			sp.grav = Vector2(0, 700)
			sp.grow = 0.0
			sp.size0 = sp.size1
		var sc := v.sprite(["scorch_01", "scorch_02"], at, Vector2.ZERO, Color(1, 0.6, 0.2, 0.9), 0.3, 240 * kk, true, 0.02)
		sc.size0 = 120.0
		# depth: a big dim glow and rolling soot BEHIND the enemy, light pooled on the floor at its feet
		bk().sprite("light_02", at, Vector2.ZERO, Color(1, 0.45, 0.1, 0.55), 0.8, 420 * kk).spin = 0.4
		for i in n(6):
			soot(at + Vector2(randf_range(-90, 90), randf_range(-70, 10)), Vector2(randf_range(-60, 60) + dir.x * 40.0, -randf_range(40, 110)), randf_range(150, 220) * kk, randf_range(1.2, 1.8), 0.1 + randf() * 0.15, true, 0.85)
		for i in 3:
			soot(at + dir * 30.0 + SpellFx._jit(30), Vector2(dir.x * 70.0, -randf_range(60, 120)), randf_range(110, 160), randf_range(1.0, 1.4), 0.14 + i * 0.07, false, 0.55)
		var pool := v.sprite("light_01", feet, Vector2.ZERO, Color(1, 0.55, 0.15, 0.7), 0.7, 260 * kk)
		pool.aspect = 0.22
		pool.spin = 0.0
		var wave := v.sprite("circle_03", feet, Vector2.ZERO, Color(1, 0.7, 0.35, 0.7), 0.45, 300 * kk)  # the shockwave lies on the floor
		wave.aspect = 0.25
		wave.size0 = 40.0
		wave.spin = 0.0
		for i in n(22):  # 4: the aftermath: embers drifting up for a second or so
			ember(at + SpellFx._jit(50), Vector2(randf_range(-140, 140) + dir.x * 80.0, randf_range(-260, -40)), randf() * 0.3)
		v.hitstop((0.06 + 0.02 * kk) * (0.5 if quick else 1.0))
		v.shake((7.0 + 4.0 * kk) * (0.6 if quick else 1.0))

	## SPLASH: calm. Blobs of water arc gently from the card, unevenly; at you, water wells up: a slow swirl round
	## you on the floor, a soft rippling ring, droplets thrown up that fall back, bubbles and glints drifting up.
	func water_aura(from: Vector2, you: Vector2) -> float:
		var blue := Color(0.35, 0.7, 1.0)
		var t := 0.0
		for i in n(7):
			var dl := i * randf_range(0.03, 0.06)
			var dur := randf_range(0.45, 0.6)
			var mv := v.move(from + SpellFx._jit(30), you + Vector2(randf_range(-140, 140), randf_range(-20, 10)), dur, randf_range(60, 200), blue, 0.0, dl,
				func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
					var b := vv.sprite("circle_05", it.pos, Vector2.ZERO, Color(blue, 0.55), 0.18, 26)
					b.grow = 0.0
					b.size1 = 8.0
					if randf() < 0.3:
						var dr := vv.part(it.pos, Vector2(randf_range(-30, 30), 40), Color(0.75, 0.9, 1.0), 0.4, 4.0, Vfx.DROP)
						dr.grav = Vector2(0, 500))
			mv.accel = false
			t = maxf(t, dl + dur)
		t *= 0.8
		var ring := v.sprite("circle_02", you, Vector2.ZERO, Color(0.6, 0.85, 1.0, 0.85), 1.2, 520)  # a soft ripple on the floor
		ring.aspect = 0.3
		ring.size0 = 60.0
		ring.spin = 0.0
		ring.delay = t
		ring.hold = 0.2
		var ring2 := v.sprite("circle_04", you, Vector2.ZERO, Color(0.5, 0.8, 1.0, 0.6), 1.4, 420)
		ring2.aspect = 0.3
		ring2.size0 = 30.0
		ring2.spin = 0.0
		ring2.delay = t + 0.28
		var sw := v.sprite(["twirl_02", "twirl_03"], you + Vector2(0, -10), Vector2.ZERO, Color(0.45, 0.8, 1.0, 0.75), 1.3, 470, true, t)  # the swirl
		sw.aspect = 0.4
		sw.spin = 2.2
		sw.hold = 0.3
		var glow := v.sprite("light_02", you + Vector2(0, -30), Vector2.ZERO, Color(0.3, 0.6, 1.0, 0.35), 1.4, 520, true, t)
		glow.spin = 0.3
		for i in n(22):  # droplets thrown up, falling back
			var dr := v.part(you + Vector2(randf_range(-160, 160), 0), Vector2(randf_range(-120, 120), -randf_range(260, 520)), Color(0.6, 0.85, 1.0), randf_range(0.6, 0.9), randf_range(9, 14), Vfx.DROP, t + randf() * 0.25)
			dr.grav = Vector2(0, 1100)
			dr.size1 = dr.size0
			dr.add = false
		v.emit(you, 1.1, t, func(vv: Vfx, _it: Vfx.Item, d: float) -> void:
			if randf() < 14.0 * d:  # bubbles, each at its own pace
				var b := vv.part(you + Vector2(randf_range(-200, 200), randf_range(-10, 30)), Vector2(0, -randf_range(50, 120)), Color(0.75, 0.92, 1.0), randf_range(0.9, 1.5), randf_range(6, 12), Vfx.BUBBLE)
				b.wobble = randf_range(25, 50)
				b.size1 = b.size0
			if randf() < 6.0 * d:  # glints
				var g := vv.sprite(["star_04", "star_07"], you + Vector2(randf_range(-190, 190), randf_range(-90, 10)), Vector2.ZERO, Color(0.85, 0.95, 1.0, 0.9), 0.35, randf_range(26, 40))
				g.size0 = 4.0
				g.spin = 0.0)
		return t

	## HEED MY CALL (a Power): slow and grand. The stage dims a touch; a magic circle draws itself on the floor
	## under you while motes spiral in; then light rises in a pillar, runes float up at their own pace and soft
	## waves roll out along the floor, and it lingers.
	func power_rise(from: Vector2, you: Vector2) -> float:
		var pc := lit()
		var deep := Color(0.55, 0.3, 0.95)
		v.flash(Color(0.05, 0.0, 0.1, 0.25), 1.2, 0.0, false)
		SpellFx._stream(v, from, you, Vector2(80, 20), pc, n(6), 0.0, 0.4)  # (from the card to you)
		var c1 := v.sprite("magic_02", you, Vector2.ZERO, Color(pc, 0.85), 1.9, 300)
		c1.aspect = 0.32
		c1.size0 = 20.0
		c1.spin = 0.5
		c1.hold = 0.55
		var c2 := v.sprite("magic_01", you, Vector2.ZERO, Color(deep, 0.8), 1.8, 190, true, 0.12)
		c2.aspect = 0.32
		c2.size0 = 10.0
		c2.spin = -0.9
		c2.hold = 0.55
		for i in 18:  # motes spiralling in from far off
			var a0 := randf() * TAU
			var r0 := randf_range(260, 420)
			var dl := randf() * 0.25
			v.emit(you, 0.45, dl, func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
				var tt := it.t()
				var r := lerpf(r0, 20.0, tt * tt)
				var ang := a0 + tt * 3.0
				var mo := vv.part(you + Vector2(cos(ang) * r, sin(ang) * r * 0.45 - 30.0), Vector2.ZERO, Color(pc, 0.9), 0.12, 5.0)
				mo.size1 = 1.0)
		var t := 0.5
		var pillar := v.sprite("trace_07", you + Vector2(0, -210), Vector2.ZERO, Color(pc, 0.75), 1.3, 260, true, t)
		pillar.aspect = 2.4
		pillar.rot = 0.0
		pillar.size0 = 60.0
		pillar.spin = 0.0
		pillar.hold = 0.35
		var bloom := v.sprite("light_01", you + Vector2(0, -60), Vector2.ZERO, Color(deep, 0.5), 1.4, 460, true, t)
		bloom.spin = 0.2
		var gl := v.sprite("star_08", you + Vector2(0, -40), Vector2.ZERO, Color(1, 0.95, 1, 0.95), 0.35, 200, true, t)
		gl.size0 = 40.0
		gl.spin = 0.6
		for w in (1 if quick else 2):  # soft waves along the floor
			var wv := v.sprite("circle_01", you, Vector2.ZERO, Color(pc, 0.5 - w * 0.15), 1.5, 520 - w * 120, true, t + w * 0.35)
			wv.aspect = 0.3
			wv.size0 = 80.0
			wv.spin = 0.0
		for i in n(14):  # runes floating up, each at its own pace
			var ru := v.part(you + Vector2(randf_range(-170, 170), randf_range(-20, 20)), Vector2(randf_range(-15, 15), -randf_range(50, 140)), pc.lerp(Color.WHITE, randf() * 0.4), randf_range(1.1, 1.9), randf_range(8, 13), Vfx.RUNE, t + randf() * 0.5)
			ru.wobble = randf_range(15, 40)
			ru.size1 = ru.size0 * 0.6
			ru.hold = 0.4
		v.shake(3.0, t)
		return t
