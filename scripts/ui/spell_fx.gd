class_name SpellFx
extends RefCounted
## Every kind of spell effect has its own show: a strike is a bolt that detonates, Burn a fireball that sets
## its target ablaze, Poison a lobbed glob that splashes and fumes, Freeze a frost beam that bursts into
## ice crystals, Weaken a shadow seal that presses down, Shield a hex dome, Heal a column of rising light,
## Execute two giant slashes, powers a magic circle, and so on.
## play() builds the whole effect and returns how long until it lands (the fight waits that long before
## applying it); the rest of the show carries on by itself.

const FIRE := Color(1.0, 0.55, 0.15)
const ICE := Color(0.55, 0.85, 1.0)
const POISON := Color(0.5, 0.95, 0.25)
const SHADOW := Color(0.7, 0.4, 1.0)
const GOLD := Color(1.0, 0.82, 0.35)
const HEAL := Color(0.45, 1.0, 0.55)
const SHIELD := Color(0.4, 0.75, 1.0)
const BLOOD := Color(1.0, 0.16, 0.2)
const THORN := Color(0.55, 0.85, 0.3)
const PURE := Color(0.85, 1.0, 1.0)
const GHOST := Color(0.8, 0.85, 1.0)
const CURSE := Color(0.6, 0.2, 0.8)
const WEAK := Color(0.45, 0.52, 0.95)  # a cold, heavy indigo: Weaken presses down

const CHANT_OPS := ["infuse", "rearrange", "duplicate", "retain", "amplify", "echo", "overload", "transmute", "copy_last"]
const SWIRL_OPS := ["convert", "insert", "move", "rotate", "swap"]
const POWER_OPS := ["passive", "each_turn", "summon_spells"]

static var _fire: Gradient


static func fire_ramp() -> Gradient:
	if _fire == null:
		_fire = Gradient.new()
		_fire.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 0.75, 1.0])
		_fire.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1, 0.8, 0.3, 1), Color(1, 0.42, 0.08, 0.85), Color(0.75, 0.13, 0.04, 0.45), Color(0.3, 0.05, 0.02, 0)])
	return _fire


## dests: one {body, row, rect?} per thing the spell reaches: an enemy (its body and its row of HP
## elements), or you / the chant / the elements coming next turn (the middle of that panel, and its rect).
## player: where you are on screen (for what comes back to you).
static func play(fx: Control, op: String, eff: Dictionary, from: Vector2, dests: Array, col: Color, player: Vector2, shake: Callable, stop := Callable()) -> float:
	var v := Vfx.make(fx)
	v.shaker = shake
	v.stopper = stop
	var n: int = int(eff.get("n", 1))
	match op:
		"strike":
			return _strike(v, from, dests, col, n)
		"burn":
			return _burn(v, from, dests, n)
		"stoke":
			return _stoke(v, from, dests)
		"poison":
			return _poison(v, from, dests)
		"freeze":
			return _freeze(v, from, dests)
		"weak":
			return _weak(v, from, dests)
		"expose":
			return _expose(v, from, dests)
		"curse":
			return _curse(v, from, dests)
		"ethereal":
			return _ethereal(v, from, dests)
		"execute":
			return _execute(v, from, dests)
		"shatter":
			return _shatter(v, from, dests)
		"purge":
			return _disintegrate(v, from, dests, Elements.COLORS.get(eff.get("el", ""), col))
		"pluck":
			return _snipe(v, from, dests, col)
		"steal", "siphon":
			return _siphon(v, from, dests, col, player)
		"redirect":
			return _redirect(v, from, dests)
		"shield":
			return _shield(v, from, dests)
		"aegis":
			return _aegis(v, from, dests)
		"thorns":
			return _thorns(v, from, dests)
		"heal":
			return _heal(v, from, dests)
		"cleanse":
			return _cleanse(v, from, dests)
		"sacrifice":
			return _sacrifice(v, dests)
		"draw":
			return _draw_fx(v, from, dests)
		"annihilate":
			return 0.0  # it has its own ceremony
		"barrage":
			return _barrage(v, from, dests)
		"random_hit":
			return _strike(v, from, dests, Color(0.6, 1.0, 0.4) if dests.size() == 1 else FIRE, n)
		"echo_next":
			return _power(v, from, SHADOW, player)
		"grimoire_pick":
			v.glow(from, 160, Color(GOLD, 0.7), 0.5)
			v.ring(from, 10, 160, GOLD, 0.45, 8.0)
			return 0.2
	if op in CHANT_OPS:
		return _chant_magic(v, op, from, dests, col)
	if op in SWIRL_OPS:
		return _swirl(v, from, dests, col)
	if op in POWER_OPS:
		return _power(v, from, col, player)
	if not dests.is_empty():
		return _strike(v, from, dests, col, 1)
	return 0.0


# ------------------------------------------------------------------ shared pieces

static func _jit(r: float) -> Vector2:
	return Vector2(randf_range(-r, r), randf_range(-r, r))


## The card gathers its power: light rushes in and a ring closes on it.
static func _charge(v: Vfx, at: Vector2, col: Color) -> float:
	var t := 0.17
	for i in 16:
		var ang := randf() * TAU
		var r := randf_range(80.0, 140.0)
		var p := v.part(at + Vector2.from_angle(ang) * r, -Vector2.from_angle(ang) * r / t, col.lerp(Color.WHITE, 0.3), t, randf_range(3.0, 6.0), Vfx.SPARK)
		p.stretch = 0.15
		p.size1 = 2.0
	v.ring(at, 130, 10, col, t + 0.03, 4.0)
	v.glow(at, 110, Color(col, 0.8), 0.35, 0.08)
	return t


## A glowing trail of sparks behind a bolt.
static func _spark_trail(v: Vfx, it: Vfx.Item, col: Color, n := 4) -> void:
	for i in n:
		var back := -it.dir * randf_range(60, 220) + _jit(70)
		var p := v.part(it.pos + _jit(6), back, col.lerp(Color.WHITE, randf() * 0.4), randf_range(0.18, 0.36), randf_range(4.5, 8.0), Vfx.SPARK)
		p.stretch = 0.6
		p.drag = 4.0
	var g := v.part(it.pos, Vector2.ZERO, Color(col, 0.6), 0.28, 26.0)
	g.size1 = 2.0


## Motes that stream from the card to one place, one after another.
static func _stream(v: Vfx, from: Vector2, to: Vector2, spread: Vector2, col: Color, count: int, delay := 0.0, dur := 0.34) -> float:
	for i in count:
		var dest := to + Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		var it := v.move(from + _jit(20), dest, dur, randf_range(-60, 200), col, randf_range(4.0, 6.5), delay + i * 0.022,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var g := vv.part(m.pos, _jit(20), Color(col, 0.7), 0.3, 7.0)
				g.size1 = 1.0,
			func(vv: Vfx, at: Vector2) -> void:
				var s := vv.part(at, Vector2.ZERO, col.lerp(Color.WHITE, 0.4), 0.35, 9.0, Vfx.STAR)
				s.spin = 4.0)
		it.accel = true
	return delay + (count - 1) * 0.022 + dur


static func _rect(d: Dictionary) -> Rect2:
	return d.get("rect", Rect2(d.body - Vector2(200, 50), Vector2(400, 100)))


# ------------------------------------------------------------------ attacks

## A searing bolt of the spell's colour that detonates: a white-hot flash, shockwaves, a spray of sparks and shards.
static func _strike(v: Vfx, from: Vector2, dests: Array, col: Color, n: int) -> float:
	var t0 := _charge(v, from, col)
	var k := 1.0 + 0.22 * clampi(n - 1, 0, 4)
	for d in dests:
		var it := v.move(from, d.row, 0.3, randf_range(80, 150), col, 19.0 * k, t0,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, col),
			func(vv: Vfx, at: Vector2) -> void: _detonate(vv, at, col, k))
		it.accel = true
	return t0 + 0.3


static func _detonate(v: Vfx, at: Vector2, col: Color, k: float) -> void:
	v.glow(at, 200 * k, Color(1, 1, 1, 0.95), 0.18)
	v.glow(at, 360 * k, Color(col, 0.8), 0.55)
	v.flare(at, 380 * k, Color(col.lerp(Color.WHITE, 0.4), 0.9), 0.3)
	v.ring(at, 12, 190 * k, col, 0.45, 16.0)
	v.ring(at, 6, 120 * k, Color(1, 1, 1, 0.9), 0.28, 6.0, 0.03)
	v.burst(at, int(40 * k), col.lerp(Color.WHITE, 0.3), Vector2(350, 950) * k, Vector2(0.2, 0.45), Vector2(5, 10))
	for s in v.burst(at, int(16 * k), col.darkened(0.1), Vector2(180, 480), Vector2(0.5, 0.85), Vector2(9, 17), Vfx.SHARD):
		s.grav = Vector2(0, 950)
		s.spin = randf_range(-12, 12)
		s.size1 = s.size0
	for e in v.burst(at, 10, col.lerp(Color.WHITE, 0.5), Vector2(40, 160), Vector2(0.6, 1.0), Vector2(2, 3.5), Vfx.DOT):
		e.grav = Vector2(0, -60)
		e.wobble = 30.0
	v.hitstop(0.035 + 0.015 * k)
	v.shake(4.0 + 3.0 * k)


## A roaring fireball that explodes into flames, then keeps its target wreathed in fire for a moment.
static func _burn(v: Vfx, from: Vector2, dests: Array, n: int) -> float:
	var t0 := _charge(v, from, FIRE)
	for d in dests:
		v.move(from, d.body, 0.44, 160, FIRE, 21.0, t0, _fire_trail, func(vv: Vfx, at: Vector2) -> void: _ignite(vv, at, n))
	return t0 + 0.45


static func _flame(v: Vfx, at: Vector2, vel: Vector2, size: float, life: float) -> Vfx.Item:
	var f := v.part(at, vel, Color.WHITE, life, size, Vfx.GLOW)
	f.ramp = fire_ramp()
	f.size1 = size * 0.15
	f.grav = Vector2(0, -300)
	f.drag = 1.5
	return f


static func _smoke(v: Vfx, at: Vector2, vel: Vector2, col: Color, size: float, life: float) -> Vfx.Item:
	var s := v.part(at, vel, col, life, size, Vfx.SMOKE)
	s.size1 = size * 3.2
	s.drag = 1.2
	return s


static func _fire_trail(v: Vfx, it: Vfx.Item, _d: float) -> void:
	for i in 4:
		_flame(v, it.pos + _jit(8), -it.dir * randf_range(40, 150) + Vector2(0, -60), randf_range(14, 24), randf_range(0.28, 0.45))
	if randf() < 0.5:
		_smoke(v, it.pos, Vector2(randf_range(-20, 20), -40), Color(0.1, 0.08, 0.08, 0.45), 12.0, 0.8)
	if randf() < 0.5:
		var e := v.part(it.pos, _jit(90), Color(1, 0.8, 0.35), randf_range(0.5, 0.8), 2.5, Vfx.DOT)
		e.grav = Vector2(0, -140)
		e.size1 = 1.0


static func _ignite(v: Vfx, at: Vector2, n: int) -> void:
	var k := 1.0 + 0.15 * clampi(n - 1, 0, 4)
	v.glow(at, 190 * k, Color(1, 1, 0.8, 0.95), 0.2)
	v.glow(at, 340 * k, Color(FIRE, 0.75), 0.65)
	v.flare(at, 360 * k, Color(1, 0.7, 0.35, 0.85), 0.3)
	v.ring(at, 14, 150 * k, FIRE, 0.45, 14.0)
	for i in int(36 * k):
		var dir := Vector2.from_angle(randf() * TAU)
		var f := _flame(v, at + dir * 10, dir * randf_range(160, 440), randf_range(18, 34), randf_range(0.45, 0.8))
		f.drag = 3.5
		f.grav = Vector2(0, -420)
	for i in 10:
		var dir := Vector2.from_angle(randf() * TAU)
		_smoke(v, at + dir * 20, dir * randf_range(40, 120) + Vector2(0, -70), Color(0.09, 0.07, 0.07, 0.5), 22.0, randf_range(1.1, 1.6))
	for i in 22:
		var e := v.part(at + _jit(30), Vector2(randf_range(-260, 260), randf_range(-420, -60)), Color(1, randf_range(0.55, 0.85), 0.3), randf_range(0.8, 1.4), randf_range(2.0, 3.5), Vfx.DOT)
		e.grav = Vector2(0, -60)
		e.drag = 2.2
		e.wobble = 45.0
		e.size1 = 0.8
	# the target stays wreathed in fire for a moment
	v.emit(at, 0.95, 0.05, func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
		var fade := 1.0 - it.t()
		for i in 3:
			var f := _flame(vv, at + Vector2(randf_range(-80, 80), randf_range(10, 70)), Vector2(randf_range(-20, 20), -randf_range(140, 280)), randf_range(12, 26) * (0.4 + 0.6 * fade), randf_range(0.4, 0.65))
			f.wobble = 60.0)
	v.hitstop(0.06)
	v.shake(6.0)


## The burning Essences flare: two pillars of fire erupt from the target.
static func _stoke(v: Vfx, from: Vector2, dests: Array) -> float:
	var t0 := _charge(v, from, FIRE)
	for d in dests:
		var at: Vector2 = d.body
		v.move(from, at, 0.35, 120, FIRE, 13.0, t0, _fire_trail, func(vv: Vfx, _at: Vector2) -> void:
			for wave in 2:
				vv.glow(at, 260, Color(FIRE, 0.75), 0.5, wave * 0.28)
				vv.ring(at + Vector2(0, 70), 20, 190, FIRE, 0.5, 12.0, wave * 0.28, 0.35)
				vv.shake(7.0, wave * 0.28)
				vv.emit(at, 0.4, wave * 0.28, func(v3: Vfx, _it: Vfx.Item, _d: float) -> void:
					for i in 5:
						var f := _flame(v3, at + Vector2(randf_range(-45, 45), 80), Vector2(randf_range(-50, 50), -randf_range(550, 950)), randf_range(20, 38), randf_range(0.35, 0.55))
						f.drag = 2.0))
	return t0 + 0.36


## A glob of venom lobbed high: it drips as it flies, splashes, and leaves the target in bubbling fumes.
static func _poison(v: Vfx, from: Vector2, dests: Array) -> float:
	for d in dests:
		v.move(from, d.body, 0.5, 280, POISON, 22.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var g := vv.part(m.pos + _jit(5), _jit(20), Color(POISON, 0.65), 0.35, 22.0)
				g.size1 = 2.0
				if randf() < 0.7:
					var dr := vv.part(m.pos + _jit(8), Vector2(randf_range(-30, 30), 80), POISON.lerp(Color(0.9, 1, 0.4), randf()), 0.6, randf_range(6, 9), Vfx.DROP)
					dr.grav = Vector2(0, 900)
					dr.size1 = dr.size0,
			_splash)
	return 0.56


static func _splash(v: Vfx, at: Vector2) -> void:
	v.glow(at, 170, Color(0.9, 1, 0.7, 0.9), 0.18)
	v.glow(at, 320, Color(POISON, 0.65), 0.7)
	v.ring(at + Vector2(0, 50), 10, 220, POISON, 0.55, 14.0, 0.0, 0.35)
	v.ring(at, 10, 150, Color(0.85, 1, 0.6), 0.35, 6.0)
	for i in 42:
		var ang := randf_range(-PI, 0)
		var dr := v.part(at + _jit(10), Vector2.from_angle(ang) * randf_range(240, 620), POISON.lerp(Color(0.85, 1, 0.3), randf() * 0.5), randf_range(0.5, 0.85), randf_range(5, 9), Vfx.DROP)
		dr.grav = Vector2(0, 1250)
		dr.size1 = dr.size0 * 0.6
	for i in 12:
		var s := _smoke(v, at + _jit(40), Vector2(randf_range(-70, 70), -randf_range(20, 60)), Color(0.18, 0.42, 0.08, 0.5), randf_range(20, 28), randf_range(1.2, 1.8))
		s.wobble = 30.0
	for i in 8:
		var g := v.part(at + _jit(50), Vector2(randf_range(-40, 40), -randf_range(20, 60)), Color(POISON, 0.25), randf_range(1.0, 1.4), 30.0)
		g.size1 = 70.0
	v.emit(at, 1.1, 0.0, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		if randf() < 0.55:
			var b := vv.part(at + Vector2(randf_range(-80, 80), randf_range(0, 70)), Vector2(0, -randf_range(40, 100)), POISON.lerp(Color.WHITE, 0.3), randf_range(0.6, 1.0), randf_range(4, 9), Vfx.BUBBLE)
			b.wobble = 45.0
			b.size1 = b.size0 * 1.3)
	v.shake(4.0)


## A beam of frost; where it lands, ice crystals burst out in a star, snow falls, and then the ice shatters.
static func _freeze(v: Vfx, from: Vector2, dests: Array) -> float:
	var t0 := _charge(v, from, ICE)
	for d in dests:
		var at: Vector2 = d.body
		v.beam(from, at, ICE, 0.55, 11.0, 0.0, t0)
		v.move(from, at, 0.17, 0.0, ICE, 10.0, t0,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				for i in 2:
					var f := vv.part(m.pos + _jit(14), _jit(50), Color(0.85, 0.95, 1), randf_range(0.5, 0.8), randf_range(5, 9), Vfx.FLAKE)
					f.spin = randf_range(-3, 3)
					f.size1 = f.size0 * 0.5,
			_frost)
	return t0 + 0.2


static func _frost(v: Vfx, at: Vector2) -> void:
	v.glow(at, 120, Color(0.85, 0.96, 1, 0.75), 0.14)
	v.glow(at, 300, Color(ICE, 0.55), 0.75)
	v.flare(at, 300, Color(ICE.lerp(Color.WHITE, 0.3), 0.8), 0.3)
	v.hitstop(0.05)
	v.ring(at, 10, 160, ICE, 0.5, 10.0)
	v.ring(at, 10, 110, Color(1, 1, 1, 0.8), 0.35, 4.0, 0.05)
	for i in 9:
		var ang := i * TAU / 9.0 + randf_range(-0.2, 0.2)
		var ln := randf_range(55, 110)
		var c := v.part(at + Vector2.from_angle(ang) * 22, Vector2.ZERO, Color(0.48, 0.76, 1.0, 0.85), 1.0, ln, Vfx.CRYSTAL)
		c.rot = ang
		c.grow = 0.12
		c.size1 = ln
		c.hold = 0.8
		var g := v.part(at + Vector2.from_angle(ang) * ln * 0.5, Vector2.ZERO, Color(ICE, 0.3), 0.95, ln * 0.5)
		g.size1 = ln * 0.45
	for i in 8:
		var g := v.part(at + _jit(30), _jit(40), Color(0.75, 0.9, 1, 0.22), 1.3, 40.0)
		g.size1 = 95.0
	v.emit(at, 1.2, 0.0, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		if randf() < 0.7:
			var f := vv.part(at + Vector2(randf_range(-160, 160), randf_range(-150, -60)), Vector2(randf_range(-20, 20), randf_range(30, 80)), Color(0.9, 0.97, 1), randf_range(1.0, 1.4), randf_range(4, 8), Vfx.FLAKE)
			f.spin = randf_range(-2, 2)
			f.wobble = 25.0
			f.size1 = f.size0)
	# the ice shatters
	v.emit(at, 0.95, 0.0, Callable(), func(vv: Vfx, _at: Vector2) -> void:
		vv.glow(at, 140, Color(0.9, 0.97, 1, 0.7), 0.2)
		vv.ring(at, 20, 120, Color(0.9, 0.97, 1, 0.8), 0.3, 4.0)
		for s in vv.burst(at, 26, Color(0.75, 0.92, 1), Vector2(150, 480), Vector2(0.5, 0.8), Vector2(8, 16), Vfx.SHARD):
			s.grav = Vector2(0, 950)
			s.spin = randf_range(-12, 12)
			s.size1 = s.size0
		vv.shake(3.0))
	v.shake(5.0)


## A heavy weight presses the target down: a cold indigo bolt, then a great chevron slams onto it from above, dust
## rings out at its feet, a flat seal settles under it and dark motes sink. (Curse is the purple one with runes.)
static func _weak(v: Vfx, from: Vector2, dests: Array) -> float:
	for d in dests:
		v.move(from, d.body, 0.38, 60, WEAK, 12.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				for i in 2:
					var g := vv.part(m.pos + _jit(6), -m.dir * randf_range(20, 80), Color(WEAK, 0.7), randf_range(0.3, 0.45), randf_range(8, 13))
					g.size1 = 1.0
				if randf() < 0.5:
					_smoke(vv, m.pos, _jit(20), Color(0.08, 0.08, 0.16, 0.45), 9.0, 0.6),
			func(vv: Vfx, at: Vector2) -> void:
				var weight := vv.part(at + Vector2(0, -260), Vector2(0, 1500), WEAK.lerp(Color.WHITE, 0.35), 0.18, 58.0, Vfx.CHEVRON)
				weight.rot = PI
				weight.size1 = 58.0
				var halo := vv.part(at + Vector2(0, -260), Vector2(0, 1500), Color(WEAK, 0.5), 0.18, 90.0)
				halo.size1 = 70.0
				vv.emit(at, 0.17, 0.0, Callable(), func(v3: Vfx, _a: Vector2) -> void:
					var feet := at + Vector2(0, 85)
					v3.glow(at, 150, Color(0.85, 0.88, 1, 0.8), 0.12)
					v3.glow(at, 260, Color(WEAK, 0.55), 0.7)
					v3.ring(feet, 20, 260, WEAK, 0.5, 12.0, 0.0, 0.28)
					v3.ring(feet, 10, 170, Color(0.85, 0.9, 1, 0.8), 0.32, 5.0, 0.03, 0.28)
					v3.sigil(feet, 120, WEAK, 1.2, 4, 0.05, 0.3, -0.6)
					for i in 14:  # dust thrown out sideways along the ground
						var side := -1.0 if i % 2 == 0 else 1.0
						var dust := _smoke(v3, feet + Vector2(randf_range(-30, 30), randf_range(-6, 6)), Vector2(side * randf_range(200, 420), -randf_range(0, 40)), Color(0.32, 0.3, 0.38, 0.5), 14.0, randf_range(0.6, 0.9))
						dust.drag = 4.0
					for wave in 3:
						for i in 5:
							var ch := v3.part(at + Vector2(randf_range(-90, 90), -110), Vector2(0, 320), WEAK.lerp(Color.WHITE, 0.25), 0.5, randf_range(11, 16), Vfx.CHEVRON, wave * 0.14)
							ch.rot = PI
							ch.drag = 1.0
							ch.size1 = ch.size0
					for i in 18:
						var m := v3.part(at + _jit(90), Vector2(randf_range(-30, 30), randf_range(80, 190)), Color(0.3, 0.32, 0.6), randf_range(0.7, 1.1), randf_range(4, 7))
						m.size1 = 1.0
					v3.hitstop(0.05)
					v3.shake(7.0)))
	return 0.6


static func _shadow_trail(v: Vfx, it: Vfx.Item, _d: float) -> void:
	for i in 3:
		var g := v.part(it.pos + _jit(6), -it.dir * randf_range(20, 80), Color(SHADOW, 0.7), randf_range(0.3, 0.45), randf_range(8, 13))
		g.wobble = 90.0
		g.size1 = 1.0
	if randf() < 0.6:
		_smoke(v, it.pos, _jit(20), Color(0.12, 0.04, 0.18, 0.5), 9.0, 0.6)


## A needle of light; a golden reticle snaps onto the target, brackets close in, and it cracks.
static func _expose(v: Vfx, from: Vector2, dests: Array) -> float:
	var red := Color(1.0, 0.45, 0.3)
	for d in dests:
		var it := v.move(from, d.body, 0.24, 30, GOLD, 8.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, GOLD, 2),
			func(vv: Vfx, at: Vector2) -> void:
				vv.ring(at, 190, 60, GOLD, 0.3, 5.0)
				vv.sigil(at, 70, red, 1.0, 4, 0.22, 1.0, 0.7)
				for k in 4:
					var dir := Vector2.from_angle(PI / 4.0 + k * PI / 2.0)
					var ch := vv.part(at + dir * 190, -dir * 1100, GOLD, 0.95, 16.0, Vfx.CHEVRON)
					ch.drag = 9.0
					ch.rot = (-dir).angle() + PI / 2.0
					ch.size1 = 16.0
					ch.hold = 0.6
				vv.glow(at, 120, Color(1, 1, 1, 0.95), 0.14, 0.26)
				vv.glow(at, 200, Color(red, 0.6), 0.5, 0.26)
				vv.burst(at, 18, GOLD.lerp(Color.WHITE, 0.3), Vector2(300, 700), Vector2(0.15, 0.35), Vector2(3, 6), Vfx.SPARK, 0.26)
				for s in vv.burst(at, 8, Color(1, 0.9, 0.7), Vector2(150, 350), Vector2(0.4, 0.7), Vector2(6, 11), Vfx.SHARD, 0.26):
					s.grav = Vector2(0, 900)
					s.spin = 10.0
					s.size1 = s.size0
				vv.shake(4.0, 0.26))
		it.accel = true
	return 0.3


## A black mist and an inverted circle of runes that sinks into the target.
static func _curse(v: Vfx, from: Vector2, dests: Array) -> float:
	for d in dests:
		v.move(from, d.body, 0.5, 120, CURSE, 11.0, 0.04, _shadow_trail, func(vv: Vfx, at: Vector2) -> void:
			vv.sigil(at, 105, CURSE, 1.4, 7, 0.0, 1.0, -0.9)
			vv.sigil(at + Vector2(0, 95), 120, CURSE, 1.4, 7, 0.1, 0.3, 0.6)
			vv.glow(at, 230, Color(CURSE, 0.5), 0.8)
			for i in 16:
				var s := _smoke(vv, at + _jit(60), Vector2(randf_range(-60, 60), -randf_range(30, 110)), Color(0.05, 0.02, 0.07, 0.6), 22.0, randf_range(1.1, 1.6))
				s.wobble = 30.0
			for i in 10:
				var r := vv.part(at + _jit(90), Vector2(0, -randf_range(40, 90)), CURSE.lerp(Color.WHITE, 0.3), randf_range(0.9, 1.3), 8.0, Vfx.RUNE)
				r.size1 = 6.0
				r.wobble = 20.0
			vv.shake(3.0))
	return 0.55


## Pale wisps curl around the target and it flickers out of step with the world.
static func _ethereal(v: Vfx, from: Vector2, dests: Array) -> float:
	for d in dests:
		var at: Vector2 = d.body
		v.move(from, at, 0.5, 140, GHOST, 9.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var g := vv.part(m.pos + _jit(8), _jit(30), Color(GHOST, 0.5), 0.55, 12.0)
				g.wobble = 120.0
				g.size1 = 2.0,
			func(vv: Vfx, _at: Vector2) -> void:
				for k in 3:
					vv.ring(at, 30, 180, Color(GHOST, 0.6), 0.7, 5.0, k * 0.16, 0.8)
				vv.glow(at, 220, Color(GHOST, 0.45), 0.9)
				for i in 24:
					var w := vv.part(at + _jit(80), Vector2(randf_range(-40, 40), -randf_range(40, 120)), Color(GHOST, 0.6), randf_range(0.9, 1.4), randf_range(8, 16))
					w.wobble = 110.0
					w.size1 = 1.0)
	return 0.55


## The killing blow: the screen darkens, two huge slashes cross the target, and it bursts in red.
static func _execute(v: Vfx, from: Vector2, dests: Array) -> float:
	v.flash(Color(0, 0, 0, 0.6), 0.8, 0.0, false)
	for d in dests:
		var at: Vector2 = d.body
		v.slash(at + Vector2(-190, -150), at + Vector2(190, 150), BLOOD, 0.5, 34.0, 0.12)
		v.slash(at + Vector2(190, -150), at + Vector2(-190, 150), BLOOD, 0.5, 34.0, 0.27)
		v.emit(at, 0.3, 0.0, Callable(), func(vv: Vfx, _at: Vector2) -> void:
			vv.glow(at, 220, Color(1, 1, 1, 0.95), 0.16)
			vv.glow(at, 330, Color(BLOOD, 0.7), 0.7)
			vv.flare(at, 520, Color(1, 0.4, 0.4, 0.9), 0.4)
			vv.ring(at, 20, 240, BLOOD, 0.5, 16.0)
			vv.ring(at, 10, 150, Color(1, 1, 1, 0.9), 0.3, 6.0, 0.04)
			vv.flash(Color(BLOOD, 0.35), 0.35)
			vv.burst(at, 44, Color(1, 0.6, 0.55), Vector2(400, 1100), Vector2(0.2, 0.5), Vector2(4, 9))
			for s in vv.burst(at, 22, Color(0.55, 0.05, 0.08), Vector2(200, 600), Vector2(0.6, 1.0), Vector2(9, 18), Vfx.SHARD):
				s.grav = Vector2(0, 1000)
				s.spin = randf_range(-14, 14)
				s.size1 = s.size0
			vv.hitstop(0.12)
			vv.shake(14.0))
	v.shake(4.0, 0.12)
	return 0.55


## Arcane Barrage: a volley of arcane bolts, one after another, each on its own wild arc to a random enemy.
static func _barrage(v: Vfx, from: Vector2, dests: Array) -> float:
	var arcane := Color(0.62, 0.5, 1.0)
	var t0 := _charge(v, from, arcane)
	var k := 0
	for d in dests:
		var to: Vector2 = d.row + _jit(22)
		var side := 1.0 if k % 2 == 0 else -1.0
		var it := v.move(from, to, 0.34, randf_range(60, 260), arcane.lerp(Color(0.5, 0.8, 1.0), randf() * 0.5), 12.0, t0 + k * 0.13,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, arcane, 3),
			func(vv: Vfx, at: Vector2) -> void: _detonate(vv, at, arcane, 0.75))
		it.bend += Vector2(side * randf_range(80, 200), 0)
		it.accel = true
		k += 1
	return t0 + 0.13 * maxi(0, k - 1) + 0.36


## A heavy steel bolt that breaks the target's guard: glass-like shards everywhere.
static func _shatter(v: Vfx, from: Vector2, dests: Array) -> float:
	var steel := Color(0.75, 0.85, 1.0)
	var t0 := _charge(v, from, steel)
	for d in dests:
		var it := v.move(from, d.body, 0.28, 90, steel, 15.0, t0,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, steel),
			func(vv: Vfx, at: Vector2) -> void:
				vv.flash(Color(0.8, 0.9, 1, 0.07), 0.16)
				vv.glow(at, 130, Color(0.95, 0.97, 1, 0.8), 0.14)
				vv.glow(at, 260, Color(steel, 0.45), 0.5)
				vv.flare(at, 360, Color(0.8, 0.9, 1, 0.8), 0.26)
				vv.ring(at, 10, 220, steel, 0.45, 14.0)
				for s in vv.burst(at, 34, Color(0.7, 0.8, 0.95), Vector2(200, 700), Vector2(0.6, 1.0), Vector2(10, 22), Vfx.SHARD):
					s.grav = Vector2(0, 1000)
					s.spin = randf_range(-14, 14)
					s.size1 = s.size0
				vv.burst(at, 30, Color.WHITE, Vector2(400, 1000), Vector2(0.15, 0.35), Vector2(3, 6))
				vv.hitstop(0.08)
				vv.shake(10.0))
		it.accel = true
	return t0 + 0.3


## Elements torn out of the target: they burst into shards and smoke of their own colour.
static func _disintegrate(v: Vfx, from: Vector2, dests: Array, col: Color) -> float:
	var t0 := _charge(v, from, col)
	for d in dests:
		var it := v.move(from, d.row, 0.3, 110, col, 17.0, t0,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, col, 6),
			func(vv: Vfx, at: Vector2) -> void:
				vv.glow(at, 240, Color(col.lerp(Color.WHITE, 0.5), 0.9), 0.2)
				vv.glow(at, 380, Color(col, 0.65), 0.6)
				vv.flare(at, 380, Color(col.lerp(Color.WHITE, 0.4), 0.85), 0.28)
				vv.ring(at, 10, 220, col, 0.45, 14.0)
				vv.ring(at, 6, 140, Color(1, 1, 1, 0.8), 0.28, 5.0, 0.03)
				for s in vv.burst(at, 40, col, Vector2(220, 640), Vector2(0.55, 0.9), Vector2(11, 20), Vfx.SHARD):
					s.grav = Vector2(0, 800)
					s.spin = randf_range(-10, 10)
					s.size1 = s.size0
				vv.burst(at, 24, col.lerp(Color.WHITE, 0.3), Vector2(250, 700), Vector2(0.2, 0.4), Vector2(3, 6))
				for i in 8:
					_smoke(vv, at + _jit(20), Vector2(randf_range(-80, 80), -randf_range(30, 90)), Color(col.darkened(0.7), 0.45), 14.0, 1.0)
				vv.hitstop(0.05)
				vv.shake(8.0))
		it.accel = true
	return t0 + 0.3


## A writhing tendril latches on and drags glowing essence back to you: a thick glowing tendril with a bright core,
## a grip that clenches on the target, and a stream of motes that lands on you with a pulse.
static func _siphon(v: Vfx, from: Vector2, dests: Array, col: Color, player: Vector2) -> float:
	for d in dests:
		var at: Vector2 = d.row
		var b := v.beam(from, at, Color(col, 0.75), 0.85, 11.0, 0.0, 0.04)
		b.wave = 24.0
		var core := v.beam(from, at, Color(col.lerp(Color.WHITE, 0.6), 0.9), 0.8, 4.0, 0.0, 0.06)
		core.wave = 24.0
		v.glow(at, 220, Color(col, 0.7), 0.7, 0.18)
		v.glow(at, 110, Color(1, 1, 1, 0.8), 0.16, 0.18)
		v.ring(at, 150, 12, col, 0.3, 7.0, 0.18)
		v.ring(at, 10, 120, Color(col.lerp(Color.WHITE, 0.4), 0.8), 0.3, 5.0, 0.48)
		for i in 18:
			var it := v.move(at + _jit(30), player + _jit(70), 0.5, randf_range(-60, 200), col.lerp(Color.WHITE, 0.25), randf_range(6, 9), 0.3 + i * 0.025,
				func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
					var g := vv.part(m.pos, _jit(15), Color(col, 0.65), 0.35, 10.0)
					g.size1 = 1.0,
				func(vv: Vfx, p: Vector2) -> void:
					vv.glow(p, 60, Color(col, 0.75), 0.3)
					vv.burst(p, 3, col.lerp(Color.WHITE, 0.4), Vector2(60, 160), Vector2(0.2, 0.35), Vector2(3, 5), Vfx.STAR))
			it.accel = true
		v.glow(player, 300, Color(col, 0.5), 0.6, 0.8)
		v.ring(player, 30, 280, col, 0.5, 10.0, 0.8, 0.42)
		v.shake(4.0, 0.2)
	return 0.35


## The magic bends: a looping arc of violet light that swirls around the target.
static func _redirect(v: Vfx, from: Vector2, dests: Array) -> float:
	for d in dests:
		v.move(from, d.body, 0.5, 320, SHADOW, 11.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, SHADOW, 2),
			func(vv: Vfx, at: Vector2) -> void:
				_orbit(vv, at, SHADOW, Color.WHITE, 0.55, 170.0)
				vv.sigil(at, 140, SHADOW, 1.0, 3, 0.0, 0.8, 2.6)
				vv.glow(at, 260, Color(SHADOW, 0.5), 0.8)
				# arrows chasing each other round it: its aim is being turned
				vv.emit(at, 0.6, 0.0, func(v3: Vfx, it: Vfx.Item, _d: float) -> void:
					for k in 3:
						var ang := it.age * 9.0 + k * TAU / 3.0
						var p := at + Vector2(cos(ang) * 175, sin(ang) * 90)
						var ch := v3.part(p, Vector2.ZERO, SHADOW.lerp(Color.WHITE, 0.4), 0.14, 15.0, Vfx.CHEVRON)
						ch.rot = ang + PI
						ch.size1 = 8.0)
				vv.ring(at, 10, 200, SHADOW, 0.5, 10.0, 0.55)
				vv.shake(4.0, 0.55))
	return 0.55


## Two strands of light spiral in around a point and pop.
static func _orbit(v: Vfx, at: Vector2, c1: Color, c2: Color, dur: float, r0: float) -> void:
	v.emit(at, dur, 0.0, func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
		var tt := it.t()
		var r := r0 * (1.0 - tt) + 10.0
		for k in 2:
			var ang := it.age * 16.0 + k * PI
			var p := at + Vector2(cos(ang) * r, sin(ang) * r * 0.45)
			var g := vv.part(p, Vector2.ZERO, c1 if k == 0 else c2, 0.35, 15.0)
			g.size1 = 2.0,
		func(vv: Vfx, _at: Vector2) -> void:
			vv.glow(at, 200, Color(c1.lerp(Color.WHITE, 0.5), 0.9), 0.25)
			vv.flare(at, 280, Color(c1.lerp(Color.WHITE, 0.5), 0.8), 0.28)
			vv.ring(at, 10, 160, c1, 0.4, 8.0)
			for s in vv.burst(at, 18, c1.lerp(Color.WHITE, 0.4), Vector2(180, 450), Vector2(0.4, 0.75), Vector2(8, 13), Vfx.STAR):
				s.drag = 3.0
				s.spin = 5.0)


## The target's elements are rewritten: two strands spiral in around its row and flash.
static func _swirl(v: Vfx, from: Vector2, dests: Array, col: Color) -> float:
	for d in dests:
		v.move(from, d.row, 0.36, 130, col, 10.0, 0.04,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void: _spark_trail(vv, m, col, 2),
			func(vv: Vfx, at: Vector2) -> void:
				_orbit(vv, at, col, Color.WHITE, 0.5, 200.0)
				vv.glow(at, 260, Color(col, 0.55), 0.8)
				vv.ring(at, 10, 180, col, 0.45, 9.0)
				vv.ring(at, 10, 240, Color(col.lerp(Color.WHITE, 0.5), 0.8), 0.45, 5.0, 0.5, 0.45)
				vv.burst(at, 22, col.lerp(Color.WHITE, 0.4), Vector2(150, 420), Vector2(0.4, 0.7), Vector2(7, 12), Vfx.STAR, 0.5))
	return 0.4


## Snipe (when it wasn't the player's own gunshot, e.g. a repeat): a white-hot tracer snaps into the Essence and it
## breaks apart in its own colour.
static func _snipe(v: Vfx, from: Vector2, dests: Array, col: Color) -> float:
	for d in dests:
		var at: Vector2 = d.row
		var tr := v.beam(from, at, Color(1, 0.92, 0.7, 0.95), 0.1, 5.0, 0.0, 0.08)
		tr.w0 = 2.0
		v.beam(from, at, Color(col, 0.45), 0.16, 14.0, 0.0, 0.08)
		v.emit(at, 0.1, 0.0, Callable(), func(vv: Vfx, _a: Vector2) -> void:
			vv.glow(at, 150, Color(1, 0.97, 0.85, 1.0), 0.1)
			vv.glow(at, 230, Color(col, 0.7), 0.4)
			vv.flare(at, 300, Color(1, 0.88, 0.5, 0.95), 0.16)
			vv.ring(at, 6, 95, Color(1, 0.95, 0.75), 0.22, 6.0)
			for s in vv.burst(at, 18, col, Vector2(200, 560), Vector2(0.5, 0.85), Vector2(6, 12), Vfx.SHARD):
				s.grav = Vector2(0, 1100)
				s.spin = randf_range(-14, 14)
				s.size1 = s.size0
			vv.hitstop(0.06)
			vv.shake(8.0))
	return 0.12


# ------------------------------------------------------------------ on you

static func _self(dests: Array) -> Dictionary:
	return dests[0] if not dests.is_empty() else {"body": Vector2(270, 800), "row": Vector2(270, 800)}


## A dome of hexagons rises around you.
static func _shield(v: Vfx, from: Vector2, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	var t := _stream(v, from, at, Vector2(160, 30), SHIELD, 10)
	v.dome(at, 290, 0.42, SHIELD, 1.3, t)
	v.ring(at, 40, 320, SHIELD, 0.55, 10.0, t, 0.42)
	var g := v.glow(at, 300, Color(SHIELD, 0.35), 0.8, t)
	g.aspect = 0.45
	for i in 16:
		var ang := randf() * TAU
		var s := v.part(at + Vector2(cos(ang) * 290, sin(ang) * 122), Vector2.ZERO, Color(0.8, 0.95, 1), randf_range(0.4, 0.8), randf_range(6, 11), Vfx.STAR, t + randf_range(0.05, 0.4))
		s.spin = 3.0
	v.shake(2.5, t)
	return t


## A golden seal of warding stamps down on you, with rays of light.
static func _aegis(v: Vfx, from: Vector2, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	var t := _stream(v, from, at, Vector2(120, 25), GOLD, 10)
	v.sigil(at, 130, GOLD, 1.4, 6, t, 1.0, 0.7)
	v.glow(at, 260, Color(GOLD, 0.6), 0.8, t)
	v.ring(at, 30, 260, GOLD, 0.5, 12.0, t)
	for i in 7:
		var ang := -PI / 2.0 + (i - 3) * 0.24
		var b := v.beam(at, at + Vector2.from_angle(ang) * randf_range(230, 300), Color(GOLD, 0.55), 0.8, 5.0, 0.0, t + i * 0.02)
		b.w0 = 5.0
	for i in 14:
		var s := v.part(at + _jit(140), Vector2(0, -randf_range(30, 90)), Color(1, 0.95, 0.75), randf_range(0.5, 0.9), randf_range(6, 11), Vfx.STAR, t + randf_range(0.0, 0.3))
		s.spin = 3.0
	v.shake(4.0, t)
	return t


## Thorns burst out all around you.
static func _thorns(v: Vfx, from: Vector2, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	var t := _stream(v, from, at, Vector2(150, 25), THORN, 8)
	for i in 20:
		var ang := i * TAU / 20.0 + randf_range(-0.08, 0.08)
		var dir := Vector2(cos(ang), sin(ang) * 0.42)
		var p := at + Vector2(cos(ang) * 235, sin(ang) * 95)
		var th := v.part(p, Vector2.ZERO, Color(0.55, 0.8, 0.28), 1.0, 70.0, Vfx.THORN, t + i * 0.01)
		th.rot = dir.angle()
		th.grow = 0.12
		th.size1 = randf_range(58, 86)
		th.hold = 0.65
		var s := v.part(p + dir.normalized() * th.size1, dir.normalized() * 120, THORN.lerp(Color.WHITE, 0.3), 0.35, 5.0, Vfx.SPARK, t + 0.1)
		s.drag = 4.0
	for i in 14:  # a second, inner ring of shorter thorns, a beat later
		var ang := (i + 0.5) * TAU / 14.0
		var dir := Vector2(cos(ang), sin(ang) * 0.42)
		var th := v.part(at + Vector2(cos(ang) * 150, sin(ang) * 60), Vector2.ZERO, Color(0.42, 0.66, 0.2), 0.9, 44.0, Vfx.THORN, t + 0.08 + i * 0.01)
		th.rot = dir.angle()
		th.grow = 0.14
		th.size1 = randf_range(36, 52)
		th.hold = 0.65
	v.glow(at, 300, Color(THORN, 0.45), 0.6, t)
	for l in v.burst(at, 16, Color(0.6, 0.9, 0.35), Vector2(200, 480), Vector2(0.5, 0.8), Vector2(6, 10), Vfx.DROP, t):
		l.grav = Vector2(0, 500)  # leaves torn loose
		l.spin = randf_range(-8, 8)
	v.ring(at, 60, 320, THORN, 0.5, 10.0, t, 0.42)
	v.shake(5.0, t)
	return t


## A column of green-gold light, and motes and little crosses rising all around you.
static func _heal(v: Vfx, from: Vector2, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	var t := _stream(v, from, at, Vector2(150, 25), HEAL, 10)
	var col := v.part(at + Vector2(0, -150), Vector2.ZERO, Color(HEAL, 0.7), 1.1, 80.0, Vfx.GLOW, t)
	col.size1 = 150.0
	col.aspect = 2.6
	col.hold = 0.4
	var core := v.part(at + Vector2(0, -150), Vector2.ZERO, Color(0.9, 1, 0.85, 0.55), 0.9, 30.0, Vfx.GLOW, t)
	core.size1 = 50.0
	core.aspect = 5.0
	var g := v.glow(at, 360, Color(HEAL, 0.6), 0.9, t)
	g.aspect = 0.5
	v.flare(at, 420, Color(0.8, 1, 0.75, 0.8), 0.35, t)
	v.ring(at, 40, 320, HEAL, 0.6, 14.0, t, 0.42)
	v.ring(at, 20, 220, Color(1, 1, 0.8, 0.8), 0.45, 6.0, t + 0.08, 0.42)
	v.emit(at, 1.1, t, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		for i in 4:
			var shape := Vfx.CROSS if randf() < 0.4 else (Vfx.STAR if randf() < 0.3 else Vfx.GLOW)
			var m := vv.part(at + Vector2(randf_range(-230, 230), randf_range(-10, 45)), Vector2(0, -randf_range(100, 230)), HEAL.lerp(Color(1, 1, 0.7), randf() * 0.5), randf_range(0.8, 1.3), randf_range(8, 15), shape)
			m.wobble = 30.0
			m.size1 = m.size0 * 0.4)
	return t


## A wave of pure light washes over you: shadows cling to you for a beat, then a burst of white light flings them
## off; they burn away into sparkles as a curtain of light rises through you.
static func _cleanse(v: Vfx, from: Vector2, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	var t := _stream(v, from, at, Vector2(150, 25), PURE, 8)
	for i in 12:  # the darkness clinging on, just before the light hits
		var s := v.part(at + Vector2(randf_range(-200, 200), randf_range(-30, 30)), Vector2(0, -10), Color(0.06, 0.05, 0.1, 0.55), 0.3, 16.0, Vfx.SMOKE, maxf(0.0, t - 0.22))
		s.size1 = 26.0
	v.flash(Color(PURE, 0.14), 0.35, t)
	v.glow(at, 170, Color(1, 1, 1, 0.85), 0.14, t)
	var wash := v.glow(at, 460, Color(PURE, 0.6), 0.85, t)
	wash.aspect = 0.5
	v.flare(at, 560, Color(0.9, 1, 1, 0.9), 0.35, t)
	v.ring(at, 30, 400, PURE, 0.55, 16.0, t, 0.42)
	v.ring(at, 20, 280, Color(1, 1, 0.85, 0.9), 0.4, 6.0, t + 0.06, 0.42)
	var curtain := v.part(at + Vector2(0, -130), Vector2.ZERO, Color(PURE, 0.55), 0.9, 90.0, Vfx.GLOW, t)
	curtain.size1 = 170.0
	curtain.aspect = 3.0
	curtain.hold = 0.3
	for i in 18:  # the shadows are flung off and burn away into sparkles where they vanish
		var dir := Vector2.from_angle(randf() * TAU)
		dir.y *= 0.5
		var s := v.part(at + dir * 40, dir.normalized() * randf_range(380, 620), Color(0.07, 0.06, 0.1, 0.65), 0.42, 16.0, Vfx.SMOKE, t)
		s.size1 = 38.0
		s.drag = 3.5
		var sp := v.part(at + dir.normalized() * randf_range(170, 260), Vector2(0, -randf_range(30, 90)), Color(0.95, 1, 1), randf_range(0.5, 0.8), randf_range(7, 12), Vfx.STAR, t + 0.3)
		sp.spin = 4.0
	v.emit(at, 0.9, t, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		for i in 2:
			var m := vv.part(at + Vector2(randf_range(-230, 230), randf_range(-10, 45)), Vector2(0, -randf_range(120, 240)), Color(0.9, 1, 1), randf_range(0.7, 1.1), randf_range(6, 11), Vfx.STAR if randf() < 0.5 else Vfx.GLOW)
			m.wobble = 25.0
			m.size1 = m.size0 * 0.3)
	v.shake(3.0, t)
	return t


## Your own blood pays for the spell.
static func _sacrifice(v: Vfx, dests: Array) -> float:
	var d := _self(dests)
	var at: Vector2 = d.body
	v.flash(Color(BLOOD, 0.3), 0.45)
	v.slash(at + Vector2(-230, -60), at + Vector2(230, 50), BLOOD, 0.5, 30.0)
	v.glow(at, 340, Color(BLOOD, 0.7), 0.7, 0.05)
	v.flare(at, 460, Color(1, 0.35, 0.35, 0.85), 0.35, 0.05)
	v.ring(at, 20, 320, BLOOD, 0.55, 14.0, 0.05, 0.42)
	for i in 44:
		var dr := v.part(at + _jit(60), Vector2(randf_range(-380, 380), -randf_range(250, 700)), Color(0.9, 0.08, 0.12), randf_range(0.6, 1.0), randf_range(6, 11), Vfx.DROP, 0.05)
		dr.grav = Vector2(0, 1300)
		dr.size1 = dr.size0 * 0.6
	v.hitstop(0.06)
	v.shake(8.0)
	return 0.25


## Gain Essence: for each Essence gained, an orb of light leaves the card and flies to the very slot where it will
## appear (in "Coming next turn", or your bag), shedding comet dust in that element's colour; on arrival it flashes
## and the Essence materializes, popping in. Returns when the last one has popped (the real Essence takes over there).
static func _draw_fx(v: Vfx, from: Vector2, dests: Array) -> float:
	var last := 0.0
	var i := 0
	for d in dests:
		var el: String = d.get("el", "A")
		var c: Color = Elements.COLORS.get(el, GOLD)
		var to: Vector2 = d.body
		var px: float = d.get("px", 44.0)
		var delay := i * 0.13
		v.glow(from, 90, Color(c.lerp(Color.WHITE, 0.4), 0.8), 0.25, delay)
		var orb := v.move(from + _jit(10), to, 0.6, randf_range(140, 230), c.lerp(Color.WHITE, 0.3), 16.0, delay,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var halo := vv.part(m.pos, Vector2.ZERO, Color(c, 0.85), 0.1, 58.0)
				halo.size1 = 30.0
				var core := vv.part(m.pos, Vector2.ZERO, Color(1, 1, 1, 0.95), 0.08, 18.0)
				core.size1 = 8.0
				var tail := vv.part(m.pos, -m.dir * 30.0, Color(c, 0.6), 0.4, 26.0)
				tail.size1 = 3.0
				for k in 5:  # comet dust, falling away behind it in the element's colour
					var dust := vv.part(m.pos + _jit(7), -m.dir * randf_range(40, 150) + _jit(40) + Vector2(0, 40), c.lerp(Color.WHITE, randf() * 0.3), randf_range(0.45, 0.85), randf_range(3.5, 6.5), Vfx.DOT if k < 3 else Vfx.GLOW)
					dust.drag = 2.2
					dust.grav = Vector2(0, 90)
					dust.size1 = 0.6
				if randf() < 0.5:
					var sp := vv.part(m.pos + _jit(10), -m.dir * 50.0 + _jit(30), c.lerp(Color.WHITE, 0.6), randf_range(0.3, 0.5), randf_range(6, 10), Vfx.STAR)
					sp.spin = 6.0
					sp.drag = 2.0,
			func(vv: Vfx, at: Vector2) -> void: _materialize(vv, at, el, c, px))
		orb.accel = false
		last = delay + 0.6
		i += 1
	return last + 0.28


## An Essence materializes at `at`: a flash, a ring snapping inwards, then it pops in (overshoots, settles) with a
## sparkle. The popped copy fades once the real Essence is showing underneath it.
static func _materialize(v: Vfx, at: Vector2, el: String, c: Color, px: float) -> void:
	v.glow(at, px * 1.8, Color(1, 1, 1, 0.95), 0.14)
	v.glow(at, px * 3.2, Color(c, 0.65), 0.55)
	v.flare(at, px * 4.0, Color(c.lerp(Color.WHITE, 0.5), 0.85), 0.25)
	v.ring(at, px * 1.6, px * 0.45, Color(c.lerp(Color.WHITE, 0.4), 0.9), 0.16, 4.0)
	v.ring(at, px * 0.5, px * 2.2, c, 0.4, 6.0, 0.14)
	for s in v.burst(at, 12, c.lerp(Color.WHITE, 0.45), Vector2(90, 260), Vector2(0.35, 0.6), Vector2(5, 9), Vfx.STAR, 0.1):
		s.spin = 5.0
		s.drag = 3.0
	var icon := ElementIcon.make(el, int(px))
	icon.size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = at - icon.size / 2.0 - v.global_position
	icon.pivot_offset = icon.size / 2.0
	icon.scale = Vector2(0.15, 0.15)
	icon.modulate = Color(2.2, 2.2, 2.2, 1.0)
	v.add_child(icon)
	var tw := icon.create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "scale", Vector2(1.28, 1.28), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "modulate", Color.WHITE, 0.3)
	tw.chain().tween_property(icon, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(icon, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(icon.queue_free)


# ------------------------------------------------------------------ on the chant

## Runes pour into the chant and a band of light sweeps along it; each kind of chant magic adds its own flourish.
static func _chant_magic(v: Vfx, op: String, from: Vector2, dests: Array, col: Color) -> float:
	# each kind of chant magic has its own colour, so they can be told apart at a glance
	col = {"amplify": GOLD, "echo": Color(0.45, 0.9, 1.0), "overload": Color(0.75, 0.55, 1.0), "duplicate": Color(0.4, 1.0, 0.65),
		"copy_last": Color(0.4, 1.0, 0.65), "retain": Color(1.0, 0.6, 0.25)}.get(op, col)
	var d := _self(dests)
	var r := _rect(d)
	var c := r.get_center()
	for i in 9:
		v.move(from + _jit(20), c + Vector2(randf_range(-r.size.x * 0.4, r.size.x * 0.4), randf_range(-15, 15)), 0.34, randf_range(80, 220), col, 9.0, i * 0.022,
			func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var ru := vv.part(m.pos, _jit(25), col.lerp(Color.WHITE, 0.3), 0.45, 10.0, Vfx.RUNE)
				ru.size1 = 6.0,
			func(vv: Vfx, p: Vector2) -> void:
				vv.glow(p, 90, Color(col, 0.85), 0.35)
				vv.burst(p, 6, col.lerp(Color.WHITE, 0.4), Vector2(100, 250), Vector2(0.2, 0.35), Vector2(3, 6)))
	var t := 0.4
	var sweep := v.move(Vector2(r.position.x, c.y), Vector2(r.end.x, c.y), 0.38, 0.0, col, 0.0, t, func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
		var bar := vv.part(m.pos, Vector2.ZERO, Color(col.lerp(Color.WHITE, 0.4), 0.7), 0.35, 34.0)
		bar.aspect = 2.4
		bar.size1 = 12.0
		for i in 3:
			var s := vv.part(m.pos + Vector2(0, randf_range(-r.size.y * 0.45, r.size.y * 0.45)), Vector2(randf_range(-40, 40), -randf_range(30, 120)), col.lerp(Color.WHITE, 0.5), randf_range(0.5, 0.8), randf_range(6, 10), Vfx.STAR)
			s.spin = 4.0)
	sweep.accel = false
	match op:
		"amplify":
			# everything in the chant swells: a golden surge and chevrons rising off every slot
			v.glow(c, r.size.x * 0.55, Color(GOLD, 0.55), 0.7, t)
			v.flare(c, r.size.x * 0.9, Color(1, 0.9, 0.5, 0.85), 0.3, t)
			v.shake(4.0, t)
			for wave in 3:
				for i in 10:
					var ch := v.part(Vector2(randf_range(r.position.x, r.end.x), c.y + 20), Vector2(0, -randf_range(320, 460)), GOLD, 0.7, randf_range(16, 24), Vfx.CHEVRON, t + wave * 0.12)
					ch.drag = 1.5
					ch.size1 = ch.size0 * 0.6
		"echo":
			# it rings out again and again: sound-wave rings, each fainter than the last
			for k in 4:
				v.ring(c, 30, r.size.x * (0.5 + 0.12 * k), Color(col, 0.9 - 0.18 * k), 0.75, 12.0 - 2.0 * k, t + k * 0.16, 0.3)
			v.glow(c, r.size.x * 0.5, Color(col, 0.45), 0.9, t)
		"overload":
			v.flash(Color(0.7, 0.5, 1, 0.18), 0.35, t)
			v.glow(c, r.size.x * 0.55, Color(0.7, 0.5, 1, 0.5), 0.7, t)
			for i in 14:
				var a := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
				var b := a + Vector2(randf_range(-280, 280), randf_range(-120, 60))
				var dl := t + randf_range(0.0, 0.45)
				v.beam(a, b, Color(0.78, 0.62, 1), 0.18, 5.0, 22.0, dl)
				v.glow(b, 60, Color(0.85, 0.75, 1, 0.8), 0.2, dl)
			v.shake(5.0, t)
		"duplicate", "copy_last":
			# a mirror image: a second sweep runs back the other way, and twin flashes split apart
			v.move(Vector2(r.end.x, c.y), Vector2(r.position.x, c.y), 0.38, 0.0, col, 0.0, t, func(vv: Vfx, m: Vfx.Item, _d: float) -> void:
				var bar := vv.part(m.pos, Vector2.ZERO, Color(col.lerp(Color.WHITE, 0.4), 0.7), 0.35, 34.0)
				bar.aspect = 2.4
				bar.size1 = 12.0)
			for side in [-1.0, 1.0]:
				var p := c + Vector2(side * r.size.x * 0.18, 0)
				v.glow(p, 180, Color(col, 0.7), 0.55, t)
				v.flare(p, 260, Color(col.lerp(Color.WHITE, 0.4), 0.8), 0.3, t)
				v.burst(p, 16, col.lerp(Color.WHITE, 0.4), Vector2(120, 340), Vector2(0.4, 0.75), Vector2(7, 12), Vfx.STAR, t)
		"retain":
			# held in place: brackets clamp in from both ends, a ring closes and a seal locks it
			v.ring(c, r.size.x * 0.65, r.size.x * 0.32, col, 0.5, 12.0, t, 0.3)
			for side in [-1.0, 1.0]:
				var br := v.part(c + Vector2(side * r.size.x * 0.62, 0), Vector2(-side * 900, 0), col.lerp(Color.WHITE, 0.3), 0.75, 26.0, Vfx.CHEVRON, t)
				br.rot = -side * PI / 2.0
				br.drag = 6.0
				br.size1 = 26.0
				br.hold = 0.6
			v.sigil(c, r.size.y * 0.9, col, 0.9, 4, t + 0.25, 0.5, 0.0)
			v.flare(c, r.size.x * 0.8, Color(col, 0.8), 0.35, t + 0.3)
			v.glow(c, r.size.x * 0.35, Color(col, 0.4), 0.6, t + 0.3)
			v.shake(3.0, t + 0.3)
		"transmute":
			_orbit(v, c, col, Color.WHITE, 0.5, r.size.x * 0.3)
	return t


# ------------------------------------------------------------------ powers

## A power takes hold: a magic circle turns on the card, light rises from it, and flows into you.
static func _power(v: Vfx, from: Vector2, col: Color, player: Vector2) -> float:
	v.sigil(from, 150, col, 1.4, 6, 0.0, 1.0, 0.8)
	v.sigil(from, 95, col.lerp(Color.WHITE, 0.4), 1.3, 3, 0.1, 1.0, -1.2)
	var pillar := v.part(from + Vector2(0, -170), Vector2.ZERO, Color(col, 0.35), 0.9, 50.0, Vfx.GLOW, 0.15)
	pillar.size1 = 80.0
	pillar.aspect = 3.2
	v.ring(from, 20, 220, col, 0.5, 10.0, 0.1)
	v.emit(from, 0.8, 0.1, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		var ang := randf() * TAU
		var ru := vv.part(from + Vector2.from_angle(ang) * 140, Vector2(0, -randf_range(80, 180)), col.lerp(Color.WHITE, 0.3), randf_range(0.6, 0.9), 8.0, Vfx.RUNE)
		ru.size1 = 5.0)
	_stream(v, from, player, Vector2(120, 20), col, 8, 0.55, 0.38)
	return 0.5
