class_name ArtifactBar
extends HFlowContainer
## Your artifacts as a row of icons (top-left). Hover one for its details; right-click pins them.

var artifacts: Array = []


static func make(p_artifacts: Array) -> ArtifactBar:
	var b := ArtifactBar.new()
	b.artifacts = p_artifacts
	return b


func _ready() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	custom_minimum_size = Vector2(620, 0)
	refresh()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	for id in artifacts:
		add_child(ArtifactChip.make(id))


class ArtifactChip extends PanelContainer:
	const TIER_COL := {"common": Color(0.6, 0.62, 0.55), "rare": Color(0.4, 0.65, 1.0), "legendary": Color(1.0, 0.75, 0.3)}

	static func make(id: String) -> ArtifactChip:
		var c := ArtifactChip.new()
		var a := Artifacts.get_def(id)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.07, 0.06, 0.9)
		sb.border_color = Color(1, 0.4, 0.4) if a.get("aspect", "") == "Cursed" else TIER_COL.get(a.get("tier", "common"), Color.WHITE)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		c.add_theme_stylebox_override("panel", sb)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := UiTheme.label(a.get("icon", "◆"), 28, Color.WHITE)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(l)
		var tier: String = Artifacts.TIER_NAMES.get(a.get("tier", "common"), "")
		c.tooltip_text = Keywords.tooltip("%s %s" % [a.get("icon", ""), a.name], a.desc, "[color=#9aa89a]%s artifact · %s[/color]" % [tier, a.get("aspect", "")])
		return c

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges() == "":
			return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
		return Keywords.make_tooltip(for_text)
