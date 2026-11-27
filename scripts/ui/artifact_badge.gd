class_name ArtifactBadge
extends Control
## The carnival artifacts' pictures (2026-11-27), drawn in code until painted art exists: a round fairground badge, its
## rim striped like a carnival tent (red and cream for Commons, blue and gold for Rares, purple and gold for the boss's),
## and the artifact's picture in the middle: a coloured coin for a Token, a halo, a neon glow stick, a contract with a
## splash of blood, an emoji for the rest. UiSkin.artifact_icon uses it for these ids (painted art named after the id wins).

const EMOJI := {"thorn_heart": "💗", "carver": "🔪", "collector": "🧐", "mysterious_hand": "🖐", "golden_ticket": "🎫",
	"bulwark": "🛡", "coal_heart": "❤‍🔥", "candy_apple": "🍎", "dark_heart": "🖤", "kunai": "🗡", "hammer": "🔨",
	"cactus_plushie": "🌵", "monochrome_prism": "🍧", "shopping_list": "🧾", "magician_hat": "🎩", "leather_glove": "🧤",
	"blood_pact": "📜", "cursed_book": "📕"}
const DRAWN := ["red_token", "blue_token", "green_token", "rainbow_token", "halo", "glow_stick"]
const TOKEN_COL := {"red_token": Color(0.9, 0.2, 0.15), "blue_token": Color(0.2, 0.45, 0.95), "green_token": Color(0.25, 0.75, 0.3)}

var id := ""
var _t := 0.0


static func has(p_id: String) -> bool:
	return EMOJI.has(p_id) or p_id in DRAWN


static func make(p_id: String, px: float) -> ArtifactBadge:
	var b := ArtifactBadge.new()
	b.id = p_id
	b.custom_minimum_size = Vector2(px, px)
	b.size = b.custom_minimum_size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _ready() -> void:
	if EMOJI.has(id):
		var l := UiTheme.label(String(EMOJI[id]), maxi(10, int(minf(size.x, size.y) * 0.46)), Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	set_process(id in ["glow_stick", "halo", "rainbow_token", "cursed_book"])  # (these shimmer)
	resized.connect(queue_redraw)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.47
	var tier := String(Artifacts.get_def(id).get("tier", "common"))
	var a_col := Color(0.82, 0.16, 0.14)
	var b_col := Color(0.98, 0.93, 0.8)
	if tier == "rare":
		a_col = Color(0.2, 0.4, 0.85)
		b_col = Color(1.0, 0.82, 0.3)
	elif tier == "legendary":
		a_col = Color(0.45, 0.15, 0.55)
		b_col = Color(1.0, 0.8, 0.3)
	draw_circle(c + Vector2(0, r * 0.06), r * 1.02, Color(0, 0, 0, 0.35))  # (its shadow)
	var n := 16
	for k in n:  # (the tent stripes)
		var a0 := TAU * k / n - PI / 2.0
		var a1 := a0 + TAU / n
		var pts := PackedVector2Array([c])
		for j in 5:
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, j / 4.0)) * r)
		draw_colored_polygon(pts, a_col if k % 2 == 0 else b_col)
	draw_arc(c, r, 0.0, TAU, 48, a_col.darkened(0.45), maxf(1.5, r * 0.05), true)
	draw_circle(c, r * 0.76, Color(0.25, 0.12, 0.08))
	draw_circle(c, r * 0.71, Color(1.0, 0.95, 0.85) if tier != "legendary" else Color(0.2, 0.12, 0.25))
	draw_arc(c, r * 0.71, -2.4, -0.9, 24, Color(1, 1, 1, 0.35), r * 0.06, true)  # (a little shine)
	match id:
		"red_token", "blue_token", "green_token":
			_coin(c, r * 0.56, TOKEN_COL[id])
		"rainbow_token":
			_coin(c, r * 0.56, Color.from_hsv(fmod(_t * 0.15, 1.0), 0.7, 0.95))
			for k in 4:
				draw_arc(c, r * (0.42 - k * 0.07), 0.0, TAU, 32, Color.from_hsv(fmod(_t * 0.15 + k * 0.2, 1.0), 0.75, 1.0), r * 0.05, true)
		"halo":
			var pulse := 0.85 + 0.15 * sin(_t * 3.0)
			draw_circle(c, r * 0.55 * pulse, Color(1.0, 0.85, 0.3, 0.18))
			draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, 0.45), r * 0.24, true)
			draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 40, Color(1.0, 0.78, 0.15), r * 0.12, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"glow_stick":
			var glow := 0.75 + 0.25 * sin(_t * 4.0)
			var p0 := c + Vector2(-r * 0.38, r * 0.34)
			var p1 := c + Vector2(r * 0.05, -r * 0.05)
			var p2 := c + Vector2(r * 0.36, -r * 0.4)
			for w in [r * 0.36, r * 0.24]:
				draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.5, 1.0, 0.3, 0.22 * glow), w, true)
			draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.6, 1.0, 0.35), r * 0.13, true)
			draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.95, 1.0, 0.85), r * 0.05, true)
		"blood_pact":  # (the contract's splash of blood, over the emoji)
			for k in 7:
				var a := TAU * k / 7.0 + 0.4
				draw_circle(c + Vector2(r * 0.18, r * 0.12) + Vector2.from_angle(a) * r * (0.12 + 0.07 * (k % 3)), r * (0.06 + 0.03 * (k % 2)), Color(0.75, 0.05, 0.05, 0.9))
			draw_circle(c + Vector2(r * 0.18, r * 0.12), r * 0.13, Color(0.8, 0.05, 0.05))
		"cursed_book":
			draw_circle(c, r * 0.62, Color(0.6, 0.3, 1.0, 0.12 + 0.08 * sin(_t * 2.5)))


## A fairground token: a brass rim, coloured enamel, a cream star.
func _coin(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(0.85, 0.65, 0.25))
	draw_circle(c, r * 0.84, Color(0.6, 0.42, 0.12))
	draw_circle(c, r * 0.78, col)
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(c + Vector2.from_angle(a) * (r * 0.5 if k % 2 == 0 else r * 0.22))
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.8))
	draw_arc(c, r * 0.66, -2.3, -1.2, 16, Color(1, 1, 1, 0.45), r * 0.07, true)
