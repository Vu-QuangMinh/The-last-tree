extends SceneTree
## Headless: runs the menu puppets for 30 simulated minutes and counts the moments two of them overlap (they must not walk through each other).
## godot --headless --path . --script res://tools/menu_actors_test.gd


func _init() -> void:
	var a := MenuActors.new()
	a.floor_top = 600.0
	a.floor_bottom = 860.0
	root.add_child(a)
	a.size = Vector2(1920, 1080)
	a._ready()
	var bad := 0
	var kinds := {}
	var frames := 0
	var maxn := 0
	for i in 36000:
		a._process(0.05)
		frames += 1
		var acts: Array = a._actors
		maxn = maxi(maxn, acts.size())
		for x in acts.size():
			for y in range(x + 1, acts.size()):
				var p: Vector2 = acts[x].node.position
				var q: Vector2 = acts[y].node.position
				var on_screen: bool = p.x > -20.0 and p.x < 1940.0 and q.x > -20.0 and q.x < 1940.0
				if on_screen and a._overlap(p, acts[x].side, q, acts[y].side):
					bad += 1
					var k: String = str(acts[x].state) + "/" + str(acts[y].state)
					kinds[k] = int(kinds.get(k, 0)) + 1
	print(kinds)
	print("frames ", frames, "  most puppets at once ", maxn, "  overlapping pair-frames ", bad)
	quit()
