"""The new card list (data/HP_spell_new.json) <-> an Excel sheet the user fills in (docs/new_cards.xlsx).

    python tools/new_cards_sheet.py export   # JSON -> xlsx (overwrites the sheet)
    python tools/new_cards_sheet.py import   # xlsx -> JSON (names, texts, upgrades; patterns stay as they are)
"""
import json
import sys
from pathlib import Path

from openpyxl import Workbook, load_workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "data" / "HP_spell_new.json"
XLSX_PATH = ROOT / "docs" / "new_cards.xlsx"
WORDS = {"F": "Fire", "W": "Water", "A": "Wind"}
FILL = {"F": "F4B183", "W": "9DC3E6", "A": "C5E0B4"}
HEAD = ["Pattern", "Marbles", "Length", "Id", "Name", "Text", "Upgrade 1", "Upgrade 2", "Notes"]
WIDTH = [10, 26, 8, 16, 20, 50, 40, 40, 40]


def export() -> None:
    d = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    wb = Workbook()
    ws = wb.active
    ws.title = "Cards"
    ws.append(["New cards: one row per pattern (order counts). Fill in Name, Text, Upgrade 1, Upgrade 2. "
               "Grey columns are fixed; Id is made from the Name if left empty. Then: python tools/new_cards_sheet.py import"])
    ws.append(HEAD)
    font = Font(name="Arial", size=11)
    bold = Font(name="Arial", size=11, bold=True)
    grey = PatternFill("solid", fgColor="E7E6E6")
    ws["A1"].font = Font(name="Arial", size=11, italic=True)
    for c in range(1, len(HEAD) + 1):
        ws.cell(row=2, column=c).font = bold
    for sp in d["spells"]:
        up = sp.get("upgrades") or [None, None]
        ws.append([sp["pattern"], ", ".join(WORDS[ch] for ch in sp["pattern"]), len(sp["pattern"]), sp.get("id", ""),
                   sp.get("name", ""), sp.get("text", ""), up[0] if len(up) > 0 else None, up[1] if len(up) > 1 else None,
                   sp.get("pattern_clash", "")])
        r = ws.max_row
        for c in range(1, len(HEAD) + 1):
            cell = ws.cell(row=r, column=c)
            cell.font = font
            cell.alignment = Alignment(wrap_text=True, vertical="top")
            if c in (2, 3):
                cell.fill = grey
        ws.cell(row=r, column=1).fill = PatternFill("solid", fgColor=FILL[sp["pattern"][0]])
        ws.cell(row=r, column=1).font = bold
    for i, w in enumerate(WIDTH, 1):
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.freeze_panes = "A3"
    ws.auto_filter.ref = "A2:%s%d" % (get_column_letter(len(HEAD)), ws.max_row)
    XLSX_PATH.parent.mkdir(exist_ok=True)
    wb.save(XLSX_PATH)
    print("wrote", XLSX_PATH, ws.max_row - 2, "rows")


def _id(name: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in name.strip().lower()).strip("_")


def do_import() -> None:
    d = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    by_pat = {}
    for sp in d["spells"]:
        by_pat.setdefault(sp["pattern"], []).append(sp)
    ws = load_workbook(XLSX_PATH).active
    n = 0
    seen = set()  # (a pattern two cards share for now: each row its own card, matched by Id first)
    more = []  # rows with no Pattern (a second list, 2026-11-21): kept with their Marbles as written
    for row in ws.iter_rows(min_row=3, values_only=True):
        pat, marbles, _l, cid, name, text, up1, up2, notes = (list(row) + [None] * 9)[:9]
        if not pat and name:
            more.append({"marbles": (marbles or "").strip(), "name": str(name).strip(), "text": str(text or "").strip(),
                         "upgrades": [str(u).strip() for u in (up1, up2) if u and str(u).strip()], "notes": (notes or "").strip()})
            continue
        if not pat or pat not in by_pat:
            continue
        cands = [x for x in by_pat[pat] if id(x) not in seen]
        if not cands:
            continue
        sp = next((x for x in cands if cid and x.get("id") == str(cid).strip()), cands[0])
        seen.add(id(sp))
        name = (name or "").strip()
        if name and not sp.get("id"):
            sp["id"] = (cid or "").strip() or _id(name)
        elif cid:
            sp["id"] = str(cid).strip()
        sp["name"] = name
        sp["text"] = str(text or "").strip()
        ups = [str(u).strip() for u in (up1, up2) if u is not None and str(u).strip()]
        if ups:
            sp["upgrades"] = ups
        if notes and str(notes).strip():
            sp["notes"] = str(notes).strip()
        n += 1
    old = d.get("more_cards", [])
    for i, m in enumerate(more):  # (the user's first wording and other fields are kept)
        if i < len(old):
            keep = dict(old[i])
            keep.update(m)
            more[i] = keep
    d["more_cards"] = more
    JSON_PATH.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")
    print("read", n, "rows into", JSON_PATH)


if __name__ == "__main__":
    {"export": export, "import": do_import}[sys.argv[1] if len(sys.argv) > 1 else "export"]()
