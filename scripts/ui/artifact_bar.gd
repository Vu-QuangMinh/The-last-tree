class_name ArtifactBar
extends HFlowContainer
## Your artifacts as a row of icons (top-left). Hover one for its details; right-click pins them.

var artifacts: Array = []
var plus: Array = []  # upgraded ones


static func make(p_artifacts: Array, p_plus: Array = []) -> ArtifactBar:
	var b := ArtifactBar.new()
	b.artifacts = p_artifacts
	b.plus = p_plus
	return b


func _ready() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	custom_minimum_size = Vector2(620, 0)
	UiSkin.frame_behind(self)  # New theme: one painted frame around all the artifacts
	refresh()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	for id in artifacts:
		add_child(ArtifactChip.make(id, id in plus))


## Artifacts that charge up (Kindling Stone, Echo Shell) shine and pulse while charged; their tooltip shows
## how far along they are.
func update_charges(p: PlayerState) -> void:
	for c in get_children():
		if c is ArtifactChip and not c.is_queued_for_deletion():
			var st := Artifacts.charge_state(c.id, p, c.id in plus)
			if not st.is_empty():
				c.set_charge(st[0], st[1])


## A quick bright flash on an artifact that just did something.
func flash(id: String) -> void:
	for c in get_children():
		if c is ArtifactChip and c.id == id:
			c.pivot_offset = c.size / 2.0
			var tw := c.create_tween()
			tw.tween_property(c, "scale", Vector2(1.5, 1.5), 0.1)
			tw.parallel().tween_property(c, "modulate", Color(2.2, 2.0, 1.4), 0.1)
			tw.tween_property(c, "scale", Vector2.ONE, 0.25)
			tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.3)


class ArtifactChip extends PanelContainer:
	const TIER_COL := {"common": Color(0.6, 0.62, 0.55), "rare": Color(0.4, 0.65, 1.0), "legendary": Color(1.0, 0.75, 0.3)}

	const SIZE := 72.0  # the square each artifact sits in
	const ICON := 52.0
	const FAINT := Color(1, 1, 1, 0.14)
	const FAINT_HOVER := Color(1, 1, 1, 0.32)

	var id := ""
	var charged := false
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
		var hover := Color(1, 1, 1, 0.2) if UiSkin.has_slot_frame() else FAINT_HOVER
		sb.border_color = idle
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		sb.set_content_margin_all(5)
		c.add_theme_stylebox_override("panel", sb)
		c.custom_minimum_size = Vector2(px, px)
		c.mouse_entered.connect(func(): if not c.charged: sb.border_color = hover)
		c.mouse_exited.connect(func(): if not c.charged: sb.border_color = idle)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var art := UiSkin.artifact_icon(id, px * ICON / SIZE)  # New theme: the painted artifact; otherwise its symbol
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
		c.tooltip_text = Keywords.tooltip(a.name, a.desc, "[color=#9aa89a]%s artifact · %s[/color]" % [tier, a.get("aspect", "")], UiSkin.inline(UiSkin.ARTIFACT_ART.get(id, id), a.get("icon", ""), 28))
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

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges() == "":
			return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
		return Keywords.make_tooltip(for_text)
