class_name ArtifactBar
extends HFlowContainer
## Your artifacts as a row of icons (top-left). Hover one for its details; right-click pins them.

var artifacts: Array = []
var plus: Array = []  # upgraded ones
## Puppet Stage: one row inside the artifacts' frame, `chip_px` squares `slot_step` apart (more of them than fit squeeze together)
var chip_px := 0.0
var row_width := 0.0
var slot_step := 0.0
var per_row := 0  # (Puppet: this many to a row at full spacing, the next ones wrap onto a new row; 0 = one row that squeezes)
const ROW_GAP := 2  # (between the wrapped rows: the top frame grows by the same, see FightScreen.ART_ROW_GAP)


static func make(p_artifacts: Array, p_plus: Array = []) -> ArtifactBar:
	var b := ArtifactBar.new()
	b.artifacts = p_artifacts
	b.plus = p_plus
	return b


func _ready() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	custom_minimum_size = Vector2(620, 0)
	if chip_px > 0.0:
		custom_minimum_size = Vector2(row_width, chip_px)
	else:
		UiSkin.frame_behind(self)  # New theme: one painted frame around all the artifacts
	refresh()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	if chip_px > 0.0 and per_row > 0:
		add_theme_constant_override("h_separation", int(floor(slot_step - chip_px)))
		add_theme_constant_override("v_separation", ROW_GAP)
	elif chip_px > 0.0:
		var n := maxi(1, artifacts.size())
		var step := minf(slot_step, (row_width - chip_px) / maxf(1.0, n - 1.0))
		add_theme_constant_override("h_separation", int(floor(step - chip_px)))
	for id in artifacts:
		add_child(ArtifactChip.make(id, id in plus, chip_px if chip_px > 0.0 else ArtifactChip.SIZE))


## Artifacts that charge up (Kindling Stone, Echo Shell) shine and pulse while charged; their tooltip shows
## how far along they are.
func update_charges(p: PlayerState) -> void:
	for c in get_children():
		if c is ArtifactChip and not c.is_queued_for_deletion():
			var st := Artifacts.charge_state(c.id, p, c.id in plus)
			if not st.is_empty():
				c.set_charge(st[0], st[1])


## An artifact that just did something: it grows, shines, and goes back to its size (one that works again and again).
func flash(id: String) -> void:
	for c in get_children():
		if c is ArtifactChip and c.id == id:
			c.activate()


class ArtifactChip extends PanelContainer:
	const TIER_COL := {"common": Color(0.6, 0.62, 0.55), "rare": Color(0.4, 0.65, 1.0), "legendary": Color(1.0, 0.75, 0.3)}

	const SIZE := 72.0  # the square each artifact sits in
	const ICON := 52.0
	const FAINT := Color(1, 1, 1, 0.14)
	const FAINT_HOVER := Color(1, 1, 1, 0.32)

	var id := ""
	var charged := false
	var _glow := 0.0  # 0..1: the golden light behind it while it is doing its thing
	var _act_tw: Tween
	var _sb: StyleBoxFlat
	var _base_border: Color
	var _base_tip := ""
	var _t := 0.0

	## px: the square it sits in (the run bar on the map uses a smaller one).
	static func make(id: String, plus := false, px := SIZE) -> ArtifactChip:
		var c := ArtifactChip.new()
		c.id = id
		var a := Artifacts.view(id, plus)
		# no box: just a soft, faint outline of the square it sits in (a touch brighter under the mouse)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		var idle := Color(1, 1, 1, 0.0) if UiSkin.has_slot_frame() else FAINT  # (the shared frame replaces the outline)
		sb.border_color = idle
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		sb.set_content_margin_all(0 if UiSkin.is_puppet() else 5)
		c.add_theme_stylebox_override("panel", sb)
		if HoverBoard.available():  # (its hover board is its own picture: the game's plain tooltip box must not show behind it)
			c.theme = HoverBoard.bare_theme()
		c.custom_minimum_size = Vector2(px, px)
		# under the mouse: no glowing outline, a tiny click and the icon grows a little (the info panel still shows)
		c.mouse_entered.connect(func():
			Audio.play("ui_click", -14.0, 1.35)
			if not c.charged:
				c.pivot_offset = c.size / 2.0
				c.create_tween().tween_property(c, "scale", Vector2(1.14, 1.14), 0.08))
		c.mouse_exited.connect(func():
			if not c.charged:
				c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.08))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var art := UiSkin.artifact_icon(id, px if UiSkin.is_puppet() else px * ICON / SIZE)  # New theme: the painted artifact (kept in proportion); otherwise its symbol
		if art != null:
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			c.add_child(art)
		else:
			var l := UiTheme.label(a.get("icon", "◆"), 36, Color.WHITE)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(l)
		var tier: String = Artifacts.TIER_NAMES.get(a.get("tier", "common"), "")
		c.tooltip_text = Keywords.tooltip(a.name, a.desc, "[color=#9aa89a]%s artifact · %s[/color]" % [tier, a.get("aspect", "")], "" if UiSkin.is_puppet() else UiSkin.inline(UiSkin.ARTIFACT_ART.get(id, id), a.get("icon", ""), 28))  # (Puppet: the big picture of the hover board stands for it)
		c._sb = sb
		c._base_border = sb.border_color
		c._base_tip = c.tooltip_text
		return c

	## Charged: a golden glow that breathes and a gentle pulse, so you can see it's ready.
	func set_charge(on: bool, progress: String) -> void:
		if not has_meta("tip_pinned"):
			tooltip_text = _base_tip + "\n[color=#ffd970]%s[/color]" % progress
		if on == charged:
			return
		charged = on
		_t = 0.0
		if not on:
			_sb.border_color = _base_border
			_sb.shadow_size = 0
			scale = Vector2.ONE
			modulate = Color.WHITE

	func _process(d: float) -> void:
		if not charged:
			return
		_t += d
		var g := 0.5 + 0.5 * sin(_t * 5.0)
		pivot_offset = size / 2.0
		scale = Vector2.ONE * (1.0 + 0.1 * g)
		modulate = Color(1, 1, 1).lerp(Color(1.5, 1.35, 0.9), g)
		_sb.border_color = Color(1.0, 0.85, 0.3).lerp(Color(1, 1, 0.85), g)
		_sb.shadow_color = Color(1.0, 0.8, 0.25, 0.5 + 0.4 * g)
		_sb.shadow_size = int(6 + 8 * g)

	## It grows to 1.55 x and shines, holds a moment, and comes back (a quick golden glow behind it).
	func activate() -> void:
		if _act_tw != null and _act_tw.is_valid():
			_act_tw.kill()
		pivot_offset = size / 2.0
		z_index = 20
		_act_tw = create_tween()
		_act_tw.tween_method(func(u: float) -> void:
			_glow = u
			scale = Vector2.ONE * lerpf(1.0, 1.55, u)
			modulate = Color.WHITE.lerp(Color(1.5, 1.4, 1.0), u)
			queue_redraw(), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_act_tw.tween_interval(0.3)
		_act_tw.tween_method(func(u: float) -> void:
			_glow = 1.0 - u
			scale = Vector2.ONE * lerpf(1.55, 1.0, u)
			modulate = Color(1.5, 1.4, 1.0).lerp(Color.WHITE, u)
			queue_redraw(), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_act_tw.tween_callback(func() -> void:
			z_index = 0
			scale = Vector2.ONE
			modulate = Color.WHITE)

	func _draw() -> void:
		if _glow > 0.01:
			var r := size.x * 0.62
			for k in 4:
				draw_circle(size / 2.0, r * (1.0 + 0.28 * k), Color(1.0, 0.82, 0.3, 0.2 * _glow * (1.0 - 0.22 * k)))

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges() == "":
			return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
		if HoverBoard.available():
			return ArtifactBar.hover_panel(id, for_text)
		return Keywords.make_tooltip(for_text)


## The hover board of an artifact (Puppet Stage): see HoverBoard.
static func hover_panel(id: String, bbcode: String) -> Control:
	return HoverBoard.make(UiSkin.tex(UiSkin.ARTIFACT_ART.get(id, id)), bbcode)
