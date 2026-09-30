extends RefCounted

const OPS := ["strike", "burn", "stoke", "poison", "freeze", "weak", "expose", "curse", "ethereal", "execute",
	"shatter", "purge", "steal", "redirect", "convert", "shield", "aegis", "thorns", "heal", "cleanse",
	"sacrifice", "draw", "amplify", "echo", "overload", "duplicate", "retain", "passive"]
const MULTI := ["burn", "strike", "barrage"]  # also shown hitting all enemies

var out := "user://vfx"
var root: Window
var tree: SceneTree


func run(t: SceneTree) -> void:
	tree = t
	root = t.root
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var ops: Array = OPS
	if args.size() > 1:
		ops = Array(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://vfx_save.json")
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["stone_knight", "ashling", "gale_sprite"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	for i in 10:
		await tree.process_frame
	for op in ops:
		for multi in ([false, true] if op in MULTI else [false]):
			var spell := _spell_for(gd.db, op)
			var eff := _eff_in(spell, op)
			if eff.is_empty():
				eff = {"op": op, "n": 2}
			var targets := []
			if not (op in FightScreen.SELF_OPS or op in SpellFx.CHANT_OPS or op in SpellFx.POWER_OPS or op == "draw"):
				targets = f.enemies.duplicate() if multi else [f.enemies[1]]
			var card: SpellCard = fs._cards[0] if not fs._cards.is_empty() else null
			var sp := {"id": card.spell.id if card else "x", "pattern": spell.get("pattern", "FF")}
			var name: String = op + ("_all" if multi else "")
			fs._anim({"type": "spell_effect", "op": op, "eff": eff, "targets": targets, "spell": sp})
			var start := Time.get_ticks_msec()
			var k := 0
			var i := 0
			while Time.get_ticks_msec() - start < 1900:
				await tree.process_frame
				i += 1
				if i % 2 == 0:
					var img := root.get_texture().get_image()
					img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
					img.save_jpg("%s/%s_%03d.jpg" % [out, name, k], 0.85)
					k += 1
			print("VFX ", name, " frames ", k)
			for j in 20:
				await tree.process_frame


func _spell_for(db, op: String) -> Dictionary:
	for s in db.all_spells:
		if _eff_in(s, op).size() > 0:
			return s
	return {"pattern": "FWA"}


func _eff_in(s: Dictionary, op: String) -> Dictionary:
	var stack: Array = [s.get("effects", [])]
	while not stack.is_empty():
		var x = stack.pop_back()
		if x is Dictionary:
			if x.get("op", "") == op:
				return x
			for v in x.values():
				stack.append(v)
		elif x is Array:
			for v in x:
				stack.append(v)
	return {"op": op, "n": 2} if s.is_empty() else {}
