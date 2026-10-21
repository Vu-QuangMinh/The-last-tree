class_name PuppetTopHud
extends RefCounted
## Measured on page 2 of Chant UI for puppet.pdf (the page is 1920 x 1080 = the screen, 1 pt = 1 design px); the slot frames are cut by tools/export_slot_boards.py,
## the older pieces (hud_frame, bottle_board, debuff_board, hover board) by tools/export_top_hud.py, which no longer writes this file.
## The HUD of a fight: the Debuff board top left, the Act sign hanging top right, the Artifact and Bottle frames, HP and Shield bottom left, the Menu bottom right.

const ACT_SIGN := Rect2(1611.8, 55.7, 212.3, 198.7)  # hanging_sign.png at 70 % of the page's size (303.3 x 283.8), same top centre: it drops at the start of a fight and goes back up 10 s after the enemies and props are out
const ACT_TEXT := Rect2(1627.3, 132.9, 183.4, 112.0)  # inside the gold line of its board
const ACT_PX := 21
const ACT_SHOWN := 10.0  # seconds it hangs once everything is out
const TRAY := Rect2(450.6, 968.0, 274.2, 58.1)  # the HP bar (ring + bar), see StripeHpBar
const HEART_AT := Vector2(465.9, 1034.6)  # (24 px picture; hidden now: the ring holds the numbers)
const RING_TEXT := Vector2(54.0, 18.0)  # the two lines in the ring, each this big, centred on the ring (481.4, 997.5 on the screen)
const RING_HP_AT := Vector2(454.4, 981.2)  # "37/50": the ring's top line
const RING_SHIELD_AT := Vector2(454.4, 997.2)  # the Shield: its second line
const HP_PX := 14
const SHIELD_PX := 14
const LASTING_AT := Vector2(586.2, 1034.6)  # "Lasting 4", under the bar
const LASTING_PX := 16
const BOTTLES := Rect2(450.6, 875.0, 279.1, 88.2)  # the Bottle Slot: one row of five
const ARTIFACTS := Rect2(163.1, 875.0, 269.7, 104.0)  # the Artifact Slot: two rows of five
const SLOT_MARGINS := [68.0, 38.0, 53.0, 38.0]  # slot_board.png (9-slice): left, top, right, bottom
const SLOT_PAD := Vector2(14.0, 8.0)  # inside a slot frame: the items keep this far from its edges (sideways, up and down)
const FRAME_MARGINS := Vector2(68.0, 53.0)  # 3-slice: the left cap and the right cap of hud_frame.png
const BOARD_MARGINS := [24.8, 25.9, 36.8, 21.1]  # bottle_board.png (9-slice): left, top, right, bottom
const DEBUFF_MARGIN := 24  # 9-slice margin of debuff_board.png
const HOVER_MARGINS := [25.7, 22.5, 23.3, 20.2]  # artifact_hover_board.png: left, top, right, bottom
const MENU := Rect2(1765.8, 1002.5, 130.3, 45.7)  # bottom right
const DEBUFF_AT := Vector2(50.2, 244.5)  # the debuff board: its top-left corner stays put, it grows right and down
const DEBUFF_MIN := Vector2(206.0, 88.2)  # its size on the page (never smaller)
const DEBUFF_MAX_RIGHT := 700.0  # it is never wider than this (a long row squeezes together)
