#!/usr/bin/env python3
"""Builds the Diver Armor art in godot/private/ from five screenshot-like source frames
(a diver with a harpoon gun on an opaque flat gray background with guide lines).

    python3 tools/make_diver_art.py misc/diver/1.png misc/diver/2.png ... misc/diver/5.png

Writes godot/private/diver_1..N.png (background removed, every frame pasted bottom-aligned on
one common canvas so the walk cycle doesn't jitter) and godot/private/diver_harpoon.png (the
arrowhead + a short rod of the LAST frame; Shot draws the rest of the shaft itself).
The art is licensed and kept out of the repository (see CREDITS.md).
Art tooling only (needs Pillow, pure Python otherwise).
"""
import os
import sys
from collections import deque
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "private")
BG = (144, 144, 144)
TOL = 14        # a pixel this close to BG (per channel) is background
POCKET_TOL = 5  # enclosed gray pockets (between arm and gun) must match this tightly
POCKET_MIN = 25
# Arrowhead + rod, as a box in the cut-out coordinates of the last frame (left, top, right, bottom),
# measured from the muzzle: found by viewing the frame (see the contact sheet).
HARPOON_BOX = (301, 140, 373, 225)


def near(p, tol):
    return abs(p[0] - BG[0]) <= tol and abs(p[1] - BG[1]) <= tol and abs(p[2] - BG[2]) <= tol


def cut_out(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    gone = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or gone[y][x] or not near(px[x, y], TOL):
            continue
        gone[y][x] = True
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    # enclosed pockets of (almost exactly) background gray
    seen = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            if gone[sy][sx] or seen[sy][sx] or not near(px[sx, sy], POCKET_TOL):
                continue
            comp, stack = [], [(sx, sy)]
            seen[sy][sx] = True
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and not gone[ny][nx] and near(px[nx, ny], POCKET_TOL):
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if len(comp) >= POCKET_MIN:
                for x, y in comp:
                    gone[y][x] = True
    # trim the gray fringe: a kept pixel touching background and still grayish goes too
    fringe = []
    for y in range(h):
        for x in range(w):
            if gone[y][x]:
                continue
            if any(0 <= nx < w and 0 <= ny < h and gone[ny][nx] for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                if near(px[x, y], 40) and max(px[x, y]) - min(px[x, y]) < 30 and sum(px[x, y]) > 3 * 70:
                    fringe.append((x, y))
    for x, y in fringe:
        gone[y][x] = True
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            if not gone[y][x]:
                op[x, y] = px[x, y] + (255,)
    return out.crop(out.getbbox())


def main(paths):
    os.makedirs(OUT, exist_ok=True)
    frames = [cut_out(p) for p in paths]
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    sheet = Image.new("RGBA", (cw * len(frames), ch), (255, 0, 255, 255))
    for i, f in enumerate(frames):
        canvas = Image.new("RGBA", (cw, ch))
        canvas.paste(f, (0, ch - f.height))  # bottom-aligned, left-aligned
        canvas.save(os.path.join(OUT, "diver_%d.png" % (i + 1)))
        sheet.alpha_composite(canvas, (cw * i, 0))
    sheet.convert("RGB").save(os.path.join(OUT, "diver_sheet_preview.png"))
    last = Image.new("RGBA", (cw, ch))
    last.paste(frames[-1], (0, ch - frames[-1].height))
    harpoon = last.crop(HARPOON_BOX)
    harpoon = harpoon.crop(harpoon.getbbox())
    harpoon.save(os.path.join(OUT, "diver_harpoon.png"))
    print("frames %dx%d, harpoon %dx%d" % (cw, ch, harpoon.width, harpoon.height))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
