"""Takes the Gemini star (the little four-point watermark in the bottom-right corner) OUT of a picture by reversing its alpha blend, the way GeminiWatermarkTool does: pix = a*255 + (1-a)*orig, so orig = (pix - 255a) / (1 - a).
The tool's own detection fails on our pure-black art (it skips: "No watermark detected"), so the alpha template is measured from a star that sits on pure black (tools/gemini_star_alpha.png, 96x96, same for every picture
size we get: 2752x1536 and 2048x2048 put it at the same offset from the corner: its box is [w-160, h-160, 96, 96]). Where the star lies over the part (a button's rounded corner) the part's own colours come back; over black it
becomes black again. Nothing is cut or painted over, nothing is resized."""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "gemini_star_alpha.png")
BOX = 96
OFFSET = 160


def make_template(png_with_star_on_black):
    """One-off: measure the alpha from a picture whose star lies over pure black."""
    a = np.asarray(Image.open(png_with_star_on_black).convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    box = a[h - OFFSET:h - OFFSET + BOX, w - OFFSET:w - OFFSET + BOX].mean(axis=2) / 255.0
    box = np.where(box < 0.04, 0.0, box)
    Image.fromarray((box * 255).astype(np.uint8), "L").save(TEMPLATE)


def remove(im):
    """im: PIL image (RGB / RGBA); returns the same kind with the star taken out."""
    t = np.asarray(Image.open(TEMPLATE)).astype(np.float32) / 255.0
    arr = np.asarray(im.convert("RGBA")).astype(np.float32)
    h, w = arr.shape[:2]
    y0, x0 = h - OFFSET, w - OFFSET
    reg = arr[y0:y0 + BOX, x0:x0 + BOX, :3]
    a = np.minimum(t, 0.95)[..., None]
    orig = (reg - 255.0 * a) / (1.0 - a)
    arr[y0:y0 + BOX, x0:x0 + BOX, :3] = np.clip(orig, 0.0, 255.0)
    return Image.fromarray(arr.astype(np.uint8), "RGBA").convert(im.mode)
