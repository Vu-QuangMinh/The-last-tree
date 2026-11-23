class_name EnemyHpBar
extends Control
## The new fight's enemy HP (2026-11-22, the user: "HP bar in that spot"): a bar where the old screen had its row of
## Essence, under the puppet. Red for HP, blue after it for Shield (the bar stretches to hold both), the numbers on it.
## EnemyView puts one in its HP row when the enemy carries an "hp" meta (MarbleBridge); it pops "-N" when hurt.

const W := 200.0
const H := 24.0
const RED := Color(0.75, 0.12, 0.12)
const BLUE := Color(0.3, 0.6, 1.0)

var hp := 0
var max_hp := 1
var shield := 0


static func make(p_hp: int, p_max: int, p_shield: int) -> EnemyHpBar:
	var b := EnemyHpBar.new()
	b.hp = p_hp
	b.max_hp = maxi(1, p_max)
	b.shield = p_shield
	b.custom_minimum_size = Vector2(W, H)
	b.size = b.custom_minimum_size
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var total := float(maxi(max_hp, hp + shield))
	draw_rect(r, Color(0.08, 0.04, 0.03, 0.92))
	var hw := r.size.x * float(hp) / maxf(1.0, total)
	draw_rect(Rect2(r.position, Vector2(hw, r.size.y)), RED)
	if shield > 0:
		draw_rect(Rect2(r.position + Vector2(hw, 0), Vector2(r.size.x * float(shield) / total, r.size.y)), BLUE)
	draw_rect(r, Color(0.9, 0.75, 0.45) if shield <= 0 else BLUE.lightened(0.4), false, 2.0)
	var font: Font = UiTheme.title_font()
	var txt := "%d / %d" % [hp, max_hp] + ("  +%d" % shield if shield > 0 else "")
	draw_string_outline(font, Vector2(0, 18), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0.1, 0.04, 0.02))
	draw_string(font, Vector2(0, 18), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color.WHITE)


## A damage number rises from the bar ("Blocked" when only its Shield was hit).
static func pop(holder: Control, at: Vector2, lost: int) -> void:
	var l := UiTheme.label(("-%d" % lost) if lost > 0 else "Blocked", 34, Color(1.0, 0.85, 0.35) if lost > 0 else Color(0.6, 0.85, 1.0))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 60
	holder.add_child(l)
	l.position = at - Vector2(40, 30)
	l.pivot_offset = Vector2(40, 20)
	l.scale = Vector2(1.5, 1.5)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 80.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
