class_name EventFlow
extends RefCounted
## Moved out of scripts/main.gd (docs/plan_dot3_kien_truc.md): the code is unchanged except that main's own members are reached through `main.`.

var main: Main


func _init(p_main: Main) -> void:
	main = p_main


func _show_event(ev: Dictionary) -> void:
	var slot := Audio.event_slot(String(ev.get("id", "")))
	if slot != "" and not ev.get("again", false):
		Audio.play_music(slot)  # (the event's own music; the map's comes back with the map)
	if ev.has("scene"):
		_bear_scene(ev)  # (played out on the stage itself)
		return
	var labels: Array = ev.options.map(func(o): return o.label)
	var pick := func(i: int):
		var o: Dictionary = ev.options[i]
		if o.has("next"):
			# a second page: its own words and options (the Bard: "Can I have it?")
			var page := ev.duplicate()
			page.text = o.next.text
			page.options = o.next.options
			page["again"] = true
			_show_event(page)
			return
		if o.get("minigame", "") == "farm":
			_farm_game(ev)
			return
		if o.get("minigame", "") == "fish":
			var g := FishGame.new()
			g.act = main.run.act
			g.finished.connect(func(wh, ba, sw):
				var reward := main.run.fish_reward(wh, ba, sw)
				if UiSkin.is_puppet():
					_tally_on_stage(ev, String(reward.text), "Enjoy your fish!")  # (the old man and his stream stay; the tally goes in the box)
					return
				var after_l := main._message(ev.title, reward.text, ["Continue"], Color(0.8, 0.7, 1))
				after_l.pressed.connect(func(_k): main.show_map()))
			_stage_overlay(g)
			return
		if o.has("recycle"):
			_event_recycle(ev, o)
			return
		if o.get("fuse", "") == "half" and is_instance_valid(main._overlay) and main._overlay is EventStage and EventStage.LAYOUTS.get(String(ev.get("id", "")), {}).get("stage_fuse", false):
			# An Abandoned Camp on its stage: the spells are picked and fused right there, in the cauldron
			var es_f: EventStage = main._overlay
			es_f.continue_label = String(o.get("ok", "Continue"))
			es_f.continued.connect(main.show_map, CONNECT_ONE_SHOT)
			es_f.fuse_cancelled.connect(func(): _show_event(ev), CONNECT_ONE_SHOT)
			es_f.start_fuse(String(o.text))
			return
		if o.get("fuse", "") == "half":
			# An Abandoned Camp: the campfire's fusing, without the wax; backing out returns to the camp
			var fs := FuseScreen.new()
			fs.setup(main.run)
			fs.no_wax = true
			main._room_bg = "campfire_fuse"
			fs.back.connect(func(): _show_event(ev))
			fs.fused.connect(func(_sp):
				var after_l := main._message(ev.title, String(o.text), ["Continue"], Color(0.8, 0.7, 1))
				after_l.pressed.connect(func(_k): main.show_map()))
			main._swap(fs)
			return
		if o.has("outcomes") or o.has("by_water") or o.has("by_kind"):
			if int(o.get("wax", 0)) > 0:
				_event_wax_pick(ev, o, 0)
			elif o.has("recycle"):
				_event_recycle(ev, o)
			elif int(o.get("pick_artifact", 0)) > 0:
				_event_artifact_pick(ev, o, [])
			elif o.get("pick_spell", false):
				_event_spell_pick(ev, o)
			elif o.get("pick_bottle", false):
				_event_bottle_pick(ev, o)
			else:
				_event_result(ev, o, -1)
			return
		match ev.options[i].get("do", ""):
			"note_swap":
				_note_pick(ev)
				return
		var res: Dictionary = main.run.choose_event_option(ev.options[i])
		if main.run.player.is_dead():
			main.run.over = true
			main._end_run()
			return
		if is_instance_valid(main._overlay) and main._overlay is EventStage and EventStage.LAYOUTS.has(String(ev.get("id", ""))) and not res.get("fight", false):
			# (an old-style option, like leaving the note: told on the stage as well, no black screen)
			var es0: EventStage = main._overlay
			es0.continue_label = String(o.get("ok", "Continue"))
			es0.continued.connect(main.show_map, CONNECT_ONE_SHOT)
			es0.show_result(String(res.text), "", false, main.run.spell(res.spell) if res.has("spell") else {})
			return
		var learned: Control = SpellCard.make(main.run.spell(res.spell)) if res.has("spell") else null  # the spell you just learned, shown as its card
		var after := main._message(ev.title, res.text, ["Fight!" if res.get("fight", false) else "Continue"], Color(0.8, 0.7, 1), learned)
		after.pressed.connect(func(_k):
			if res.get("fight", false):
				main.run.current_node()["as"] = "fight"
				main._show_loadout(main.run.encounter_ids())
			else:
				main.show_map())
	if UiSkin.is_puppet() and EventStage.has_layout(String(ev.get("id", ""))):
		_event_stage(ev, pick)  # (the props of the story stand on the stage; click one to choose)
		return
	var s := MessageScreen.new()  # (each option a card; the ones you can't afford greyed out)
	s.title = ev.title
	s.body = ev.text
	s.buttons = labels
	s.title_color = Color(0.8, 0.7, 1)
	s.act = main.run.act
	s.cards = true
	s.disabled = ev.options.map(func(o): return not main.run.can_choose(o))
	s.pressed.connect(pick)
	main._put(s)


## A rewritten event's choice: roll what happens, and say it (only the outcome's own words). Then the bottles that
## didn't fit (swap screen), then the fight it started, or the map.
func _event_result(ev: Dictionary, opt: Dictionary, bottle_at: int, spell_id := "") -> void:
	var on_its_stage: bool = is_instance_valid(main._overlay) and main._overlay is EventStage
	main._picked = on_its_stage  # (an artifact it gives is shown in its own result, not in the "You found an artifact!" pop-up)
	var res := main.run.event_outcome(opt, bottle_at, spell_id)
	main._picked = false
	if main.run.player.is_dead():
		main.run.over = true
		main._end_run()
		return
	if res.get("again", false):
		# Skipping Stones: what happened, then the event's own choices again
		var again := ev.duplicate()
		again.text = res.text
		again["again"] = true  # (the lake and its stones stay; the stone that was just thrown skips across)
		var opts := []
		for o in ev.options:
			var c: Dictionary = o.duplicate()
			if c.label == "Skip a stone":
				c.label = "Skip another stone"
			opts.append(c)
		again.options = opts
		_show_event(again)
		return
	if res.has("then"):
		# the same choices again, under what just happened (Far from Any Road: following the voice)
		var page := ev.duplicate()
		page.text = res.text
		page.options = res.then.options
		page["again"] = true
		_show_event(page)
		return
	# what comes after the words: a fight, a room (a campfire, the merchant, a boss), or the map
	var go_on := func():
		if res.has("room"):
			_event_room(String(res.room))
		elif res.has("fight"):
			main.run.current_node()["as"] = res.fight.kind
			var ids: Array = res.fight.ids
			if ids.is_empty():
				ids = main.run.encounter_ids()
			else:
				main.run.set_encounter(ids)
			main._show_loadout(ids)
		else:
			main.show_map()
	# an event with props that tells its result on its own stage (no black screen): the words in the hint panel, then Continue
	if is_instance_valid(main._overlay) and main._overlay is EventStage and EventStage.LAYOUTS.has(String(ev.get("id", ""))) and res.overflow.is_empty():
		var es: EventStage = main._overlay
		es.continued.connect(go_on, CONNECT_ONE_SHOT)
		es.continue_label = String(res.ok) if String(res.get("ok", "")) != "" else ("Fight!" if res.has("fight") or res.get("room", "") == "boss" else "Continue")
		var soaked_after: Dictionary = main.run.spell(String(res.soaked)) if res.has("soaked") else {}
		var soaked_before: Dictionary = {}
		if not soaked_after.is_empty():  # (the Water is not in the card yet: it flies in from the river)
			soaked_before = soaked_after.duplicate(true)
			soaked_before.pattern = String(soaked_after.pattern).left(maxi(0, String(soaked_after.pattern).length() - 1))
			soaked_before.size = String(soaked_before.pattern).length()
			soaked_before.burden = String(soaked_after.get("burden", "")).left(maxi(0, String(soaked_after.get("burden", "")).length() - 1))
		es.result_artifact = String(res.get("artifact", ""))  # (its card stands over the box, with the words)
		if res.get("curse_card", false) and not soaked_after.is_empty():
			# the Whispering Well's grudge: its words and "Oh no...", then the spell gets its Water, then Next
			es.continued.disconnect(go_on)
			es.continued.connect(func():
				await es.curse_card(soaked_before, soaked_after)
				es.continued.connect(go_on, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
			es.show_result(String(res.text), _result_how(ev, opt, String(res.text), spell_id), false)
			return
		es.show_result(String(res.text), _result_how(ev, opt, String(res.text), spell_id), false, main.run.spell(res.spell) if res.has("spell") else soaked_after, soaked_before)
		return
	var shown: Control = ArtifactCard.make(Artifacts.view(res.artifact, false)) if res.has("artifact") else null
	if res.has("spell"):
		shown = SpellCard.make(main.run.spell(res.spell))  # (a spell you learned: its card)
	var fights: bool = res.has("fight") or res.get("room", "") == "boss"
	var after := main._message(ev.title, res.text, ["Fight!" if fights else "Continue"], Color(0.8, 0.7, 1), shown)
	after.pressed.connect(func(_k):
		if res.overflow.is_empty():
			go_on.call()
		else:
			_bottle_swap(res.overflow, go_on))


## They See Me Rolling / the bear's revenge, on the stage with his puppet. Stopping him pays; stepping aside sets up
## his revenge; the revenge is an elite fight with the Enraged Rolling Bear, you Stunned on the first turn.
func _bear_scene(ev: Dictionary) -> void:
	var sc := BearRollScene.new()
	sc.mode = "revenge" if ev.scene == "bear_revenge" else "meet"
	sc.act = main.run.act
	sc.hurt.connect(func():
		main.run.player.take_effect(5.0)
		if main.run.player.is_dead():
			main.run.over = true
			main._end_run())
	sc.paid.connect(func(): main.run.amber += 50)
	sc.chosen.connect(func(what: String):
		if what == "fight":
			main.run.stun_next = 1
			main.run.current_node()["as"] = "elite"
			main.run.set_encounter(["enraged_bear"])
			main._show_loadout(["enraged_bear"])
			return
		if what != "stop":  # (stopping him was paid for as it happened: hurt, paid)
			main.run.bear_choice(what)
		if main.run.player.is_dead():
			main.run.over = true
			main._end_run()
			return
		main.show_map())
	_stage_overlay(sc)


## A "?" event played with props on the stage (EventStage): `pick(i)` is the same choice-maker the plain event screen uses.
func _event_stage(ev: Dictionary, pick: Callable) -> void:
	var s := EventStage.new()
	s.ev = ev
	s.edit_allowed = main._test_mode
	s.run_ref = main.run
	s.act = main.run.act
	s.again = ev.get("again", false)
	s.disabled = ev.options.map(func(o): return not main.run.can_choose(o))
	s.picked.connect(pick)
	# the options that ask for one of your spells, artifacts or bottles are answered on the stage itself: they stand there, glowing
	for i in ev.options.size():
		var o: Dictionary = ev.options[i]
		if not main.run.can_choose(o):
			if o.has("recycle"):
				s.hidden_opts.append(i)  # (the Recycler: nothing of that kind to give, so no button for it)
			continue
		var kind := ""
		var ids: Array = []
		var need := 1
		if o.has("recycle"):
			kind = String(o.recycle)
			ids = main.run.recyclable(kind)
		elif int(o.get("pick_artifact", 0)) > 0:
			kind = "artifact"
			ids = main.run.giftable_artifacts()
			need = int(o.pick_artifact)
		elif o.get("pick_spell", false):
			kind = "spell"
			ids = main.run.spellbook.duplicate()
		elif o.get("pick_bottle", false):
			kind = "bottle"
			ids = main.run.player.bottles.duplicate()
		if kind == "" or ids.size() < need:
			continue
		for id in ids:
			s.items.append({"opt": i, "kind": kind, "id": String(id), "need": need, "spell": main.run.spell(id) if kind == "spell" else {}})
	s.item_picked.connect(func(opt: int, picked_ids: Array):
		var o: Dictionary = ev.options[opt]
		if String(o.get("do", "")) == "note_swap":
			_note_done(ev, String(picked_ids[0]))
			return
		if int(o.get("wax", 0)) > 0:
			_event_wax_seal(ev, o, String(picked_ids[0]))
		elif o.has("recycle") and main._overlay is EventStage:
			_recycle_on_stage(ev, o, String(picked_ids[0]), opt)
		elif o.has("recycle"):
			_event_recycle(ev, o, String(picked_ids[0]))
		elif int(o.get("pick_artifact", 0)) > 0:
			_event_result(ev, o, -1, ",".join(picked_ids))
		elif o.get("pick_spell", false):
			_event_result(ev, o, -1, String(picked_ids[0]))
		else:
			_event_result(ev, o, main.run.player.bottles.find(String(picked_ids[0]))))
	_stage_overlay(s)
	if is_instance_valid(main.current) and main.current is FightScreen:
		main.current.peek_hud(false)  # (an event: no HUD at all)


## Put `c` on the stage, like a fight: the stage is put up first if it isn't (the test rooms have none).
func _stage_overlay(c: Control) -> void:
	# (a stage already up, the map's or a page before this one, is kept with its scenery: Skipping Stones' next throw)
	var up: bool = is_instance_valid(main.current) and main.current is FightScreen and main.current.map_mode
	if UiSkin.is_puppet() and not main._on_stage():
		if not up:
			var base := main._new_fight_screen(main.run.make_fight([]))
			base.map_mode = true
			main._swap(base)
		c.set("on_stage", true)
		main._set_overlay(c)
	else:
		main._put(c)


## After a minigame: the event's own stage again (its props stay), the tally in the hint panel, then Continue.
func _tally_on_stage(ev: Dictionary, text: String, ok := "Continue") -> void:
	var fev := ev.duplicate()
	fev["options"] = []
	fev["text"] = ""
	var es := EventStage.new()
	es.ev = fev
	es.again = true
	es.act = main.run.act
	es.continue_label = ok
	es.continued.connect(main.show_map, CONNECT_ONE_SHOT)
	_stage_overlay(es)
	es.show_result.call_deferred(text)


## The Farmer's Farm: the shooting in the wheat, then the farmer's tally (and your Leaves).
func _farm_game(ev: Dictionary) -> void:
	var g := FarmGame.new()
	g.act = main.run.act
	if UiSkin.is_puppet() and not main._on_stage():
		# (always on the stage, like a fight: from the test rooms too, where events otherwise have no stage)
		var base := main._new_fight_screen(main.run.make_fight([]))
		base.map_mode = true
		main._swap(base)
		g.on_stage = true
		main._set_overlay(g)
	else:
		main._put(g)
	g.finished.connect(func(gob, hob, fai):
		var res := main.run.farm_reward(gob, hob, fai)
		if UiSkin.is_puppet() and main._on_stage():
			_tally_on_stage(ev, String(res.text), "Happy to help!")  # (the farmer and his wheat stay; the tally goes in the box)
			return
		var after := main._message(ev.title, res.text, ["Continue"], Color(0.8, 0.7, 1))
		after.pressed.connect(func(_k): main.show_map()))


## Far from Any Road: which spell burns? (Changing your mind takes you back to the event.)
func _event_spell_pick(ev: Dictionary, opt: Dictionary) -> void:
	var ids := main.run.spellbook.duplicate()
	var sub := "Choose a spell to cast for the tree." if opt.get("keep_spell", false) else "Choose a spell to burn. It is gone for the rest of the run."
	var ch := main._choice(ev.title, sub, ids.map(func(id): return main.run.spell(id)), [], true, true)
	ch.chosen.connect(func(i):
		if i < 0:
			_show_event(ev)
		else:
			_event_result(ev, opt, -1, ids[i]))


## The Mystery Shed: which of your artifacts become their new toys? One at a time, as many as the option asks for
## (two); changing your mind takes you back to the event, with nothing given.
func _event_artifact_pick(ev: Dictionary, opt: Dictionary, picked: Array) -> void:
	if _offers_on_stage(ev) and picked.is_empty():  # (the Mystery Shed: your artifacts stand on the stage, glowing; click two)
		var need0 := int(opt.get("pick_artifact", 1))
		(main._overlay as EventStage).offer_items(main.run.giftable_artifacts().map(func(id): return {"opt": ev.options.find(opt), "kind": "artifact", "id": String(id), "need": need0, "spell": {}}), "Give each a new toy")
		return
	var need := int(opt.get("pick_artifact", 1))
	var ids := main.run.giftable_artifacts().filter(func(id): return not (id in picked))
	var who := "the boy" if picked.is_empty() else "the girl"
	var ch := main._choice(ev.title, "Choose an artifact to give %s as a new toy (%d of %d). It's theirs now." % [who, picked.size() + 1, need], [], ids.map(func(id): return Artifacts.view(id, id in main.run.artifacts_plus)), true, true)
	ch.chosen.connect(func(i):
		if i < 0:
			_show_event(ev)
			return
		var now: Array = picked + [ids[i]]
		if now.size() < need:
			_event_artifact_pick(ev, opt, now)
		else:
			_event_result(ev, opt, -1, ",".join(now)))


## The Wax Witch: pick a spell, then the Essence the wax goes on, once per drop of blood; then the price is taken.
## (Changing your mind at the first pick takes you back to the witch, with nothing paid.)
var _wax_done := 0
## How the stage plays an option's result: by its label, and for the vine / the bridge by what happened.
func _result_how(ev: Dictionary, opt: Dictionary, text: String, spell_id: String) -> String:
	var id := String(ev.get("id", ""))
	if id == "overgrown_vine" and opt.has("by_kind"):
		return "vine_" + String(main.run.spell(spell_id).get("kind", "utility"))
	if id == "broken_bridge":
		if String(opt.label).begins_with("Jump"):
			return "bridge_fail" if text.contains("splash") else "bridge_ok"
		return "bridge_around"
	return EventStage.how_for_result(id, String(opt.label), text)


## The Recycler, on his stage: your item goes into him, he hands back three, and the one you click is yours (then his words and Continue).
func _recycle_on_stage(_ev: Dictionary, opt: Dictionary, give: String, opt_index: int) -> void:
	var es: EventStage = main._overlay
	var kind: String = opt.recycle
	var offer := main.run.recycle_offer(kind, give)
	var entries: Array = offer.map(func(id): return {"opt": opt_index, "kind": kind, "id": String(id), "need": 1, "spell": main.run.spell(id) if kind == "spell" else {}})
	es.traded.connect(func(take: String):
		main._picked = true  # (the card he handed over is the one shown: no "You found an artifact!" pop-up)
		main.run.recycle(kind, give, take)
		main._picked = false
		es.present(take)  # (the one you took grows and stays; the other two are gone)
		es.continue_label = String(opt.get("ok", "Continue"))
		es.continued.connect(main.show_map, CONNECT_ONE_SHOT)
		es.show_result(String(opt.text), "", true), CONNECT_ONE_SHOT)
	es.trade(give, entries, "\"RECYCLE!\" He tosses it onto his cart, rummages through the pile, and holds out three things. Take one.")


## Is this event played on its stage with the options answered by items that stand there (EventStage.offer_items)?
func _offers_on_stage(ev: Dictionary) -> bool:
	return is_instance_valid(main._overlay) and main._overlay is EventStage and EventStage.LAYOUTS.get(String(ev.get("id", "")), {}).get("offer_on_stage", false)


## The Wax Witch, on the stage: the wax is dropped on the spell you picked (its card and its Essence, SealScreen laid over the stage), then the next drop or the result.
func _event_wax_seal(ev: Dictionary, opt: Dictionary, spell_id: String) -> void:
	var es: EventStage = main._overlay
	es.hide_items(true)
	es.hard_lock = true
	var seal := SealScreen.new()
	seal.setup(main.run, spell_id)
	seal.embedded = true
	seal.can_back = true
	seal.hint_changed.connect(es.set_hint)
	seal.backed.connect(func():  # (Back / right-click before the stamp: the spells again)
		seal.queue_free()
		_event_wax_pick(ev, opt, _wax_done))
	seal.done.connect(func():
		seal.queue_free()
		_event_wax_pick(ev, opt, _wax_done + 1))
	es.add_child(seal)


func _event_wax_pick(ev: Dictionary, opt: Dictionary, done: int) -> void:
	var need := int(opt.get("wax", 1))
	if done >= need:
		_event_result(ev, opt, -1)
		return
	var ids := main.run.waxable_spells()
	if _offers_on_stage(ev):  # (the cards stand on the stage, glowing; the wax is dropped on one right there)
		_wax_done = done
		(main._overlay as EventStage).hard_lock = done > 0  # (the first drop is still undone: the other prop can be chosen instead)
		(main._overlay as EventStage).offer_items(ids.map(func(id): return {"opt": ev.options.find(opt), "kind": "spell", "id": String(id), "need": 1, "spell": main.run.spell(id)}), "A drop of wax on this spell (%d of %d)" % [done + 1, need])
		(main._overlay as EventStage).set_hint("Pick a spell for the drop of wax%s." % ("" if need == 1 else " (%d of %d)" % [done + 1, need]))
		return
	var ch := main._choice(ev.title, "Choose a spell for the purple wax (%d of %d)." % [done + 1, need], ids.map(func(id): return main.run.spell(id)), [], done == 0, true)
	ch.chosen.connect(func(i):
		if i < 0:
			_show_event(ev)
			return
		var seal := SealScreen.new()
		seal.setup(main.run, ids[i])
		seal.done.connect(func(): _event_wax_pick(ev, opt, done + 1))
		main._swap(seal))


## The Recycler: pick what you give him (changing your mind takes you back to him), then one of the 3 he offers back.
func _event_recycle(ev: Dictionary, opt: Dictionary, give_now := "") -> void:
	var kind: String = opt.recycle
	var ids := main.run.recyclable(kind)
	var take_pick := func(give: String) -> void:
		var offer := main.run.recycle_offer(kind, give)
		var finish := func(i: int) -> void:
			main.run.recycle(kind, give, offer[i])
			var shown: Control = (SpellCard.make(main.run.spell(offer[i])) as Control) if kind == "spell" else ((ArtifactCard.make(Artifacts.view(offer[i], false)) as Control) if kind == "artifact" else null)
			var after := main._message(ev.title, String(opt.text), ["Continue"], Color(0.8, 0.7, 1), shown)
			after.pressed.connect(func(_k): main.show_map())
		var sub := "\"RECYCLE!\" He tosses it onto his cart, rummages through the pile, and holds out three things. Take one."
		if kind == "bottle":
			_bottle_cards(ev.title, sub, offer, [], finish)
		else:
			var ch := main._choice(ev.title, sub, offer.map(func(x): return main.run.spell(x)) if kind == "spell" else [], offer.map(func(x): return Artifacts.view(x, false)) if kind == "artifact" else [], false, true)
			ch.chosen.connect(finish)
	if give_now != "":
		take_pick.call(give_now)  # (picked on the stage already)
		return
	var what := {"spell": "spell", "artifact": "artifact", "bottle": "bottle"}[kind] as String
	var sub0 := "Which %s do you give him?" % what
	if kind == "bottle":
		_bottle_cards(ev.title, sub0, ids, ["Keep my bottles"], func(i):
			if i >= ids.size():
				_show_event(ev)
			else:
				take_pick.call(ids[i]))
	else:
		var ch := main._choice(ev.title, sub0, ids.map(func(x): return main.run.spell(x)) if kind == "spell" else [], ids.map(func(x): return Artifacts.view(x, x in main.run.artifacts_plus)) if kind == "artifact" else [], true, true)
		ch.chosen.connect(func(i):
			if i < 0:
				_show_event(ev)
			else:
				take_pick.call(ids[i]))


## Bottles to choose from, as option cards (name and what it does), plus any extra plain options after them.
func _bottle_cards(title: String, body: String, ids: Array, extra: Array, then: Callable) -> void:
	var s := MessageScreen.new()
	s.title = title
	s.body = body
	s.buttons = ids.map(func(b): var d := Bottles.get_def(b); return "%s: %s" % [d.get("name", b), d.get("desc", "")]) + extra
	s.title_color = Color(0.8, 0.7, 1)
	s.act = main.run.act
	s.cards = true
	s.pulse_n = ids.size()
	s.pressed.connect(then)
	main._put(s)


## The Ruined Watchtower: off to what you saw (the merchant's shop, the Abandoned Camp event). A boss is a random Act 1 one, with no talk first and full boss rewards,
## but the act doesn't end.
func _event_room(kind: String) -> void:
	var n := main.run.current_node()
	n["as"] = kind
	if kind == "boss":
		n["no_advance"] = true
		main.run.no_talk_next = true
		var bosses: Array = EnemyDefs.BOSSES[1]
		var ids: Array = [bosses[main.run.rng.randi() % bosses.size()]]
		main.run.set_encounter(ids)
		main._show_loadout(ids)
	elif kind == "lost_camp":  # (the tent seen from the tower: on to An Abandoned Camp)
		var camp := MapEvents.get_event("lost_camp")
		main._room_bg = main.EVENT_BG.get("lost_camp", "")
		_show_event(camp)
	else:
		main._enter_room(kind)


## The Hollow Stump: which of your bottles goes in? (Changing your mind takes you back to the event.)
func _event_bottle_pick(ev: Dictionary, opt: Dictionary) -> void:
	var names: Array = main.run.player.bottles.map(func(b): var d := Bottles.get_def(b); return "%s: %s" % [d.get("name", b), d.get("desc", "")])
	var s := MessageScreen.new()
	s.title = ev.title
	s.body = "Which bottle do you throw in?"
	s.buttons = names + ["Keep my bottles"]
	s.title_color = Color(0.8, 0.7, 1)
	s.act = main.run.act
	s.cards = true
	s.pulse_n = names.size()
	s.pressed.connect(func(i):
		if i >= main.run.player.bottles.size():
			_show_event(ev)
		else:
			_event_result(ev, opt, i))
	main._put(s)


## More bottles than slots: drag them in and out until you like what you carry. The rest stay behind.
func _bottle_swap(extra: Array, then: Callable) -> void:
	var s := BottleSwapScreen.new()
	s.slots = main.run.bottle_slots()
	s.mine = main.run.player.bottles.duplicate()
	s.found = extra.duplicate()
	s.act = main.run.act
	s.done.connect(func(kept):
		main.run.player.bottles = kept.duplicate()
		then.call())
	main._put(s)


## A Note to Yourself: pick which of your spells goes into the note (for a later run); you take the one already in it.
func _note_pick(ev: Dictionary) -> void:
	var ids := main.run.storable_spells()
	var held: Dictionary = main.run.db.get_spell(main.run.note_spell_id())
	if _offers_on_stage(ev):  # (your spells stand on the stage, glowing: click the one you leave in the note)
		(main._overlay as EventStage).offer_items(ids.map(func(id): return {"opt": 0, "kind": "spell", "id": String(id), "need": 1, "spell": main.run.spell(id)}), "Leave this spell in the note")
		return
	var ch := main._choice(ev.title, "The note holds %s. Choose one of your spells to leave in it, for a later run." % held.name, ids.map(func(id): return main.run.spell(id)), [], false, true)
	ch.chosen.connect(func(i):
		if i < 0:
			main.show_map()
			return
		var left: String = main.run.spell(ids[i]).name
		var took := main.run.note_swap(ids[i])
		var after := main._message(ev.title, "You take %s, and leave %s in the note." % [main.run.db.get_spell(took).name, left], ["Continue"], Color(0.8, 0.7, 1), SpellCard.make(main.run.spell(took)))
		after.pressed.connect(func(_k): main.show_map()))


## A Note to Yourself, on the stage: you left `left_id` in the note and took what it held; told in the hint panel, with the card you took.
func _note_done(_ev: Dictionary, left_id: String) -> void:
	var left: String = main.run.spell(left_id).name
	var took := main.run.note_swap(left_id)
	var es: EventStage = main._overlay
	es.continue_label = "Thanks, past me!"
	es.continued.connect(main.show_map, CONNECT_ONE_SHOT)
	es.show_result("You take %s, and leave %s in the note." % [main.run.db.get_spell(took).name, left], "", false, main.run.spell(took))
