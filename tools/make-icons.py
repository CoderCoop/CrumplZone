#!/usr/bin/env python3
"""Draws the CrumplZone icon and loading art, at every size the build needs.

    python3 tools/make-icons.py

The art is code rather than a checked-in binary so it can be reviewed in a
diff, recoloured in one place, and regenerated at a new size without hunting
for whatever drew it. There is no image library in the toolchain and none is
worth adding for six flat-shaded pictures, so this rasterises them itself:
shapes are sampled on a 3x3 grid per pixel, which is enough anti-aliasing for
art made of straight edges and one circle.

The subject is what the game is: a building coming apart, and the ball that
did it. At 44 px on a phone home screen almost nothing survives, so the
building is three heavy bands and the ball is a quarter of the frame.
"""
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "art"

# The game's own palette, so the icon and the first frame of the game agree.
NIGHT = (0x1F, 0x22, 0x29)
AMBER = (0xF2, 0xB8, 0x47)
AMBER_DIM = (0xC4, 0x8D, 0x2E)
STEEL = (0x9A, 0xA3, 0xB2)
STEEL_DARK = (0x5A, 0x62, 0x70)
DUST = (0x3A, 0x3F, 0x4A)


class Canvas:
    def __init__(self, size, background):
        self.size = size
        self.px = [[background[0], background[1], background[2], 255]
                   for _ in range(size * size)]

    def blend(self, x, y, colour, alpha):
        if alpha <= 0.0:
            return
        i = y * self.size + x
        dst = self.px[i]
        for c in range(3):
            dst[c] = int(round(dst[c] * (1.0 - alpha) + colour[c] * alpha))

    def fill(self, shape, colour, samples=3):
        """Covers every pixel the shape touches, anti-aliased by supersampling."""
        x0, y0, x1, y1 = shape.bounds()
        x0 = max(0, int(x0) - 1)
        y0 = max(0, int(y0) - 1)
        x1 = min(self.size - 1, int(x1) + 1)
        y1 = min(self.size - 1, int(y1) + 1)
        step = 1.0 / samples
        offsets = [(step * (i + 0.5), step * (j + 0.5))
                   for j in range(samples) for i in range(samples)]
        total = float(len(offsets))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                hits = 0
                for ox, oy in offsets:
                    if shape.inside(x + ox, y + oy):
                        hits += 1
                if hits:
                    self.blend(x, y, colour, hits / total)

    def png(self, path):
        raw = bytearray()
        for y in range(self.size):
            raw.append(0)
            for x in range(self.size):
                raw.extend(self.px[y * self.size + x])
        def chunk(tag, data):
            body = tag + data
            return (struct.pack(">I", len(data)) + body
                    + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))
        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.size, self.size, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        path.write_bytes(png)


class Rect:
    def __init__(self, x, y, w, h, radius=0.0):
        self.x, self.y, self.w, self.h, self.r = x, y, w, h, radius

    def bounds(self):
        return self.x, self.y, self.x + self.w, self.y + self.h

    def inside(self, px, py):
        dx = px - self.x
        dy = py - self.y
        if dx < 0 or dy < 0 or dx > self.w or dy > self.h:
            return False
        r = self.r
        if r <= 0:
            return True
        cx = min(max(dx, r), self.w - r)
        cy = min(max(dy, r), self.h - r)
        return (dx - cx) ** 2 + (dy - cy) ** 2 <= r * r


class Poly:
    def __init__(self, points):
        self.pts = points

    def bounds(self):
        xs = [p[0] for p in self.pts]
        ys = [p[1] for p in self.pts]
        return min(xs), min(ys), max(xs), max(ys)

    def inside(self, px, py):
        inside = False
        pts = self.pts
        n = len(pts)
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py):
                if px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                    inside = not inside
            j = i
        return inside


class Disc:
    def __init__(self, cx, cy, r):
        self.cx, self.cy, self.r = cx, cy, r

    def bounds(self):
        return self.cx - self.r, self.cy - self.r, self.cx + self.r, self.cy + self.r

    def inside(self, px, py):
        return (px - self.cx) ** 2 + (py - self.cy) ** 2 <= self.r * self.r


def bar(x, y, w, h, lean=0.0):
    """A slab, optionally sheared — a floor that has started to go over."""
    return Poly([(x + lean, y), (x + w + lean, y), (x + w, y + h), (x, y + h)])


def draw_icon(size, rounded=True):
    """The app icon: a tower with its top corner knocked off, and the ball.

    Kept to three things — a slab of building, windows, a ball — because at
    44 px on a home screen a fourth reads as noise. Earlier attempts had a
    chain and a rim on the ball and came out looking like a magnifying glass,
    and separate floors on columns came out looking like a shelf.
    """
    u = size / 64.0
    c = Canvas(size, NIGHT)
    if rounded:
        # Most launchers mask the icon themselves, so the rounding here only
        # has to stop a square of night sky sitting on a light background.
        c.fill(Rect(0, 0, size, size, 14 * u), NIGHT)

    # The tower: one solid mass, with the top right corner sheared away on a
    # diagonal. The diagonal is the whole idea — a rectangle is a building,
    # a rectangle missing a corner is a building being demolished.
    c.fill(Poly([
        (13 * u, 54 * u), (13 * u, 16 * u), (30 * u, 16 * u),
        (30 * u, 26 * u), (40 * u, 36 * u), (40 * u, 54 * u),
    ]), AMBER)

    # Windows, in the night colour so they read as openings rather than as
    # decoration. Three columns, stopping where the corner is gone.
    for row in range(4):
        y = (21 + row * 8) * u
        for col in range(3):
            x = (17 + col * 8) * u
            if x + 4 * u > 30 * u and y < 34 * u:
                continue  # inside the sheared-off corner
            c.fill(Rect(x, y, 4.5 * u, 4.5 * u), NIGHT)

    # The block that came off the corner, tumbling clear.
    c.fill(bar(45 * u, 41 * u, 9 * u, 5 * u, 2.0 * u), AMBER_DIM)

    # The ball, sitting in the bite it took. One flat disc: a rim turned it
    # into a lens.
    c.fill(Disc(37 * u, 25 * u, 9.5 * u), STEEL)

    # Rubble along the footing, level with the base of the tower.
    c.fill(bar(8 * u, 54 * u, 17 * u, 3 * u, 0.0), DUST)
    c.fill(bar(27 * u, 55 * u, 12 * u, 2 * u, 0.0), DUST)
    c.fill(bar(42 * u, 54 * u, 8 * u, 3 * u, 0.0), DUST)
    return c


def draw_splash(width, height):
    """The loading picture, in the same hand as the icon but wider."""
    c = Canvas(max(width, height), NIGHT)
    inner = draw_icon(max(width, height), rounded=False)
    return inner


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (512, 180, 144, 128, 64):
        draw_icon(size).png(OUT / f"icon-{size}.png")
        print(f"wrote art/icon-{size}.png")
    draw_splash(256, 256).png(OUT / "splash.png")
    print("wrote art/splash.png")


if __name__ == "__main__":
    main()
