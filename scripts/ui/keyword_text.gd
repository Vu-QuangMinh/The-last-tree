class_name KeywordText
extends RichTextLabel
## Rules text with coloured keywords you can hover: each keyword shows its own explanation as a tooltip, and
## right-click pins it (like every other tooltip). Hovering plain words shows nothing.

var on_parchment := false


static func make(text: String, font_px := 20, p_on_parchment := false) -> KeywordText:
	var r := KeywordText.new()
	r.on_parchment = p_on_parchment
	r.add_theme_font_size_override("normal_font_size", font_px)
	r.add_theme_font_size_override("bold_font_size", font_px)
	r.set_rules(text)
	return r


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_underlined = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	meta_hover_started.connect(func(meta): if not has_meta("tip_pinned"): tooltip_text = Keywords.keyword_tip(str(meta)))
	meta_hover_ended.connect(func(_meta): tooltip_text = "")


func set_rules(text: String, centered := true) -> void:
	var body := Keywords.colorize(text, on_parchment, true)
	self.text = ("[center]%s[/center]" % body) if centered else body


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	return Keywords.make_tooltip(for_text)
