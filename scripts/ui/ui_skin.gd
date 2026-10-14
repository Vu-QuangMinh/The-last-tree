class_name UiSkin
extends RefCounted
## The two looks of the game: "new" (hand-drawn art, assets/New/) and "puppet" (the wooden puppet theatre, assets/Puppet/). Art that both share
## sits in assets/Global/. Settings -> Theme picks one. (The old Default and Cirus looks are gone: a save that still says so opens in New.)
## A piece of art that's missing just returns null, and the caller keeps drawing in code.
##
## Every theme folder has the same shape (see assets/README.md): Card, Enemies/Act1..3, Fonts, Icon/{Artifact,Bottle,Effect,Intent},
## UI/..., Map/..., Stage/Act1..3/{Props,Backdrop,Wall,Floor,Ceiling,Fx}, SFX. Art is found BY NAME: the first folder of FOLDERS (in each
## root, in ROOTS' order) that holds <name>.png or <name>.jpg wins, so a picture can be moved between those folders freely.

const ASSETS := "res://assets/"
const OPTIONS := ["new", "puppet"]
const LABELS := ["New", "Puppet Stage"]
## Puppet Stage theme: pieces that would clash with the stage (the painted stump under an enemy) are hidden.
const PUPPET_HIDDEN := ["enemy_stand"]

static var _tex := {}
static var _paths := {}  # name -> res:// path ("" = there is none)
## Where a name is looked for, inside a theme folder (in this order).
const FOLDERS := ["UI/Panels", "UI/Hp", "UI/Machine", "UI/Hint", "UI/Buttons", "UI/Essence", "Icon/Intent", "Icon/Effect", "UI/Icons",
	"Card", "UI/Numbers", "Card/Treasure", "Map", "UI/Fx", "Stage/Act1/Backdrop", "Stage/Act2/Backdrop", "Stage/Act3/Backdrop",
	"Map/Rooms/Backgrounds", "Stage/Act1/Fx", "Stage/Act2/Fx", "Stage/Act3/Fx", "UI/Banners", "UI/Characters", "Icon/Artifact", "Icon/Bottle",
	"Map/Rooms/Campfire", "Map/Rooms/Apothecary", "UI/Misc", "UI"]

## artifact id -> picture name, where they differ
const ARTIFACT_ART := {"scholar_quill": "scholars_quill"}


## "new" or "puppet".
static func theme_id() -> String:
	var t: String = SaveManager.setting("theme", "new")
	return t if t in OPTIONS else "new"


## The theme folders to look in, the chosen theme first (Puppet falls back to New for what it has no art of its own for yet, then Global).
static func roots() -> Array:
	return [ASSETS + "Puppet/", ASSETS + "New/", ASSETS + "Global/"] if is_puppet() else [ASSETS + "New/", ASSETS + "Global/"]


## The folder of the chosen theme ("res://assets/New/" or ".../Puppet/").
static func theme_dir() -> String:
	return ASSETS + ("Puppet/" if is_puppet() else "New/")


## True: the painted art is always on (there is no code-drawn Default look any more); the code paths that ask for art key off this.
static func is_new() -> bool:
	return true


## Puppet Stage reuses the layout that was first made for the Cirus tent (launcher strips, panel and toast sizes...): the name stayed.
static func is_circus() -> bool:
	return is_puppet()


static func is_puppet() -> bool:
	return theme_id() == "puppet"


static func set_theme(id: String) -> void:
	SaveManager.set_setting("theme", id if id in OPTIONS else "new")
	_tex.clear()  # the same name now means another picture
	_paths.clear()
	UiTheme.reset()  # the shared Theme is rebuilt for the next screen
	apply_clear_color()


## The colour of the bars shown beside the 16:9 picture on a screen of another shape (the game is laid out for 1920 x 1080 and kept in that shape).
static func apply_clear_color() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.045, 0.03) if is_puppet() else Color(0.05, 0.07, 0.06))


## Where a picture is (res:// path), or "" when there is no such picture.
static func path_of(name: String) -> String:
	if not _paths.has(name):
		var found := ""
		for root in roots():
			for folder in FOLDERS:
				for ext in [".png", ".jpg"]:  # (the room backgrounds are jpg: big, flat-coloured pictures)
					var p: String = root + folder + "/" + name + ext
					if ResourceLoader.exists(p):
						found = p
						break
				if found != "":
					break
			if found != "":
				break
		_paths[name] = found
	return _paths[name]


## A texture by name, or null when the file isn't there.
static func tex(name: String) -> Texture2D:
	if not is_new() or (is_puppet() and name in PUPPET_HIDDEN):
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


## New theme: the painted slot frame (3 slices: left cap | middle | right cap, UI/Panels/slot_strip.png).
static func has_slot_frame() -> bool:
	return tex("slot_strip") != null


## New theme: ONE frame behind all the children of `row` (a row of artifact or bottle slots), drawn from the first child's
## left edge to the last one's right edge and growing with them. Does nothing in Default or while the row is empty.
static func frame_behind(row: Control, pad := Vector2(16, 11), frame := "slot_strip") -> void:
	if is_puppet():
		pad = Vector2(12, 8)  # (the Puppet plaque has a thick carved rim: hug the slots, or it dwarfs them)
	var sb := box(frame, [22, 16, 22, 16] if is_puppet() else [28, 0, 27, 0])
	if sb == null and frame != "slot_strip":
		sb = box("slot_strip", [22, 16, 22, 16] if is_puppet() else [28, 0, 27, 0])
	if sb == null:
		return
	row.sort_children.connect(row.queue_redraw)
	row.draw.connect(func():
		var all := Rect2()
		var any := false
		for k in row.get_children():
			if k is Control and k.visible and not k.is_queued_for_deletion():
				var r := Rect2(k.position, k.size)  # (not its scale: a charged artifact pulses, the frame stays still)
				all = r if not any else all.merge(r)
				any = true
		if any:
			row.draw_style_box(sb, all.grow_individual(pad.x, pad.y, pad.x, pad.y)))


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


## The main menu's "Unlocks (7 <seedling>)": the painted seedling stands inside the bracket, right of the number, which makes room for it (the
## bracket moves back), a little lower (2 px) than the middle of the button.
static func seedling_count_button(b: Button, label: String, count: int, px := 26) -> void:
	var t := tex("icon_seedling")
	if t == null:
		b.text = "%s  (%d)" % [label, count]
		return
	var font := b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	var head := "%s  (%d" % [label, count]
	var gap := float(px) + 6.0
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad := " ".repeat(maxi(1, ceili(gap / maxf(space, 1.0))))
	b.text = head + pad + ")"
	var icon := TextureRect.new()
	icon.texture = t
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var place := func() -> void:
		var full := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := (b.size.x - full) / 2.0
		var head_w := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		icon.position = Vector2(x0 + head_w + 3.0, (b.size.y - px) / 2.0 + 2.0)
	b.resized.connect(place)
	place.call_deferred()


## An artifact's painted icon (Icon/Artifact/<id>.png) in a square of `px`; null if that artifact has none yet.
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
