class_name ScaledBox
extends StyleBox
## A nine-patch for the BIG pictures of NewUI Ver2 (2000+ px, never shrunk on disk). Given several pictures of different proportions (a tall, a square, a wide and a banner panel) it
## draws the one whose proportions are nearest to the box, scaled evenly to fit it: the corners (a fixed share of the picture, `frac` of its short side) keep their shape and only the
## edges and the middle stretch, so a picture is never pulled out of proportion by much. It has the `modulate_color` of a StyleBoxTexture.

var textures: Array = []
var frac := 0.14
var modulate_color := Color.WHITE
var corner_px := 0.0  # > 0: the corners are drawn this many px wide whatever the box's size (a big picture used as a thin frame: the rim keeps its own thickness)


static func make(texs: Array, texel_frac: float, content: Array) -> ScaledBox:
	var b := ScaledBox.new()
	b.textures = texs
	b.frac = texel_frac
	b.content_margin_left = content[0]
	b.content_margin_top = content[1]
	b.content_margin_right = content[2]
	b.content_margin_bottom = content[3]
	return b


func _pick(rect: Rect2) -> Texture2D:
	var best: Texture2D = null
	var best_d := INF
	var want := log(maxf(rect.size.x, 1.0) / maxf(rect.size.y, 1.0))
	for t: Texture2D in textures:
		var d := absf(log(float(t.get_width()) / float(t.get_height())) - want)
		if d < best_d:
			best_d = d
			best = t
	return best


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if textures.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tex := _pick(rect)
	var ts := tex.get_size()
	var tm := roundf(minf(ts.x, ts.y) * frac)  # (the corner, in texels)
	var k := minf(rect.size.x / ts.x, rect.size.y / ts.y)  # (the picture scaled evenly to fit the box)
	var c := minf(corner_px if corner_px > 0.0 else tm * k, minf(rect.size.x, rect.size.y) * 0.45)
	var xs := [0.0, c, rect.size.x - c, rect.size.x]
	var ys := [0.0, c, rect.size.y - c, rect.size.y]
	var us := [0.0, tm, ts.x - tm, ts.x]
	var vs := [0.0, tm, ts.y - tm, ts.y]
	for j in 3:
		for i in 3:
			var dst := Rect2(rect.position + Vector2(xs[i], ys[j]), Vector2(xs[i + 1] - xs[i], ys[j + 1] - ys[j]))
			var src := Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j])
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, dst, tex.get_rid(), src, modulate_color)
