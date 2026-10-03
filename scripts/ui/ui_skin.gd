class_name UiSkin
extends RefCounted
## The "New" look: hand-drawn art from assets/ui/new/ (cut from assets/ui/Fight UI.pdf by tools/export_fight_ui.py).
## Settings → Theme picks it ("new" = the art wherever there is some, and it's the default; "default" = everything
## drawn in code).
## A piece of art that's missing just returns null, and the caller keeps drawing in code.

const DIR := "res://assets/ui/new/"
const OPTIONS := ["default", "new"]
const LABELS := ["Default", "New"]

static var _tex := {}


static func is_new() -> bool:
	return SaveManager.setting("theme", "new") == "new"


static func set_theme(id: String) -> void:
	SaveManager.set_setting("theme", id)
	UiTheme.reset()  # the shared Theme is rebuilt for the next screen


## A texture from the New set, or null when the theme is Default (or the file isn't there).
static func tex(name: String) -> Texture2D:
	if not is_new():
		return null
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


## A StyleBoxTexture: margins = [left, top, right, bottom] for 9-slice (all 0 = the whole image stretched to fit).
## content = [left, top, right, bottom] padding for whatever sits inside.
static func box(name: String, margins := [0, 0, 0, 0], content := [0, 0, 0, 0]) -> StyleBoxTexture:
	var t := tex(name)
	if t == null:
		return null
	var b := StyleBoxTexture.new()
	b.texture = t
	b.texture_margin_left = margins[0]
	b.texture_margin_top = margins[1]
	b.texture_margin_right = margins[2]
	b.texture_margin_bottom = margins[3]
	b.content_margin_left = content[0]
	b.content_margin_top = content[1]
	b.content_margin_right = content[2]
	b.content_margin_bottom = content[3]
	return b


## A TextureRect showing `name` inside a square of `px`; null when there's no art.
static func icon(name: String, px: float) -> TextureRect:
	var t := tex(name)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


const GLYPHS := {"+": "num_plus", "-": "num_minus", "x": "num_times", "×": "num_times", "÷": "num_divide"}


## A number written in the New theme's big painted digits (0-9 + - × ÷), `h` px tall (`white` = the white set, which the
## caller can tint; `sign_scale` shrinks the + - × ÷ signs next to the digits). Null if the digits aren't there, so the
## caller keeps its text label.
static func number(text: String, h: float, white := false, sign_scale := 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not fill_number(row, text, h, white, sign_scale):
		row.free()
		return null
	return row


## Put the painted glyphs of `text` into an existing container (replacing what it held). False (and the container
## emptied) when the digits aren't there.
static func fill_number(row: Container, text: String, h: float, white := false, sign_scale := 1.0, align_end := false) -> bool:
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	for ch in text:
		var name: String = "num_" + ch if ch >= "0" and ch <= "9" else GLYPHS.get(ch, "")
		var t := tex(name.replace("num_", "numw_") if white and name != "" else name)
		if t == null:
			return false
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var k := h / 128.0 * (1.0 if ch >= "0" and ch <= "9" else sign_scale)  # all digits are cut 128 px tall; signs can be smaller
		r.custom_minimum_size = Vector2(t.get_width(), t.get_height()) * k
		r.size_flags_vertical = Control.SIZE_SHRINK_END if align_end else Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	return true


## Draw `name` centred in a box of `px`, keeping its proportions. Returns false if there's no art.
static func draw_fit(ci: CanvasItem, name: String, centre: Vector2, px: float, mod := Color.WHITE) -> bool:
	var t := tex(name)
	if t == null:
		return false
	var s := minf(px / t.get_width(), px / t.get_height())
	var sz := Vector2(t.get_width(), t.get_height()) * s
	ci.draw_texture_rect(t, Rect2(centre - sz / 2.0, sz), false, mod)
	return true
