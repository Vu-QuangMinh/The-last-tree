"""The sounds of what spells do, for tools/make_spell_sfx.py (see FX below).
Prompts are short and only about the sound (the source, then one or two words on how it sounds): the model works best like that."""


## Words added to the negative prompt of one sound (what it must NOT sound like), by key.
EXTRA_NEGATIVE = {
    "fx_magic_bolt": "bell, chime, ringing, sparkle, glockenspiel, high pitched",
}

## The sound of what spells DO, shared by many cards (Burn, Shield, Heal, Repaint ...): group id -> (name, prompt, seconds). Made into SFX/Spell SFX/spellfx_<id>.wav;
## the effect events of a fight play them (FightScreen.EFFECT_FX). The ops each one stands for are in the comment.
FX = {
    "remove_essence": ("Remove Essence", "wooden ball smashing, hard wood crack and splintering", 1.3),  # strike, random_hit
    "magic_bolt": ("Magic Bolt", "deep low magical bolt whoosh, dark arcane thump, bass energy", 1.2),  # barrage (each shot of a volley)
    "snipe": ("Snipe", "sci-fi laser beam zap, high energy whine, no gunshot", 1.3),  # pluck
    "burn": ("Burn", "flame igniting, hissing flare of fire catching", 1.8),  # burn
    "stoke": ("Double Burn", "flames flaring up doubled, fire swelling whoosh", 1.8),  # stoke
    "weaken": ("Weaken", "weakening magic, drained descending sigh, soft sagging thud", 1.6),  # weak
    "vulnerable": ("Vulnerable", "brittle shell cracking, fragile glass crackle", 1.5),  # vulnerable
    "freeze": ("Freeze", "freezing crackle, ice forming fast, frosty shimmer", 1.8),  # freeze
    "daze": ("Dazed", "dizzy ringing tone, wobbling woozy swirl", 1.8),  # daze
    "ethereal": ("Ethereal", "ghostly shimmer, airy phasing whoosh", 1.8),  # ethereal
    "shield": ("Shield", "magic shield forming, bright ring and a soft thud", 1.5),  # shield
    "lasting_shield": ("Lasting Shield", "heavy lasting barrier forming, deep solid hum, metal ring", 2.2),  # shield (Lasting)
    "thorns": ("Thorns", "heavy powerful slam, forceful retaliating crack, strong counter strike", 1.8),  # thorns, thorn_guard
    "evasion": ("Evasion", "quick dodge swish, light sidestep whoosh", 1.2),  # aegis
    "cleanse": ("Cleanse", "holy blessing, soft angelic shimmer, gentle uplifting bells", 2.2),  # cleanse, unbind
    "repaint": ("Repaint", "paintbrush scrubbing and smearing wet paint, then a paint splash", 2.0),  # expose, wild_repaint, self_repaint (the same sound)
    "infuse": ("Infuse", "magical essence poured in, bubbling liquid drop, glow", 1.6),  # infuse, infuse_upcoming
    "rearrange": ("Rearrange", "deep hollow wooden balls knocking and sliding, low wood clacks", 1.5),  # rearrange, wild_move, move
    "duplicate": ("Duplicate", "magical copy echo, double chime, shimmering clone", 1.8),  # duplicate, echo_next
    "conjure": ("Conjure", "spell conjured from nothing, magical whoosh and sparkle, pop", 1.8),  # conjure, summon_spells
    "steal": ("Steal", "fast swishing whoosh whoosh, quick snatching swipes", 2.2),  # steal
    "execute": ("Execute", "final executioner blow, heavy slash and thud", 1.8),  # execute
    "purge": ("Purge Essence", "sweeping vacuum clearing everything, big wipe whoosh", 2.2),  # purge, purge_all, annihilate
    "transmute": ("Transmute", "alchemical transformation, bubbling fizz, magical change chime", 1.8),  # convert, transmute
    "gain_essence": ("Gain Essence", "glowing orb appearing, soft magical pickup chime", 1.4),  # draw
    "lose_hp": ("Lose HP", "dark sacrifice, heartbeat thump, painful gulp", 1.6),  # sacrifice
    "max_hp": ("Max HP", "vitality swell, rising warm chime", 2.0),  # max_hp
    "amplify": ("Amplify", "power surge, rising hum, crackling energy", 1.8),  # amplify
    "break_armour": ("Break Armour", "armour breaking apart, metal crack, plates clattering", 1.8),  # shatter
    "seal": ("Seal", "magic lock sealing, heavy click, wax stamp press", 1.4),  # temp_seal
    "power": ("Power", "passive power pulse, low magical throb, soft glow", 1.8),  # passive, each_turn
    "refund": ("Refund", "coin returned, quick rewind chime", 1.4),  # retain
    "curse": ("Curse", "clear shhh shushing sound, breathy ominous hiss", 1.8),  # curse
}
