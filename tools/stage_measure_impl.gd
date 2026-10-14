extends RefCounted

const SCREEN := Rect2(0, 0, 1920, 1080)


## Sutherland-Hodgman: a polygon clipped to the screen rectangle.
func _clip(poly: Array) -> Array:
	var out := poly
	for edge in 4:
		var inp := out
		out = []
		if inp.is_empty():
			break
		var prev: Vector2 = inp[inp.size() - 1]
		for cur in inp:
			var a := _inside(cur, edge)
			var b := _inside(prev, edge)
			if a != b:
				out.append(_cut(prev, cur, edge))
			if a:
				out.append(cur)
			prev = cur
	return out


func _inside(p: Vector2, edge: int) -> bool:
	match edge:
		0: return p.x >= SCREEN.position.x
		1: return p.x <= SCREEN.end.x
		2: return p.y >= SCREEN.position.y
	return p.y <= SCREEN.end.y


func _cut(a: Vector2, b: Vector2, edge: int) -> Vector2:
	var t := 0.0
	match edge:
		0: t = (SCREEN.position.x - a.x) / (b.x - a.x)
		1: t = (SCREEN.end.x - a.x) / (b.x - a.x)
		2: t = (SCREEN.position.y - a.y) / (b.y - a.y)
		_: t = (SCREEN.end.y - a.y) / (b.y - a.y)
	return a.lerp(b, t)


## Screen point -> the picture's own (u, v) in 0..1 (the inverse of the stage's homography).
func _uv(h: Array, p: Vector2) -> Vector2:
	var a1: float = h[0] - p.x * h[6]
	var b1: float = h[1] - p.x * h[7]
	var c1: float = p.x - h[2]
	var a2: float = h[3] - p.y * h[6]
	var b2: float = h[4] - p.y * h[7]
	var c2: float = p.y - h[5]
	var det := a1 * b2 - a2 * b1
	return Vector2((c1 * b2 - c2 * b1) / det, (a1 * c2 - a2 * c1) / det)


## The polygon without what is above y.
func _clip_y(poly: Array, y: float) -> Array:
	var out: Array = []
	var prev: Vector2 = poly[poly.size() - 1]
	for cur in poly:
		var a: bool = cur.y >= y
		var b: bool = prev.y >= y
		if a != b:
			out.append(prev.lerp(cur, (y - prev.y) / (cur.y - prev.y)))
		if a:
			out.append(cur)
		prev = cur
	return out


## Prints how big a visible polygon is on screen and how much of the file it shows, measured along its top and bottom rows.
func _report(h: Array, vis: Array, tw: float, th: float, what: String) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in vis:
		lo = lo.min(p)
		hi = hi.max(p)
	var rows := [lo.y + 0.5, hi.y - 0.5]
	var info: Array = []
	for y in rows:
		var xs: Array = []
		for i in vis.size():
			var a: Vector2 = vis[i]
			var b: Vector2 = vis[(i + 1) % vis.size()]
			if (a.y - y) * (b.y - y) <= 0.0 and absf(a.y - b.y) > 0.001:
				xs.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
		xs.sort()
		var x0: float = xs[0]
		var x1: float = xs[xs.size() - 1]
		var u0 := _uv(h, Vector2(x0, y))
		var u1 := _uv(h, Vector2(x1, y))
		info.append([x1 - x0, (u1.x - u0.x) * tw, u0, u1])
	var top_uv: Vector2 = info[0][2]
	var bot_uv: Vector2 = info[1][2]
	var v_top := (top_uv.y) * th
	var v_bot := (bot_uv.y) * th
	var native_h := absf(v_bot - v_top)
	print("   [%s]" % what)
	print("     on screen: %.0f px tall (y %.0f..%.0f), %.0f px wide at its top row, %.0f px wide at its bottom row" % [hi.y - lo.y, lo.y, hi.y, info[0][0], info[1][0]])
	print("     the part of the file that shows: %.0f px tall (rows %.0f..%.0f), %.0f px wide along the top row, %.0f px wide along the bottom row" % [native_h, minf(v_top, v_bot), maxf(v_top, v_bot), info[0][1], info[1][1]])
	print("     screen px per file px: across %.2f (top row), %.2f (bottom row); down %.2f   (1 = exact, above 1 = enlarged, below 1 = shrunk)" % [info[0][0] / maxf(1.0, info[0][1]), info[1][0] / maxf(1.0, info[1][1]), (hi.y - lo.y) / maxf(1.0, native_h)])


func _row_width(poly: Array, y: float) -> float:
	var xs: Array = []
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if (a.y - y) * (b.y - y) <= 0.0 and absf(a.y - b.y) > 0.001:
			xs.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
	if xs.size() < 2:
		return 0.0
	xs.sort()
	return xs[xs.size() - 1] - xs[0]


func run(t: SceneTree) -> void:
	var act := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	var save = t.root.get_node("SaveManager")
	save.use_test_file("user://measure_save.json")
	save.data.settings["theme"] = "puppet"
	var st := PuppetStage.new(act)
	t.root.add_child(st)
	await t.process_frame
	print("ACT %d  (points: user://puppet_stage_verts_act%d.json if it exists, else the defaults; screen 1920 x 1080, scene lowered %d px)" % [act, act, int(PuppetStage.SCENE_DY)])
	for k in st.verts:
		print("   %-11s %s" % [k, st.verts[k]])
	print("")
	for qn in PuppetStage.QUADS:
		var q: Object = null
		for c in st._quads:
			if c.names == PuppetStage.QUADS[qn]:
				q = c
		var tex: Texture2D = q.tex
		var corners: Array = []
		for n in PuppetStage.QUADS[qn]:
			var v: Vector2 = st.verts[n]
			corners.append(Vector2(v.x, v.y + (0.0 if String(n).begins_with("low_") else PuppetStage.SCENE_DY)))
		q.corners = corners
		q.x_scale = 1.0
		var h: Array = q._homography()
		var vis := _clip(corners)
		print("%s   file %d x %d" % [qn, tex.get_width(), tex.get_height()])
		if vis.size() < 3:
			print("   NOT on screen at all")
			print("")
			continue
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var uv_lo := Vector2(1e9, 1e9)
		var uv_hi := Vector2(-1e9, -1e9)
		for p in vis:
			lo = lo.min(p)
			hi = hi.max(p)
			var uv := _uv(h, p)
			uv_lo = uv_lo.min(uv)
			uv_hi = uv_hi.max(uv)
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		_report(h, vis, tw, th, "everything on screen")
		var under := _clip_y(vis, 146.0)  # (the ceiling's valance covers the top 146 px)
		if under.size() >= 3 and lo.y < 146.0:
			_report(h, under, tw, th, "only what is below the ceiling (y >= 146)")
		print("")
	# the ceiling (not tilted, over the top of the screen)
	var ce: Texture2D = st._ceiling.texture
	print("ceiling_overlay   file %d x %d   shown at %.0f x %.0f (x%.2f across, x%.2f down)" % [ce.get_width(), ce.get_height(), st._ceiling.size.x, st._ceiling.size.y, st._ceiling.size.x / ce.get_width(), st._ceiling.size.y / ce.get_height()])
	print("")
	# scenery: the rule gives each kind its height (the picture is scaled to it); measured over 60 random layouts
	var stats := {}
	for seed in range(1, 61):
		var s2 := PuppetStage.new(act)
		t.root.add_child(s2)
		s2.add_default_props(seed)
		for sp_d in s2._sprites:
			var sp: Sprite2D = sp_d.node
			if sp.texture == null:
				continue
			var f := String(sp.texture.resource_path).get_file()
			var sh: float = sp.texture.get_height() * sp.scale.y
			var e: Array = stats.get(f, [sp.texture.get_width(), sp.texture.get_height(), 1e9, 0.0, 0])
			e[2] = minf(e[2], sh)
			e[3] = maxf(e[3], sh)
			e[4] += 1
			stats[f] = e
		s2.queue_free()
	var sg := PuppetStage.new(act)
	t.root.add_child(sg)
	var sign_sp := sg.add_hanging_sign(300.0, 250.0)
	stats["hanging_sign.png"] = [sign_sp.texture.get_width(), sign_sp.texture.get_height(), 250.0, 250.0, 1]
	var names := stats.keys()
	names.sort()
	for f in names:
		var e: Array = stats[f]
		var w: float = e[0]
		var hh: float = e[1]
		print("%-16s file %4d x %4d   shown %.0f..%.0f px tall (%.0f..%.0f wide)   screen px per file px %.2f..%.2f" % [f, w, hh, e[2], e[3], e[2] * w / hh, e[3] * w / hh, e[2] / hh, e[3] / hh])
	t.quit()
