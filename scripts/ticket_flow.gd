class_name TicketFlow
extends RefCounted
## Tickets on the screen (the user, 2026-11-27; see Tickets): where you are (what can be used), using one (in a fight
## through MarbleBridge.use_ticket, outside one on the run), and the scene that offers a ticket you found (take it or
## leave it; with your slots full, use or throw one away first, from the ticket bar). Same `main.` pattern as EventFlow.

var main: Main
var _busy := false  # a ticket's choice (or its offer) is on the screen


func _init(p_main: Main) -> void:
	main = p_main


func _fight_screen() -> FightScreen:
	return main.current as FightScreen if is_instance_valid(main.current) and main.current is FightScreen else null


## Where you are, for the tickets: "fight", "shop", "event", "map", or "" (nothing can be used just now).
func where() -> String:
	if _busy or main.run == null:
		return ""
	var fs := _fight_screen()
	if fs != null and not fs.map_mode and fs.fight != null and not fs.fight.over and not is_instance_valid(main._overlay):
		if not (fs.fight is MarbleBridge):
			return ""  # (the old rules' fights, in the tests: no tickets)
		if fs.busy or fs.aiming or fs.chant_mode != "" or fs.pick_view != null or fs.move_view != null or not (fs.phase in ["build", "spells"]):
			return ""
		return "fight"
	if is_instance_valid(main._overlay) and main._overlay is ShopScreen or main.current is ShopScreen:
		return "shop"
	if is_instance_valid(main._overlay) and main._overlay is EventStage:
		return "event"
	return "map"


func use(slot: int, view: TicketView) -> void:
	var run := main.run
	var w := where()
	if run == null or slot < 0 or slot >= run.tickets.size() or w == "":
		return
	var id := String(run.tickets[slot])
	if not Tickets.usable_in(id, w):
		return
	_busy = true
	var at := Juice.center(view) if is_instance_valid(view) else Vector2(140, 140)
	if w != "fight" and Tickets.usable_in(id, w):
		Juice.pop(main.get_tree(), at, Color(1.0, 0.7, 0.45))  # (the ticket is torn: a burst of light from its slot)
	if w == "fight":
		await _use_in_fight(slot, id, view)
	else:
		await _use_outside(slot, id, w)
	_busy = false


# ------------------------------------------------------------------ in a fight

func _use_in_fight(slot: int, id: String, view: TicketView) -> void:
	var fs := _fight_screen()
	var br := fs.fight as MarbleBridge
	var mf := br.m
	var arg := {}
	match id:
		"marble", "greater_marble":
			var n := 3 if id == "marble" else 5
			var k := 1 if id == "marble" else 2
			var ms := main.run.marble_offer(n)
			var got := await PickOverlay.ask(main.overlay_layer, "Choose %s" % ("a marble" if k == 1 else "2 marbles"),
				"Yours for good, and out on the table right now.", ms.map(func(m): return PickOverlay.marble_view(m)), k)
			if got.size() < k:
				return
			arg.marbles = got.map(func(i): return ms[i])
		"duplication", "removal":
			if mf.hand.is_empty():
				Events.toast.emit("No marble is out this turn", Color(1, 0.8, 0.4))
				return
			var got := await PickOverlay.ask(main.overlay_layer, "Duplicate a marble" if id == "duplication" else "Remove a marble",
				"Its copy joins your bag for good, and comes out now." if id == "duplication" else "It leaves your bag for good; another is drawn in its place.",
				mf.hand.map(func(m): return PickOverlay.marble_view(m)))
			if got.is_empty():
				return
			arg.hand = int(got[0])
		"fixing":
			var broken := []
			for ci in mf.run.cards.size():
				if mf.broken(ci):
					broken.append(ci)
			if broken.is_empty():
				Events.toast.emit("None of your spells is broken", Color(1, 0.8, 0.4))
				return
			var got := await PickOverlay.ask(main.overlay_layer, "Fix a spell", "It works again, with its full Durability.",
				broken.map(func(ci): return PickOverlay.spell_view(main.run.spell(String(mf.run.cards[ci])))))
			if got.is_empty():
				return
			arg.ci = int(broken[int(got[0])])
		"timeout":
			var swaps := await _timeout_swaps(mf)
			if swaps.is_empty():
				return
			arg.swaps = swaps
	if not is_instance_valid(fs) or fs.fight.over:
		return
	fs._bottle_from = view.get_global_rect().get_center() if is_instance_valid(view) else Vector2(140, 140)
	fs.busy = true
	await br.use_ticket(slot, arg)
	if not is_instance_valid(fs):
		return
	fs._h_hud._sync_views()
	fs.busy = false
	fs._h_hud._refresh_all()
	if fs.fight.over:
		await fs._h_anim._finish()


## The Ticket of Timeout: swap cards between your active row and your backpack, as many times as you like; Done ends it.
func _timeout_swaps(mf: MarblesFight) -> Array:
	var cards: Array = mf.run.cards.duplicate()
	var pack: Array = mf.mrun.backpack.duplicate()
	var swaps := []
	if pack.is_empty():
		Events.toast.emit("Your backpack is empty", Color(1, 0.8, 0.4))
		return []
	while true:
		var a := await PickOverlay.ask(main.overlay_layer, "Timeout", "Choose a card of your active row to take out%s." % (" (or Back when you are done)" if not swaps.is_empty() else ""),
			cards.map(func(id): return PickOverlay.spell_view(main.run.spell(String(id)), 0.75)))
		if a.is_empty():
			break
		var b := await PickOverlay.ask(main.overlay_layer, "Timeout", "Choose the backpack card that takes its place.",
			pack.map(func(id): return PickOverlay.spell_view(main.run.spell(String(id)), 0.75)))
		if b.is_empty():
			continue
		var ci := int(a[0])
		var bi := int(b[0])
		var out: String = cards[ci]
		cards[ci] = pack[bi]
		pack[bi] = out
		swaps.append([ci, bi])
	return swaps


# ------------------------------------------------------------------ outside a fight

func _use_outside(slot: int, id: String, w: String) -> void:
	var run := main.run
	var done := true
	var said := ""
	match id:
		"health", "money", "discount":
			said = run.use_ticket_plain(id)
		"mystery":
			run.discard_ticket(slot)
			var a := Tickets.random(run.rng, ["mystery"])
			var b := Tickets.random(run.rng, ["mystery"])
			run.gain_ticket(a)
			Events.toast.emit("The Mystery Ticket turns into two", Color(1, 0.9, 0.55))
			if not run.gain_ticket(b):
				_busy = false
				await offer(b)
			return
		"marble", "greater_marble":
			var n := 3 if id == "marble" else 5
			var k := 1 if id == "marble" else 2
			var ms := run.marble_offer(n)
			var got := await PickOverlay.ask(main.overlay_layer, "Choose %s" % ("a marble" if k == 1 else "2 marbles"), "For your bag, for good.",
				ms.map(func(m): return PickOverlay.marble_view(m)), k)
			done = got.size() >= k
			for i in got:
				run.marble_bag.append(ms[i])
		"duplication", "removal", "carving":
			var idx: Array = range(run.marble_bag.size()) if id != "carving" else run.plain_marbles()
			if idx.is_empty():
				Events.toast.emit("You have no plain marble to carve" if id == "carving" else "Your bag is empty", Color(1, 0.8, 0.4))
				return
			var heads := {"duplication": ["Duplicate a marble", "Its copy joins your bag, for good."],
				"removal": ["Remove a marble", "It leaves your bag, for good."], "carving": ["Carve a marble", "Choose a plain marble to carve."]}
			var got := await PickOverlay.ask(main.overlay_layer, heads[id][0], heads[id][1], idx.map(func(i): return PickOverlay.marble_view(run.marble_bag[i], 72.0)))
			done = not got.is_empty()
			if done:
				var bi := int(idx[int(got[0])])
				match id:
					"duplication":
						run.marble_bag.append((run.marble_bag[bi] as Dictionary).duplicate())
					"removal":
						run.marble_bag.remove_at(bi)
					"carving":
						var syms := run.carving_offer(3)
						var c := String(run.marble_bag[bi].c)
						var s := await PickOverlay.ask(main.overlay_layer, "Carve a marble", "Choose its carving.",
							syms.map(func(sy): return PickOverlay.marble_view({"c": c, "sym": sy})))
						done = not s.is_empty()
						if done:
							run.marble_bag[bi].sym = String(syms[int(s[0])])
		"wax":
			var ids := run.upgradable()
			if ids.is_empty():
				Events.toast.emit("No spell has a spot left for wax", Color(1, 0.8, 0.4))
				return
			var got := await PickOverlay.ask(main.overlay_layer, "Wax a spell", "Choose the spell; then the spot for the wax.", ids.map(func(sid): return PickOverlay.spell_view(run.spell(String(sid)), 0.75)))
			done = not got.is_empty()
			if done:
				var seal := SealScreen.new()
				seal.setup(run, String(ids[int(got[0])]))
				main.overlay_layer.add_child(seal)
				await seal.done
				seal.queue_free()
		"blessing":
			var ids := run.cursed_spells()
			if ids.is_empty():
				Events.toast.emit("None of your spells is cursed", Color(1, 0.8, 0.4))
				return
			var got := await PickOverlay.ask(main.overlay_layer, "Lift a curse", "Choose the spell; one of its curses is lifted.", ids.map(func(sid): return PickOverlay.spell_view(run.spell(String(sid)), 0.75)))
			done = not got.is_empty()
			if done:
				var sid := String(ids[int(got[0])])
				var k: String = (run.curses.get(sid, ["burden"]) as Array)[0]
				run.remove_curse(sid, k)
				said = "%s is lifted from %s" % [RunState.CURSE_NAMES.get(k, "A curse"), run.spell(sid).get("name", sid)]
		"upgrade":
			var ids := run.upgradable_cards()
			if ids.is_empty():
				Events.toast.emit("Your cards are all at their last level", Color(1, 0.8, 0.4))
				return
			var got := await PickOverlay.ask(main.overlay_layer, "Upgrade a card", "It goes up one level.", ids.map(func(sid): return PickOverlay.spell_view(run.spell(String(sid)), 0.75)))
			done = not got.is_empty()
			if done:
				run.upgrade_card(String(ids[int(got[0])]))
				said = "%s goes up a level" % run.spell(String(ids[int(got[0])])).get("name", "")
		"rehearsal":
			if w != "shop":
				return
		_:
			return
	if not done:
		return
	run.discard_ticket(run.tickets.find(id) if slot >= run.tickets.size() or String(run.tickets[slot]) != id else slot)
	Audio.play("elem_pickup")
	if said != "":
		Events.toast.emit(said, Color(1, 0.9, 0.55))
	var shop: ShopScreen = main._overlay as ShopScreen if is_instance_valid(main._overlay) and main._overlay is ShopScreen else (main.current as ShopScreen if main.current is ShopScreen else null)
	if shop != null:
		shop.ticket_used(id)


# ------------------------------------------------------------------ the Carver (2026-11-27)

## Carve n marbles of your bag: pick a marble, 3 carvings are rolled for THAT marble, pick one and it solidifies (a bright
## moment: the marble pops in the spinning light). n times.
func carve(n: int) -> void:
	var run := main.run
	if run == null or run.marble_bag.is_empty():
		return
	_busy = true
	for k in n:
		var bag: Array = run.marble_bag
		var got := await PickOverlay.ask(main.overlay_layer, "The Carver: carve a marble (%d of %d)" % [k + 1, n],
			"Choose a marble; then choose one of the 3 carvings rolled for it.", bag.map(func(m): return PickOverlay.marble_view(m, 72.0)), 1, false)
		if got.is_empty():
			break
		var bi := int(got[0])
		var c := String(bag[bi].c)
		var syms := run.carving_offer(3)
		var s := await PickOverlay.ask(main.overlay_layer, "Carve it", "Its carving, for good.",
			syms.map(func(sy): return PickOverlay.marble_view({"c": c, "sym": sy}, 110.0)), 1, false)
		if s.is_empty():
			break
		run.marble_bag[bi].sym = String(syms[int(s[0])])
		Audio.play("artifact_get")
		await WinBanner.play(main.overlay_layer, "Carved!", Color(1.0, 0.88, 0.5), MarbleView.make(run.marble_bag[bi], 170.0))
	_busy = false


# ------------------------------------------------------------------ a ticket found

## A ticket is offered (after a fight, from an event): the ticket, big, what it does, Take it / Leave it. With your
## slots full Take waits: use or throw one away from the ticket bar first. Returns when you have chosen.
func offer(id: String) -> void:
	if id == "" or main.run == null:
		return
	var ov := TicketOffer.new()
	ov.id = id
	ov.run = main.run
	main.overlay_layer.add_child(ov)
	await ov.closed
