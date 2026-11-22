#!/usr/bin/env python3
"""Prints the collision box (fractions of the sprite) for an enemy made of one
or more animation frames, ready to paste into Enemy.KINDS as `"hit": Rect2(...)`.

    python3 tools/sprite_hitbox.py hedgehog1 hedgehog2 hedgehog_ball

Thin protrusions (a tail, antennae, spikes) are ignored: a row/column only
counts when at least 15% of the sprite is opaque in it, and the box is the
intersection over all frames so it never grows when the animation changes.
Art tooling only (needs Pillow).
"""
import os
import sys
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "godot", "assets")
THRESHOLD = 0.15


def box(name):
    im = Image.open(os.path.join(ASSETS, name + ".png")).convert("RGBA")
    w, h = im.size
    al = im.split()[3].load()
    rows = [sum(1 for x in range(w) if al[x, y] > 30) for y in range(h)]
    cols = [sum(1 for y in range(h) if al[x, y] > 30) for x in range(w)]
    r = [i for i, v in enumerate(rows) if v > THRESHOLD * w]
    c = [i for i, v in enumerate(cols) if v > THRESHOLD * h]
    return c[0] / w, r[0] / h, (c[-1] + 1) / w, (r[-1] + 1) / h


if __name__ == "__main__":
    boxes = [box(n) for n in sys.argv[1:]]
    l = max(b[0] for b in boxes)
    t = max(b[1] for b in boxes)
    r = min(b[2] for b in boxes)
    b = min(b[3] for b in boxes)
    print('"hit": Rect2(%.2f, %.2f, %.2f, %.2f)' % (l, t, r - l, b - t))
