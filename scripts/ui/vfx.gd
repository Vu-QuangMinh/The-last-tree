class_name Vfx
extends Control
## The building blocks of every spell effect: glowing particles, shockwave rings, beams, slashes, magic
## circles, hex shields, screen flashes and projectiles that shed trails. A whole effect is authored up
## front (each piece with its own delay), plays on its own clock, and the node frees itself once all of it
## has faded. Light is drawn additively on top, so overlapping glows burn towards white; smoke, shards,
## crystals and thorns are drawn normally underneath it.

enum { GLOW, SPARK, DOT, SHARD, SMOKE, FLAKE, CRYSTAL, BUBBLE, CROSS, STAR, RUNE, CHEVRON, THORN, DROP }
const SOLID := [SHARD, SMOKE, CRYSTAL, THORN]


class Item:
	var kind := "p"  # p (particle), ring, beam, slash, sigil, dome, flash, mover
	var delay := 0.0
	var age := 0.0
	var life := 1.0
	var add := true
	var col := Color.WHITE
	var col1 := Color(1, 1, 1, 0)
	var ramp: Gradient  # colour over life (overrides col/col1)
	var hold := 0.0  # fraction of life spent at full colour before fading to col1
	# particles
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var grav := Vector2.ZERO
	var drag := 0.0
	var size0 := 8.0
	var size1 := 0.0
	var grow := 0.0  # > 0: size springs up to size1 over this fraction of life, then holds
	var aspect := 1.0
	var shape := 0
	var rot := 0.0
	var spin := 0.0
	var stretch := 0.0
	var wobble := 0.0
	var phase := 0.0
	# rings, circles, domes
	var r0 := 0.0
	var r1 := 0.0
	var w0 := 0.0
	var w1 := 0.0
	var squash := 1.0
	var sides := 0
	# beams, slashes, movers
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var bend := Vector2.ZERO
	var jag := 0.0
	var wave := 0.0
	var head := 0.0
	var accel := false
	var dir := Vector2.RIGHT
	var on_step: Callable
	var on_arrive: Callable
	var arrived := false

	func t() -> float:
		return clampf(age / life, 0.0, 1.0)

	func color() -> Color:
		var tt := t()
		if ramp:
			return ramp.sample(tt) * Color(1, 1, 1, col.a)
		if tt <= hold:
			return col
		return col.lerp(col1, (tt - hold) / maxf(0.001, 1.0 - hold))


static var _glow_tex: Texture2D
static var _glyphs: Array = []

var shaker: Callable  # shakes the screen: shaker.call(amount)
var _items: Array = []
var _add_layer := Control.new()
var _mix_layer := Control.new()


static func make(parent: Node, z := 45) -> Vfx:
	var v := Vfx.new()
	v.z_index = z
	parent.add_child(v)
	return v


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for l in [_mix_layer, _add_layer]:
		l.mouse_filter = MOUSE_FILTER_IGNORE
		l.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(l)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer.material = m
	_mix_layer.draw.connect(_draw_layer.bind(_mix_layer, false))
	_add_layer.draw.connect(_draw_layer.bind(_add_layer, true))


## A soft round light: bright in the middle, falling off smoothly to nothing.
static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 0.55, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow_tex = t
	return _glow_tex


## Little made-up runes for magic circles and chant magic: each one a few strokes in a unit square.
static func glyphs() -> Array:
	if _glyphs.is_empty():
		var V := func(x: float, y: float) -> Vector2: return Vector2(x, y)
		_glyphs = [
			[[V.call(0, -1), V.call(0, 1)], [V.call(-0.6, -0.3), V.call(0.6, 0.3)]],
			[[V.call(-0.7, 1), V.call(0, -1), V.call(0.7, 1)], [V.call(-0.4, 0.3), V.call(0.4, 0.3)]],
			[[V.call(-0.6, -1), V.call(0.6, -1), V.call(-0.6, 1), V.call(0.6, 1)]],
			[[V.call(0, -1), V.call(0, 1)], [V.call(0, -0.3), V.call(-0.7, -0.9)], [V.call(0, -0.3), V.call(0.7, -0.9)]],
			[[V.call(-0.7, -0.7), V.call(0.7, -0.7), V.call(0.7, 0.7), V.call(-0.7, 0.7)], [V.call(0, -1), V.call(0, 1)]],
			[[V.call(-0.7, -1), V.call(0.7, 0), V.call(-0.7, 1)]],
			[[V.call(0, -1), V.call(0.8, 0), V.call(0, 1), V.call(-0.8, 0), V.call(0, -1)]],
			[[V.call(-0.7, 1), V.call(-0.7, -1), V.call(0.7, 1), V.call(0.7, -1)]],
		]
	return _glyphs


# ------------------------------------------------------------------ building an effect

func _add(it: Item, delay: float) -> Item:
	it.delay = delay
	_items.append(it)
	return it


## One particle. Its layer follows its shape (smoke, shards, crystals and thorns are solid; the rest is light).
func part(pos: Vector2, vel: Vector2, col: Color, life: float, size: float, shape := GLOW, delay := 0.0) -> Item:
	var it := Item.new()
	it.pos = pos
	it.vel = vel
	it.col = col
	it.col1 = Color(col, 0.0)
	it.life = life
	it.size0 = size
	it.size1 = size * 0.3
	it.shape = shape
	it.add = not (shape in SOLID)
	it.rot = randf() * TAU
	it.phase = randf() * 100.0
	return _add(it, delay)


## A spray of particles from one point: `arc` wide around the direction `aim`.
func burst(at: Vector2, n: int, col: Color, speed: Vector2, life: Vector2, size: Vector2, shape := SPARK, delay := 0.0, arc := TAU, aim := 0.0) -> Array:
	var out := []
	for i in n:
		var ang := aim + randf_range(-arc / 2.0, arc / 2.0)
		var it := part(at, Vector2.from_angle(ang) * randf_range(speed.x, speed.y), col, randf_range(life.x, life.y), randf_range(size.x, size.y), shape, delay)
		if shape == SPARK:
			it.stretch = 0.5
			it.drag = 4.0
		out.append(it)
	return out


## A still bloom of light that swells a little and fades.
func glow(at: Vector2, size: float, col: Color, life: float, delay := 0.0) -> Item:
	var it := part(at, Vector2.ZERO, col, life, size * 0.7, GLOW, delay)
	it.size1 = size
	return it


## An anamorphic lens flare: a long thin streak of light across a bright point, with a shorter upright one.
func flare(at: Vector2, length: float, col: Color, life: float, delay := 0.0) -> void:
	var h := part(at, Vector2.ZERO, col, life, length * 0.6, GLOW, delay)
	h.size1 = length
	h.aspect = 0.05
	var core := part(at, Vector2.ZERO, Color(1, 1, 1, col.a), life * 0.8, length * 0.35, GLOW, delay)
	core.size1 = length * 0.6
	core.aspect = 0.03
	var v := part(at, Vector2.ZERO, Color(col, col.a * 0.6), life * 0.7, length * 0.2, GLOW, delay)
	v.size1 = length * 0.3
	v.aspect = 4.0
	v.size0 = length * 0.05
	v.size1 = length * 0.08


## A shockwave ring that races out (or closes in, if r1 < r0) and thins as it goes.
func ring(at: Vector2, r0: float, r1: float, col: Color, life: float, width := 8.0, delay := 0.0, squash := 1.0) -> Item:
	var it := Item.new()
	it.kind = "ring"
	it.pos = at
	it.r0 = r0
	it.r1 = r1
	it.w0 = width
	it.w1 = width * 0.15
	it.col = col
	it.life = life
	it.squash = squash
	return _add(it, delay)


## A beam of light from a to b that shoots out, holds and fades. `jag` makes it crackle like lightning,
## `wave` makes it writhe like a tendril.
func beam(a: Vector2, b: Vector2, col: Color, life: float, width := 8.0, jag := 0.0, delay := 0.0) -> Item:
	var it := Item.new()
	it.kind = "beam"
	it.a = a
	it.b = b
	it.col = col
	it.life = life
	it.w0 = width
	it.jag = jag
	return _add(it, delay)


## A blade-cut: a curved sliver of light drawn from a to b in an instant, then thinning away.
func slash(a: Vector2, b: Vector2, col: Color, life: float, width := 24.0, delay := 0.0) -> Item:
	var it := Item.new()
	it.kind = "slash"
	it.a = a
	it.b = b
	it.col = col
	it.life = life
	it.w0 = width
	return _add(it, delay)


## A magic circle: rings, a star and runes that draw themselves in, turn, and fade.
func sigil(at: Vector2, r: float, col: Color, life: float, sides := 6, delay := 0.0, squash := 1.0, spin := 0.8) -> Item:
	var it := Item.new()
	it.kind = "sigil"
	it.pos = at
	it.r0 = r
	it.col = col
	it.life = life
	it.sides = sides
	it.squash = squash
	it.spin = spin
	return _add(it, delay)


## A shield of hexagons that grows out from the middle, shimmers, and fades.
func dome(at: Vector2, r: float, squash: float, col: Color, life: float, delay := 0.0) -> Item:
	var it := Item.new()
	it.kind = "dome"
	it.pos = at
	it.r0 = r
	it.squash = squash
	it.col = col
	it.life = life
	return _add(it, delay)


## The whole screen flashes a colour (additive light, or a normal tint such as a sudden darkness).
func flash(col: Color, life: float, delay := 0.0, additive := true) -> Item:
	var it := Item.new()
	it.kind = "flash"
	it.col = col
	it.life = life
	it.add = additive
	return _add(it, delay)


## A projectile flying a to b over `dur`, arcing `rise` px up. on_step(vfx, item, dt) runs every frame
## (shed its trail there); on_arrive(vfx, at) runs when it lands.
func move(a: Vector2, b: Vector2, dur: float, rise: float, col: Color, head: float, delay: float, on_step := Callable(), on_arrive := Callable()) -> Item:
	var it := Item.new()
	it.kind = "mover"
	it.a = a
	it.b = b
	it.pos = a
	it.bend = Vector2(0, -rise)
	it.life = dur
	it.col = col
	it.head = head
	it.on_step = on_step
	it.on_arrive = on_arrive
	return _add(it, delay)


## Something that stays in one place for `dur`, running on_step every frame (a fountain, a swirl).
func emit(at: Vector2, dur: float, delay: float, on_step: Callable, on_done := Callable()) -> Item:
	return move(at, at, dur, 0.0, Color.WHITE, 0.0, delay, on_step, on_done)


## Shake the screen, now or a little later.
func shake(amount: float, delay := 0.0) -> void:
	if not shaker.is_valid():
		return
	if delay <= 0.0:
		shaker.call(amount)
	else:
		emit(Vector2.ZERO, delay, 0.0, Callable(), func(_v: Vfx, _at: Vector2) -> void: shaker.call(amount))


# ------------------------------------------------------------------ running it

func _process(d: float) -> void:
	var list := _items
	_items = []
	var live := []
	for it: Item in list:
		if it.delay > 0.0:
			it.delay -= d
			live.append(it)
			continue
		it.age += d
		if it.kind == "p":
			it.vel = it.vel * exp(-it.drag * d) + it.grav * d
			it.pos += it.vel * d
			if it.wobble != 0.0:
				it.pos.x += cos(it.age * 7.0 + it.phase) * it.wobble * d
			it.rot += it.spin * d
		elif it.kind == "mover":
			var tt := it.t()
			var e := tt * tt if it.accel else tt * tt * (3.0 - 2.0 * tt)
			var ctrl := (it.a + it.b) / 2.0 + it.bend
			var p := it.a.lerp(ctrl, e).lerp(ctrl.lerp(it.b, e), e)
			if p.distance_squared_to(it.pos) > 0.01:
				it.dir = (p - it.pos).normalized()
			it.pos = p
			if it.on_step.is_valid() and not it.arrived:
				it.on_step.call(self, it, d)
			if tt >= 1.0 and not it.arrived:
				it.arrived = true
				if it.on_arrive.is_valid():
					it.on_arrive.call(self, it.b)
		if it.age < it.life or (it.kind == "mover" and not it.arrived):
			live.append(it)
	_items = live + _items  # anything spawned this frame goes on top
	if _items.is_empty():
		queue_free()
		return
	_add_layer.queue_redraw()
	_mix_layer.queue_redraw()


# ------------------------------------------------------------------ drawing it

func _draw_layer(L: Control, additive: bool) -> void:
	for it: Item in _items:
		if it.delay > 0.0 or it.add != additive:
			continue
		match it.kind:
			"p":
				_draw_particle(L, it)
			"ring":
				_draw_ring(L, it)
			"beam":
				_draw_beam(L, it)
			"slash":
				_draw_slash(L, it)
			"sigil":
				_draw_sigil(L, it)
			"dome":
				_draw_dome(L, it)
			"flash":
				var c := it.col
				c.a *= pow(1.0 - it.t(), 2.0)
				L.draw_rect(Rect2(Vector2(-60, -60), size + Vector2(120, 120)), c)
			"mover":
				if it.head > 0.0 and not it.arrived:
					_soft(L, it.pos, it.head * 3.2, Color(it.col, 0.35))
					_soft(L, it.pos, it.head * 1.7, Color(it.col, 0.9))
					_soft(L, it.pos, it.head * 0.8, Color(1, 1, 1, 0.95))


func _soft(L: Control, p: Vector2, r: float, c: Color, aspect := 1.0) -> void:
	L.draw_texture_rect(glow_tex(), Rect2(p.x - r, p.y - r * aspect, r * 2.0, r * 2.0 * aspect), false, c)


func _draw_particle(L: Control, it: Item) -> void:
	var tt := it.t()
	var s: float
	if it.grow > 0.0:
		var g := minf(1.0, tt / it.grow)
		s = it.size1 * (1.0 - pow(1.0 - g, 3.0))
	else:
		s = lerpf(it.size0, it.size1, tt)
	if s <= 0.05:
		return
	var c := it.color()
	if c.a <= 0.003:
		return
	var p := it.pos
	match it.shape:
		GLOW, SMOKE:
			_soft(L, p, s, c, it.aspect)
		DOT:
			L.draw_circle(p, s, c)
		SPARK:
			var ln := s * (1.0 + it.stretch * it.vel.length() / 60.0)
			L.draw_set_transform(p, it.vel.angle(), Vector2.ONE)
			L.draw_texture_rect(glow_tex(), Rect2(-ln, -s * 0.6, ln * 2.0, s * 1.2), false, c)
			L.draw_texture_rect(glow_tex(), Rect2(-ln * 0.55, -s * 0.25, ln * 1.1, s * 0.5), false, Color(1, 1, 1, c.a))
			L.draw_set_transform_matrix(Transform2D.IDENTITY)
		SHARD:
			var a := it.rot
			var pts := PackedVector2Array([p + Vector2.from_angle(a) * s, p + Vector2.from_angle(a + 2.3) * s * 0.55, p + Vector2.from_angle(a + 3.9) * s * 0.8])
			L.draw_colored_polygon(pts, c)
			pts.append(pts[0])
			L.draw_polyline(pts, Color(c.darkened(0.55), c.a), 1.5, true)
		FLAKE:
			_soft(L, p, s * 1.3, Color(c, c.a * 0.35))
			for k in 6:
				var d := Vector2.from_angle(it.rot + k * TAU / 6.0)
				L.draw_line(p, p + d * s, c, 1.6, true)
				var m := p + d * s * 0.55
				L.draw_line(m, m + d.rotated(0.7) * s * 0.3, c, 1.2, true)
				L.draw_line(m, m + d.rotated(-0.7) * s * 0.3, c, 1.2, true)
		CRYSTAL:
			var d := Vector2.from_angle(it.rot)
			var n := d.orthogonal()
			var back := p - d * s * 0.12
			var tip := p + d * s
			var mid := p + d * s * 0.38
			var pts := PackedVector2Array([back, mid + n * s * 0.13, tip, mid - n * s * 0.13])
			L.draw_colored_polygon(pts, c)
			L.draw_colored_polygon(PackedVector2Array([back, mid + n * s * 0.13, tip]), Color(c.lightened(0.45), c.a))
			pts.append(pts[0])
			L.draw_polyline(pts, Color(0.95, 1, 1, c.a), 1.5, true)
		BUBBLE:
			L.draw_arc(p, s, 0, TAU, 20, c, 1.6, true)
			L.draw_circle(p + Vector2(-s, -s) * 0.35, s * 0.2, Color(1, 1, 1, c.a))
		CROSS:
			_soft(L, p, s * 1.8, Color(c, c.a * 0.45))
			L.draw_rect(Rect2(p - Vector2(s * 0.2, s * 0.65), Vector2(s * 0.4, s * 1.3)), c)
			L.draw_rect(Rect2(p - Vector2(s * 0.65, s * 0.2), Vector2(s * 1.3, s * 0.4)), c)
		STAR:
			_soft(L, p, s * 1.6, Color(c, c.a * 0.5))
			var pts := PackedVector2Array()
			for k in 8:
				pts.append(p + Vector2.from_angle(it.rot + k * TAU / 8.0) * (s if k % 2 == 0 else s * 0.22))
			L.draw_colored_polygon(pts, c)
		RUNE:
			_soft(L, p, s * 1.8, Color(c, c.a * 0.35))
			var g: Array = glyphs()[int(it.phase) % glyphs().size()]
			for stroke in g:
				var pts := PackedVector2Array()
				for q: Vector2 in stroke:
					pts.append(p + q.rotated(it.rot) * s)
				L.draw_polyline(pts, c, 2.0, true)
		CHEVRON:
			var pts := PackedVector2Array([p + Vector2(-s, s * 0.45).rotated(it.rot), p + Vector2(0, -s * 0.45).rotated(it.rot), p + Vector2(s, s * 0.45).rotated(it.rot)])
			_soft(L, p, s * 1.4, Color(c, c.a * 0.4))
			L.draw_polyline(pts, c, maxf(2.0, s * 0.28), true)
		THORN:
			var d := Vector2.from_angle(it.rot)
			var n := d.orthogonal() * s * 0.2
			var pts := PackedVector2Array([p + n, p + d * s, p - n])
			L.draw_colored_polygon(pts, c)
			L.draw_line(p, p + d * s, Color(c.lightened(0.5), c.a), 1.5, true)
		DROP:
			var d := it.vel.normalized() if it.vel.length() > 1.0 else Vector2.DOWN
			var n := d.orthogonal() * s * 0.42
			_soft(L, p, s * 1.7, Color(c, c.a * 0.4))
			L.draw_colored_polygon(PackedVector2Array([p + n, p - d * s * 1.5, p - n]), c)
			L.draw_circle(p, s * 0.45, c)


func _draw_ring(L: Control, it: Item) -> void:
	var tt := it.t()
	var e := 1.0 - pow(1.0 - tt, 3.0)
	var r := lerpf(it.r0, it.r1, e)
	var w := lerpf(it.w0, it.w1, tt)
	var al := it.col.a * (1.0 - tt)
	if r <= 0.5 or al <= 0.003:
		return
	L.draw_set_transform(it.pos, 0.0, Vector2(1.0, it.squash))
	L.draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(it.col, al * 0.22), w * 3.0, true)
	L.draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(it.col, al * 0.85), w, true)
	L.draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(1, 1, 1, al * 0.8), maxf(1.0, w * 0.3), true)
	L.draw_set_transform_matrix(Transform2D.IDENTITY)


func _beam_points(it: Item, reach: float) -> PackedVector2Array:
	var d := it.b - it.a
	var ln := d.length()
	var n := d.orthogonal().normalized()
	var steps := maxi(2, int(ln / 22.0))
	var pts := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / steps
		if u > reach:
			pts.append(it.a + d * reach)
			break
		var off := 0.0
		if i > 0 and i < steps:
			off = randf_range(-it.jag, it.jag) + sin(u * PI * 3.0 - it.age * 14.0) * it.wave * sin(u * PI)
		pts.append(it.a + d * u + n * off)
	return pts


func _draw_beam(L: Control, it: Item) -> void:
	var tt := it.t()
	var reach := minf(1.0, tt / 0.22)
	var al := it.col.a * (1.0 if tt < 0.6 else 1.0 - (tt - 0.6) / 0.4)
	var pts := _beam_points(it, reach)
	if pts.size() < 2:
		return
	var w := it.w0 * (1.0 + 0.15 * sin(it.age * 40.0))
	L.draw_polyline(pts, Color(it.col, al * 0.18), w * 4.0, true)
	L.draw_polyline(pts, Color(it.col, al * 0.6), w * 1.8, true)
	L.draw_polyline(pts, Color(it.col.lightened(0.4), al), w, true)
	L.draw_polyline(pts, Color(1, 1, 1, al), maxf(1.0, w * 0.35), true)
	_soft(L, pts[pts.size() - 1], w * 3.5, Color(it.col, al * 0.8))


func _draw_slash(L: Control, it: Item) -> void:
	var tt := it.t()
	var reach := minf(1.0, tt / 0.12)
	var thin := 1.0 if tt < 0.25 else 1.0 - (tt - 0.25) / 0.75
	var d := it.b - it.a
	var n := d.orthogonal().normalized()
	var steps := 18
	for layer in 3:
		var wl: float = it.w0 * thin * [2.4, 1.0, 0.35][layer]
		var c: Color = [Color(it.col, 0.3 * thin), Color(it.col.lightened(0.3), 0.9 * thin), Color(1, 1, 1, thin)][layer]
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in steps + 1:
			var u := float(i) / steps * reach
			var center := it.a + d * u + n * sin(u * PI) * d.length() * 0.12
			var w := maxf(0.4, sin(u / maxf(reach, 0.001) * PI) * wl)
			top.append(center + n * w * 0.5)
			if i > 0 and i < steps:
				bot.append(center - n * w * 0.5)
		bot.reverse()
		var poly := top + bot
		if poly.size() >= 3:
			L.draw_colored_polygon(poly, c)


func _draw_sigil(L: Control, it: Item) -> void:
	var tt := it.t()
	var drawn := 1.0 - pow(1.0 - minf(1.0, tt / 0.3), 3.0)
	var al := it.col.a * (1.0 if tt < 0.7 else 1.0 - (tt - 0.7) / 0.3)
	var r := it.r0 * (1.0 + 0.2 * (1.0 - drawn))
	var ang := it.age * it.spin
	var c := Color(it.col, al)
	L.draw_set_transform(it.pos, 0.0, Vector2(1.0, it.squash))
	_soft(L, Vector2.ZERO, r * 1.1, Color(it.col, al * 0.28))
	L.draw_arc(Vector2.ZERO, r, ang, ang + TAU * drawn, 90, Color(it.col, al * 0.25), 10.0, true)
	L.draw_arc(Vector2.ZERO, r, ang, ang + TAU * drawn, 90, c, 3.0, true)
	L.draw_arc(Vector2.ZERO, r * 0.8, -ang, -ang - TAU * drawn, 80, c, 1.6, true)
	L.draw_arc(Vector2.ZERO, r * 0.3, ang * 2.0, ang * 2.0 + TAU * drawn, 40, c, 1.6, true)
	# the star: every second corner joined, turning the other way
	var n := maxi(3, it.sides)
	var step := 2 if n >= 5 else 1
	for k in n:
		var p1 := Vector2.from_angle(-ang * 0.6 + k * TAU / n) * r * 0.8
		var p2 := Vector2.from_angle(-ang * 0.6 + (k + step) * TAU / n) * r * 0.8
		L.draw_line(p1, p1.lerp(p2, drawn), Color(it.col.lightened(0.3), al * 0.9), 2.0, true)
	# runes around the band between the rings
	var g := glyphs()
	var count := n * 2
	for k in count:
		if float(k) / count > drawn:
			break
		var a2 := ang + k * TAU / count + PI / count
		var center := Vector2.from_angle(a2) * r * 0.9
		for stroke in g[k % g.size()]:
			var pts := PackedVector2Array()
			for q: Vector2 in stroke:
				pts.append(center + q.rotated(a2 + PI / 2.0) * r * 0.055)
			L.draw_polyline(pts, c, 1.5, true)
	L.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_dome(L: Control, it: Item) -> void:
	var tt := it.t()
	var reveal := 1.0 - pow(1.0 - minf(1.0, tt / 0.35), 3.0)
	var al := it.col.a * (1.0 if tt < 0.6 else 1.0 - (tt - 0.6) / 0.4)
	var r := it.r0
	var sq := it.squash
	L.draw_set_transform(it.pos, 0.0, Vector2(1.0, sq))
	_soft(L, Vector2.ZERO, r * 1.05, Color(it.col, al * 0.22 * reveal))
	var h := r / 5.5  # hex size
	var rows := int(r / (h * 1.5)) + 1
	for q in range(-rows * 2, rows * 2 + 1):
		for rr in range(-rows, rows + 1):
			var c := Vector2(h * sqrt(3.0) * (q + rr / 2.0), h * 1.5 * rr)
			var dist := c.length() / r
			if dist > 0.97 or dist > reveal * 1.05:
				continue
			var shimmer := maxf(0.0, sin(it.age * 9.0 - dist * 7.0)) * 0.35
			var a := al * (0.14 + 0.75 * pow(dist, 3.0) + shimmer)
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(c + Vector2.from_angle(PI / 6.0 + k * TAU / 6.0) * h * 0.92)
			L.draw_polyline(pts, Color(it.col.lightened(0.3), a), 1.6, true)
	L.draw_arc(Vector2.ZERO, r * reveal, 0, TAU, 96, Color(it.col, al * 0.3), 16.0, true)
	L.draw_arc(Vector2.ZERO, r * reveal, 0, TAU, 96, Color(it.col.lightened(0.4), al), 3.0, true)
	L.draw_set_transform_matrix(Transform2D.IDENTITY)
