"""Enemies move from orb HP (a row of Essence) to a number of HP (2026-11-15): 1 orb = 3 HP.

Writes, from data/spells.json (the game still loads that one, untouched):
  data/orb_spell_old.json  every current spell, as it is (the orb version)
  data/HP_spell_old.json   the same spells in HP terms, each with "hp_status" (unchanged / converted / needs_redesign)
                           and "hp_note" (what changed, or why it has no HP equivalent yet)
  docs/HP_spell_old.md     the list to read: old card text, then what changes

Usage: python tools/convert_spells_hp.py [<dump.json from tools/dump_spells.gd, for the old card texts>]
"""
import copy
import json
import sys
from pathlib import Path

ORB = 3  # HP per orb
ROOT = Path(__file__).resolve().parent.parent

# effects that work on the enemy's orbs and have no plain HP equivalent (no row of Essence to act on)
NO_HP = {
    "expose": "Repaint enemy Essence",
    "move": "Rearrange enemy Essence",
    "convert": "turn an enemy's Essence of one element into another",
    "shatter": "break enemy Armour (armour on orbs)",
    "annihilate": "wipe out one element from every enemy",
    "purge_all": "remove every Essence of one element from an enemy",
}
# passives whose number counts orbs
PASSIVE_X3 = {"strike_burn", "burn_bonus", "snipe_bonus", "thorns", "thorns_on_hit"}


def convert_effect(e, notes, flags):
    e = copy.deepcopy(e)
    op = e["op"]
    if "effects" in e:  # each_turn
        e["effects"] = [convert_effect(x, notes, flags) for x in e["effects"]]
        return e
    if op in ("strike", "pluck", "random_hit"):
        n = int(e["n"])
        old = {"strike": "%d %s damage" % (n, e.get("from", "right").title()), "pluck": "Snipe %d" % n, "random_hit": "%d Random damage" % n}[op]
        e = {k: v for k, v in e.items() if k not in ("op", "from", "n")}
        new = {"op": "damage", "n": n * ORB}
        new.update(e)
        if "bonus_if" in new:
            new["bonus"] = ORB  # (Blowtorch: +1 orb if it burns -> +3 HP)
        notes.append("%s -> %d damage" % (old, n * ORB))
        return new
    if op == "barrage":
        e["dmg"] = ORB
        notes.append("%d hits of 1 -> %d hits of %d damage" % (e["n"], e["n"], ORB))
        return e
    if op == "burn":
        n = int(e["n"])
        e["n"] = n * ORB
        msg = "Burn %d -> Burn %d (loses that much HP at the start of its turn)" % (n, n * ORB)
        if "if_burn" in e:
            pass
        notes.append(msg)
        return e
    if op == "stun" and "if_burn" in e:
        e["if_burn"] = int(e["if_burn"]) * ORB
        notes.append("its condition: %d+ Burn -> %d+ Burn" % (int(e["if_burn"]) // ORB, e["if_burn"]))
        return e
    if op in ("thorns", "amplify"):
        n = int(e["n"])
        e["n"] = n * ORB
        notes.append("%s %d -> %s %d (HP)" % (op.title(), n, op.title(), n * ORB))
        return e
    if op == "steal":
        n = int(e["n"])
        e["dmg"] = n * ORB
        notes.append("Steal %d -> deal %d damage and gain %d Essence (random element: there is no orb to take)" % (n, n * ORB, n))
        return e
    if op == "purge":
        n = int(e["n"])
        notes.append("remove up to %d %s -> %d damage (no element on an HP bar)" % (n, e.get("el", "?"), n * ORB))
        return {"op": "damage", "n": n * ORB, "target": e.get("target", "target")}
    if op == "wild_repaint":
        notes.append("Wild Repaint -> Self-Repaint (your chant only: enemies have no Essence to paint)")
        e["op"] = "self_repaint"
        return e
    if op == "wild_move":
        notes.append("Wild Rearrange -> Rearrange (your chant only)")
        e["op"] = "rearrange"
        return e
    if op == "passive" and e.get("key") in PASSIVE_X3:
        n = int(e["n"])
        e["n"] = n * ORB
        notes.append("passive %s %d -> %d" % (e["key"], n, n * ORB))
        return e
    if op == "passive" and e.get("key") == "steal_each_chant":
        e["dmg"] = int(e["n"]) * ORB
        notes.append("each Chant: Instant Steal %d -> deal %d damage and gain %d Essence into your chant" % (e["n"], e["dmg"], e["n"]))
        return e
    if op in NO_HP:
        flags.append("%s (%s): no HP equivalent" % (op, NO_HP[op]))
        return e
    return e


def main():
    src = json.loads((ROOT / "data/spells.json").read_text(encoding="utf-8"))
    old_text = {}
    if len(sys.argv) > 1:
        for s in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")):
            old_text[s["id"]] = s["text"]
    (ROOT / "data/orb_spell_old.json").write_text(json.dumps(src, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    new = copy.deepcopy(src)
    rows = {"needs_redesign": [], "converted": [], "unchanged": []}
    for s in new["spells"]:
        notes, flags = [], []
        s["effects"] = [convert_effect(e, notes, flags) for e in s["effects"]]
        status = "needs_redesign" if flags else ("converted" if notes else "unchanged")
        s["hp_status"] = status
        if notes or flags:
            s["hp_note"] = "; ".join(notes + flags)
        rows[status].append(s)
    (ROOT / "data/HP_spell_old.json").write_text(json.dumps(new, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    out = ["# HP_spell_old", "",
           "Enemies have HP instead of a row of Essence orbs: **1 orb = 3 HP**. Every spell from `data/orb_spell_old.json`, in HP terms "
           "(`data/HP_spell_old.json`). The game still runs on `data/spells.json` (the orb version) until the enemies are switched over.", "",
           "%d spells: %d converted, %d unchanged (nothing in them counts orbs), %d need a redesign (they act on the enemy's orbs)." % (
               len(new["spells"]), len(rows["converted"]), len(rows["unchanged"]), len(rows["needs_redesign"])), ""]
    titles = {"needs_redesign": "Need a redesign (no HP equivalent)", "converted": "Converted", "unchanged": "Unchanged"}
    for k in ("needs_redesign", "converted", "unchanged"):
        out += ["## %s (%d)" % (titles[k], len(rows[k])), "", "| Spell | Pattern | Rarity | Old card text | In HP terms |", "|---|---|---|---|---|"]
        for s in rows[k]:
            txt = old_text.get(s["id"], "").replace("\n", " ").replace("|", "/")
            out.append("| %s | %s | %s | %s | %s |" % (s["name"], s["pattern"], s.get("rarity", ""), txt, s.get("hp_note", "same")))
        out.append("")
    (ROOT / "docs/HP_spell_old.md").write_text("\n".join(out), encoding="utf-8")
    print("orb_spell_old: %d, HP_spell_old: %d (converted %d, unchanged %d, needs_redesign %d)" % (
        len(src["spells"]), len(new["spells"]), len(rows["converted"]), len(rows["unchanged"]), len(rows["needs_redesign"])))


main()
