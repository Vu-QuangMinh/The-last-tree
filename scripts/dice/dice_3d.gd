class_name Dice3D
extends SubViewportContainer
## Die on Stage (2026-11-17): the dice in 3D. A transparent 3D layer over the whole stage: the dice are thrown from the
## screen (they start big, right in front of the camera) out onto the stage floor, bounce, tumble and settle, and stay
## there (the fight screen puts an invisible drag handle on each: screen_pos()). A d6 is a cube, a d4 a pyramid, a d10
## a ten-sided kite die; each face is drawn by DiceDieView.draw_die (paint, carving), on a sheet per die.
## The fight decides the roll first: the tumble is a scripted path worked out backwards so the die lands showing it.

const CELL := 128  # (one face on a die's sheet, in px)
const LAND_Y := 774.0  # (where on the screen the first row of dice comes to rest)
const BACK_Y := 722.0  # (a second row: dice added later in the turn, Focus)
const GAP := 108.0  # (between dice on the floor, in screen px)
const DIE_PX := 70.0  # (a landed die's size on the screen)
const FLOOR_SHADOW := Color(0, 0, 0, 0.45)

var _vp: SubViewport
var _cam: Camera3D
var _world: Node3D
var _dice := {}  # rolled index -> {node, mesh, sheet, drawer, mat, shadow, kind, geo, faces, k, land, src}
var _geo := {}  # kind -> {mesh_faces: [{n, u, c, poly}], cols, rows}
var _shadow_tex: Texture2D
var _size := 0.4  # (a die's world size, worked out from DIE_PX)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.size = Vector2i(1920, 1080)
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.05
	_world.add_child(_cam)
	_cam.position = Vector3(0, 6.4, 8.2)  # (looking down a fair bit: the top faces, the ones that count, read well)
	_cam.look_at(Vector3(0, 0.0, -0.6))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	_world.add_child(sun)
	sun.rotation_degrees = Vector3(-58, -28, 0)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	_world.add_child(fill)
	fill.rotation_degrees = Vector3(-30, 8, 0)  # (from behind the camera: the faces turned to you are lit)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.92, 0.82)
	e.ambient_light_energy = 0.55
	env.environment = e
	_world.add_child(env)
	var g := GradientTexture2D.new()  # (a soft round shadow under each die)
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, FLOOR_SHADOW)
	grad.set_color(1, Color(0, 0, 0, 0))
	g.gradient = grad
	_shadow_tex = g
	var at := _floor_point(Vector2(960, LAND_Y))
	_size = DIE_PX * _cam.global_position.distance_to(at) * 2.0 * tan(deg_to_rad(_cam.fov) / 2.0) / 1080.0
	_geo = {"d6": _cube(), "d4": _tetra(), "d10": _d10()}


## Where a point of the screen meets the floor (y = 0).
func _floor_point(p: Vector2) -> Vector3:
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	return o + d * (-o.y / d.y)


func has_die(r: int) -> bool:
	return _dice.has(r)


func count() -> int:
	return _dice.size()


## Where die r is on the screen (its landing spot), for its drag handle.
func screen_pos(r: int) -> Vector2:
	if not _dice.has(r):
		return Vector2(-999, -999)
	return _cam.unproject_position(_dice[r].land)


func clear() -> void:
	for r in _dice:
		if _dice[r].has("tween") and (_dice[r].tween as Tween).is_valid():
			(_dice[r].tween as Tween).kill()
		(_dice[r].node as Node).queue_free()
		(_dice[r].sheet as Node).queue_free()
	_dice.clear()


## Throw these dice (each {r, faces: [{v, paint, carve}], k: the face rolled, src: the fight's `rolled` entry}) from the
## screen onto the floor, in a row at `row_y`. Returns when they have all landed.
func throw(entries: Array, row_y := LAND_Y) -> void:
	var n := entries.size()
	var longest := 0.0
	var spots := []  # (where they come to rest first: scattered over the stage, apart from each other)
	var lanes := 7
	for k in lanes:
		spots.append(SCATTER_X.x + (SCATTER_X.y - SCATTER_X.x) * (k + 0.5) / lanes)
	spots.shuffle()
	for j in n:
		var e: Dictionary = entries[j]
		var x := 960.0 + (j - (n - 1) / 2.0) * GAP
		var home := _floor_point(Vector2(x, row_y))
		var d := _make_die(int(e.r), e.faces, int(e.k), e.src)
		var home_rest := _rest_basis(d, int(e.k), home)
		home.y = _rest_height(d, home_rest)
		var sx: float = float(spots[j % lanes]) + randf_range(-40.0, 40.0)
		var spot := _floor_point(Vector2(sx, randf_range(SCATTER_Y.x, SCATTER_Y.y)))
		var rest := _rest_basis(d, int(e.k), spot)
		spot.y = _rest_height(d, rest)
		d.land = spot
		var t := randf_range(1.05, 1.3)
		_tumble(d, rest, j * 0.09, t, true)
		_go_home(d, home, home_rest)  # (then it slides back to its place in the row)
		d.land = home  # (its place for good: where its drag handle goes)
		longest = maxf(longest, t + j * 0.09 + HOME_WAIT + HOME_TIME)
	Audio.play("wooden_ball_colide", -6.0, 1.3)
	await get_tree().create_timer(longest + 0.05).timeout


const SCATTER_X := Vector2(360.0, 1560.0)  # (the stretch of the stage the dice scatter over, screen px)
const SCATTER_Y := Vector2(610.0, 790.0)
const HOME_WAIT := 0.3  # (it lies where it stopped this long...)
const HOME_TIME := 0.38  # (... then zooms back to its place in the row)


## After its tumble: the die zooms from where it stopped back to `home`, with a little hop, still showing its face.
func _go_home(d: Dictionary, home: Vector3, home_rest: Basis) -> void:
	var tw: Tween = d.tween
	var node: Node3D = d.node
	var sh: MeshInstance3D = d.shadow
	tw.tween_interval(HOME_WAIT)
	var from := [Vector3.ZERO, Quaternion.IDENTITY]
	tw.tween_callback(func():
		from[0] = node.position
		from[1] = node.basis.get_rotation_quaternion())
	var to_q := home_rest.get_rotation_quaternion()
	var step := func(p: float) -> void:
		var e := ease(p, -2.0)  # (in and out)
		var a: Vector3 = from[0]
		node.position = a.lerp(home, e) + Vector3(0, sin(p * PI) * 0.6 * _size, 0)
		node.basis = Basis((from[1] as Quaternion).slerp(to_q, e))
		sh.position = Vector3(node.position.x, 0.003, node.position.z)
	tw.tween_method(step, 0.0, 1.0, HOME_TIME)
	tw.tween_callback(func():
		node.position = home
		node.basis = home_rest)


## Die r was rolled again (a purple face, the Reroll move): it hops up where it lies and lands on its new face.
func hop(r: int, faces: Array, k: int, src: Dictionary) -> void:
	if not _dice.has(r):
		return
	var d: Dictionary = _dice[r]
	d.faces = faces.duplicate(true)
	d.k = k
	d.src = src
	_paint(d)
	var rest := _rest_basis(d, k, d.land)
	d.land.y = _rest_height(d, rest)
	_tumble(d, rest, 0.0, 0.62, false)


## Keep die r showing what the fight says: hidden when used, its top face changed by Hype Up / Calm Down / Stack,
## all "?" while face down (Confuse), icy while frozen. Returns false when it needs a hop() (it was rolled again).
func sync(r: int, src: Dictionary, used: bool) -> bool:
	if not _dice.has(r):
		return true
	var d: Dictionary = _dice[r]
	if not is_same(d.src, src):
		return false
	(d.node as Node3D).visible = not used
	(d.shadow as Node3D).visible = not used
	var want := [int(src.value), bool(src.hidden), bool(src.frozen)]
	if want != d.get("shown", []):
		d.shown = want
		_paint(d)
	return true


# --- building a die --------------------------------------------------------------------------------------------------

func _kind(faces: Array) -> String:
	match faces.size():
		4:
			return "d4"
		10:
			return "d10"
	return "d6"


func _make_die(r: int, faces: Array, k: int, src: Dictionary) -> Dictionary:
	if _dice.has(r):
		if _dice[r].has("tween") and (_dice[r].tween as Tween).is_valid():
			(_dice[r].tween as Tween).kill()
		(_dice[r].node as Node).queue_free()
		(_dice[r].sheet as Node).queue_free()
	var kind := _kind(faces)
	var geo: Dictionary = _geo[kind]
	var sheet := SubViewport.new()
	sheet.size = Vector2i(int(geo.cols) * CELL, int(geo.rows) * CELL)
	sheet.transparent_bg = false
	sheet.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawer := Control.new()
	drawer.size = Vector2(sheet.size)
	sheet.add_child(drawer)
	_vp.add_child(sheet)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = sheet.get_texture()
	mat.roughness = 0.75
	mat.metallic_specular = 0.15  # (no shine washing the number out)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(geo)
	mi.material_override = mat
	mi.scale = Vector3.ONE * _size  # (on the mesh: the node's turn is set whole while it tumbles)
	var node := Node3D.new()
	node.add_child(mi)
	_world.add_child(node)
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 1.7) * _size
	sh.mesh = pm
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = _shadow_tex
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.material_override = smat
	_world.add_child(sh)
	var d := {"node": node, "mesh": mi, "sheet": sheet, "drawer": drawer, "mat": mat, "shadow": sh, "kind": kind, "geo": geo,
		"faces": faces.duplicate(true), "k": k, "land": Vector3.ZERO, "src": src, "shown": [int(src.value), bool(src.hidden), bool(src.frozen)]}
	drawer.draw.connect(func(): _draw_sheet(d))
	_dice[r] = d
	_paint(d)
	return d


## Redraws the die's sheet: its faces, with the rolled face showing the die's value now (an adjustment this turn).
func _paint(d: Dictionary) -> void:
	var src: Dictionary = d.src
	(d.mat as StandardMaterial3D).albedo_color = Color(0.72, 0.88, 1.0) if bool(src.get("frozen", false)) else Color.WHITE
	(d.drawer as Control).queue_redraw()
	(d.sheet as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_sheet(d: Dictionary) -> void:
	var c: Control = d.drawer
	var geo: Dictionary = d.geo
	var src: Dictionary = d.src
	var face_down := bool(src.get("hidden", false))
	var font := ThemeDB.fallback_font
	for k in (d.faces as Array).size():
		var f: Dictionary = d.faces[k]
		var v := int(f.get("v", 1))
		if k == int(d.k):
			v = int(src.get("value", v))
		var paint: String = f.get("paint") if f.get("paint") is String else ""
		var carve: String = f.get("carve") if f.get("carve") is String else ""
		var rect := Rect2(Vector2((k % int(geo.cols)) * CELL, (k / int(geo.cols)) * CELL), Vector2(CELL, CELL))
		var body := Color(0.97, 0.94, 0.86)
		if paint != "" and DiceFace.PAINTS.has(paint):
			body = DiceFace.PAINTS[paint].col
		if face_down:
			body = Color(0.25, 0.2, 0.3)
		c.draw_rect(rect, body)
		var ink := Color(0.15, 0.08, 0.05) if body.get_luminance() > 0.45 else Color(0.97, 0.94, 0.86)
		if face_down:
			c.draw_string(font, rect.position + Vector2(0, CELL * 0.66), "?", HORIZONTAL_ALIGNMENT_CENTER, CELL, 64, Color(0.95, 0.9, 1.0))
		elif String(d.kind) == "d6":
			DiceDieView.draw_die(c, rect.grow(-1.0), v, false, paint, carve)
		else:  # (a d4 / d10 face: its number, a line under a 6 or a 9, the carving under it)
			var fs := 50 if String(d.kind) == "d10" else 44
			var at := rect.position + Vector2(0, CELL * 0.56)
			c.draw_string(font, at, str(v), HORIZONTAL_ALIGNMENT_CENTER, CELL, fs, ink)
			if v == 6 or v == 9:
				c.draw_line(rect.position + Vector2(CELL * 0.4, CELL * 0.62), rect.position + Vector2(CELL * 0.6, CELL * 0.62), ink, 3.0)
			if carve != "" and DiceFace.CARVES.has(carve):
				var sym: String = DiceFace.CARVES[carve].sym
				c.draw_string(font, rect.position + Vector2(0, CELL * 0.8), sym, HORIZONTAL_ALIGNMENT_CENTER, CELL, 22, ink)


func _mesh(geo: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := int(geo.cols)
	var rows := int(geo.rows)
	for k in (geo.faces as Array).size():
		var f: Dictionary = geo.faces[k]
		var n: Vector3 = f.n
		var u: Vector3 = f.u
		var rgt := u.cross(n)
		var c: Vector3 = f.c
		var poly: Array = f.poly
		var span := 0.0
		for p: Vector3 in poly:
			span = maxf(span, maxf(absf((p - c).dot(rgt)), absf((p - c).dot(u))))
		var uvs := []
		for p: Vector3 in poly:
			var x := 0.5 + (p - c).dot(rgt) / (2.0 * span)
			var y := 0.5 - (p - c).dot(u) / (2.0 * span)  # (a viewport's texture comes out upside down here: the sheet's top is the face's "up")
			uvs.append(Vector2((k % cols + x) / cols, (k / cols + y) / rows))
		for j in range(1, poly.size() - 1):
			for idx in [0, j, j + 1]:
				st.set_normal(n)
				st.set_uv(uvs[idx])
				st.add_vertex(poly[idx])
	return st.commit()


## A face of a solid: its outward normal, its "up" (the top of the number on it), its centre, its corners.
func _face(poly: Array, up_to: Vector3) -> Dictionary:
	var c := Vector3.ZERO
	for p: Vector3 in poly:
		c += p
	c /= poly.size()
	var n: Vector3 = (poly[1] - poly[0]).cross(poly[2] - poly[0]).normalized()
	if n.dot(c) < 0.0:
		n = -n
	var u := (up_to - c)
	u = (u - n * n.dot(u)).normalized()
	return {"n": n, "u": u, "c": c, "poly": poly}


func _cube() -> Dictionary:
	var a := 0.5
	# (opposite faces add up to 7 on a plain d6: faces 0/5, 1/4, 2/3 opposite)
	var dirs := [[Vector3.UP, Vector3.FORWARD], [Vector3.RIGHT, Vector3.UP], [Vector3.BACK, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.DOWN, Vector3.BACK]]
	var faces := []
	for du in dirs:
		var n: Vector3 = du[0]
		var u: Vector3 = du[1]
		var rgt := u.cross(n)
		var c := n * a
		faces.append({"n": n, "u": u, "c": c, "poly": [c + (-rgt - u) * a, c + (rgt - u) * a, c + (rgt + u) * a, c + (-rgt + u) * a]})
	return {"faces": faces, "cols": 3, "rows": 2}


func _tetra() -> Dictionary:
	var s := 0.5
	var v := [Vector3(1, 1, 1) * s, Vector3(1, -1, -1) * s, Vector3(-1, 1, -1) * s, Vector3(-1, -1, 1) * s]
	var faces := []
	for k in 4:  # (face k: the three corners but corner k; its number points to corner k + 1, the top when it rests on face k + 1)
		var poly := []
		for j in 4:
			if j != k:
				poly.append(v[j])
		faces.append(_face(poly, v[(k + 1) % 4]))
	return {"faces": faces, "cols": 2, "rows": 2, "corners": v}


func _d10() -> Dictionary:
	var h := 0.8
	var rad := 0.78
	var lo := 0.001
	var hi := h - 0.001
	var low_sign := signf(_kite_bend(h, rad, lo))
	for i in 50:  # (the ring's height that makes each kite flat)
		var z := (lo + hi) / 2.0
		if signf(_kite_bend(h, rad, z)) == low_sign:
			lo = z
		else:
			hi = z
	var zr := (lo + hi) / 2.0
	var ring := []
	for i in 10:
		var ang := i * PI / 5.0
		ring.append(Vector3(rad * cos(ang), zr if i % 2 == 0 else -zr, rad * sin(ang)))
	var t := Vector3(0, h, 0)
	var btm := Vector3(0, -h, 0)
	var faces := []
	for j in 5:
		faces.append(_face([t, ring[2 * j], ring[(2 * j + 1) % 10], ring[(2 * j + 2) % 10]], t))
		faces.append(_face([btm, ring[(2 * j + 1) % 10], ring[(2 * j + 2) % 10], ring[(2 * j + 3) % 10]], btm))
	return {"faces": faces, "cols": 4, "rows": 3}


## How far from flat a kite of the d10 is, with its ring at height z (0: flat).
func _kite_bend(h: float, rad: float, z: float) -> float:
	var top := Vector3(0, h, 0)
	var a := Vector3(rad, z, 0)
	var b := Vector3(rad * cos(PI / 5.0), -z, rad * sin(PI / 5.0))
	var c := Vector3(rad * cos(2.0 * PI / 5.0), z, rad * sin(2.0 * PI / 5.0))
	return (a - top).cross(b - top).dot(c - top)


## The die's turn at rest (the user, 2026-11-17): face k looks straight at the camera from where the die lies at `at`,
## flat to you, its number upright; every die the same, no twist.
func _rest_basis(d: Dictionary, k: int, at: Vector3) -> Basis:
	var geo: Dictionary = d.geo
	var f: Dictionary = geo.faces[k]
	var to_cam := (_cam.global_position - at).normalized()
	var cam_up := _cam.global_transform.basis.y
	return _frame(to_cam, cam_up) * _frame(f.n, f.u).inverse()


## How high its centre stands so that its lowest corner just touches the floor, turned like this.
func _rest_height(d: Dictionary, rest: Basis) -> float:
	var low := 0.0
	for f in (d.geo.faces as Array):
		for p: Vector3 in f.poly:
			low = minf(low, (rest * p).y)
	return -low * _size


func _frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * x.dot(b)).normalized()
	return Basis(x, y, x.cross(y))


# --- the throw -------------------------------------------------------------------------------------------------------

## The die flies (from the screen when `from_screen`, else up from where it lies), hits the floor, bounces twice and
## rolls to a stop on its rest turn. Its spin runs down to nothing exactly as it stops.
func _tumble(d: Dictionary, rest: Basis, delay: float, dur: float, from_screen: bool) -> void:
	var node: Node3D = d.node
	var sh: MeshInstance3D = d.shadow
	var land: Vector3 = d.land
	var start: Vector3
	if from_screen:
		var fwd := -_cam.global_transform.basis.z
		start = _cam.global_position + fwd * 1.5 + Vector3(randf_range(-0.35, 0.35), -0.55, 0)
	else:
		start = land
	var axis := Vector3(randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)).normalized()
	if from_screen:  # (mostly rolling forward, away from you)
		axis = (Vector3(1, 0, 0) + axis * 0.6).normalized() * (-1.0 if randf() < 0.5 else 1.0)
	var spin := randf_range(3.5, 5.0) * TAU if from_screen else randf_range(1.5, 2.5) * TAU
	node.position = start
	node.basis = Basis(axis, spin) * rest
	node.visible = delay <= 0.0
	sh.visible = node.visible
	sh.position = Vector3(start.x, 0.003, start.z)
	if d.has("tween") and (d.tween as Tween).is_valid():
		(d.tween as Tween).kill()
	var tw := create_tween()
	d.tween = tw
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func():
			node.visible = true
			sh.visible = true)
	var bumps := [0.48, 0.72, 0.86]  # (the moments it hits the floor, as parts of the throw)
	var clacked := [false, false, false]
	var step := func(p: float) -> void:
		node.position = _path(start, land, p, from_screen)
		node.basis = Basis(axis, spin * pow(1.0 - p, 1.7)) * rest
		sh.position = Vector3(node.position.x, 0.003, node.position.z)
		var up := clampf((node.position.y - land.y) / 2.0, 0.0, 1.0)
		sh.scale = Vector3.ONE * (1.0 + up)
		(sh.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1.0 - up * 0.8)
		for b in 3:
			if not clacked[b] and p >= bumps[b] and (from_screen or b > 0):
				clacked[b] = true
				Audio.play("wooden_ball_colide", -10.0 - b * 4.0, randf_range(1.5, 1.9))
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(func():
		node.position = land
		node.basis = rest)


## Where the die is at p (0..1) of its throw: a falling arc to the first hit, two smaller bounces, then a short roll.
func _path(start: Vector3, land: Vector3, p: float, from_screen: bool) -> Vector3:
	var flat := Vector3(land.x, 0, land.z) - Vector3(start.x, 0, start.z)
	var base := Vector3(start.x, 0, start.z)
	var rest_h := land.y
	if not from_screen:  # (a hop where it lies)
		var q := (p - 0.72) / 0.28
		var s0 := p / 0.72
		var hgt := 1.6 * _size * 4.0 * s0 * (1.0 - s0) if p < 0.72 else 0.35 * _size * 4.0 * q * (1.0 - q)
		return Vector3(land.x, rest_h + hgt, land.z)
	var hits: Array[float] = [0.48, 0.72, 0.86, 1.0]
	var along: Array[float] = [0.78, 0.93, 0.985, 1.0]
	if p < hits[0]:
		var s := p / hits[0]
		var h := lerpf(start.y, rest_h, s * s) + 0.7 * s * (1.0 - s)  # (it falls faster as it goes)
		return base + flat * (along[0] * s) + Vector3(0, h, 0)
	for b in 3:
		if p < hits[b + 1]:
			var s: float = (p - hits[b]) / (hits[b + 1] - hits[b])
			var heights := [0.9, 0.3, 0.0]
			var h: float = rest_h + float(heights[b]) * _size * 4.0 * s * (1.0 - s)
			return base + flat * lerpf(along[b], along[b + 1], s) + Vector3(0, h, 0)
	return land
