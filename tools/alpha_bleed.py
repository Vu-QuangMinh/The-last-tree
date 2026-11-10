"""2026-11-10: no white outline on cut-out sprites. A sprite cut on a white page has WHITE colour in its transparent pixels and a white-ish matte in its semi-transparent edge pixels; when the
game scales the picture (bilinear) that white leaks into the edge = a pale outline. bleed(im) keeps every pixel's ALPHA as it is but gives each edge pixel (alpha < 255, or a solid pixel within
`erode` px of the edge) the COLOUR of the nearest solid pixel of the sprite's core, so the edge only ever blends the sprite's own colours. Pictures with no transparency are left alone."""
import numpy as np
from PIL import Image
from scipy import ndimage


def bleed(im, erode=1):
    a = np.array(im.convert("RGBA"))
    al = a[:, :, 3]
    if al.min() == 255:
        return im.convert("RGBA")
    core = ndimage.binary_erosion(al >= 250, iterations=erode)
    if not core.any():
        return im.convert("RGBA")
    _, (iy, ix) = ndimage.distance_transform_edt(~core, return_indices=True)
    out = a.copy()
    fix = ~core
    out[fix, :3] = a[iy[fix], ix[fix], :3]
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        bleed(Image.open(p)).save(p)
