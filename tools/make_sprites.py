#!/usr/bin/env python3
"""Draws the original sprites of the milestone-3 opponents (hedgehog, fox, owl,
bee) into godot/assets/. They are our own artwork, so there is nothing to
license - see CREDITS.md. Art tooling only; the game itself is pure Godot.

    python3 tools/make_sprites.py          # needs Pillow

Everything is drawn 4x larger and scaled down for smooth edges. The characters
face LEFT (enemies walk toward the squirrel).
"""
import math
import os
import random
from PIL import Image, ImageDraw

S = 4  # supersampling factor
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets")
INK = (52, 34, 24, 255)  # outline colour


def canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def sc(v):
    return [int(round(c * S)) for c in v]


def ell(d, cx, cy, rx, ry, fill, outline=INK, width=2.5):
    d.ellipse(sc([cx - rx, cy - ry, cx + rx, cy + ry]), fill=fill, outline=outline, width=int(width * S))


def poly(d, pts, fill, outline=INK, width=2.5):
    p = [(x * S, y * S) for x, y in pts]
    d.polygon(p, fill=fill)
    if outline:
        d.line(p + [p[0]], fill=outline, width=int(width * S), joint="curve")


def line(d, a, b, fill, width):
    d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=fill, width=int(width * S))


def paste_rotated(img, layer, angle, cx, cy):
    r = layer.rotate(angle, resample=Image.BICUBIC, center=(cx * S, cy * S))
    img.alpha_composite(r)


def save(img, name, w, h):
    img = img.resize((w, h), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", os.path.normpath(path), img.size)


# ---------------------------------------------------------------- hedgehog 280x200
def hedgehog(frame):
    w, h = 280, 200
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    if frame == "ball":
        cx, cy, r = 140, 100, 70
        for i in range(44):
            a = math.tau * i / 44
            b0, b1 = a - 0.11, a + 0.11
            tip = r + 26 + rnd.randint(-3, 3)
            col = (74, 48, 30, 255) if i % 2 else (98, 66, 40, 255)
            poly(d, [(cx + math.cos(b0) * (r - 6), cy + math.sin(b0) * (r - 6)),
                     (cx + math.cos(a) * tip, cy + math.sin(a) * tip),
                     (cx + math.cos(b1) * (r - 6), cy + math.sin(b1) * (r - 6))], col, width=1.5)
        ell(d, cx, cy, r, r, (112, 76, 46, 255))
        ell(d, cx - 24, cy - 18, 22, 14, (140, 100, 62, 255), outline=None)
        # a tiny nose peeking out so it still reads as an animal
        ell(d, cx - 58, cy + 18, 8, 7, (30, 20, 16, 255), outline=None)
        return img
    # walking: spiky back, beige face on the left, two legs that alternate
    for i in range(30):
        a = math.pi * (1.05 + 0.92 * i / 29)  # over the top, left to right
        cx, cy, rx, ry = 148, 118, 92, 66
        px, py = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        nx, ny = math.cos(a), math.sin(a)
        tip = 30 + rnd.randint(-3, 4)
        t = (-ny, nx)
        col = (74, 48, 30, 255) if i % 2 else (98, 66, 40, 255)
        poly(d, [(px + t[0] * 9, py + t[1] * 9), (px + nx * tip, py + ny * tip), (px - t[0] * 9, py - t[1] * 9)], col, width=1.5)
    off = 9 if frame == "1" else -9
    for lx in (100, 182):
        ell(d, lx + off * (1 if lx < 150 else -1), 176, 17, 11, (86, 58, 36, 255))
    ell(d, 148, 118, 92, 62, (112, 76, 46, 255))
    ell(d, 140, 140, 64, 34, (226, 192, 150, 255), outline=None)       # belly
    ell(d, 78, 132, 44, 36, (232, 198, 158, 255))                       # head
    ell(d, 40, 140, 26, 18, (232, 198, 158, 255))                       # snout
    ell(d, 17, 140, 8, 7, (30, 20, 16, 255), outline=None)              # nose
    ell(d, 62, 120, 7, 7, (255, 255, 255, 255), outline=INK, width=1.5)
    ell(d, 60, 121, 3.5, 3.5, (20, 14, 10, 255), outline=None)
    ell(d, 92, 104, 12, 10, (200, 150, 110, 255))                       # ear
    return img


# ---------------------------------------------------------------- fox 320x200
def fox(frame):
    w, h = 320, 200
    img = canvas(w, h)
    fur, fur_dark, white = (226, 116, 36, 255), (176, 82, 24, 255), (250, 244, 232, 255)
    # tail (behind the body): rotated ellipse with a white tip
    tail = canvas(w, h)
    td = ImageDraw.Draw(tail)
    ell(td, 270, 96, 48, 20, fur)
    ell(td, 300, 96, 20, 16, white, outline=INK)
    paste_rotated(img, tail, 28, 250, 110)
    d = ImageDraw.Draw(img)
    # legs: running pose, two alternate frames
    if frame == "1":
        legs = [((120, 125), (92, 178)), ((140, 128), (166, 170)), ((215, 125), (250, 166)), ((232, 124), (206, 178))]
    else:
        legs = [((120, 125), (140, 172)), ((140, 128), (104, 176)), ((215, 125), (198, 176)), ((232, 124), (262, 170))]
    for (a, b) in legs:
        line(d, a, b, INK, 17)
        line(d, a, b, fur_dark, 12)
        line(d, ((a[0] + b[0] * 2) / 3, (a[1] + b[1] * 2) / 3), b, (46, 30, 24, 255), 12)  # dark socks
    ell(d, 178, 108, 82, 38, fur)                                       # body
    ell(d, 118, 128, 34, 24, white, outline=None)                       # chest
    ell(d, 196, 122, 54, 18, (240, 150, 70, 255), outline=None)         # lighter flank
    # head
    poly(d, [(86, 70), (96, 24), (122, 62)], fur)                       # ears
    poly(d, [(112, 64), (136, 26), (150, 74)], fur)
    poly(d, [(94, 62), (99, 40), (111, 60)], (60, 38, 28, 255), outline=None)
    ell(d, 100, 90, 44, 34, fur)
    poly(d, [(64, 92), (10, 106), (58, 122)], white)                    # muzzle
    ell(d, 11, 106, 6, 5, (24, 16, 12, 255), outline=None)              # nose
    ell(d, 84, 82, 6.5, 7, (255, 255, 255, 255), outline=INK, width=1.5)
    ell(d, 82, 83, 3.2, 4, (20, 14, 10, 255), outline=None)
    return img


# ---------------------------------------------------------------- owl 220x240
def owl(frame):
    w, h = 220, 240
    img = canvas(w, h)
    brown, light = (140, 100, 62, 255), (228, 204, 164, 255)
    d = ImageDraw.Draw(img)
    # wings first (behind): raised in frame 1, lowered in frame 2
    if frame == "1":
        left = [(58, 120), (4, 36), (2, 100), (30, 150)]
        right = [(162, 120), (216, 36), (218, 100), (190, 150)]
    else:
        left = [(56, 128), (6, 200), (30, 222), (66, 180)]
        right = [(164, 128), (214, 200), (190, 222), (154, 180)]
    poly(d, left, (112, 78, 46, 255))
    poly(d, right, (112, 78, 46, 255))
    ell(d, 110, 142, 66, 84, brown)                                     # body
    ell(d, 110, 168, 42, 58, light, outline=None)                       # belly
    for k in range(4):                                                  # feather chevrons
        y = 140 + k * 20
        d.line([(88 * S, y * S), (110 * S, (y + 11) * S), (132 * S, y * S)], fill=(150, 118, 84, 255), width=3 * S)
    ell(d, 110, 90, 64, 56, brown)                                      # head
    poly(d, [(58, 62), (64, 12), (88, 52)], brown)                      # ear tufts
    poly(d, [(162, 62), (156, 12), (132, 52)], brown)
    ell(d, 80, 92, 30, 29, (242, 228, 196, 255))                        # facial disc
    ell(d, 140, 92, 30, 29, (242, 228, 196, 255))
    for ex in (80, 140):
        ell(d, ex, 92, 19, 19, (252, 200, 30, 255))
        ell(d, ex, 92, 8.5, 9.5, (16, 12, 10, 255), outline=None)
        ell(d, ex - 4, 87, 3, 3, (255, 255, 255, 255), outline=None)
    poly(d, [(110, 100), (97, 124), (123, 124)], (240, 140, 30, 255))   # beak
    for fx in (88, 132):                                                # feet
        ell(d, fx, 226, 15, 8, (240, 140, 30, 255))
    return img


# ---------------------------------------------------------------- bee 150x120
def bee(frame):
    w, h = 150, 120
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    wing = (205, 232, 255, 190)
    if frame == "1":
        ws = [(72, 30, 30, 15, -25), (98, 30, 30, 15, 25)]
    else:
        ws = [(70, 52, 28, 12, 20), (100, 52, 28, 12, -20)]
    for cx, cy, rx, ry, ang in ws:
        layer = canvas(w, h)
        ld = ImageDraw.Draw(layer)
        ell(ld, cx, cy, rx, ry, wing, outline=(120, 150, 190, 255), width=2)
        paste_rotated(img, layer, ang, cx, cy)
    d = ImageDraw.Draw(img)
    # striped body clipped to an ellipse
    body = canvas(w, h)
    bd = ImageDraw.Draw(body)
    ell(bd, 86, 72, 46, 30, (252, 204, 30, 255), outline=None)
    for x0 in (66, 92, 118):
        bd.rectangle(sc([x0, 30, x0 + 14, 110]), fill=(40, 28, 16, 255))
    mask = canvas(w, h)
    ImageDraw.Draw(mask).ellipse(sc([86 - 46, 72 - 30, 86 + 46, 72 + 30]), fill=(255, 255, 255, 255))
    body.putalpha(Image.composite(body.split()[3], Image.new("L", body.size, 0), mask.split()[3]))
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    d.ellipse(sc([86 - 46, 72 - 30, 86 + 46, 72 + 30]), outline=INK, width=int(2.5 * S))
    poly(d, [(130, 66), (148, 72), (130, 78)], (40, 28, 16, 255))       # stinger
    ell(d, 38, 70, 24, 22, (252, 204, 30, 255))                         # head
    ell(d, 30, 64, 7, 8, (255, 255, 255, 255), outline=INK, width=1.5)
    ell(d, 28, 65, 3.5, 4, (16, 12, 10, 255), outline=None)
    d.arc(sc([20, 72, 40, 86]), 20, 160, fill=INK, width=int(2 * S))     # smile
    line(d, (34, 52), (24, 34), INK, 2.5)                               # antennae
    line(d, (44, 52), (46, 32), INK, 2.5)
    ell(d, 24, 33, 3, 3, INK, outline=None)
    ell(d, 46, 31, 3, 3, INK, outline=None)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save(hedgehog("1"), "hedgehog1.png", 280, 200)
    save(hedgehog("2"), "hedgehog2.png", 280, 200)
    save(hedgehog("ball"), "hedgehog_ball.png", 280, 200)
    save(fox("1"), "fox1.png", 320, 200)
    save(fox("2"), "fox2.png", 320, 200)
    save(owl("1"), "owl1.png", 220, 240)
    save(owl("2"), "owl2.png", 220, 240)
    save(bee("1"), "bee1.png", 150, 120)
    save(bee("2"), "bee2.png", 150, 120)
