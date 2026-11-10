class_name EnemyDefs
extends RefCounted
## Every enemy: Essence pattern (elements, left to right), moves (cycled in order), passives.
## Moves are used in the listed order, looping. Normal enemies mix offence, defence and utility.
## Move kinds: attack {n, hits}, armor {pos}, mend {el, n, who: self/ally/all}, shuffle, silence {turns}, frail {turns},
## lock {len}, steal {n}, confuse (Hypnotize: you can't see the enemies' intents next turn), blind {turns}, poison {n}, freeze {n}, ethereal, empower {n}, brittle {turns},
## summon {id, n}, toll, invert, hex, mimic. A move may carry `also` (a second move done the same turn).

const E := {
	# ---------------- act 1: the Verdant Circle (druids, changed animals, elemental spirits). tier = how early in the
	# act it can show up (see POOLS); its Essence is exactly its pattern (no extra Essence on deeper floors).
	"ashling": {"name": "Ashling", "act": 1, "tier": 1.0, "hp": "FFA", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small fire spirit."},
	"iceling": {"name": "Iceling", "act": 1, "tier": 1.0, "hp": "WWA", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small ice spirit."},
	"zephling": {"name": "Zephling", "act": 1, "tier": 1.0, "hp": "AAW", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small air spirit."},
	"purple_slime": {"name": "Purple Slime", "act": 1, "tier": 1.5, "hp": "WFWAW", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Wobbly, wet and purple."},
	"green_slime": {"name": "Green Slime", "act": 1, "tier": 1.5, "hp": "AWAFA", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Light as air, for a slime."},
	"yellow_slime": {"name": "Yellow Slime", "act": 1, "tier": 1.5, "hp": "FAFWF", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Warm to the touch. Don't touch it."},
	"bramble_back": {"name": "Bramble Back", "act": 1, "tier": 2.0, "hp": "FAFWFAF", "moves": [{"kind": "attack", "n": 5}], "passives": ["thorns"],
		"flavor": "An enraged porcupine on two legs."},
	"winged_tortoise": {"name": "Winged Tortoise", "act": 1, "tier": 2.0, "flying": true, "passives": ["flying"], "hp": "WAWWAWW", "moves": [{"kind": "armor", "pos": -1}, {"kind": "attack", "n": 5}],
		"flavor": "A shell that learned to fly."},
	"leech_bat": {"name": "Leech Bat", "act": 0, "tier": 2.5, "flying": true, "passives": ["flying"], "hp": "AFAWAFA", "moves": [{"kind": "attack", "n": 5, "also": {"kind": "mend", "el": "random", "n": 1, "who": "self"}}],
		"flavor": "Shiny fangs, and it feeds on every bite."},
	"hush_moth": {"name": "Hush Moth", "act": 1, "tier": 2.0, "flying": true, "passives": ["flying"], "hp": "AWAAWAW", "moves": [{"kind": "silence", "turns": 1}, {"kind": "attack", "n": 5}],
		"flavor": "Its wings steal your words."},
	"cinder_hound": {"name": "Cinder Hound", "act": 0, "tier": 2.5, "hp": "FFAFFWFFAF", "moves": [{"kind": "attack", "n": 6}], "passives": ["burn_immune"],
		"flavor": "Flame Essence burns under its skin like tattoos."},
	"mirror_fairy": {"name": "Mirror Fairy", "act": 1, "tier": 2.5, "hp": "AWFWAAWFWA", "size": 3.0, "passives": ["mirror_deflect"], "moves": [{"kind": "confuse"}, {"kind": "attack", "n": 6}],
		"flavor": "A fairy's face in a mirror, her hands gripping it from behind."},
	"yeti": {"name": "Yeti", "act": 0, "tier": 2.5, "hp": "WWAWWAWWAWWA", "moves": [{"kind": "freeze", "n": 2}, {"kind": "attack", "n": 7}],
		"flavor": "Big, white and very cold."},
	"greenseer": {"name": "Greenseer", "act": 1, "tier": 3.0, "hp": "AWFAWAFWAWFAW", "moves": [{"kind": "summon", "ids": ["purple_slime", "green_slime", "yellow_slime"], "n": 1}, {"kind": "mend", "el": "random", "n": 2, "who": "self"}, {"kind": "attack", "n": 6}],
		"flavor": "A druid in moss clothes under a big mushroom hat."},
	"rolling_bear": {"name": "Rolling Bear", "act": 1, "tier": 3.0, "hp": "FWFAFWFAFWFAFWF", "moves": [{"kind": "attack", "n": 3, "also": {"kind": "empower", "n": 2}}],
		"flavor": "It rolls. It never stops rolling."},
	"giant_slime": {"name": "Giant Slime", "act": 1, "tier": 3.0, "hp": "FWAFWAFWAF", "moves": [{"kind": "attack", "n": 7}], "passives": ["slime_burst"],
		"flavor": "A giant rainbow slime."},
	"tomato_knight": {"name": "Tomato Knight", "act": 0, "tier": 3.0, "hp": "FFWFFAFFWFFAFFW", "moves": [{"kind": "armor", "pos": -1}, {"kind": "attack", "n": 7}],
		"moves2": [{"kind": "attack", "n": 4, "hits": 2}], "passives": ["rage_at_half"],
		"flavor": "Ripe, red and armoured."},
	# ---------------- in reserve (not in any act's pool for now; kept to reuse in later acts)
	"puddle_slime": {"name": "Puddle Slime", "act": 0, "hp": "WAW", "moves": [{"kind": "attack", "n": 3}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "vulnerable", "n": 1}],
		"flavor": "It keeps refilling itself."},
	"gale_sprite": {"name": "Gale Sprite", "act": 0, "hp": "AFA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "armor", "pos": 0}, {"kind": "freeze", "n": 1}],
		"flavor": "Two quick jabs of wind."},
	"stone_knight": {"name": "Stone Knight", "act": 0, "hp": "FFW", "moves": [{"kind": "armor", "pos": 1}, {"kind": "attack", "n": 8}, {"kind": "vulnerable", "n": 1, "also": {"kind": "attack", "n": 3}}],
		"flavor": "Braces, then swings."},
	"tidecaller": {"name": "Tidecaller", "act": 0, "hp": "WAWA", "moves": [{"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "attack", "n": 5}, {"kind": "freeze", "n": 1}],
		"flavor": "The tide always comes back."},
	"mirror_wisp": {"name": "Mirror Wisp", "act": 0, "hp": "AWF", "moves": [{"kind": "attack", "n": 4, "also": {"kind": "shuffle"}}, {"kind": "blind", "turns": 1}, {"kind": "armor", "pos": 0}],
		"flavor": "Never in the same order twice."},
	"frost_hex": {"name": "Frost Hex", "act": 0, "hp": "WWA", "moves": [{"kind": "freeze", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}],
		"flavor": "Your fingers go numb."},
	"pickpocket_imp": {"name": "Pickpocket Imp", "act": 0, "hp": "AFA", "moves": [{"kind": "steal", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "armor", "pos": 0}],
		"flavor": "It wears what it steals."},
	# ---------------- act 2
	# The Anxious Armadillo (Act 2, met once ever: the second fight of Act 2 on your very first run). He never attacks:
	# he only curls up tighter (+2 Thorns a turn: your Release hitting him hurts you that much). Beaten, he doesn't
	# break: FightScreen._armadillo_ending plays his scene (sad, he tries to hop away, the string yanks him up).
	"anxious_armadillo": {"name": "Anxious Armadillo", "act": 2, "unique": true, "no_extra": true, "hp": "WFAAFWWAFFAWWFAA",
		"passives": ["armadillo"], "moves": [{"kind": "grow_thorns", "n": 2}],
		"flavor": "Curled up, spiky, and very, very nervous."},
	# Act 2 (see POOLS; exact numbers: no act bonus). The Starving Mobs: three peasants, 7 Essence each.
	"mob_pitchfork": {"name": "Pitchfork Peasant", "act": 2, "size": 1.5, "member": true, "no_extra": true, "no_bonus": true, "hp": "FFWAF",
		"moves": [{"kind": "attack", "n": 2, "also": {"kind": "bleed", "n": 2}}],
		"flavor": "It used to turn hay."},
	"mob_slingshot": {"name": "Slingshot Peasant", "act": 2, "size": 1.5, "member": true, "no_extra": true, "no_bonus": true, "hp": "WAAFW",
		"moves": [{"kind": "attack", "n": 2, "also": {"kind": "drain_essence", "n": 1}}],
		"flavor": "Stones are the only thing left that is free."},
	"mob_torch": {"name": "Torch Peasant", "act": 2, "size": 1.5, "member": true, "no_extra": true, "no_bonus": true, "hp": "AFFWA",
		"moves": [{"kind": "ignite_spell", "n": 1, "turns": 9999, "until_cast": true}],
		"flavor": "Everything he owned has already burned."},
	# The Undying Duo: the skeleton keeps his first Essence armoured until it is his last; behind him the Necromancer can't be touched.
	"shield_bearer": {"name": "Skeleton Shield Bearer", "act": 2, "size": 2.0, "member": true, "no_extra": true, "no_bonus": true, "hp": "WWFAWWFAWFA", "passives": ["big_shield"],
		"moves": [{"kind": "guard"}],
		"flavor": "Nobody told him the war was over."},
	"necromancer": {"name": "Necromancer", "act": 2, "size": 1.3, "member": true, "no_extra": true, "no_bonus": true, "hp": "FAW", "passives": ["behind_shield"],
		"moves": [{"kind": "poison", "n": 3}, {"kind": "mend", "el": "random", "n": 3, "who": "ally", "cap": 11}],  # (the heal: back up to the Bearer's 11; with him down, it does nothing)
		"flavor": "Brave, as long as somebody else is holding the shield."},
	# The Sentinels: large golems. Each does nothing until it is down to 12 Essence, or for 3 turns. Alone they are normal fights;
	# together they are the Twin Sentinels, a mini boss. Red (a red core): hits for 3 once, twice, four times, stuns itself for a turn, starts over.
	"sentinel": {"name": "Red Sentinel", "act": 2, "size": 2.0, "tint": Color(0.75, 0.2, 0.15), "member": true, "no_extra": true, "no_bonus": true, "hp": "WAFWAWFAWWFAAWFW", "passives": ["dormant"],
		"moves": [{"kind": "attack", "n": 3}, {"kind": "attack", "n": 3, "hits": 2}, {"kind": "attack", "n": 3, "hits": 4}, {"kind": "recharge"}],
		"flavor": "Its red core turns slowly toward you."},
	# Blue (a blue core): every blow freezes your Essence too. Freeze stacks.
	"blue_sentinel": {"name": "Blue Sentinel", "act": 2, "size": 2.0, "tint": Color(0.2, 0.4, 0.8), "member": true, "no_extra": true, "no_bonus": true, "hp": "AWFAWFWWFAFWAWAF", "passives": ["dormant"],
		"moves": [{"kind": "freeze", "n": 1, "also": {"kind": "attack", "n": 2}}, {"kind": "freeze", "n": 2, "also": {"kind": "attack", "n": 4}}, {"kind": "freeze", "n": 4, "also": {"kind": "attack", "n": 4}}],
		"flavor": "Its blue core turns slowly toward you."},
	# The Rot Snake: a big, half-rotten snake. Poison 5, then a bite for 5 and Poison 1, in turn.
	"rot_snake": {"name": "Rot Snake", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "WFAWWFAFWA",
		"moves": [{"kind": "poison", "n": 5, "sfx": "sfx_snake_hiss"}, {"kind": "attack", "n": 5, "also": {"kind": "poison", "n": 1}}],
		"flavor": "Half of it is already dead. The other half hasn't noticed."},
	# The Headless Horseman: two moves in turn. At 10 Essence or less his next move is to throw his head, which silences every spell;
	# from then on he only has the first move.
	"headless_horseman": {"name": "Headless Horseman", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "FWAFWAAWFFWAFAWF", "passives": ["head_throw"],
		"moves": [{"kind": "attack", "n": 6, "hits": 2}, {"kind": "silence", "turns": 1, "also": {"kind": "attack", "n": 4}}],
		"head_move": {"kind": "silence", "all": true, "turns": 1, "head": true},
		"flavor": "He holds it up to his neck to scream."},
	# The Scavengers: four animals with human posture, 6 Essence each. Flying: see EnemyState.flying.
	"scav_rat": {"name": "Scavenger Rat", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "FWAFWA",
		"moves": [{"kind": "attack", "n": 1, "hits": 3}],
		"flavor": "Three small bites, and it has already gone through your pockets."},
	"scav_hyena": {"name": "Scavenger Hyena", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "WAFWAF",
		"moves": [{"kind": "empower", "n": 1, "who": "all", "name": "Howl"}],
		"flavor": "It laughs, and the others get braver."},
	"scav_vulture": {"name": "Scavenger Vulture", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "flying": true, "hp": "AFWAFW", "passives": ["flying"],
		"moves": [{"kind": "attack", "n": 2, "hits": 2}],
		"flavor": "It is in no hurry."},
	"scav_beetle": {"name": "Scavenger Dung Beetle", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "WWAAFF", "passives": ["shell"],
		"moves": [{"kind": "attack", "n": 3}],
		"flavor": "Somebody has to clean up."},
	# The Maddened Soldier: ragged, a shiny red eye, his hands fused into a two-handed sword he drags along the ground. Hits for 2;
	# every spell you cast is one more hit on his next attack (that turn only: it starts over each turn).
	"mad_soldier": {"name": "Maddened Soldier", "act": 2, "size": 1.5, "member": true, "no_extra": true, "no_bonus": true, "hp": "FWWAFAFWAAWF", "passives": ["maddened"],
		"moves": [{"kind": "attack", "n": 2}],
		"flavor": "The sword isn't in his hands. It is his hands."},
	# The Tree Dwellers: a tree with two people growing out of it as branches, each with a bow and its own 8 Essence.
	"tree_dweller_a": {"name": "Tree Dweller", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "WFAWFA",
		"moves": [{"kind": "poison", "n": 2}],
		"flavor": "He stood his post. He is still standing it."},
	"tree_dweller_b": {"name": "Tree Dweller", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "AWFAAW",
		"moves": [{"kind": "poison", "n": 2}],
		"flavor": "The bark has almost reached her eyes."},
	# The Bog Lantern: an enormous angler fish on two legs (any of its moves, at random), and its lamp, a separate enemy hanging on
	# its hook, on a clock: 2, 1, then at 0 it stuns you and starts over. It is part of the fish: put out, it stays there, dark, and
	# lights up again after a turn, its clock at 2.
	"bog_fish": {"name": "Bog Lantern", "act": 2, "member": true, "size": 2.0, "no_extra": true, "no_bonus": true, "hp": "WAFWWAFAWAFW", "passives": ["lure"], "random_moves": true,
		"moves": [{"kind": "attack", "n": 5}, {"kind": "poison", "n": 3}, {"kind": "grow_thorns", "n": 2}],
		"flavor": "Don't look at the light."},
	"bog_lamp": {"name": "Lamp", "act": 2, "hang": 150.0, "member": true, "no_extra": true, "no_bonus": true, "hp": "FF",
		"moves": [{"kind": "glow", "n": 2}, {"kind": "stun", "turns": 1}],
		"flavor": "Brighter. Brighter. Brighter."},
	# The Bug Hunter: a little brass bell on legs, its head the bell, a striker in its hands. It hunts bugs: it strikes its
	# own head (5 every turn: the bell rings and shakes) and keeps a clock of 3 turns; on its 4th turn it rings the alarm
	# and a Sentinel (red or blue) comes to destroy the bug. Only once: after that, only the strikes. (Was a robot.)
	"bug_hunter": {"name": "The Bug Hunter", "act": 2, "call_once": true, "member": true, "no_extra": true, "no_bonus": true, "hp": "FWAFFWAWW",
		"moves": [{"kind": "attack", "n": 5, "also": {"kind": "summon_clock", "n": 3}}, {"kind": "attack", "n": 5, "also": {"kind": "summon_clock", "n": 2}},
			{"kind": "attack", "n": 5, "also": {"kind": "summon_clock", "n": 1}}, {"kind": "attack", "n": 5, "also": {"kind": "summon", "ids": ["sentinel", "blue_sentinel"], "n": 1}}],
		"flavor": "It hunts for bugs. When it finds one, it rings."},
	# ---------------- act 3
	"inverter": {"name": "Inverter", "act": 3, "hp": "FWFW", "moves": [{"kind": "invert"}, {"kind": "attack", "n": 5}, {"kind": "armor", "pos": 0}],
		"flavor": "Fire becomes water, water becomes fire."},
	"warded_golem": {"name": "Warded Golem", "act": 3, "hp": "FFWWAA", "moves": [{"kind": "attack", "n": 5}, {"kind": "armor", "pos": 2}, {"kind": "vulnerable", "n": 1}], "passives": ["warded"],
		"flavor": "Short chants bounce off."},
	"echo_wraith": {"name": "Echo Wraith", "act": 3, "hp": "AWAF", "moves": [{"kind": "confuse"}, {"kind": "attack", "n": 2}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}], "passives": ["echo"],
		"flavor": "Everything it does, it does twice."},
	"mimic_chest": {"name": "Mimic Chest", "act": 3, "hp": "FWAF", "moves": [{"kind": "mimic"}, {"kind": "attack", "n": 6}, {"kind": "armor", "pos": 0}],
		"flavor": "It becomes your last words, backwards."},
	"last_gasp_spore": {"name": "Last Gasp Spore", "act": 3, "hp": "AWW", "moves": [{"kind": "attack", "n": 3}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "poison", "n": 1}], "passives": ["last_gasp"],
		"flavor": "Bursts when it dies."},
	"storm_imp": {"name": "Storm Imp", "act": 3, "hp": "AAF", "moves": [{"kind": "attack", "n": 1, "hits": 3}, {"kind": "deflect"}, {"kind": "empower", "n": 1}],
		"flavor": "Flickers out of reach."},
	# ---------------- elites
	"storm_rider": {"name": "Storm Rider", "act": 2, "elite": true, "retired": true, "hp": "AAFAA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "attack", "n": 2, "also": {"kind": "shuffle"}}],
		"flavor": "Fast, and hard to read."},
	"lockwarden": {"name": "The Warden", "act": 2, "elite": true, "hp": "WFWAF", "moves": [{"kind": "lock", "len": 2}, {"kind": "attack", "n": 5}, {"kind": "attack", "n": 5}],
		"flavor": "Chains your spells shut."},
	# The Samurai and his Retainer, Tasuke (an Act 2 mini boss, met together; exact numbers: no act bonus). The Samurai stands on the LEFT and the Retainer
	# on the RIGHT (his arms in the pictures reach out to the left, toward the Samurai: the bottle flies that way).
	# The Samurai: one slash for 10; Deflect (his sword held sideways: on the turn he shows it, your Release can't touch either of them,
	# each Essence is cut out of the air by an air slash, but your spells still work); an Iai charge, 3 x 3.
	# The Retainer looks after him: a bottle (cleanses him, and he is Impervious for a turn: no status can be put on
	# him), the fan (Mend 2 random Essence), the gong (+1 Power for the rest of the fight).
	# The Samurai falls first: the Retainer yields and the fight is won. The Retainer falls first: the Samurai swears
	# revenge and gains 5 Power at once.
	# His stance shows what is coming ("pose" on each move; the puppet's picture is samurai_<pose>.png): sword held high
	# in In no kamae for the slash, Ko gasumi for the Deflect, Sha no kamae for the Iai charge.
	"samurai_retainer": {"name": "Retainer", "act": 2, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "hp": "AWFAWFW",
		"passives": ["retainer"],
		"moves": [{"kind": "bottle", "who": "samurai", "pose": "bottle"}, {"kind": "mend", "el": "random", "n": 2, "who": "samurai", "cap": 15, "sfx": "fan", "pose": "fan"},
			{"kind": "empower", "n": 1, "who": "samurai", "sfx": "gong", "pose": "gong"}],
		"flavor": "He goes where his lord goes."},
	"samurai": {"name": "The Samurai", "act": 2, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "hp": "FAWWFAFWAAFWFAW",
		"passives": ["avenger"],
		"moves": [{"kind": "attack", "n": 10, "pose": "in_no_kamae"}, {"kind": "deflect", "pose": "ko_gasumi", "pair": true}, {"kind": "attack", "n": 3, "hits": 3, "iai": true, "pose": "sha_no_kamae"}],
		"flavor": "One cut, and it is over."},
	"tide_colossus": {"name": "Tide Colossus", "act": 3, "elite": true, "retired": true, "hp": "WWWWFW", "moves": [{"kind": "mend", "el": "W", "n": 2, "who": "self"}, {"kind": "attack", "n": 8}],
		"flavor": "A wave that stands up."},
	# The Triplet (a mini boss of three separate enemies): one spirit of each element, each with its own cycle of moves.
	# They START at different points of it ("start"); a stun or a death can bring them in step later, and that's fine.
	# Their support moves land on one of the three at random: the fire one gives Power +1, the air one Armour, and the
	# water one heals 1 Essence (that sprite's own element, never past 5), always on a hurt one if any is hurt.
	"triplet_fire": {"name": "Ember Sprite", "act": 1, "elite": true, "member": true, "start": 0, "hp": "FFFFF",
		"moves": [{"kind": "ignite_spell", "turns": 1}, {"kind": "attack", "n": 3}, {"kind": "empower", "n": 1, "who": "random"}],
		"flavor": "Sets your words on fire."},
	"triplet_water": {"name": "Ripple Sprite", "act": 1, "elite": true, "member": true, "start": 1, "hp": "WWWWW",
		"moves": [{"kind": "freeze", "n": 1}, {"kind": "attack", "n": 3}, {"kind": "mend", "el": "own", "n": 1, "who": "random_hurt", "cap": 5}],
		"flavor": "Freezes your Essence."},
	"triplet_air": {"name": "Zephyr Sprite", "act": 1, "elite": true, "member": true, "start": 2, "hp": "AAAAA",
		"moves": [{"kind": "silence", "turns": 1}, {"kind": "attack", "n": 3}, {"kind": "armor", "pos": -1, "who": "random"}],
		"flavor": "Steals your voice."},
	# Enraged Rolling Bear (a mini boss): bigger, red fur. It attacks every turn, and every time you gain Shield it
	# gains Power +1 (once per separate gain).
	"enraged_bear": {"name": "Enraged Rolling Bear", "act": 1, "elite": true, "hp": "FWFAFWFAFWFA", "passives": ["shield_rage"],
		"tint": Color(0.78, 0.16, 0.12), "size": 1.3,
		"moves": [{"kind": "attack", "n": 4}],
		"flavor": "Hide behind a shield and it only gets angrier."},
	"bramble_matron": {"name": "Bramble Matron", "act": 1, "elite": true, "hp": "WFAWFAW", "walls": 3, "passives": ["briar_walls"],
		# her own turn (planned when her intent shows): a wall down -> regrow it; both up -> sing / attack, in turn.
		# Each wall attacks on its own, in this pattern.
		"moves": [{"kind": "sing"}, {"kind": "attack", "n": 1, "hits": 2}],
		"wall_moves": [{"kind": "attack", "n": 2, "hits": 1}, {"kind": "attack", "n": 1, "hits": 2}, {"kind": "attack", "n": 1, "hits": 3}],
		"flavor": "A hedge that sings."},
	"mirror_knight": {"name": "Mirror Knight", "act": 3, "elite": true, "hp": "WAFWAF", "moves": [{"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 5}}, {"kind": "shuffle", "also": {"kind": "attack", "n": 7}}],
		"flavor": "Its guard is where you least expect."},
	"void_archon": {"name": "Void Archon", "act": 3, "elite": true, "retired": true, "hp": "AFWAFWA", "moves": [{"kind": "blind", "turns": 2, "also": {"kind": "attack", "n": 5}}, {"kind": "lock", "len": 2}, {"kind": "attack", "n": 4, "hits": 3}],
		"flavor": "It steals the light, then the words."},
	# ---------------- bosses (moves2 = second phase, at half HP)
	# The Yin Yang Beast (an Act 1 boss), in three stages. Each one starts by inverting your spells at once (random ones:
	# a spell becomes an anti-spell, an anti-spell a spell), then takes its turns.
	#   1. Black, 12 Essence (2 rows of 6): inverts 3. Roar (silence 2 spells for your next turn, a 5 hit) <-> a 3 x 3 attack.
	#      Every anti-spell you cast gives it +1 Power (+1 damage per hit).
	#   2. At 0 it rises again as the White one (pieces of the white puppet burst out and fly back), 12 Essence: inverts 3,
	#      same moves; every normal spell you cast gives it +1 Power.
	#   3. At 0 again it falls apart into two Cubs, 10 Essence each (2 rows of 5): each inverts 1 at once, then one attacks
	#      2 x 2 while the other silences, and they swap every turn. The white Cub grows on your spells, the black one on
	#      your anti-spells.
	"yin_yang_beast": {"name": "Yin Yang Beast", "act": 1, "boss": true, "hp": "FWAFWAWAFWAF", "hp2": "AWFAWFFAWFAW", "yin": "black",
		"passives": ["yinyang_split", "yy_rebirth"], "flip": 3, "hp_row": 6,
		"moves": [{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 5}}, {"kind": "attack", "n": 3, "hits": 3}],
		"flavor": "Two halves of one temper."},
	# Their rows share no two-Essence run (the white one's pairs: FF FW WW WA AA AF; the black one's: AW WF FA), so a
	# chant aimed deep into one only ever takes a single Essence off the other.
	"yin_yang_clone": {"name": "Yin Yang Cub", "act": 1, "member": true, "hp": "FFWWAAFFWW", "hp_black": "AWFAWFAWFA", "yin": "white",
		"flip": 1, "hp_row": 5,
		"moves": [{"kind": "attack", "n": 2, "hits": 2}, {"kind": "silence", "turns": 3, "n": 2}],
		"moves_black": [{"kind": "silence", "turns": 3, "n": 2}, {"kind": "attack", "n": 2, "hits": 2}],
		"flavor": "Half a beast, all the temper."},
	# The Invoker (an Act 1 boss): he never attacks. He conjures 3 of his 10 spells (no repeats) as cards on his side and
	# keeps them: each turn he casts one he chose, plus every one your chant matched; a cast spell leaves his side, and
	# once all three are gone he conjures a new set. At 0 Essence he rises again with 15 more, takes a turn to speak, and
	# from then on chants Quas / Wex / Exort, one a turn: that Essence is stripped from his spells' patterns for the rest
	# of the fight (they get easier to set off).
	"invoker": {"name": "Good Ol' Wizard", "act": 1, "boss": true, "hp": "FWAFWAFWAFWAFWAFWAFW", "hp2": "AWFAWFAWFAWFAWF",
		"invokes": true, "hidden_intent": true, "passives": ["invoker", "invoker_rebirth"], "tint": Color(0.5, 0.3, 0.72),
		"moves": [{"kind": "invoke"}],
		"flavor": "Ten spells, three words, no patience."},
	# (two Forge Spirits come at once: their rows share no start, so one chant can't take both down)
	"forge_spirit": {"name": "Forge Spirit", "act": 1, "member": true, "hp": "FFW", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A spark of the Good Ol' Wizard's forge, with a temper to match."},
	"forge_spirit_b": {"name": "Forge Spirit", "act": 1, "member": true, "hp": "WAF", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A spark of the Good Ol' Wizard's forge, with a temper to match."},
	# The Handyman (an Act 1 boss). His HANDS are what you fight: two at a time, one on each side, 10 Essence each. A hand at 0
	# Essence is knocked off and lies on the floor, and the next hand of that side grows in its place (left: sword, crossbow,
	# spear; right: tweezer, hammer, shield). Once all six lie on the floor he cries, shakes and pulls them back up: now every
	# hand has 2 Essence and he has 1. Clear them all to win.
	"handyman": {"name": "The Handyman", "act": 1, "boss": true, "no_extra": true, "hp": "A", "passives": ["handyman"],
		"moves": [{"kind": "attack", "n": 999}], "flavor": "Six hands, one job."},
	"hand_sword": {"name": "Sword Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🗡", "hp": "WWWAFWAAFW", "moves": [{"kind": "attack", "n": 5}],
		"flavor": "It swings, and swings, and swings."},
	"hand_tweezer": {"name": "Tweezer Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🥢", "hp": "FAFWAFWAFA", "moves": [{"kind": "steal", "n": 1}],
		"flavor": "Plucks Essence out of your bag and keeps it."},
	"hand_hammer": {"name": "Hammer Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🔨", "hp": "AWFWAAWFWF", "moves": [{"kind": "hammer_spell"}],
		"flavor": "It knows which spell is closest to breaking."},
	"hand_crossbow": {"name": "Crossbow Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🏹", "hp": "FFWAFAWFFW", "moves": [{"kind": "charge", "left": 1, "n": 20, "turns": 2},
		{"kind": "charge", "left": 0, "hit": true}], "flavor": "Slow to load. Not slow to hurt."},
	"hand_spear": {"name": "Spear Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🔱", "hp": "AAAFWAAFWA", "moves": [{"kind": "attack", "n": 8}],
		"flavor": "The last hands are the sharpest."},
	"hand_shield": {"name": "Shield Hand", "act": 1, "member": true, "boss": true, "no_extra": true, "passives": ["hand"], "tint": Color(0.86, 0.7, 0.55), "tool": "🛡", "hp": "FFFWAFFWAW", "moves": [{"kind": "armor", "pos": -1, "who": "random"}],
		"flavor": "Always covering for one of the others."},
	"woodcutter": {"name": "The Woodcutter", "act": 0, "boss": true, "hp": "FWAFWAFFWAWFA",
		"moves": [{"kind": "attack", "n": 8}, {"kind": "summon", "id": "ashling", "n": 1}, {"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 4}}],
		"moves2": [{"kind": "attack", "n": 5, "hits": 2}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}],
		"flavor": "He came for the last tree."},
	# Violet Eyes (an Act 2 boss; was the Veiled Eyes). Phase 1: a ball hanging on a white thread, two violet human eyes behind a black
	# veil. Phase 2 (at 0 Essence the veil falls): the spider underneath, the human eyes on its back and 4 spider-eye
	# dots. Its intent is shown like anyone's; its eyes also light up, a turn ahead ("eyes" on each move).
	# Phase 1 cycles laser (both eyes) / venom (right eye) / slashes (left eye); phase 2 counts its dots 0 -> 4 and
	# starts at 1 (the theft): 1 steal a spell into a cocoon, 2 venom, 3 two spiderlings, 4 eight slashes, 0 the human
	# eyes' laser (the only time they look straight at you). Envenomed: every hit that takes HP gives you 1 Poison.
	# Its numbers are exactly these: no act bonus Essence (no_extra) and no act attack bonus (no_bonus).
	"veiled_eyes": {"name": "Violet Eyes", "act": 2, "boss": true, "no_extra": true, "no_bonus": true,
		"hp": "FWAAWFFAWWFAAFW", "hp2": "AWFFWAAFWWAFFAWWFAAW", "passives": ["envenomed", "veil_falls"], "tint": Color(0.16, 0.12, 0.2),
		"moves": [{"kind": "attack", "n": 5, "eyes": "both", "laser": true}, {"kind": "poison", "n": 4, "eyes": "right"},
			{"kind": "attack", "n": 1, "hits": 4, "eyes": "left"}],
		"moves2": [{"kind": "steal_spell", "eyes": 1}, {"kind": "poison", "n": 5, "eyes": 2},
			{"kind": "summon", "list": ["spiderling_a", "spiderling_b"], "n": 2, "eyes": 3},
			{"kind": "attack", "n": 1, "hits": 8, "eyes": 4}, {"kind": "attack", "n": 5, "eyes": 0, "laser": true}],
		"flavor": "It looks at you in desperation."},
	# (two spiderlings come at once: their rows share no start, so one chant can't take both down)
	"spiderling_a": {"name": "Spiderling", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "FFAWA", "passives": ["envenomed"],
		"tint": Color(0.18, 0.14, 0.22), "moves": [{"kind": "attack", "n": 1, "hits": 2}], "flavor": "Small, fast, and very much its mother's."},
	"spiderling_b": {"name": "Spiderling", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "hp": "WWFAF", "passives": ["envenomed"],
		"tint": Color(0.18, 0.14, 0.22), "moves": [{"kind": "attack", "n": 1, "hits": 2}], "flavor": "Small, fast, and very much its mother's."},
	# the cocoon Violet Eyes wraps a stolen spell in: it does nothing; break it and the spell comes back
	"spider_cocoon": {"name": "Silk Cocoon", "act": 2, "member": true, "no_extra": true, "no_bonus": true, "inert": true, "hidden_intent": true,
		"hp": "WAF", "passives": ["cocoon"], "tint": Color(0.92, 0.9, 0.86), "moves": [{"kind": "hold"}],
		"flavor": "Something you need is wrapped up in there."},
	# The Pianist (the Act 2 boss; Ludwig, see docs/story.md). Tall and thin like Slender Man, black suit, white collar, a
	# hat; his left hand was cut off, so he plays with one hand and one foot. He has no moves: he plays, in real time,
	# from the moment the fight starts (PianistSong, on the fight screen), through every turn and animation. If the piece
	# ends, he slams the keys: The End, and you die. Turkish March normally; give him back the Mysterious Hand (his own)
	# in the talk and he plays Fur Elise instead. A "Silence, please" sign on his stage.
	# 50 Essence in all, as five pages of 10 ("pages"; no act bonus): each time a page's Essence is gone, he stops the
	# music, turns the page (that is his turn: you can do nothing; every status on him is gone) and plays on from where
	# he stopped (that is your turn). The fifth page gone: he is beaten.
	"pianist": {"name": "The Pianist", "act": 2, "boss": true, "no_extra": true, "no_bonus": true,
		"hp": "FWAAWFWAFF", "pages": ["FWAAWFWAFF", "WAWFAWFAWW", "AFFWAFWAAF", "WFWAFAWWFA", "FWAWFFAWAF"], "passives": ["pianist"],
		"moves": [{"kind": "play"}],
		"flavor": "Silence, please."},
	# The Corrector (an Act 2 boss): a code debugger made real, deployed by the Hand. His head is a TV screen that shows
	# what he is about to do. 16 Essence; at 0 he reboots once with 16 more, and a second, smaller screen lights up on
	# top of the first: from then on he does two things every turn, the big screen's move and a weaker one of the
	# small screen's ("moves_small", in their own cycle). Patch (Mend 3) only when it heals all 3, Mend 2 likewise
	# ("only_if_missing"); a move that would be wasted is skipped.
	"corrector": {"name": "The Corrector", "act": 2, "boss": true, "no_extra": true, "no_bonus": true,
		"hp": "WAFFWAWFAWFAFWAW", "hp2": "FAWWFAFWAFWFAWFA", "passives": ["corrector_reboot"],
		"moves": [{"kind": "mend", "el": "random", "n": 3, "only_if_missing": 3, "name": "Patch"},
			{"kind": "virus", "n": 3, "name": "Syntax Error", "also": {"kind": "lock", "len": 3, "other": true}},
			{"kind": "attack", "n": 6, "name": "Step Over"}],
		"moves_small": [{"kind": "attack", "n": 3, "name": "Step Over"}, {"kind": "lock", "len": 2, "name": "Breakpoint"},
			{"kind": "virus", "n": 2, "name": "Syntax Error"}, {"kind": "mend", "el": "random", "n": 2, "only_if_missing": 2, "name": "Patch"}],
		"flavor": "Stay tuned."},
	# The Fire Dragon (an Act 3 mini boss, the user's design, 2026-10-26). It lies across the stage: tail on the left,
	# head on the right, one wing on its back. Head and tail are separate enemies (20 Essence each, both must fall), each
	# with its own intent at its own end of the stage. Every turn the wing folds over one of them, at random and shown
	# ahead (Fight.wing_fold): that part can't be touched by anything you do that turn (even when the other part is dead,
	# the wing keeps folding back and forth). Each part picks its move at random ("random_moves").
	"dragon_tail": {"hidden": true, "name": "Dragon's Tail", "act": 3, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "random_moves": true,
		"dragon": "tail", "hp": "FAFWFAWFAFWFAFWAFAWF", "tint": Color(0.93, 0.5, 0.2),
		"moves": [{"kind": "attack", "n": 10, "name": "Slap"}, {"kind": "attack", "n": 2, "name": "Thrash", "also": {"kind": "stun", "turns": 1}}],
		"flavor": "It sweeps the stage clean."},
	"dragon_head": {"hidden": true, "name": "Dragon's Head", "act": 3, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "random_moves": true,
		"dragon": "head", "bubble_right": true, "hp": "FWFAFFWAFWFAFFAWFWAF", "tint": Color(0.97, 0.62, 0.25),
		"moves": [{"kind": "attack", "n": 2, "hits": 3, "name": "Bite"}, {"kind": "empower", "n": 2, "name": "Howl"},
			{"kind": "summon", "id": "dragon_fireball", "n": 1, "name": "Fireball"}],
		"flavor": "It smiles in its sleep. It is not asleep."},
	# The Winter Wyvern (Act 3 mini boss) uses the Fire Dragon's mechanics (user decision 2026-10-31): separate head and tail (20 Essence
	# each, both must fall), the wing folds over one of them every turn, random moves, a hovering Fireball that Ignites all your spells.
	# Its pictures are the user's own (Dragon2/Dragon.pdf, see DragonRig): `rig_part` says which part of the one rig this enemy draws, `parts` what
	# the picture does for the move. It faces left, so its head stands on the LEFT (`head_left`: the Fireball appears on the head's right) and its
	# tail on the right (`bubble_right`: the intent bubble stands at the right end of the stage); both views are `wide`, so the pieces fit.
	"wyvern_head": {"name": "Wyvern's Head", "act": 3, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "random_moves": true,
		"dragon": "head", "rig_part": "head", "head_left": true, "wide": true, "hp": "FWFAFFWAFWFAFFAWFWAF", "tint": Color(0.62, 0.85, 1.0),
		"moves": [{"kind": "attack", "n": 2, "hits": 3, "name": "Bite", "parts": {"head": "bite"}}, {"kind": "empower", "n": 2, "name": "Howl", "parts": {"head": "up"}},
			{"kind": "summon", "id": "wyvern_fireball", "n": 1, "name": "Fireball", "parts": {"head": "up"}}],
		"flavor": "Wings spread, then fire."},
	"wyvern_tail": {"name": "Wyvern's Tail", "act": 3, "elite": true, "member": true, "no_extra": true, "no_bonus": true, "random_moves": true,
		"dragon": "tail", "rig_part": "tail", "bubble_right": true, "wide": true, "hp": "FAFWFAWFAFWFAFWAFAWF", "tint": Color(0.55, 0.8, 0.95),
		"moves": [{"kind": "attack", "n": 10, "name": "Slap", "parts": {"tail": "slam"}},
			{"kind": "attack", "n": 2, "name": "Thrash", "also": {"kind": "stun", "turns": 1}, "parts": {"tail": "sweep"}}],
		"flavor": "It sweeps the stage clean."},
	"wyvern_fireball": {"name": "Fireball", "act": 3, "member": true, "no_extra": true, "no_bonus": true, "dragon": "fireball",
		"hp": "FFFFF", "tint": Color(1.0, 0.45, 0.1), "moves": [{"kind": "ignite_spell", "all": true, "turns": 1, "burst": true}],
		"flavor": "Pop it before it pops."},
	# the Dragon's fireball: it hangs in mid-air above the wing (the wing can't cover it). Its intent shows at once;
	# a turn later it bursts and Ignites ALL your spells, and is gone.
	"dragon_fireball": {"hidden": true, "name": "Fireball", "act": 3, "member": true, "no_extra": true, "no_bonus": true, "dragon": "fireball",
		"hp": "FFFFF", "tint": Color(1.0, 0.45, 0.1), "moves": [{"kind": "ignite_spell", "all": true, "turns": 1, "burst": true}],
		"flavor": "Pop it before it pops."},
	"last_winter": {"name": "The Last Winter", "act": 3, "boss": true, "hp": "WWAWFAWWAFAWWAFWAW",
		"moves": [{"kind": "freeze", "n": 2}, {"kind": "attack", "n": 8}, {"kind": "confuse"}, {"kind": "attack", "n": 7}],
		"moves2": [{"kind": "lock", "len": 3}, {"kind": "summon", "id": "storm_imp", "n": 2}, {"kind": "attack", "n": 6, "hits": 2}],
		"flavor": "The end of every season."},
}

const PASSIVE_TEXT := {
	"mirror_deflect": "Mirror: a spell you aim at her has a 50% chance to bounce off her mirror and do nothing.",
	"burning_hide": "Burning Hide: you take 1 damage whenever your Release hits it.",
	"split": "Split: struck but not killed, it splits its remaining Essence into two enemies (once).",
	"overgrowth": "Overgrowth: if not struck during your turn, it grows a random Essence.",
	"warded": "Warded: only chants of 4 or more Essence can strike it.",
	"last_gasp": "Last Gasp: gives you Poison 2 when it dies.",
	"pianist": "The Pianist: he never attacks. He plays one piece, in real time, from the first turn on. If he gets to the end of it, you die. 50 Essence, as five pages of 10: every time a page is cleared he stops, turns the page (his turn) and plays on.",
	"corrector_reboot": "Reboot: at 0 Essence he restarts with 16 more, and a second, smaller screen lights up: from then on he does two things every turn (the small screen's moves are weaker).",
	"retainer": "Loyal: if the Samurai falls first, his Retainer yields and the fight is over.",
	"avenger": "Avenger: if his Retainer falls first, the Samurai gains 5 Power for the rest of the fight.",
	"dormant": "Dormant: does nothing until it is down to 12 Essence, or for 3 turns.",
	"head_throw": "Head Throw: at 10 Essence or less, he throws his head and silences all your spells. After that he only swings.",
	"flying": "Flying: your chant can't hit it. Damage from a spell or a bottle brings it down, and it is stunned for a turn.",
	"shell": "Shell: its first Essence is always armoured, until it is its last one.",
	"maddened": "Maddened: every spell you cast this turn is one more hit on his attack. It starts over each turn.",
	"lure": "Lure: its lamp hangs on its hook. Put out, it goes dark for a turn, then lights up again, its clock back at 2.",
	"last_fuse": "Last Fuse: at 0 Essence it reboots with 4 Essence. Destroy those, or on its turn it explodes for 10 and dies.",
	"big_shield": "Big Shield: guards the Necromancer, who can't be touched while it stands. On its last Essence it swings instead. Fallen, it can be raised again.",
	"behind_shield": "Hiding: while the Shield Bearer stands, nothing you do can touch it.",
	"gem_crown": "Gem Crown: at the end of its turn, armours its first Essence if nothing is armoured (not when it has 1 left).",
	"echo": "Echo: repeats each action twice.",
	"briar_walls": "Briar Walls: she hides between two hedge walls (3 Essence each, the two ends of her row). They are part of her: leftmost and rightmost effects hit the ends of her row (a wall while it stands), random effects pick wall Essence first, and Snipe can reach anything. She regrows a fallen wall (she shows it first); with both up she sings (Power +1) or attacks. When her own Essence is gone, the walls fall with her.",
	"thorns": "Thorns 2: you lose 2 HP whenever your Release hits it.",
	"burn_immune": "Fireproof: Burn has no effect on it.",
	"slime_burst": "Burst: when it dies, two small slimes pop out.",
	"hand": "A hand with 10 Essence: knocked out, it drops off and lies on the floor, and the next hand grows in its place. Once every hand has fallen, he pulls them all back up for his last stand, 2 Essence each; those hands shatter for good when beaten.",
	"handyman": "The Handyman himself: 1 Essence. Once his hands are all down he cries, shakes, and takes them back; when those are beaten too he shows himself: 1 Essence, and a 999 blow.",
	"invoker": "Good Ol' Wizard: every turn he conjures 3 spells. On his turn he casts every one your chant matched, or else the one it came closest to.",
	"invoker_rebirth": "Second wind: at 0 Essence he rises again with 10 more, and starts chanting Quas, Wex or Exort, one a turn: each strips that Essence (Water, Air, Fire) from his spells for the rest of the fight.",
	"yinyang_split": "Split: when it dies for good, it splits into two Yin Yang Cubs (10 Essence each), one white and one black.",
	"shield_rage": "Enraged: every time you gain Shield, it gains Power +1 (its attacks deal 1 more damage).",
	"envenomed": "Envenomed: every hit that takes HP from you also gives you 1 Poison (hits your Shield stops don't).",
	"veil_falls": "The veil falls: at 0 Essence the veil drops and what is underneath fights on, with 20 more Essence and new moves.",
	"cocoon": "Cocoon: a spell of yours is wrapped inside. Break it and the spell comes back (and it comes back anyway if you win).",
	"rage_at_half": "Shield Wall: above half its Essence it guards and strikes in turn. At half or below it drops its shield and attacks twice every turn.",
}

## Light-hearted descriptions for the preparation screen.
const BIOS := {
	"ashling": "A campfire spark that got ambitious. Bites like a toddler with a grudge.",
	"iceling": "A snowflake with an attitude. Small, cold, and surprisingly pointy.",
	"zephling": "A gust of wind that decided to have a face. Mostly harmless, mostly.",
	"purple_slime": "Wobbles. Squelches. Hits you. That's the whole personality.",
	"green_slime": "The lightest slime in the forest, and very proud of it.",
	"yellow_slime": "Warm, sticky, and a little bit angry about it.",
	"bramble_back": "A porcupine that stood up and got mad. Hitting it with your chant is a prickly business.",
	"winged_tortoise": "Slow to fly, quick to hide. Every other turn it tucks another Essence behind its shell.",
	"leech_bat": "Shiny fangs, zero shame. Every bite patches it back up.",
	"mirror_fairy": "She lives in the mirror and turns your words backwards. Read your chant from the right!",
	"yeti": "Huge, fluffy, and it freezes your Essence solid before punching you.",
	"greenseer": "The druid in the mushroom hat. Grows slimes, heals itself, and lets them do the fighting.",
	"rolling_bear": "Starts as a gentle roll and ends as an avalanche. It gets stronger every single turn.",
	"giant_slime": "A rainbow of wobble. Pop it and two smaller slimes come out to finish the job.",
	"tomato_knight": "Guards behind a big shield while it's healthy. Squish it past halfway and it throws the shield away and goes berserk.",
	"puddle_slime": "Technically a puddle. Emotionally, also a puddle. It keeps topping itself up so it never has to face the drain.",
	"gale_sprite": "Two jabs, no manners. Toughens up when you look at it funny, and loves freezing your fingers mid-spell.",
	"cinder_hound": "Good boy. Very hot boy. Flames run under its fur like tattoos, so Burn just tickles.",
	"stone_knight": "Spends a whole turn bracing, then swings like it gets paid by the bruise. Politely makes you fragile first.",
	"tidecaller": "Refills itself like a tide that refuses to go out. Also freezes things, because the ocean is petty.",
	"mirror_wisp": "Never in the same order twice. Blinds you, reshuffles itself, and giggles about it.",
	"frost_hex": "Freezes your Essence, then waits for you to complain. Mends itself with the same cold patience.",
	"pickpocket_imp": "Steals your Essence and wears them like jewellery. Surprisingly good fashion sense for a thief.",
	"hush_moth": "Its wings whisper \"shhh\" at one of your spells: it can't fire for a turn.",
	"mob_pitchfork": "A farmer with nothing left to farm. Stabs you, and the wound stays open.",
	"mob_slingshot": "Small stones, good aim. Every hit knocks an Essence out of your bag.",
	"mob_torch": "Sets one of your spells alight. It stays alight until you cast it, and then it burns you.",
	"shield_bearer": "A skeleton behind a very big shield. Doesn't fight back until he is nearly gone, and he doesn't stay down for long.",
	"necromancer": "Three Essence, Poison 3, a heal of 3 for his skeleton, and he raises it when it falls. You can't touch him, or even see his Essence, while it stands.",
	"rot_snake": "Spits a mouthful of rot, then bites. Its Poison piles up fast.",
	"sentinel": "Wakes when you hurt it, or when it has seen enough. Each round of blows is bigger, then it has to stop and recharge.",
	"blue_sentinel": "Wakes when you hurt it, or when it has seen enough. Every blow freezes your Essence, more and more of it.",
	"headless_horseman": "Swings twice, or screams through the head he holds to his neck. Hurt him enough and he throws it.",
	"scav_rat": "Three little bites a turn. Gets nastier with every howl.",
	"scav_hyena": "Doesn't bite. It howls, and all of them hit harder.",
	"scav_vulture": "Your chant can't reach it. Knock it down with a spell, and it lies stunned for a turn.",
	"scav_beetle": "Its shell never comes off, and it hits harder than it looks.",
	"mad_soldier": "Weak on his own, but every spell you cast this turn adds a swing. Cast less, or kill him fast.",
	"tree_dweller_a": "Rooted to the spot, and never stops shooting. Two Poison a turn, every turn.",
	"tree_dweller_b": "Rooted to the spot, and never stops shooting. Two Poison a turn, every turn.",
	"bog_fish": "An enormous angler fish on two legs. Bites, spits Poison, or grows more Thorns, whichever it feels like.",
	"bog_lamp": "Its clock runs 2, 1, 0, and at 0 you are Stunned. Put it out and it lights up again, but its clock starts over.",
	"bug_hunter": "A brass bell on legs that hunts for bugs. It strikes its own head to hurt you, and on its 4th turn it rings the alarm for a Sentinel. Silence it before then.",
	"inverter": "Fire becomes water, water becomes fire, and your plans become confetti.",
	"warded_golem": "Short chants bounce right off. Say something meaningful: at least four Essence long.",
	"echo_wraith": "Everything it does, it does twice. Everything it does, it does twice.",
	"mimic_chest": "Turns into your last words, backwards. Not the treasure you were hoping for.",
	"last_gasp_spore": "Mostly harmless until it dies. Then it sneezes on you, and you feel sick about it.",
	"storm_imp": "Three tiny zaps, then it flickers out of reach. Hits harder every time it gets bored.",
	"storm_rider": "Fast, loud and hard to read. Imagine a thunderstorm that learned to ride a horse.",
	"lockwarden": "Chains your spells shut and expects you to guess the combination.",
	"tide_colossus": "A wave that stood up and decided to stay standing. Mends two at a time and swings like a tsunami.",
	"triplet_fire": "The hot-headed one of the Triplet. Touch a burning spell and you'll feel it.",
	"triplet_water": "The calm one of the Triplet. Calm like a frozen lake.",
	"triplet_air": "The quiet one of the Triplet. It prefers that you be quiet too.",
	"enraged_bear": "The Rolling Bear, but someone woke it up. Red-furred, huge, and it takes your shields personally.",
	"yin_yang_beast": "A beast of black and white that turns your words inside out. Black, it feeds on your anti-spells; white, on your spells. It gets back up once.",
	"yin_yang_clone": "What's left when the Yin Yang Beast falls apart: two smaller, angrier halves.",
	"invoker": "A sorcerer who remembers every spell ever cast. He never swings a fist: he just reads your chant back at you.",
	"forge_spirit": "Hot, small, and very eager to prove itself.",
	"handyman": "A tinkerer with too many hands and a tool in each. He never shows himself until there's nothing left to hide behind.",
	"bramble_matron": "A druid wrapped in a living hedge. Her two walls do the fighting while she sings them stronger. Cut the walls, or Snipe her straight through them.",
	"mirror_knight": "Its guard is always exactly where you didn't aim. Rude, but fair.",
	"void_archon": "Steals the light, then your words, then your patience.",
	"woodcutter": "He came for the last tree, and he brought friends and an axe. Mostly the axe.",
	"veiled_eyes": "Two haunting violet eyes behind a thin black veil. They look at you in desperation. Don't look back for too long.",
	"spiderling_a": "Eight legs, one thought: you.",
	"spiderling_b": "Eight legs, one thought: you.",
	"spider_cocoon": "Silk, wrapped tight around something that used to be yours.",
	"last_winter": "The end of every season. Freezes your hands, scrambles your words, and calls a storm to finish the job.",
}

const BOSSES := {1: ["yin_yang_beast", "invoker", "handyman"], 2: ["pianist", "veiled_eyes", "corrector"], 3: ["last_winter"]}
## Passives the fight never tells you about (only the Codex does, once you've beaten it).
## Passives explained in a fight (hover). Every other one is a native trait you learn by facing the enemy: no symbol, no
## tooltip; the Codex explains it in words.
const SHOWN_PASSIVES := ["mirror_deflect", "cocoon"]
const HIDDEN_PASSIVES := ["yinyang_split", "yy_rebirth", "invoker_rebirth", "armadillo", "veil_falls"]

## The Invoker's spells (Dota 2's Invoker: Quas = Water, Wex = Air, Exort = Fire). Each one's "cast" is the move he makes
## when it goes off; "desc" is its card text.
const INVOKER_WORDS := {"W": "Quas", "A": "Wex", "F": "Exort"}
## What he says as he chants each word (his second wind).
const INVOKER_CHANTS := {
	"W": "The icy touch of the primordial void, come to me: Quas!",
	"A": "Spirit of the wind, come, I beckon you: Wex!",
	"F": "Essence of fire, heed my call: Exort!",
}
## One of these each time he conjures a new set of spells.
const INVOKER_SUMMON_LINES := ["Knowledge is power!", "Behold, the pinnacle of wizardry!", "Concentration!", "More!", "Boundless knowledge!", "I challenge you!"]
## His spells cost 2 Essence: the pattern they had without its middle one (Ice Wall and Deafening Blast share WF, so
## they never come in the same set).
const INVOKER_SPELLS := [
	{"id": "inv_cold_snap", "name": "Cold Snap", "pattern": "WW", "kind": "damage", "desc_fmt": "Deal %d damage to you, 4 times.", "dmg": [1],
		"cast": {"kind": "attack", "n": 1, "hits": 4}},
	{"id": "inv_ghost_walk", "name": "Ghost Walk", "pattern": "WA", "kind": "utility", "desc": "He cleanses all his debuffs.",
		"cast": {"kind": "cleanse_self"}},
	{"id": "inv_ice_wall", "name": "Ice Wall", "pattern": "WF", "kind": "defense", "desc": "He Armours 3 of his Essence.",
		"cast": {"kind": "armor", "pos": -1, "count": 3}},
	{"id": "inv_emp", "name": "EMP", "pattern": "AA", "kind": "utility", "desc_fmt": "You lose 2 random Essence from your bag, and take %d damage.", "dmg": [2],
		"cast": {"kind": "drain_essence", "n": 2, "also": {"kind": "attack", "n": 2}}},
	{"id": "inv_tornado", "name": "Tornado", "pattern": "AW", "kind": "damage", "desc_fmt": "Deal %d damage to you and Silence 1 of your spells (1 turn).", "dmg": [3],
		"cast": {"kind": "attack", "n": 3, "also": {"kind": "silence", "n": 1, "turns": 1}}},
	{"id": "inv_alacrity", "name": "Alacrity", "pattern": "AF", "kind": "utility", "desc": "He gains Power +2.",
		"cast": {"kind": "empower", "n": 2}},
	{"id": "inv_sun_strike", "name": "Sun Strike", "pattern": "FF", "kind": "damage", "desc_fmt": "Deal %d damage to you.", "dmg": [10],
		"cast": {"kind": "attack", "n": 10}},
	{"id": "inv_forge_spirit", "name": "Forge Spirit", "pattern": "FW", "kind": "utility", "desc": "He summons 2 Forge Spirits (3 Essence each, attack for 3).",
		"cast": {"kind": "summon", "list": ["forge_spirit", "forge_spirit_b"], "n": 2, "flank": true}},
	{"id": "inv_chaos_meteor", "name": "Chaos Meteor", "pattern": "FA", "kind": "damage", "desc_fmt": "Deal %d damage to you, 3 times, and Ignite 3 of your spells.", "dmg": [2],
		"cast": {"kind": "attack", "n": 2, "hits": 3, "also": {"kind": "ignite_spell", "n": 3, "turns": 1}}},
	{"id": "inv_deafening_blast", "name": "Deafening Blast", "pattern": "WF", "kind": "damage", "desc_fmt": "Deal %d damage to you and Disarm you (your next Release does nothing).", "dmg": [5],
		"cast": {"kind": "attack", "n": 5, "also": {"kind": "disarm", "turns": 1}}},
]


static func get_def(id: String) -> Dictionary:
	var d: Dictionary = E[id].duplicate(true)
	d.id = id
	return d


## Every enemy that stands in one of this act's normal fights (POOLS), in order, once.
static func fight_ids(act: int) -> Array:
	var out: Array = []
	for pool in POOLS.get(act, {}).values():
		for enc in pool:
			for id in enc.ids:
				if not out.has(id):
					out.append(id)
	return out


static func normals(act: int) -> Array:
	return E.keys().filter(func(k): return E[k].act == act and not E[k].get("elite", false) and not E[k].get("boss", false) and not E[k].get("unique", false) and not E[k].get("member", false))


## The mini bosses of an act (only that act's own; "retired" ones are kept for old saves and the codex but never met).
## Act 1: The Triplet, Enraged Rolling Bear, Bramble Matron. Act 2: Chairman, Blackwing, The Warden, the Samurai and his Retainer.
## Act 3: Bottle Head, Winter Wyvern, Mirror Knight. (Chairman, Blackwing and Bottle Head: not made yet.)
static func elites(act: int) -> Array:
	var out := E.keys().filter(func(k): return E[k].get("elite", false) and not E[k].get("member", false) and not E[k].get("retired", false) and E[k].act == act)
	return out + ELITE_GROUPS.keys().filter(func(k): return ELITE_GROUPS[k].act == act and not ELITE_GROUPS[k].get("wip", false) and not ELITE_GROUPS[k].get("hidden", false))  # (wip: Test mode only; hidden: nowhere: the Winter Wyvern took the Fire Dragon's place)


## Mini bosses that are a group: always met together, left to right.
const ELITE_GROUPS := {
	"the_triplet": {"name": "The Triplet", "act": 1, "ids": ["triplet_fire", "triplet_water", "triplet_air"]},
	"samurai_pair": {"name": "The Samurai and his Retainer", "act": 2, "ids": ["samurai", "samurai_retainer"]},
	"twin_sentinels": {"name": "The Twin Sentinels", "act": 2, "ids": ["sentinel", "blue_sentinel"]},
	"fire_dragon": {"hidden": true, "name": "The Fire Dragon", "act": 3, "ids": ["dragon_tail", "dragon_head"]},
	"winter_wyvern": {"name": "The Winter Wyvern", "act": 3, "ids": ["wyvern_head", "wyvern_tail"]},
}


## Is it out of the game altogether (the Fire Dragon, replaced by the Winter Wyvern)? Not in a run, the codex, Test mode or the Room Test.
static func is_hidden(id: String) -> bool:
	if ELITE_GROUPS.has(id):
		return ELITE_GROUPS[id].get("hidden", false)
	if LINKED.has(id):
		return false
	return E.has(id) and E[id].get("hidden", false)


## Normal-fight enemies that only ever come together, as one (Test mode puts them on the stage together, never one alone).
const LINKED := {
	"undying_duo": {"name": "The Undying Duo", "act": 2, "ids": ["shield_bearer", "necromancer"]},
	"bog_lantern": {"name": "The Bog Lantern", "act": 2, "ids": ["bog_lamp", "bog_fish"], "thumb": "bog_fish"},
}


## The enemies an id brings into a fight: a group's members, or just itself.
static func ids_of(id: String) -> Array:
	if LINKED.has(id):
		return LINKED[id].ids.duplicate()
	return ELITE_GROUPS[id].ids.duplicate() if ELITE_GROUPS.has(id) else [id]


## Every enemy that only comes as part of a LINKED pair.
static func linked_members() -> Array:
	var out: Array = []
	for k in LINKED:
		out.append_array(LINKED[k].ids)
	return out


static func name_of(id: String) -> String:
	if LINKED.has(id):
		return LINKED[id].name
	return ELITE_GROUPS[id].name if ELITE_GROUPS.has(id) else E[id].name


## Normal fights, the Slay the Spire way: hand-made, themed encounters in three pools per act. Each one is always the same
## group of enemies. What decides the pool is how many fights you have had in the act, not where you are on the map: when an act
## starts, its whole list of fights is rolled (roll_fight_plan), and every normal fight takes the next one. act -> pool -> [{name, ids (left to right), w}]
const POOLS := {
	1: {
		"easy": [
			{"name": "A Fire Spirit", "ids": ["ashling"], "w": 1.0},
			{"name": "An Ice Spirit", "ids": ["iceling"], "w": 1.0},
			{"name": "An Air Spirit", "ids": ["zephling"], "w": 1.0},
			{"name": "Purple Slime", "ids": ["purple_slime"], "w": 1.0},
			{"name": "Green Slime", "ids": ["green_slime"], "w": 1.0},
			{"name": "Yellow Slime", "ids": ["yellow_slime"], "w": 1.0},
			{"name": "Steam", "ids": ["ashling", "iceling"], "w": 1.0},
			{"name": "Wildfire", "ids": ["zephling", "ashling"], "w": 1.0},
			{"name": "Frost Wind", "ids": ["iceling", "zephling"], "w": 1.0},
		],
		"medium": [
			{"name": "Bramble Back", "ids": ["bramble_back"], "w": 1.0},
			{"name": "Winged Tortoise", "ids": ["winged_tortoise"], "w": 1.0},
			{"name": "Hush Moth", "ids": ["hush_moth"], "w": 1.0},
			{"name": "The Elemental Trio", "ids": ["ashling", "iceling", "zephling"], "w": 1.0},
			{"name": "Marsh", "ids": ["purple_slime", "iceling"], "w": 0.7},
			{"name": "Hot Puddle", "ids": ["yellow_slime", "ashling"], "w": 0.7},
			{"name": "Breezy Ooze", "ids": ["green_slime", "zephling"], "w": 0.7},
			{"name": "Mirror Fairy", "ids": ["mirror_fairy"], "w": 1.0},
		],
		# (by the numbers: medium tops out near 10 Essence and 9 damage a turn; the 13+ Essence groups are hard)
		"hard": [
			{"name": "The Slime Trio", "ids": ["purple_slime", "green_slime", "yellow_slime"], "w": 1.0},
			{"name": "The Forest Floor", "ids": ["bramble_back", "winged_tortoise"], "w": 0.8},
			{"name": "The Greenseer's Garden", "ids": ["greenseer", "green_slime"], "w": 1.0},
			{"name": "Rolling Bear", "ids": ["rolling_bear"], "w": 1.0},
			{"name": "Giant Slime", "ids": ["giant_slime"], "w": 1.0},
			{"name": "Hall of Mirrors", "ids": ["mirror_fairy", "zephling"], "w": 0.7},
		],
	},
	2: {
		"easy": [
				{"name": "The Bug Hunter", "ids": ["bug_hunter"], "w": 1.0},
			{"name": "Starving Mobs", "ids": ["mob_pitchfork", "mob_slingshot", "mob_torch"], "w": 1.0},
			{"name": "Maddened Soldier", "ids": ["mad_soldier"], "w": 1.0},
			{"name": "The Tree Dwellers", "ids": ["tree_dweller_a", "tree_dweller_b"], "w": 1.0},
		],
		"medium": [
				{"name": "The Red Sentinel", "ids": ["sentinel"], "w": 1.0},
		{"name": "The Blue Sentinel", "ids": ["blue_sentinel"], "w": 1.0},
		{"name": "The Rot Snake", "ids": ["rot_snake"], "w": 1.0},
		{"name": "The Bog Lantern", "ids": ["bog_lamp", "bog_fish"], "w": 1.0},
		{"name": "The Undying Duo", "ids": ["shield_bearer", "necromancer"], "w": 1.0},
		],
		"hard": [
			{"name": "The Headless Horseman", "ids": ["headless_horseman"], "w": 1.0},
			{"name": "The Scavengers", "ids": ["scav_rat", "scav_hyena", "scav_vulture", "scav_beetle"], "w": 1.0},
			{"name": "Three Bug Hunters", "ids": ["bug_hunter", "bug_hunter", "bug_hunter"], "w": 1.0},
		],
	},
}

const FIRST_SPIRITS := ["ashling", "iceling", "zephling"]  # the run's first fight is one of these, alone
const PLAN_LENGTH := 12  # more than a path through an act can hold
const EASY_FIGHTS := 2  # the first two fights of an act are easy,
const MEDIUM_FIGHTS := 2  # the next two medium, the rest hard


## An act's fights, in the order they will be met: weighted, never one of the last two, and where the pool changes, nothing
## that shares an enemy with the fight just before it (no Slimes right after Slimes).
static func roll_fight_plan(act: int, rng: RandomNumberGenerator) -> Array:
	var pools: Dictionary = POOLS[act]
	var plan: Array = []
	for i in PLAN_LENGTH:
		var kind := "easy" if i < EASY_FIGHTS else ("medium" if i < EASY_FIGHTS + MEDIUM_FIGHTS else "hard")
		var pool: Array = pools[kind]
		if kind == "hard" and pool.size() < 3:
			pool = pool + pools.medium  # (too few hard fights yet to keep from repeating: the medium ones help out)
		if act == 1 and i == 0:
			pool = pool.filter(func(enc): return enc.ids.size() == 1 and enc.ids[0] in FIRST_SPIRITS)  # (the very first fight of a run: one spirit alone)
		elif act == 1 and i == 1:
			pool = pool.filter(func(enc): return not (enc.ids.size() == 1 and enc.ids[0] in FIRST_SPIRITS))  # (the second: a pair of spirits, or a slime)
		if i == EASY_FIGHTS or i == EASY_FIGHTS + MEDIUM_FIGHTS:
			var before: Array = plan[-1].ids
			var fresh := pool.filter(func(enc): return not enc.ids.any(func(id): return id in before))
			if not fresh.is_empty():
				pool = fresh
		plan.append(_pick_encounter(pool, rng, plan.map(func(enc): return enc.name)))
	return plan


static func _pick_encounter(pool: Array, rng: RandomNumberGenerator, recent: Array) -> Dictionary:
	var last_two := recent.slice(maxi(0, recent.size() - 2))
	var fresh := pool.filter(func(enc): return not (enc.name in last_two))
	if fresh.is_empty():
		fresh = pool
	var total := 0.0
	for enc in fresh:
		total += enc.w
	var r := rng.randf() * total
	for enc in fresh:
		r -= enc.w
		if r < 0.0:
			return enc.duplicate(true)
	return fresh[-1].duplicate(true)


## Enemy ids for a node. floor is 1-based within the act. seen: ids met earlier this run (avoided when possible).
static func encounter(kind: String, act: int, floor: int, rng: RandomNumberGenerator, seen: Array = []) -> Array:
	match kind:
		"boss":
			var bosses: Array = BOSSES[act]
			return [bosses[rng.randi() % bosses.size()]]
		"elite":
			var pool := elites(act)
			var fresh := pool.filter(func(id): return not (ids_of(id)[0] in seen))
			if not fresh.is_empty():
				pool = fresh
			return ids_of(pool[rng.randi() % pool.size()])  # (a mini boss comes alone: no escorts)
	var pool := normals(act)
	var count := group_size(act, floor, rng)
	var out := []
	for i in count:
		# prefer enemies not already in this fight or met recently
		var fresh := pool.filter(func(id): return not (id in out) and not (id in seen.slice(maxi(0, seen.size() - 6))))
		var from: Array = fresh if not fresh.is_empty() else pool
		out.append(from[rng.randi() % from.size()])
	return out


## How many enemies a normal fight has: 1 to 5, more likely to be big deeper in the run.
## [count, weight] per act (the first two floors of act 1 are always a single enemy).
const GROUP_ODDS := {
	1: [[1, 0.2], [2, 0.45], [3, 0.27], [4, 0.08]],
	2: [[2, 0.3], [3, 0.38], [4, 0.22], [5, 0.1]],
	3: [[2, 0.08], [3, 0.3], [4, 0.37], [5, 0.25]],
}


static func group_size(act: int, floor: int, rng: RandomNumberGenerator) -> int:
	if act == 1 and floor <= 2:
		return 1
	var odds: Array = GROUP_ODDS.get(act, GROUP_ODDS[3])
	var r := rng.randf()
	for o in odds:
		r -= o[1]
		if r < 0.0:
			return o[0]
	return odds[-1][0]


## Extra Essence an enemy gets on top of its own row: none. Every enemy's Essence is set by hand in its row (and its
## second-phase row); nothing is added for the act or the floor.
static func extra_for(_id: String, _act: int, _floor: int, _rng: RandomNumberGenerator, _group := 2) -> Array:
	return []


static func attack_bonus(act: int) -> int:
	return [0, 0, 4, 6][act]


static func describe_move(m: Dictionary, bonus := 0, full := false) -> String:
	var s := ""
	match m.kind:
		"attack":
			var n: int = m.n + bonus
			s = "Attack %d" % n if m.get("hits", 1) == 1 else "Attack %d×%d" % [n, m.hits]
		"armor":
			s = "Armour its next Essence (the first one not armoured yet)" if m.pos < 0 else "Armour its %s Essence" % ["1st", "2nd", "3rd", "4th"][mini(m.pos, 3)]
			if m.get("who", "self") == "random":
				s = "Armour 1 Essence of one of them, at random"
		"mend":
			var el: String = "random Essence" if m.el == "random" else ("Essence" if m.el == "own" else Elements.NAMES[m.el])
			s = "Mend +%d %s%s" % [m.n, el, {"self": "", "ally": " on an ally", "all": " on every enemy", "weakest": " on the most hurt of them", "random_hurt": " on one of them at random (a hurt one first)", "samurai": " on the Samurai"}[m.get("who", "self")]]
		"shuffle":
			s = "Shuffle its Essence"
		"silence":
			var many: int = m.get("n", 1)
			s = "Silence %s (%d turn%s)" % ["ALL your spells" if m.get("all", false) else ("one of your spells" if many == 1 else "%d of your spells" % many), m.turns, "" if m.turns == 1 else "s"]
		"invert_spells":
			s = "Invert %d of your spell%s (a spell becomes an anti-spell, an anti-spell a spell)" % [m.n, "" if m.n == 1 else "s"]
			if full:
				s += ". A spell turned anti gives it 1 Essence of its pattern; one turned back gains 1 random Essence"
		"invoke":
			s = "Cast his glowing spells"
			if m.has("word"):
				s = "Chant %s %s" % [INVOKER_WORDS[m.word], Elements.NAMES[m.word]]  # (just what he'll say: "Chant Quas" + the Water icon)
			if full:
				s = "Cast the spell he chose this turn, and every one your chant contains" + ((", then chant %s (his spells lose every %s)" % [INVOKER_WORDS[m.word], Elements.NAMES[m.word]]) if m.has("word") else "")
		"cleanse_self":
			s = "Cleanse all its debuffs"
		"bottle":
			s = "Give the Samurai a bottle: cleanse him, and he is Impervious for a turn (no status can be put on him)"
		"deflect":
			s = "Deflect: this turn your Release can't touch %s (your spells still work)" % ("him or his Retainer" if m.get("pair", false) else "it")
		"drain_essence":
			s = "You lose %d random Essence from your bag" % m.n
		"disarm":
			s = "Disarm you (your next Release does nothing)"
		"hammer_spell":
			s = "Hammer the spell closest to breaking (3 hits break a spell for the fight; a spell with Durability loses 1 per hit)"
		"stunned":
			s = "Knocked out: back next turn"
		"grow_thorns":
			s = "Gain %d Thorns (your Release hitting it hurts you that much)" % int(m.n)
		"revive":
			s = "Resurrected in %d turn%s" % [int(m.left), "" if int(m.left) == 1 else "s"]
		"fireball":
			s = "Spit a Fireball: it hovers, and explodes next turn for %d" % (int(m.n) + bonus)
		"fireball_blast":
			s = "The Fireball explodes"
		"charge":
			if not full and int(m.get("left", 1)) == 0:
				s = "Fires at the end of this turn"
			elif full and m.has("n"):
				s = "Charge for %d turns (an hourglass), then hit for %d. While it charges, every spell of its own colour you cast (white: spells, black: anti-spells) raises the hit by 5 (one of the other colour does nothing to it)" % [int(m.get("turns", 3)), m.n]
			elif full:
				s = ""
			else:
				s = "Charging: %d turn%s left" % [m.left, "" if m.left == 1 else "s"]
		"ignite_spell":
			if m.get("until_cast", false):
				s = "Ignite a spell (it stays Ignited until you cast it, then deals %d damage, more if it is lit again; Shield stops it)" % Fight.IGNITE_DAMAGE
			elif m.get("all", false):
				s = "Burst: Ignite ALL your spells for your next turn (casting one burns you for %d)" % Fight.IGNITE_DAMAGE
			else:
				s = "Ignite one of your spells for your next turn (casting it burns you for %d)" % Fight.IGNITE_DAMAGE
		"stun":
			s = "Stun you: your next turn is skipped (you still get your Essence)"
		"lock":
			s = "Lock %s of your spells (%d symbols)" % ["another" if m.get("other", false) else "one", m.len]
		"steal":
			s = "Steal %d of your Essence" % m.n
		"confuse":
			s = "Confuse you: a black veil over the slot machine (next turn you can't see what is coming next)"
		"blind":
			s = "Blind you (%d turns)" % m.turns
		"poison":
			s = "Poison you (%d)" % m.n
		"bleed":
			s = "Bleed %d" % m.n
		"guard":
			s = "Guard: the Necromancer behind it can't be touched"
		"resurrect":
			s = "Raise the skeleton again, with 3 Essence"
		"summon_clock":
			s = "Calls a Sentinel in %d turn%s" % [m.n, "" if int(m.n) == 1 else "s"]
		"grounded":
			s = "Stunned: it skips its action"
		"recharge":
			s = "Recharging: it stuns itself for a turn"
		"dormant":
			s = "Dormant: it does nothing until it is down to 12 Essence, or for 3 turns"
		"glow":
			s = "Shines brighter: at 0 it stuns you (clock: %d)" % m.n
		"explode":
			s = "Explode: %d damage, and it is destroyed" % m.n
		"freeze":
			s = "Freeze %d of your Essence" % m.n
		"empower":
			s = "Empower +%d" % m.n + {"random": " one of them, at random", "samurai": " the Samurai", "all": " every enemy"}.get(m.get("who", "self"), "")
		"summon":
			if m.has("list"):
				s = "Call %d %s%s" % [m.n, E[m.list[0]].name, "" if m.n == 1 else "s"]
			elif m.has("ids"):
				s = "Call %d of: %s" % [m.n, ", ".join(m.ids.map(func(x): return E[x].name))]
			else:
				s = "Call %d %s" % [m.n, E[m.id].name] if m.has("id") else "Call %d random small slime%s" % [m.n, "" if m.n == 1 else "s"]
		"steal_spell":
			s = "Steal one of your spells (at random) and wrap it in a cocoon: break the cocoon to get it back"
		"hold":
			s = "Nothing: it just hangs there"
		"play":
			s = "He plays on. When the piece ends, you die"
		"toll":
			s = "Burden: your next chant holds at most %d Essence (the slots after it are stone)" % PlayerState.TOLL_CAP
		"invert":
			s = "Invert: swap your Fire and Water"
		"virus":
			s = "Virus: one of your spells will give you Poison %d when you cast it" % int(m.get("n", 3))
		"vulnerable":
			s = "Make you Vulnerable %d (you take 50%% more damage)" % int(m.n)
		"mimic":
			s = "Mimic: its Essence becomes your last chant, backwards"
		"wall_attack":
			s = "Each wall attacks for %d%s" % [m.n + bonus, (" × %d hits" % m.hits) if m.get("hits", 1) > 1 else ""]
		"regrow":
			s = "Regrow her %s wall" % ("left" if m.get("side", "L") == "L" else "right")
		"sing":
			s = "Sing: Power +1 (her and her walls hit 1 harder)"
		"brittle":
			s = "Brittle %d: the Shield you gain is 50%% smaller" % m.turns
	if m.has("also"):
		s += " + " + describe_move(m.also, bonus, full)
	if m.has("name"):
		s = "%s: %s" % [m.name, s]  # (a named move: the Dragon's Slap, Thrash, Bite...)
	return s
