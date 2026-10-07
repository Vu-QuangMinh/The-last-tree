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
static var _paths := {}  # name -> res:// path ("" = there is none)
## The art is sorted into folders under DIR (by what it is); a name is looked up in each, as a png and then a jpg.
const FOLDERS := ["panels", "buttons", "essence", "intent", "status", "icons", "cards", "numbers", "treasure", "map", "fx",
	"backgrounds", "leaves", "title", "characters", "artifacts", "bottles", "campfire", "room", "misc"]

## artifact id -> picture name, where they differ
const ARTIFACT_ART := {"scholar_quill": "scholars_quill"}


static func is_new() -> bool:
	return SaveManager.setting("theme", "new") == "new"


static func set_theme(id: String) -> void:
	SaveManager.set_setting("theme", id)
	UiTheme.reset()  # the shared Theme is rebuilt for the next screen


## Where a picture of the New set is (res:// path), or "" when there is no such picture.
static func path_of(name: String) -> String:
	if not _paths.has(name):
		var found := ""
		for folder in FOLDERS:
			for ext in [".png", ".jpg"]:  # (the room backgrounds are jpg: big, flat-coloured pictures)
				var p: String = DIR + folder + "/" + name + ext
				if ResourceLoader.exists(p):
					found = p
					break
			if found != "":
				break
		_paths[name] = found
	return _paths[name]


## A texture from the New set, or null when the theme is Default (or the file isn't there).
static func tex(name: String) -> Texture2D:
	if not is_new():
		return null
	if not _tex.has(name):
		var p := path_of(name)
		_tex[name] = load(p) if p != "" else null
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


## A picture to put INSIDE rich text ([img] in a RichTextLabel / tooltip): the painted one in the New theme, `fallback` (the
## old emoji or text) otherwise or when that picture isn't there.
static func inline(name: String, fallback := "", px := 24) -> String:
	if tex(name) == null:
		return fallback
	return "[img=%dx%d]%s[/img]" % [px, px, path_of(name)]


## The same for a plain Label (a toast): a marker the toast turns into a picture, or into `fallback` when there isn't one.
static func icon_token(name: String, fallback := "") -> String:
	return "{icon:%s|%s}" % [name, fallback]


## New theme: a Button gets the painted Seedling beside its text (`text` without the old ✿ glyph); otherwise it keeps `plain`.
static func seedling_button(b: Button, text: String, plain: String, px := 24) -> void:
	var t := tex("icon_seedling")
	if t == null:
		b.text = plain
		return
	b.text = text
	b.icon = t
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", px)


## An artifact's painted icon (assets/ui/new/<id>.png) in a square of `px`; null in Default or if that artifact has none yet.
static func artifact_icon(id: String, px: float) -> TextureRect:
	return icon(ARTIFACT_ART.get(id, id), px)


## Draw `name` centred in a box of `px`, keeping its proportions. Returns false if there's no art.
static func draw_fit(ci: CanvasItem, name: String, centre: Vector2, px: float, mod := Color.WHITE) -> bool:
	var t := tex(name)
	if t == null:
		return false
	var s := minf(px / t.get_width(), px / t.get_height())
	var sz := Vector2(t.get_width(), t.get_height()) * s
	ci.draw_texture_rect(t, Rect2(centre - sz / 2.0, sz), false, mod)
	return true
