"""The merchant of the Ruined Watchtower (2026-11-02): the whole group of the shop (the merchant, his cart and both wheels), put together the way ShopScreen puts them (the PDF's places),
into assets/Puppet/Events/event_merchant.png at full size. Run with Tachnen's python: python tools/make_event_merchant.py"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

SRC = os.path.join(AP.PUPPET, "UI", "Characters", "Merchant")
# the places in Merchant.pdf (x, y, w, h): the same numbers as ShopScreen's CART_RECT, WHEEL_*_RECT, MERCHANT_RECT
PARTS = [
    ("Cart.png", (1064.3, 114.1, 696.0, 655.0)),
    ("Layer 1.png", (1217.1, 563.3, 142.7, 142.7)),
    ("layer 2.png", (1504.7, 527.9, 178.1, 178.1)),
    ("merchant_full.png", (931.9, 330.1, 256.0, 387.0)),
]
K = 3.0  # (picture pixels per PDF px: the cart's picture is about that big)


def main():
    x0 = min(r[0] for _, r in PARTS)
    y0 = min(r[1] for _, r in PARTS)
    x1 = max(r[0] + r[2] for _, r in PARTS)
    y1 = max(r[1] + r[3] for _, r in PARTS)
    out = Image.new("RGBA", (round((x1 - x0) * K), round((y1 - y0) * K)), (0, 0, 0, 0))
    for name, (x, y, w, h) in PARTS:
        im = Image.open(os.path.join(SRC, name)).convert("RGBA").resize((round(w * K), round(h * K)), Image.LANCZOS)
        out.alpha_composite(im, (round((x - x0) * K), round((y - y0) * K)))
    dest = os.path.join(AP.PUPPET, "Events", "event_merchant.png")
    out.save(dest)
    print(dest, out.size)


if __name__ == "__main__":
    main()
