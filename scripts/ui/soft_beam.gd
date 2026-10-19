class_name SoftBeam
extends Node2D
## A beam of light with soft edges, like the glow of the Veiled Eyes: many thin lines laid over each other, a bright core in the middle fading
## out to a wide faint halo (added to what is under it), with a round glow at each end. It comes in fast, holds, and fades.

var a := Vector2.ZERO
var b := Vector2.ZERO
var color := Color(0.7, 0.35, 1.0)
var width := 12.0  # the core's width: the halo is several times wider
var life := 0.32
var _age := 0.0
const LAYERS := 14


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 90


func _process(d: float) -> void:
	_age += d
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var u := _age / life
	var env := minf(u / 0.12, 1.0) * (1.0 - smoothstep(0.55, 1.0, u))  # (in fast, holds, fades)
	var flicker := 0.92 + 0.08 * sin(_age * 70.0)
	for i in LAYERS:
		var t := float(i) / (LAYERS - 1)  # 0 = the core, 1 = the edge of the halo
		var w := lerpf(width * 0.35, width * 4.2, t)
		var alpha := pow(1.0 - t, 2.4) * 0.5 * env * flicker + 0.01 * env
		var col := Color(1.0, 0.9, 1.0).lerp(color, minf(1.0, t * 2.2))
		draw_line(a, b, Color(col, alpha), w, true)
	var glow := Vfx.glow_tex()
	for p in [a, b]:
		var s := width * (7.0 if p == a else 9.0) * (0.85 + 0.15 * env)
		draw_texture_rect(glow, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(color, 0.85 * env))
