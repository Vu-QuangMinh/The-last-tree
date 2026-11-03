"""Puppet Stage theme: the events' dialogue box, painted by ImageSet (set "Puppet Dialogue", prompts in assets/Puppet/UI/Panels/dialogue_prompts.txt + dialogue_style.txt;
raw pictures kept in assets/Puppet/_Source/Dialogue Frame.png and Dialogue Button*.png) -> assets/Puppet/UI/Panels/dialogue_panel.png and UI/Buttons/btn_<kind>.png (primary gold, default walnut, back cream, danger red, buy green), all 9-slice.
  panel: the carved frame with the red velvet. It is only a strip high on screen, so the painted rim is squeezed to T px (the velvet keeps its scale, a band of it is cut out
         between the rims) and the brass nails are cut from the painting and set back on the thin corners.
  button: the walnut plaque with the brass line and the ochre-gold face, scaled to BTN_H px high (the Gemini star in the corner is left out).
Run: python tools/cut_dialogue_panel.py   (needs pillow; then Godot --headless --editor --quit once so it imports the new files)"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "_Source")
DIR = os.path.join(AP.PUPPET, "UI", "Panels")
W = 1060  # the box's width on screen (EventStage.BOX_TEXT_W + 60)
T = 14  # the rim's thickness on screen
R = 100  # the painted rim's thickness in the picture
BAND = 130  # rows of velvet between the rims
NAIL = (45, 47, 13)  # the top-left nail in the picture, measured from the cut picture's corner: x, y, radius
BTN_H = 48


def cut(im, limit=None):
	"""The object on the black background: crop to it and make the background (reached from the corners) transparent."""
	im = im.convert("RGB")
	if limit is not None:
		im = im.crop((0, 0, im.width, int(im.height * limit)))
	bb = im.point(lambda v: 255 if v > 20 else 0).convert("L").getbbox()
	im = im.crop(bb)
	mask = im.point(lambda v: 255 if v > 20 else 0).convert("L").point(lambda v: v)
	flood = Image.new("L", im.size, 0)
	dark = im.convert("L").point(lambda v: 255 if v <= 20 else 0)
	for pt in ((0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)):
		if dark.getpixel(pt) == 255:
			ImageDraw.floodfill(dark, pt, 128)
	alpha = dark.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.GaussianBlur(0.8))
	out = im.convert("RGBA")
	out.putalpha(alpha)
	return out


def panel():
	src = cut(Image.open(os.path.join(SRC, "Dialogue Frame.png")))
	sw, sh = src.size
	nail = src.crop((NAIL[0] - NAIL[2], NAIL[1] - NAIL[2], NAIL[0] + NAIL[2], NAIL[1] + NAIL[2]))
	disc = Image.new("L", nail.size, 0)
	ImageDraw.Draw(disc).ellipse((1, 1, nail.width - 2, nail.height - 2), fill=255)
	nail.putalpha(disc)
	k = W / sw
	inner = src.crop((R, R, sw - R, sh - R))
	iw = W - 2 * T
	inner = inner.resize((iw, round(inner.height * k)), Image.LANCZOS)
	mid = inner.height // 2
	out = Image.new("RGBA", (W, T + BAND + T), (0, 0, 0, 0))
	out.paste(inner.crop((0, mid - BAND // 2, iw, mid + BAND // 2)), (T, T))
	H = out.height

	def rim(box, size, at):
		out.paste(src.crop(box).resize(size, Image.LANCZOS), at)

	rim((R, 0, sw - R, R), (W - 2 * T, T), (T, 0))
	rim((R, sh - R, sw - R, sh), (W - 2 * T, T), (T, H - T))
	rim((0, R, R, sh - R), (T, H - 2 * T), (0, T))
	rim((sw - R, R, sw, sh - R), (T, H - 2 * T), (W - T, T))
	for cx, cy, at in ((0, 0, (0, 0)), (sw - R, 0, (W - T, 0)), (0, sh - R, (0, H - T)), (sw - R, sh - R, (W - T, H - T))):
		rim((cx, cy, cx + R, cy + R), (T, T), at)
	n = nail.resize((T - 4, T - 4), Image.LANCZOS)
	for at in ((2, 2), (W - T + 2, 2), (2, H - T + 2), (W - T + 2, H - T + 2)):
		out.alpha_composite(n, at)
	out.save(os.path.join(DIR, "dialogue_panel.png"))
	print("dialogue_panel", out.size)


BUTTONS = {"primary": "Dialogue Button", "default": "Dialogue Button Walnut", "back": "Dialogue Button Cream", "danger": "Dialogue Button Red", "buy": "Dialogue Button Green"}
BW = 128  # the plaque's width (it is stretched wider in the game: 9-slice, margin 20)
SS = 4  # supersampling for the edges
BEVEL = 3  # px: the chiselled edge, hard (not a gradient)


def shifted(mask, dx, dy):
	out = Image.new("L", mask.size, 0)  # (no wrap-around, unlike ImageChops.offset)
	out.paste(mask, (dx, dy))
	return out


def plank(raw):
	"""A flat, rough wooden plank button: the painted wood of the ImageSet picture (its middle: grain, chips, brush marks) cut to a rounded block with a hard chiselled bevel,
	lit from the upper left like the rest of the art (light top / left edges, dark bottom / right edges, a dark outline). No gradient, no shine."""
	im = raw.convert("RGB")
	w, h = im.size
	face = im.crop((int(w * 0.30), int(h * 0.36), int(w * 0.70), int(h * 0.64)))  # (just paint and grain: no rim, no star)
	W, H = BW * SS, BTN_H * SS
	tex = face.resize((W, H), Image.LANCZOS)
	mask = Image.new("L", (W, H), 0)
	ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), radius=9 * SS, fill=255)
	d = BEVEL * SS
	inner = mask.filter(ImageFilter.MinFilter(2 * d + 1))
	lit = ImageChops.subtract(mask, shifted(mask, d, d))  # (the top-left edge)
	shade = ImageChops.subtract(mask, shifted(mask, -d, -d))  # (the bottom-right edge)
	line = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(SS + 1)))  # (the outline)
	light = Image.new("RGB", (W, H), (255, 240, 215))
	dark = Image.new("RGB", (W, H), (30, 14, 8))
	out = Image.composite(light, tex, lit.point(lambda v: v * 40 // 100))
	out = Image.composite(dark, out, shade.point(lambda v: v * 55 // 100))
	out = Image.composite(Image.new("RGB", (W, H), (28, 12, 6)), out, line.point(lambda v: v * 85 // 100))
	res = out.resize((BW, BTN_H), Image.LANCZOS).convert("RGBA")
	res.putalpha(mask.resize((BW, BTN_H), Image.LANCZOS))
	return res


def buttons():
	for kind, raw in BUTTONS.items():
		path = os.path.join(SRC, raw + ".png")
		if not os.path.exists(path):
			continue
		out = plank(Image.open(path))
		out.save(os.path.join(AP.PUPPET, "UI", "Buttons", "btn_%s.png" % kind))
		print("btn_" + kind, out.size)


panel()
buttons()
