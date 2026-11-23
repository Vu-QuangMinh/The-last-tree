extends SceneTree
## Headless: every new card's rarity, the Power cards first (godot --headless --path . --script res://tools/card_rarity_report.gd)


func _init() -> void:
	create_timer(30).timeout.connect(quit)
	await process_frame
	var count := {}
	var powers := []
	for id in MarbleCards.C:
		var r := MarbleCards.rarity(String(id))
		count[r] = int(count.get(r, 0)) + 1
		if bool(MarbleCards.C[id].get("power", false)):
			powers.append("%s=%s" % [id, r])
	print("RARITY counts: ", count)
	print("RARITY powers: ", powers)
	quit()
