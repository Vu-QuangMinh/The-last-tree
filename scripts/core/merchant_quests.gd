class_name MerchantQuests
extends RefCounted
## The merchant's three favours. They carry over from run to run (SaveManager keeps {"done": n, "open": bool}); the
## thing he asks for must be in your current run to hand it over, and it's gone once you do.
##   1) a Blanket (the Bramble Matron always drops it): your next spell from him is free.
##   2) a Chair (the Chairman's: not in the game yet): your next artifact from him is free.
##   3) something to numb his pain (the Sake Bottle: the Samurai's Retainer gives it): all the bottles he has, free.
## From the visit after the third one on, he sits drunk on his chair for good: 10% off everything, and his family
## picture lies on the counter for you to steal.
## One visit: either he asks for a favour, or you bring one back, never both.

const ITEMS := ["blanket", "chair", "sake_bottle"]
const DISCOUNT := 0.1

## He asks (one line per bubble), what you answer to take it on, and what he says then.
const ASK := [
	["Ah, a customer! Before you look around, friend... might I trouble you for a favour?",
		"The nights get colder every year, and these old bones feel every one of them.",
		"Bring me a blanket, would you? A thick one. They say the Bramble Matron sleeps under a fine one, though she won't part with it kindly."],
	["Back again! The blanket keeps me warm, bless you. But my back...",
		"Standing behind this cart all day, every day. It's killing me, friend.",
		"A chair. That's all I ask. There's a fellow up the road who calls himself the Chairman. Sits on the finest chair you ever saw, and never gets up."],
	["Warm, and sitting down. I should be happy, shouldn't I?",
		"But some nights the house is too quiet. I still set out two cups.",
		"Bring me something to numb this pain, friend. They say a loyal servant up the road raises a drink to anyone who bests his master fairly."],
]
const ACCEPT := ["I'll find you a blanket.", "I'll get you that chair.", "I'll find you something."]
const ACCEPTED := ["Bless you, friend. I'll keep the kettle warm.", "Wonderful. I'll save you a seat. Ha! A seat.", "...Thank you. Don't tell anyone I asked."]
const DECLINE := "Not now."

## You carry what he asked for: what he says when he sees it, the button, and what he says once it's his.
const SEE := [
	["Is that... a blanket? For me?"],
	["A chair! A real chair!"],
	["Sake? ...Yes. Yes, that will do."],
]
const HAND_OVER := ["Give him the Blanket", "Give him the Chair", "Give him the Sake Bottle"]
const KEEP := "Keep it for now"
const THANKS := [
	["It's warm. It's still warm.", "My boy used to drag one just like it around the house.",
		"A gift for a gift: pick any spell on my shelf. The first one's on the house."],
	["Ahh... I haven't sat down in... I don't remember how long.",
		"Take an artifact, friend. Any one you like. The first one's free."],
	["Ahh. That's the stuff.", "Take my bottles. All of them. I won't need them where I'm going. Which is nowhere. Ha!",
		"You're a good kid, you know that? My Adam... he'd be about your age."],
]

## He's waiting for it and you don't have it yet.
const REMIND := ["No blanket yet? The Bramble Matron, friend. Mind the thorns.",
	"The Chairman's chair, friend. My back is counting on you.",
	"Something to numb the pain... You'll know it when you find it."]
const LATER := "Come back next time, friend. One favour a visit."
const DRUNK := ["*hic* My favourite customer! Ten percent off, as promised. Don't tell anyone.",
	"Did I ever tell you about my boy? ...No? Good. Good. *hic*",
	"Sit, sit! Oh. There's only the one chair. *hic*"]
const PICTURE := "He nods off over his cart. A small framed picture lies by his elbow."
const STEAL := "Steal the picture"
const LEAVE_IT := "Leave it"


## What talking to him does now: "ask" (a new favour), "return" (you carry what he asked for), "remind" (you don't
## yet), "later" (you already talked this visit), "drunk" (all three done, from the next visit on), "" (nothing:
## all three done this very visit).
static func mode(state: Dictionary, owned: Array, talked: bool) -> String:
	var done := int(state.get("done", 0))
	if is_drunk(state):
		return "drunk"
	if talked:
		return "later"
	if done >= ITEMS.size():
		return ""
	if not state.get("open", false):
		return "ask"
	return "return" if ITEMS[done] in owned else "remind"


## The mark over his head: "!" a new favour, "?" you can hand one over, "" nothing new.
static func mark(state: Dictionary, owned: Array, talked: bool) -> String:
	return {"ask": "!", "return": "?"}.get(mode(state, owned, talked), "")


## He's drunk on his chair (a visit after the third favour was done).
static func is_drunk(state: Dictionary) -> bool:
	return int(state.get("done", 0)) >= ITEMS.size() and state.get("drunk", false)


## He takes on the next favour.
static func accept(state: Dictionary) -> void:
	state.open = true


## The favour is done: returns which one (0, 1 or 2).
static func complete(state: Dictionary) -> int:
	var n := int(state.get("done", 0))
	state.done = n + 1
	state.open = false
	return n


## A visit begins: after the third favour, from the next visit on, he is drunk.
static func visit(state: Dictionary) -> void:
	if int(state.get("done", 0)) >= ITEMS.size():
		state.drunk = true
