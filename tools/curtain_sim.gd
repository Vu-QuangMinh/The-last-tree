extends SceneTree
## The Curtain map: how many rooms a player gets through before the boss, for a few ways of playing.
## godot --headless --path . -s tools/curtain_sim.gd


const N := 2000


func _init() -> void:
	for style in ["rush", "careful", "greedy", "max", "random"]:
		var total := 0
		var lo := 999
		var hi := 0
		var caught := 0
		var kinds := {}
		for k in N:
			var r := RunState.new()
			r.rng.seed = k + 1
			r.map_style = "curtain"
			r.new_map()
			var n := 0
			while true:
				var opts: Array = r.options()
				if opts[0].x == r.map.size() - 1:
					if r.caught():
						caught += 1
					break
				var o: Vector2i = _pick(r, opts, style)
				var node := r.move_to(o.y, o.x)
				n += 1
				kinds[node.type] = kinds.get(node.type, 0) + 1
			total += n
			lo = mini(lo, n)
			hi = maxi(hi, n)
		var per := []
		for t in ["fight", "event", "elite", "shop", "rest"]:
			per.append("%s %.1f" % [t, kinds.get(t, 0) / float(N)])
		print("%-8s rooms before the boss: avg %.1f (min %d, max %d) · caught by the Curtain %d%% · %s" % [style, total / float(N), lo, hi, 100 * caught / N, ", ".join(per)])
	quit()


## rush: always up. careful: sideways only for a camp, merchant or elite, and only with a move to spare.
## greedy: sideways for anything but a fight, while it is safe. max: sideways whenever it is safe. random: anything.
func _pick(r: RunState, opts: Array, style: String) -> Vector2i:
	var up := opts.filter(func(o): return o.x > r.row)
	var side := opts.filter(func(o): return o.x == r.row)
	if style == "random":
		return opts[r.rng.randi() % opts.size()]
	var safe_side := side.filter(func(_o): return (r.turns + 1) / MapGen.CURTAIN_EVERY - r.curtain_hold <= r.row)
	var good := func(o: Vector2i) -> bool: return r.map[o.x][o.y].type in ["elite", "shop", "rest"]
	if style == "careful":
		safe_side = safe_side.filter(func(_o): return (r.turns + 2) / MapGen.CURTAIN_EVERY - r.curtain_hold <= r.row)
		safe_side = safe_side.filter(good)
	elif style == "greedy":
		safe_side = safe_side.filter(func(o): return r.map[o.x][o.y].type != "fight")
	elif style == "rush":
		safe_side = []
	if not safe_side.is_empty():
		return safe_side[r.rng.randi() % safe_side.size()]
	var best := up.filter(good)
	var from: Array = best if not best.is_empty() else up
	return from[r.rng.randi() % from.size()]
