class_name DustCloud
extends Control
## "Turning to dust" (the Thanos-snap effect, as games usually build it): a picture of the thing is shown with a
## dissolve shader whose ragged, glowing front sweeps across it; right behind the front, the picture's own pixels break
## off as tiny specks of their real colour, which a wind carries away (up and to the right), swirling a little as they
## fade. Here it eats a charge's hourglass bubble when the charge goes off.
##
## DustCloud.crumble(parent, image, at, scale, duration) does it all: `image` is a picture of the thing (with alpha),
## `at` the screen position of its top-left corner. It frees itself when the last speck is gone.

const WIND := Vector2(150.0, -70.0)  # px/s: where the dust blows
var _img: Image
var _scale := 1.0
var _dur := 0.75
var _t := 0.0
var _mat: ShaderMaterial
var _pic: TextureRect
var _cells := []  # [{p: Vector2 (in the picture), c: Color, u: float (0 left .. 1 right, plus jitter)}]: specks not yet shed
var _specks := []  # flying: {p, v, c, life, age, s, ph}


static func crumble(parent: Node, image: Image, at: Vector2, p_scale := 1.0, duration := 0.75) -> DustCloud:
	var d := DustCloud.new()
	d._img = image
	d._scale = p_scale
	d._dur = duration
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.position = at
	parent.add_child(d)
	d._setup()
	return d


func _setup() -> void:
	z_index = 75
	var tex := ImageTexture.create_from_image(_img)
	_pic = TextureRect.new()
	_pic.texture = tex
	_pic.size = Vector2(_img.get_size()) * _scale
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/card/power_dissolve.gdshader")
	_mat.set_shader_parameter("from", Vector2(-1, 0))  # (it goes from the left: the wind blows the dust right)
	_mat.set_shader_parameter("edge_color", Color(1.0, 0.86, 0.55))
	_mat.set_shader_parameter("raggedness", 0.45)
	_mat.set_shader_parameter("edge_width", 0.05)
	_pic.material = _mat
	add_child(_pic)
	# every visible pixel (every 2nd, in each direction) becomes a speck once the front reaches it
	var w := _img.get_width()
	var h := _img.get_height()
	var rng := RandomNumberGenerator.new()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := _img.get_pixel(x, y)
			if c.a > 0.3:
				# (the jitter roughly follows the shader's noisy front, so specks leave where the picture is eaten)
				_cells.append({"p": Vector2(x, y), "c": c, "u": float(x) / w * 0.6 + rng.randf() * 0.45})
	_cells.sort_custom(func(a, b): return a.u < b.u)


func _process(d: float) -> void:
	_t += d
	var prog := clampf(_t / _dur, 0.0, 1.0)
	_mat.set_shader_parameter("progress", prog * 1.12)
	# shed the specks the front has passed
	while not _cells.is_empty() and _cells[0].u <= prog * 1.05:
		var cell: Dictionary = _cells.pop_front()
		var v := WIND * randf_range(0.5, 1.3) + Vector2(randf_range(-30, 30), randf_range(-40, 20))
		_specks.append({"p": cell.p * _scale, "v": v, "c": cell.c.lerp(Color(1.0, 0.88, 0.6), 0.25), "life": randf_range(0.45, 0.95),
			"age": 0.0, "s": randf_range(1.6, 3.2) * _scale, "ph": randf() * TAU})
	for sp in _specks:
		sp.age += d
		# the wind picks up, and each speck swirls on its own
		sp.v += Vector2(40.0, -25.0) * d
		var swirl := Vector2(cos(sp.ph + sp.age * 7.0), sin(sp.ph + sp.age * 5.0)) * 35.0
		sp.p += (sp.v + swirl) * d
	_specks = _specks.filter(func(sp): return sp.age < sp.life)
	queue_redraw()
	if prog >= 1.0:
		_pic.visible = false
		if _specks.is_empty() and _cells.is_empty():
			queue_free()


func _draw() -> void:
	for sp in _specks:
		var k: float = 1.0 - sp.age / sp.life
		var c: Color = sp.c
		c.a *= k
		var s: float = sp.s * (0.5 + 0.5 * k)
		draw_rect(Rect2(sp.p - Vector2(s, s) / 2.0, Vector2(s, s)), c)
