"""2026-11-09: input picture for MuseSet "set 2": the grand piano ALONE (the clean piano_1 picture aligned onto the user's scene picture) plus the right ARM only
(cut out of the user's picture with a traced outline): no pianist body, head, hat, stool or sheet. The piano stays so that Muse understands the keys.
python tools/make_muse_set2_input.py <scene.png (the user's picture)> <out.png>"""
import sys
from PIL import Image, ImageDraw

scene, out = sys.argv[1], sys.argv[2]
src = Image.open(scene).convert("RGBA")
bg = Image.new("RGBA", src.size, (255, 255, 255, 255))
bg.alpha_composite(src)
s = bg.convert("RGB")
piano = Image.open(r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\back\piano_1.png").convert("RGBA")
q = piano.resize((round(piano.width * 0.536), round(piano.height * 0.536)), Image.LANCZOS)  # (scale / offset found by matching the piano's outer parts)
base = Image.new("RGBA", s.size, (255, 255, 255, 255))
base.alpha_composite(q, (178, 110))
base = base.convert("RGB")
# the arm's outline, traced on a 4x enlargement of the crop (730, 480)-(990, 710)
OUTLINE = [(192, 100), (240, 108), (272, 170), (300, 178), (335, 205), (420, 390), (500, 520), (545, 600), (600, 605), (655, 620), (705, 616), (770, 645), (825, 690),
           (852, 745), (870, 775), (866, 796), (800, 788), (735, 792), (712, 800), (660, 802), (600, 801), (540, 797), (480, 775), (430, 745), (398, 700), (330, 630),
           (270, 540), (215, 450), (190, 400), (190, 340)]
pts = [(730 + x / 4, 480 + y / 4) for x, y in OUTLINE]
S = 4
mask = Image.new("L", (s.width * S, s.height * S), 0)
ImageDraw.Draw(mask).polygon([(x * S, y * S) for x, y in pts], fill=255)
mask = mask.resize(s.size, Image.LANCZOS)
base.paste(s, (0, 0), mask)
top, bot = 90, 1230  # (the same 16:9 framing as the scene picture)
crop = base.crop((0, top, base.width, bot))
h = crop.height
w = round(h * 16 / 9)
canvas = Image.new("RGB", (w, h), (255, 255, 255))
canvas.paste(crop, ((w - crop.width) // 2, 0))
canvas = canvas.crop((545, 320, 1515, 866)).resize((1920, 1080), Image.LANCZOS)  # (16:9 close-up on the keyboard: the arm is twice as big in the video)
canvas.save(out)
print("saved", out, canvas.size)
