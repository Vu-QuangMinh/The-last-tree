class_name CardSplit
extends Node2D
## Puppet Stage, the Hammer Hand's blows on a spell card: the card is cut into wooden planks (the same cut as a puppet that breaks, see
## PuppetShatter) that stay where they are, a hair apart, each with a dark edge. 1 hit: 5 planks; 2 hits: 10. (The 3rd hit breaks it for good:
## FightScreen._shatter_card.) Child of the card, in the card's own coordinates; `tex` is a picture of the card with `pad` px of margin.

var level := 0


static func make(tex: Texture2D, pad: Vector2, size: Vector2, hits: int) -> CardSplit:
	var sp := CardSplit.new()
	sp.level = hits
	sp.z_index = 4
	var back := Polygon2D.new()  # (the dark between the planks)
	back.polygon = PackedVector2Array([Vector2(3, 3), Vector2(size.x - 3, 3), size - Vector2(3, 3), Vector2(3, size.y - 3)])
	back.color = Color(0.32, 0.19, 0.1)
	sp.add_child(back)
	var cells := PuppetShatter.tile(Rect2(Vector2.ZERO, size), 5 if hits <= 1 else 10)
	for cell in cells:
		sp._add_plank(cell, tex, pad)
	return sp


func _add_plank(cell: PackedVector2Array, tex: Texture2D, pad: Vector2) -> void:
	var mid := Vector2.ZERO
	for p in cell:
		mid += p
	mid /= cell.size()
	var local := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in cell:
		local.append((p - mid) * 0.95)  # (a hair apart: the card shows dark between the planks)
		uv.append(p + pad)
	var holder := Node2D.new()
	holder.position = mid + Vector2(randf_range(-2.6, 2.6), randf_range(-2.6, 2.6))
	holder.rotation = randf_range(-0.045, 0.045)
	for layer in [3, 2, 1, 0]:
		var pg := Polygon2D.new()
		pg.texture = tex
		pg.polygon = local
		pg.uv = uv
		pg.position = Vector2(1.6, 1.3) * layer
		if layer > 0:
			pg.color = Color(0.5, 0.31, 0.17).darkened(0.12 * layer)
		holder.add_child(pg)
	add_child(holder)


## The planks jolt apart for a moment and settle (the blow lands).
func thump() -> void:
	for k in range(1, get_child_count()):  # (child 0 is the dark back)
		var h: Node2D = get_child(k)
		var home: Vector2 = h.position
		var away := (home - Vector2(SpellCard.W, SpellCard.H) / 2.0).normalized() * 5.0
		var tw: Tween = h.create_tween()
		tw.tween_property(h, "position", home + away, 0.05)
		tw.tween_property(h, "position", home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
