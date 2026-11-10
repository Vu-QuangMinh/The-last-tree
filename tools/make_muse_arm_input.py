"""2026-11-09: the input picture for MuseSet's arm clips: the user's sample (pianist seen from behind, teal background, markers "1" and "10")
with the BODY removed: only the right arm (brass shoulder ball, sleeve, elbow ball, cuff, hand) and the two markers are left, on the flat teal.
python tools/make_muse_arm_input.py <sample.png> <out.png>"""
import sys
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
bg = im.getpixel((10, 10))
# the arm's outline, traced on a 1.5x enlargement of the crop (1000, 640)-(1500, 1220) of the 1792x2400 sample
OUTLINE = [(140, 95), (185, 98), (200, 170), (205, 195), (365, 590), (385, 592), (470, 612), (480, 600), (520, 598), (560, 610), (610, 660), (637, 715),
           (632, 740), (560, 737), (520, 732), (492, 757), (450, 767), (330, 745), (260, 720), (225, 690), (222, 650), (215, 640), (130, 450), (140, 300)]
pts = [(1000 + x / 1.5, 640 + y / 1.5) for x, y in OUTLINE]
S = 4  # (a smooth edge: the mask is drawn 4x bigger and shrunk)
mask = Image.new("L", (im.width * S, im.height * S), 0)
ImageDraw.Draw(mask).polygon([(x * S, y * S) for x, y in pts], fill=255)
mask = mask.resize(im.size, Image.LANCZOS)
for box in [(30, 1030, 105, 1140), (1620, 1030, 1775, 1140)]:  # the markers "1" and "10"
    ImageDraw.Draw(mask).rectangle(box, fill=255)
canvas = Image.new("RGB", im.size, bg)
canvas.paste(im, (0, 0), mask)
canvas = canvas.crop((0, 560, 1792, 1568))  # (16:9 band around the arm and the markers, so the arm is big in the video)
canvas.save(out)
print("saved", out, canvas.size)
