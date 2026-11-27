extends RefCounted
## The tickets on the real screens (Main): the bar in a fight, its Use / Throw away buttons, a ticket's choice, the
## "You won a card!" banner, a ticket offered with full slots, the shop's tickets.

var t: SceneTree
var out := ""


func _shot(name: String) -> void:
	await t.process_frame
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _bar(root: Node) -> TicketBar:
	for n in root.find_children("*", "TicketBar", true, false):
		return n
	return null


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	out = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://tickets_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m.run.tickets = ["health", "encore"]
	m._start_fight(["iceling", "ashling"])
	await t.create_timer(6.0).timeout
	print("where in the fight: ", m._tickets.where(), "  fight: ", m.current.fight.get_class() if m.current is FightScreen else "?")
	await _shot("t1_fight")
	var bar := _bar(root)
	bar._on_pressed(bar._views[0])
	await t.create_timer(0.3).timeout
	await _shot("t2_menu")
	bar.close_menu()
	# the Encore, used in the fight
	m._tickets.use(1, bar._views[1])
	await t.create_timer(2.0).timeout
	print("encore after use: ", (m.current.fight as MarbleBridge).m.encore, " tickets ", m.run.tickets)
	# a Marble Ticket: its choice
	m.run.tickets.append("marble")
	await t.create_timer(0.3).timeout
	m._tickets.use(1, null)
	await t.create_timer(0.6).timeout
	await _shot("t3_pick")
	var po: PickOverlay = root.find_children("*", "PickOverlay", true, false)[0]
	var hand_before: int = (m.current.fight as MarbleBridge).m.hand.size()
	po._click(0)
	await t.create_timer(2.5).timeout
	print("marble ticket: hand ", hand_before, " -> ", (m.current.fight as MarbleBridge).m.hand.size(), " tickets ", m.run.tickets)
	await _shot("t4_after_marble")
	# the banner
	WinBanner.play(m.overlay_layer, "You won a card!")
	await t.create_timer(0.7).timeout
	await _shot("t5_banner")
	await t.create_timer(2.0).timeout
	# a ticket offered with full slots, then room made
	m.run.tickets = ["wax", "discount"]
	m._tickets.offer("money")
	await t.create_timer(0.6).timeout
	await _shot("t6_offer_full")
	m.run.discard_ticket(0)
	await t.create_timer(0.4).timeout
	await _shot("t7_offer_room")
	var off: TicketOffer = root.find_children("*", "TicketOffer", true, false)[0]
	off._take_it()
	await t.create_timer(0.4).timeout
	print("after take: ", m.run.tickets)
	# the shop
	m.run.amber = 300
	m.show_map()  # (the real way in: from the map, the merchant's cart on the stage)
	await t.create_timer(4.0).timeout
	m._show_shop(m.run.shop_stock())
	await t.create_timer(7.0).timeout
	var shop_node = m._overlay if is_instance_valid(m._overlay) else m.current
	if shop_node is ShopScreen and shop_node.get("_true_cart"):
		shop_node._zoom_in()
		await t.create_timer(2.0).timeout
	print("where in the shop: ", m._tickets.where())
	await _shot("t8_shop")
	# every ticket, big, for a look at the pictures
	var sheet := Control.new()
	sheet.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.08)
	bg.size = sheet.size
	sheet.add_child(bg)
	for i in Tickets.ALL.size():
		var tv := TicketView.make(String(Tickets.ALL[i].id), 110.0)
		tv.position = Vector2(40 + (i % 6) * 310, 60 + (i / 6) * 200)
		sheet.add_child(tv)
		var l := UiTheme.label(String(Tickets.ALL[i].name), 18, Color.WHITE)
		l.position = tv.position + Vector2(0, 118)
		sheet.add_child(l)
	var cl := CanvasLayer.new()
	cl.layer = 100
	cl.add_child(sheet)
	root.add_child(cl)
	await t.create_timer(0.8).timeout
	await _shot("t9_all_tickets")
