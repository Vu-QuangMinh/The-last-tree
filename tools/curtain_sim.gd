extends SceneTree
## The Curtain map: how many rooms a player gets through before the boss, for a few ways of playing.
## godot --headless --path . -s tools/curtain_sim.gd


const N := 400


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	for style in ["rush", "hunter", "climber", "slow", "random"]:
		var total := 0
		var lo := 999
		var hi := 0
		var forced := 0
		var kinds := {}
		for k in N:
			var r := RunState.new()
			r.rng.seed = k + 1
			r.map_style = "curtain"
			r.new_map()
			var n := 0
			while n < 60:
				var opts: Array = r.options()
				var o: Vector2i = _pick(r, opts, style)
				if o.x == r.map.size() - 1:
					if opts.size() == 1:
						forced += 1
					break
				if r.is_free_tile(o.x, o.y):  # (a tailwind or a portal: no room)
					kinds[r.map[o.x][o.y].type] = kinds.get(r.map[o.x][o.y].type, 0) + 1
					r.free_step(o.y, o.x)
					continue
				var node := r.move_to(o.y, o.x)
				n += 1
				kinds[node.type] = kinds.get(node.type, 0) + 1
			total += n
			lo = mini(lo, n)
			hi = maxi(hi, n)
		var per := []
		for t in ["fight", "event", "elite", "shop", "rest", "treasure", "portal", "wind"]:
			per.append("%s %.1f" % [t, kinds.get(t, 0) / float(N)])
		print("%-8s rooms before the boss: avg %.1f (min %d, max %d) · the Curtain forced the boss %d%% · %s" % [style, total / float(N), lo, hi, 100 * forced / N, ", ".join(per)])
	quit()


## rush: straight up, and the boss as soon as it is offered. hunter: a merchant, camp, elite or "?" when there is one.
## climber: a mix (straight up half the time). slow: always to the side (a level at a time). random: anything.
## Only rush takes the boss before the Curtain forces it.
func _pick(r: RunState, opts: Array, style: String) -> Vector2i:
	var boss := Vector2i(r.map.size() - 1, 0)
	var tiles := opts.filter(func(o): return o != boss)
	if tiles.is_empty() or (style == "rush" and boss in opts):
		return boss
	if style == "random":
		return opts[r.rng.randi() % opts.size()]
	var straight := tiles.filter(func(o): return o.x == r.row + 2)
	var side := tiles.filter(func(o): return o.x != r.row + 2)
	var from: Array = tiles
	match style:
		"rush":
			from = straight if not straight.is_empty() else tiles
		"slow":
			from = side if not side.is_empty() else tiles
		"climber":
			from = straight if (not straight.is_empty() and r.rng.randf() < 0.5) else (side if not side.is_empty() else tiles)
		"hunter":
			var good := tiles.filter(func(o): return r.map[o.x][o.y].type in ["elite", "shop", "rest", "event", "treasure"])
			from = good if not good.is_empty() else tiles
	return from[r.rng.randi() % from.size()]
