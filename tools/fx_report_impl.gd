extends RefCounted


func run() -> void:
	for id in MarbleCards.C:
		var c := MarbleCards.card(String(id), 0)
		var fx := MarblesFight.fx_of(c)
		print("FX %s -> %s/%s  p=%s  | %s" % [id, fx.get("op", "(power: badge)"), fx.get("to", "-"), c.p, String(c.text).left(70)])
