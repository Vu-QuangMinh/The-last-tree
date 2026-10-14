extends RefCounted
func run(t: SceneTree) -> void:
	var save = t.root.get_node("SaveManager")
	save.use_test_file("user://probe.json")
	save.data.settings["theme"] = "puppet"
	for n in ["card_overlay_silenced", "card_overlay_locked", "card_overlay_used", "card_overlay_charged", "kind_defense", "kind_utility", "kind_damage", "rarity_common", "rarity_rare", "rarity_legendary", "special_fleeting", "special_fused", "special_power", "wax_seal", "wax_seal_on_card", "hot_meal", "elem_hidden", "essence_hidden", "essence_unknown", "bottles_frame", "artifacts_frame", "slot_strip", "hint_close", "icon_close", "sign_victory"]:
		print(n, " -> ", UiSkin.path_of(n))
	t.quit()
