class_name CardPip
extends RefCounted
## The look shared by every element on screen (ElementIcon draws with it): a white disc with a coloured rim
## and the element's picture inside. Also loads the card artwork textures.

const RIM := {"F": Color(0.4, 0.16, 0.115), "W": Color(0.17, 0.21, 0.385), "A": Color(0.265, 0.33, 0.44)}
const ICON := {"F": "el_fire", "W": "el_water", "A": "el_wind"}
## The icon fits inside this fraction of the disc's diameter.
const ICON_FIT := 0.86

static var _tex := {}


## A texture from res://assets/card/, loaded once; null when the file isn't there.
static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## The disc itself, also used by ElementIcon so every element on screen looks alike: white, a rim in the
## element's colour, the element's picture inside. alpha fades it all (ghosts and dimmed elements).
static func draw_pip(ci: CanvasItem, c: Vector2, r: float, p_el: String, alpha := 1.0) -> void:
	var rim := maxf(1.0, r * 0.1)
	ci.draw_circle(c, r, Color(1, 1, 1, alpha), true, -1.0, true)
	ci.draw_arc(c, r - rim / 2.0, 0.0, TAU, 48, Color(RIM[p_el], alpha), rim, true)
	var t := tex("res://assets/card/icons/%s.png" % ICON[p_el])
	if t == null:
		return
	var box := r * 2.0 * ICON_FIT
	var s := minf(box / t.get_width(), box / t.get_height())
	var sz := Vector2(t.get_width(), t.get_height()) * s
	ci.draw_texture_rect(t, Rect2(c - sz / 2.0, sz), false, Color(1, 1, 1, alpha))
