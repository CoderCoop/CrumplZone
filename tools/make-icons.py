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
    """The app icon: a wrecking ball on a chain, mid-swing into a tower.

    What was missing in the first version that shipped was the *swing*. A ball
    resting in a notch is a grey circle next to a yellow shape; the same ball
    on a taut chain, angled, with the corner it just took out flying away from
    it, is a wrecking ball. The chain is the single most identifying part and
    it had been left out for reading as a magnifying glass handle — the fix
    was to hang it from a corner at an angle rather than stick it on the side.
    """
    u = size / 64.0
    c = Canvas(size, NIGHT)
    if rounded:
        # Most launchers mask the icon themselves, so the rounding here only
        # has to stop a square of night sky sitting on a light background.
        c.fill(Rect(0, 0, size, size, 14 * u), NIGHT)

    # The tower, left of centre, with its top right corner sheared off.
    c.fill(Poly([
        (9 * u, 56 * u), (9 * u, 14 * u), (24 * u, 14 * u),
        (24 * u, 21 * u), (36 * u, 37 * u), (36 * u, 56 * u),
    ]), AMBER)
    # A darker face down the right-hand side, so the tower has two sides and
    # reads as a solid rather than as a flat cut-out.
    c.fill(Poly([
        (30 * u, 56 * u), (30 * u, 29 * u), (36 * u, 37 * u), (36 * u, 56 * u),
    ]), AMBER_DIM)

    # Windows, in the night colour so they read as openings.
    for row in range(4):
        y = (19 + row * 9) * u
        for col in range(2):
            x = (13 + col * 8) * u
            if y < 26 * u and x > 18 * u:
                continue  # inside the sheared-off corner
            c.fill(Rect(x, y, 5 * u, 5 * u), NIGHT)

    # The chain: from the top right corner of the frame down to the ball, taut
    # and at an angle. Drawn as links so it is a chain and not a stick.
    hook = (60 * u, 5 * u)
    ball = (44 * u, 30 * u)
    for i in range(5):
        t0 = i / 5.0
        t1 = t0 + 0.62 / 5.0
        ax = hook[0] + (ball[0] - hook[0]) * t0
        ay = hook[1] + (ball[1] - hook[1]) * t0
        bx = hook[0] + (ball[0] - hook[0]) * t1
        by = hook[1] + (ball[1] - hook[1]) * t1
        c.fill(Poly([(ax - 1.6 * u, ay), (ax + 1.6 * u, ay),
                     (bx + 1.6 * u, by), (bx - 1.6 * u, by)]), STEEL_DARK)

    # The ball, hanging on the end of it and overlapping the bite it took.
    c.fill(Disc(42 * u, 33 * u, 9.5 * u), STEEL_DARK)
    c.fill(Disc(42 * u, 33 * u, 8.2 * u), STEEL)

    # The chunk of corner it knocked loose, thrown clear to the right and down.
    c.fill(bar(48 * u, 44 * u, 10 * u, 5 * u, 2.5 * u), AMBER_DIM)

    # Rubble along the footing, level with the base of the tower.
    c.fill(bar(6 * u, 56 * u, 15 * u, 3 * u, 0.0), DUST)
    c.fill(bar(23 * u, 57 * u, 11 * u, 2 * u, 0.0), DUST)
    c.fill(bar(37 * u, 56 * u, 8 * u, 3 * u, 0.0), DUST)
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
