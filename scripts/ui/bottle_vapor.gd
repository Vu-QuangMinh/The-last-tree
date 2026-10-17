class_name BottleVapor
extends Control
## A bottle that has been drunk: its picture grows and shines, then it vaporises: a puff of smoke blooms over it, the bottle fades inside the smoke, and the smoke rolls
## upwards, swelling and thinning, until it is gone. It is a picture of its own, so it plays on whatever happens to the real chip meanwhile.
## The smoke is made of soft, lumpy puffs (one little picture, drawn many times, turned and scaled), not of circles.

const GROW := 0.22
const VAPOR := 0.6
const END := 2.1

static var _puff: Texture2D

var _tex: Texture2D
var _px := 44.0
var _t := 0.0
var _puffs: Array = []  # {p, v, born, life, r0, r1, rot, spin, tone, sway, ph}


## One soft, slightly uneven blob of smoke (white, its alpha is the shape).
static func _puff_texture() -> Texture2D:
	if _puff == null:
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var dx := (x + 0.5) / n * 2.0 - 1.0
				var dy := (y + 0.5) / n * 2.0 - 1.0
				var ang := atan2(dy, dx)
				var edge := 0.78 + 0.1 * sin(ang * 3.0 + 0.7) + 0.07 * sin(ang * 5.0 - 1.3) + 0.04 * sin(ang * 8.0 + 2.1)  # (a lumpy outline)
				var d := sqrt(dx * dx + dy * dy) / edge
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)  # smoothstep: soft to the edge
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_puff = ImageTexture.create_from_image(img)
	return _puff


## `name`: the picture (UiSkin name); `centre`: where it stands, in `parent`'s coordinates; `px`: the size of its square.
static func play(parent: Node, name: String, centre: Vector2, px: float) -> void:
	var t := UiSkin.tex(name)
	if t == null:
		return
	var v := BottleVapor.new()
	v._tex = t
	v._px = px
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size = Vector2(px, px) * 7.0
	v.position = centre - v.size / 2.0
	v.z_index = 120
	parent.add_child(v)
	# a burst that hides the bottle: big puffs that swell fast, then a long stream of smaller ones that roll up and away
	for k in 7:
		v._puffs.append(_make(px, GROW + randf() * 0.12, randf_range(0.9, 1.3), randf_range(0.5, 0.75), randf_range(1.2, 1.7), Vector2(randf_range(-0.28, 0.28), randf_range(-0.2, 0.3)) * px, Vector2(randf_range(-14.0, 14.0), randf_range(-22.0, -8.0))))
	for k in 30:
		v._puffs.append(_make(px, GROW + 0.1 + randf() * 0.7, randf_range(0.9, 1.5), randf_range(0.4, 0.7), randf_range(1.0, 1.7), Vector2(randf_range(-0.5, 0.5), randf_range(-0.3, 0.35)) * px, Vector2(randf_range(-18.0, 18.0), randf_range(-70.0, -26.0))))


static func _make(px: float, born: float, life: float, r0: float, r1: float, at: Vector2, vel: Vector2) -> Dictionary:
	return {"p": at, "v": vel, "born": born, "life": life, "r0": r0 * px, "r1": r1 * px, "rot": randf() * TAU, "spin": randf_range(-1.2, 1.2),
		"tone": randf_range(0.0, 1.0), "sway": randf_range(6.0, 16.0), "ph": randf() * TAU}


func _process(d: float) -> void:
	_t += d
	if _t > END:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var grow := clampf(_t / GROW, 0.0, 1.0)
	var k := 1.0 + 0.45 * sin(grow * PI / 2.0)  # (it grows to 1.45 x)
	var shine := grow if _t < GROW else maxf(0.0, 1.0 - (_t - GROW) / (VAPOR * 0.7))
	var alpha := 1.0 if _t < GROW + 0.1 else clampf(1.0 - (_t - GROW - 0.1) / (VAPOR * 0.85), 0.0, 1.0)
	if shine > 0.01:  # (a warm light behind it)
		for j in 4:
			draw_circle(c, _px * 0.62 * k * (1.0 + 0.3 * j), Color(1.0, 0.85, 0.4, 0.15 * shine * (1.0 - 0.2 * j)))
	var sc := minf(_px * k / _tex.get_width(), _px * k / _tex.get_height())
	var sz := Vector2(_tex.get_width(), _tex.get_height()) * sc
	draw_texture_rect(_tex, Rect2(c - sz / 2.0, sz), false, Color(1.0 + 0.6 * shine, 1.0 + 0.5 * shine, 1.0 + 0.2 * shine, alpha))
	var puff := _puff_texture()
	for pf in _puffs:
		var age: float = _t - float(pf.born)
		if age < 0.0 or age > float(pf.life):
			continue
		var u: float = age / float(pf.life)
		var a := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.45, 1.0, u)) * 0.72  # (it comes up fast and thins out slowly)
		var at: Vector2 = c + pf.p + pf.v * age + Vector2(sin(_t * 2.2 + float(pf.ph)) * float(pf.sway) * u, 0.0)
		var r: float = lerpf(float(pf.r0), float(pf.r1), 1.0 - pow(1.0 - u, 2.0))  # (it swells fast at first)
		var tone: float = float(pf.tone)
		var col := Color(0.97 - 0.14 * tone, 0.95 - 0.14 * tone, 0.93 - 0.12 * tone, a)  # (warm white to soft grey: some depth)
		draw_set_transform(at, float(pf.rot) + float(pf.spin) * age, Vector2.ONE)
		draw_texture_rect(puff, Rect2(-Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
