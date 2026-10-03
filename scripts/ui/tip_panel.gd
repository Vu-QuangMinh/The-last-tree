class_name TipPanel
extends PanelContainer
## A panel whose tooltip is rich text (Keywords BBCode), like the status badges under your HP.


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	return Keywords.make_tooltip(for_text)
