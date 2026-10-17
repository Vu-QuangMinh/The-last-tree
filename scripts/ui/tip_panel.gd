class_name TipPanel
extends PanelContainer
## A panel whose tooltip is rich text (Keywords BBCode), like the status badges. In the Puppet Stage `hover_tex` (the thing's picture) puts the words on the painted hover board.

var hover_tex: Texture2D
var hover_left := false  # the board appears to the left of this panel (not under the mouse)


func _ready() -> void:
	if hover_tex != null and HoverBoard.available():
		theme = HoverBoard.bare_theme()  # (the game's plain tooltip box must not show behind the board)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	if hover_tex != null and HoverBoard.available():
		return HoverBoard.make(hover_tex, for_text, self if hover_left else null)
	return Keywords.make_tooltip(for_text)
