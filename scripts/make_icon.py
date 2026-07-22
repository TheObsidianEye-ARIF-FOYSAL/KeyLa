"""Generates the Keyla app icon: a hexagonal key on an indigo gradient.

Shapes are drawn 4x oversampled and downscaled for antialiasing; the gradient
is built at final size (a per-pixel loop at 4x would be needlessly slow).
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024          # final size
SS = 4            # supersample factor for the key artwork
OUT = os.path.join(os.path.dirname(__file__), "out")

INDIGO = (79, 70, 229)        # AppColors.primary
INDIGO_DARK = (43, 37, 130)   # a shade below primaryDark, for gradient depth
EMERALD = (16, 185, 129)      # AppColors.success
WHITE = (255, 255, 255)
LILAC = (226, 224, 255)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def gradient(size):
    """Diagonal top-left -> bottom-right indigo ramp."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x / size * 0.45 + y / size * 0.55)
            px[x, y] = lerp(INDIGO, INDIGO_DARK, t)
    return img


def glow(size):
    """Soft light bloom in the upper-left, so the tile isn't flat."""
    layer = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(layer)
    cx, cy, r = size * 0.28, size * 0.20, size * 0.62
    steps = 40
    for i in range(steps):
        f = 1 - i / steps
        rr = r * (i + 1) / steps
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=int(46 * f * f))
    return layer.filter(ImageFilter.GaussianBlur(size * 0.04))


def hexagon(cx, cy, r, rotation=math.pi / 2):
    return [
        (cx + r * math.cos(rotation + i * math.pi / 3),
         cy + r * math.sin(rotation + i * math.pi / 3))
        for i in range(6)
    ]


def key_layer(size, scale):
    """The key, drawn on transparency. `scale` shrinks it within the canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def u(v):
        # Layout is authored in a 1024 design space, centred and scaled.
        return size / 2 + (v - 512) * (size / 1024) * scale

    # --- bow: a hexagonal ring ---
    # Sits left of centre so the teeth, which only extend right, balance it.
    bow_cx, bow_cy = 494, 352
    d.polygon([(u(x), u(y)) for x, y in hexagon(bow_cx, bow_cy, 196)], fill=WHITE)
    # Alpha 0 on an RGBA image replaces rather than blends, punching the ring open.
    d.polygon([(u(x), u(y)) for x, y in hexagon(bow_cx, bow_cy, 118)], fill=(0, 0, 0, 0))

    # --- teeth, stepping off the right of the shaft ---
    # Both start inside the shaft so they read as one solid key, not floating bars.
    d.rounded_rectangle([u(490), u(646), u(730), u(716)], radius=u(547) - u(512),
                        fill=EMERALD)
    d.rounded_rectangle([u(490), u(768), u(654), u(838)], radius=u(547) - u(512),
                        fill=WHITE)

    # --- shaft ---
    d.rounded_rectangle(
        [u(456), u(500), u(532), u(880)], radius=u(550) - u(512), fill=WHITE
    )
    return img


def build(size, scale, background=True):
    art = key_layer(size * SS, scale).resize((size, size), Image.LANCZOS)

    if not background:
        return art

    base = gradient(size).convert("RGBA")
    base.paste(Image.new("RGB", (size, size), WHITE), (0, 0), glow(size))

    # Drop the key onto the tile with a soft shadow so it lifts off the gradient.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow.putalpha(art.getchannel("A").point(lambda a: a * 0.42))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.018))
    base.alpha_composite(shadow, (0, int(size * 0.014)))
    base.alpha_composite(art)
    return base


def rounded(img, radius_ratio=0.225):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_ratio), fill=255,
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


os.makedirs(OUT, exist_ok=True)

# Square master — flutter_launcher_icons rounds it per-platform.
build(S, 0.78).convert("RGB").save(os.path.join(OUT, "icon.png"))
# Adaptive-icon foreground: extra inset, since Android crops to ~66% of the canvas.
build(S, 0.50, background=False).save(os.path.join(OUT, "icon_foreground.png"))
# Pre-rounded, for the landing page and README where nothing masks it for us.
rounded(build(S, 0.78)).save(os.path.join(OUT, "icon_rounded.png"))
print("wrote", os.listdir(OUT))
