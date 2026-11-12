import numpy as np, math, sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA"); W, H = im.size
A = np.array(im); alpha = A[:, :, 3] > 8
J = {  # source px (2048): joints read off the gridded picture
 "neck": (1040, 575), "pelvis": (1030, 1090), "head_top": (1040, 120),
 "sh_l": (890, 690), "el_l": (620, 890), "wr_l": (530, 985), "hand_l": (500, 1020),
 "sh_r": (1215, 680), "el_r": (1430, 1000), "wr_r": (1560, 1180), "hand_r": (1650, 1330),
 "hip_l": (930, 1090), "kn_l": (860, 1540), "an_l": (890, 1830), "toe_l": (800, 1930),
 "hip_r": (1130, 1090), "kn_r": (1200, 1540), "an_r": (1180, 1830), "toe_r": (1300, 1930)}
BONES = {  # piece -> (joint a, joint b)
 "head": ("neck", "head_top"), "torso": ("neck", "pelvis"),
 "uarm_l": ("sh_l", "el_l"), "farm_l": ("el_l", "hand_l"), "uarm_r": ("sh_r", "el_r"), "farm_r": ("el_r", "hand_r"),
 "thigh_l": ("hip_l", "kn_l"), "shin_l": ("kn_l", "an_l"), "foot_l": ("an_l", "toe_l"),
 "thigh_r": ("hip_r", "kn_r"), "shin_r": ("kn_r", "an_r"), "foot_r": ("an_r", "toe_r")}
names = list(BONES)
yy, xx = np.mgrid[0:H, 0:W]
def segdist(a, b):
    a = np.array(J[a], float); b = np.array(J[b], float); ab = b - a
    t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / (ab @ ab), 0, 1)
    return np.hypot(xx - (a[0] + t * ab[0]), yy - (a[1] + t * ab[1]))
D = np.stack([segdist(*BONES[n]) for n in names])
# the hat is wide: the head bone is as long as the head; torso keeps everything between the shoulders
D[names.index("head")] *= 0.55
D[names.index("torso")] *= 0.9
label = np.argmin(D, axis=0)
label[~alpha] = -1
# the pitchfork (a held prop): everything left of x=700 goes with the left forearm
label[(xx < 700) & alpha] = names.index("farm_l")
pieces = {}
for i, n in enumerate(names):
    m = (label == i)
    pieces[n] = m
def piece_img(n, grow=10):
    from scipy.ndimage import binary_dilation
    m = binary_dilation(pieces[n], iterations=grow) & alpha  # a little overlap under the neighbour: no gap when it turns
    a = A.copy(); a[~m, 3] = 0
    return Image.fromarray(a, "RGBA")
imgs = {n: piece_img(n) for n in names}
PARENT = {"head": ("torso", "neck"), "uarm_l": ("torso", "sh_l"), "uarm_r": ("torso", "sh_r"), "farm_l": ("uarm_l", "el_l"), "farm_r": ("uarm_r", "el_r"),
          "thigh_l": ("torso", "hip_l"), "thigh_r": ("torso", "hip_r"), "shin_l": ("thigh_l", "kn_l"), "shin_r": ("thigh_r", "kn_r"), "foot_l": ("shin_l", "an_l"), "foot_r": ("shin_r", "an_r")}
ORDER = ["thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "torso", "uarm_r", "farm_r", "head", "uarm_l", "farm_l"]
def rot(a, c):
    ca, sa = math.cos(a), math.sin(a)
    return np.array([[ca, -sa, c[0] - ca * c[0] + sa * c[1]], [sa, ca, c[1] - sa * c[0] - ca * c[1]], [0, 0, 1]])
def render(angles, out, shift=(0, 0)):
    M = {"torso": rot(angles.get("torso", 0), J["pelvis"])}
    M["torso"] = M["torso"].copy(); M["torso"][0, 2] += shift[0]; M["torso"][1, 2] += shift[1]
    for n in ["head", "uarm_l", "uarm_r", "thigh_l", "thigh_r", "farm_l", "farm_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
        p, j = PARENT[n]
        M[n] = M[p] @ rot(angles.get(n, 0), J[j])
    canvas = Image.new("RGBA", (W, H), (40, 50, 70, 255))
    for n in ORDER:
        inv = np.linalg.inv(M[n])
        t = imgs[n].transform((W, H), Image.AFFINE, (inv[0, 0], inv[0, 1], inv[0, 2], inv[1, 0], inv[1, 1], inv[1, 2]), Image.BICUBIC)
        canvas.alpha_composite(t)
    canvas.resize((700, 700)).save(out)
d = math.radians
base = sys.argv[2]
render({}, base + "_0_rest.png")
render({"uarm_r": d(-75), "farm_r": d(-25), "torso": d(-4), "head": d(5)}, base + "_1_raise.png")                       # a swing: right arm up and forward
render({"uarm_l": d(25), "farm_l": d(-35), "uarm_r": d(20), "farm_r": d(30), "torso": d(5), "thigh_l": d(-12), "thigh_r": d(14), "shin_l": d(10), "shin_r": d(-6), "head": d(-6)}, base + "_2_lunge.png")
render({"uarm_l": d(8), "uarm_r": d(-6), "torso": d(1.5), "head": d(2)}, base + "_3_idle.png", shift=(0, 6))
# the pieces side by side
sheet = Image.new("RGBA", (W, H), (40, 50, 70, 255))
tiles = Image.new("RGBA", (2800, 1400), (40, 50, 70, 255))
for k, n in enumerate(names):
    bb = imgs[n].getbbox(); c = imgs[n].crop(bb); c.thumbnail((380, 380)); tiles.alpha_composite(c, ((k % 7) * 400 + 10, (k // 7) * 400 + 10))
tiles.resize((1400, 700)).save(base + "_pieces.png")
