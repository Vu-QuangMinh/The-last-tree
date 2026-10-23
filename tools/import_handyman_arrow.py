"""The Crossbow Hand's arrow: assets/Puppet/Enemies/Act1/handyman/Gemini_Generated_Image_*.png (newest) -> handyman/arrow.png.
The white background is cut with Tachnen's BiRefNet, only the biggest piece is kept (the raw picture has a dark sliver on its right edge), the
picture is trimmed and scaled to 420 px long. The arrow points LEFT (head on the left) in the file.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_handyman_arrow.py   (then Godot --headless --editor --quit once)"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

TACHNEN = r"D:\GitHub Projects\Tachnen"
sys.path.insert(0, TACHNEN)
import numpy as np
from PIL import Image
from scipy.ndimage import label

DIR = os.path.join(AP.PUPPET, "Enemies", "Act1", "handyman")
LENGTH = 420
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}

files = glob.glob(os.path.join(glob.escape(DIR), "Gemini_Generated_Image_*.png"))
src = max(files, key=os.path.getmtime)
import tachnen_core as core
im = core.Processor().run(Image.open(src).convert("RGBA"), CUT_OPTS)
a = np.array(im)
lab, n = label(a[:, :, 3] > 8)
sizes = np.bincount(lab.ravel())
sizes[0] = 0
a[lab != sizes.argmax(), 3] = 0
im = Image.fromarray(a)
im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
im = im.resize((LENGTH, max(1, round(im.height * LENGTH / im.width))), Image.LANCZOS)
im.save(os.path.join(DIR, "arrow.png"))
print("arrow.png", im.size, "from", os.path.basename(src))
