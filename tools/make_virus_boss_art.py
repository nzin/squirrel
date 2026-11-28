#!/usr/bin/env python3
"""Builds the virus boss art in godot/private/ from nine screenshot-like source frames
(a pink monster with purple viruses on its back, on a flat gray background with faint
diagonal guide lines): the first four frames are the walk cycle, the last five the throw.

    python3 tools/make_virus_boss_art.py misc/virus/6.png ... misc/virus/14.png

Writes godot/private/virus_1..9.png (background removed, every frame pasted bottom/right
aligned on one common canvas so the animation doesn't jitter), and godot/private/virus_bomb.png
(the virus that flies away in the last throw frames, cut out and trimmed). A virus detached
from the monster in a throw frame is removed from that frame (the game spawns it as a shot).
Prints the collision box (fractions of the canvas) of the walking body, ready for Enemy.KINDS.
The art is licensed and kept out of the repository (see CREDITS.md). Needs Pillow.
"""
import os
import sys
from collections import deque
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "private")
BG_MIN, BG_MAX = 122, 172  # the flat gray (about 141) plus the lighter guide lines
HALO_MIN = 80              # darker neutral pixels touching the background are anti-aliasing: trimmed
SPECK = 60                 # smaller detached bits are noise
DETACHED = 1500            # a larger detached bit is a flying virus: removed from the monster frame
# The virus that has just left the tail in the 8th frame touches the tail tip, so it cannot be told
# apart by connectivity: erase that disc of the source image (frame index -> (centre, radius)).
ERASE = {7: ((94, 178), 54)}


def neutral(p):
    return max(p) - min(p) <= 12


def is_bg(p):
    return neutral(p) and BG_MIN <= sum(p) // 3 <= BG_MAX


def components(alpha, w, h):
    seen = [[False] * w for _ in range(h)]
    out = []
    for sy in range(h):
        for sx in range(w):
            if not alpha[sy][sx] or seen[sy][sx]:
                continue
            comp, q = [], deque([(sx, sy)])
            seen[sy][sx] = True
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and alpha[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            q.append((nx, ny))
            out.append(comp)
    return out


def cut_out(path, erase=None):
    """-> (monster image, [detached big bits as images])."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    alpha = [[not is_bg(px[x, y]) for x in range(w)] for y in range(h)]
    if erase:
        (cx, cy), r = erase
        for y in range(h):
            for x in range(w):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    alpha[y][x] = False
    for _ in range(2):  # anti-aliasing halo: dark gray pixels that touch the background
        halo = []
        for y in range(h):
            for x in range(w):
                if alpha[y][x] and neutral(px[x, y]) and HALO_MIN <= sum(px[x, y]) // 3:
                    if any(0 <= nx < w and 0 <= ny < h and not alpha[ny][nx] for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                        halo.append((x, y))
        for x, y in halo:
            alpha[y][x] = False
    comps = sorted(components(alpha, w, h), key=len, reverse=True)
    body, bits = comps[0], []
    keep = list(body)
    for c in comps[1:]:
        if len(c) >= DETACHED:
            bits.append(c)
        elif len(c) >= SPECK:
            keep.extend(c)  # (a detail that merely isn't touching the body)

    def render(pixels):
        img = Image.new("RGBA", (w, h))
        ip = img.load()
        for x, y in pixels:
            ip[x, y] = px[x, y] + (255,)
        return img.crop(img.getbbox())

    return render(keep), [render(c) for c in bits]


def main(paths):
    os.makedirs(OUT, exist_ok=True)
    frames, bits = [], []
    for i, p in enumerate(paths):
        f, b = cut_out(p, ERASE.get(i))
        frames.append(f)
        bits.extend(b)
        print("%s: %dx%d, %d detached bit(s)" % (os.path.basename(p), f.width, f.height, len(b)))
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    sheet = Image.new("RGBA", (cw * len(frames), ch), (255, 0, 255, 255))
    canvases = []
    for i, f in enumerate(frames):
        canvas = Image.new("RGBA", (cw, ch))
        canvas.paste(f, (cw - f.width, ch - f.height))  # bottom-right aligned (the viruses sit at the back)
        canvas.save(os.path.join(OUT, "virus_%d.png" % (i + 1)))
        sheet.alpha_composite(canvas, (cw * i, 0))
        canvases.append(canvas)
    sheet.convert("RGB").save(os.path.join(OUT, "virus_sheet_preview.png"))
    if bits:
        bomb = max(bits, key=lambda b: b.width * b.height)
        bomb.save(os.path.join(OUT, "virus_bomb.png"))
        print("virus_bomb %dx%d" % bomb.size)
    # collision box of the body while walking: rows/cols that are at least 15% opaque, on every walk frame
    lo_x, lo_y, hi_x, hi_y = 0.0, 0.0, 1.0, 1.0
    for c in canvases[:4]:
        al = c.split()[3].load()
        rows = [sum(1 for x in range(cw) if al[x, y] > 30) for y in range(ch)]
        cols = [sum(1 for y in range(ch) if al[x, y] > 30) for x in range(cw)]
        r = [i for i, v in enumerate(rows) if v > 0.15 * cw]
        k = [i for i, v in enumerate(cols) if v > 0.15 * ch]
        lo_x, lo_y = max(lo_x, k[0] / cw), max(lo_y, r[0] / ch)
        hi_x, hi_y = min(hi_x, (k[-1] + 1) / cw), min(hi_y, (r[-1] + 1) / ch)
    print("canvas %dx%d  hit Rect2(%.2f, %.2f, %.2f, %.2f)" % (cw, ch, lo_x, lo_y, hi_x - lo_x, hi_y - lo_y))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
