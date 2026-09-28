class_name EnemyInfo
extends RefCounted
## What hovering an enemy portrait shows: its moves as bullet points, in the order it uses them
## (only once it's in your Codex), with every keyword explained.


static func moves_tooltip(id: String, bonus: int) -> String:
	var d := EnemyDefs.get_def(id)
	var title: String = d.name + (" · Boss" if d.get("boss", false) else (" · Elite" if d.get("elite", false) else ""))
	if not SaveManager.in_codex(id):
		return Keywords.tooltip(title, "Moves unknown. Defeat it once to record it in the Codex.")
	var lines := ["Moves, in order (then it starts again):"]
	for m in d.moves:
		lines.append("• " + EnemyDefs.describe_move(m, bonus))
	if d.has("moves2"):
		lines.append("Below half Essence it switches to:")
		for m in d.moves2:
			lines.append("• " + EnemyDefs.describe_move(m, bonus))
	for p in d.get("passives", []):
		lines.append("◆ " + EnemyDefs.PASSIVE_TEXT[p])
	return Keywords.tooltip(title, "\n".join(lines))
