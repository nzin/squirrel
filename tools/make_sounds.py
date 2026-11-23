#!/usr/bin/env python3
"""Synthesizes the game's original sound effects into godot/assets/audio/sfx/ -
nothing to license, nothing downloaded.

    python3 tools/make_sounds.py            # pure Python, no dependencies
    python3 tools/make_sounds.py coin hit   # only these effects (by name)

Mono, 22.05 kHz, 16 bit. The music is made by make_arcade_music.py (which also
reuses the helpers in this file). The game looks sounds up by file name, so any
sound can be replaced by dropping a file with the same name (.ogg or .wav).
Art tooling only; the game itself is pure Godot.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "audio")
TAU = math.tau
random.seed(7)  # reproducible output


# ----------------------------------------------------------------- building blocks
def n_samples(dur):
    return max(1, int(dur * SR))


def silence(dur):
    return [0.0] * n_samples(dur)


def mix_into(dest, src, offset=0.0, gain=1.0):
    o = int(offset * SR)
    if o + len(src) > len(dest):
        dest.extend([0.0] * (o + len(src) - len(dest)))
    for i, v in enumerate(src):
        dest[o + i] += v * gain


def env_exp(n, tau):
    return [math.exp(-i / SR / tau) for i in range(n)]


def adsr(n, a=0.01, d=0.05, s=0.7, r=0.05):
    out = []
    an, dn, rn = int(a * SR), int(d * SR), int(r * SR)
    for i in range(n):
        if i < an:
            v = i / max(1, an)
        elif i < an + dn:
            v = 1.0 - (1.0 - s) * (i - an) / max(1, dn)
        elif i > n - rn:
            v = s * (n - i) / max(1, rn)
        else:
            v = s
        out.append(max(0.0, v))
    return out


def sweep(f0, f1, dur, shape="sine", tau=None, vib=0.0, vib_hz=7.0, harmonics=None):
    """Tone gliding from f0 to f1 (exponentially) with a decay envelope."""
    n = n_samples(dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        if vib:
            f *= 1.0 + vib * math.sin(TAU * vib_hz * i / SR)
        ph += TAU * f / SR
        if shape == "sine":
            v = math.sin(ph)
        elif shape == "tri":
            v = 2.0 / math.pi * math.asin(math.sin(ph))
        elif shape == "square":
            v = 1.0 if math.sin(ph) > 0 else -1.0
            v *= 0.6
        else:  # "saw" from harmonics
            v = sum(math.sin(ph * k) / k for k in range(1, (harmonics or 8) + 1)) * 0.6
        out.append(v)
    e = env_exp(n, tau if tau else dur / 3.0)
    return [v * ev for v, ev in zip(out, e)]


def noise(dur, lp=None, hp=None, tau=None, vol=1.0):
    """White noise, optionally low/high-passed, optionally decaying."""
    n = n_samples(dur)
    out = [random.uniform(-1, 1) for _ in range(n)]
    if lp:
        out = lowpass(out, lp)
    if hp:
        out = highpass(out, hp)
    if tau:
        out = [v * e for v, e in zip(out, env_exp(n, tau))]
    return [v * vol for v in out]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def swept_noise(dur, c0, c1, vol=1.0, shape="up"):
    """Whoosh: noise whose low-pass cutoff glides c0 -> c1 with a swell envelope."""
    n = n_samples(dur)
    out, y = [], 0.0
    for i in range(n):
        t = i / n
        c = c0 * (c1 / c0) ** t
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (random.uniform(-1, 1) - y)
        swell = math.sin(math.pi * t) ** (1.5 if shape == "up" else 1.0)
        out.append(y * swell * vol * 2.0)
    return out


def tremolo(x, hz, depth):
    return [v * (1.0 - depth + depth * 0.5 * (1 + math.sin(TAU * hz * i / SR))) for i, v in enumerate(x)]


def bell(freq, dur, vol=0.5):
    """Inharmonic partials with a long decay: a small bell / coin."""
    n = n_samples(dur)
    out = [0.0] * n
    for k, (m, g) in enumerate([(1.0, 1.0), (2.76, 0.6), (5.4, 0.3), (8.93, 0.15)]):
        for i in range(n):
            out[i] += math.sin(TAU * freq * m * i / SR) * g * math.exp(-i / SR / (dur / (2.0 + k)))
    return [v * vol for v in out]


def normalize(x, peak=0.88):
    m = max(1e-9, max(abs(v) for v in x))
    return [v / m * peak for v in x]


def fade_edges(x, ms_in=2, ms_out=8):
    a, b = int(ms_in / 1000 * SR), int(ms_out / 1000 * SR)
    for i in range(min(a, len(x))):
        x[i] *= i / a
    for i in range(min(b, len(x))):
        x[-1 - i] *= i / b
    return x


def write_wav(path, x, peak=0.88, norm=True):
    if norm:
        x = normalize(x, peak)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


# ----------------------------------------------------------------- music voices
def midi(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    p = name[0]
    acc = 0
    rest = name[1:]
    if rest[0] == "#":
        acc, rest = 1, rest[1:]
    elif rest[0] == "b":
        acc, rest = -1, rest[1:]
    return 12 * (int(rest) + 1) + names[p] + acc


def hz(note):
    return 440.0 * 2 ** ((midi(note) - 69) / 12.0)


def marimba(freq, dur, vol=0.6):
    n = n_samples(dur)
    out = []
    for i in range(n):
        t = i / SR
        v = math.sin(TAU * freq * t) * math.exp(-t / 0.28)
        v += 0.35 * math.sin(TAU * freq * 4 * t) * math.exp(-t / 0.06)
        v += 0.15 * math.sin(TAU * freq * 10 * t) * math.exp(-t / 0.02)
        out.append(v * vol)
    return fade_edges(out, 1, 10)


# ----------------------------------------------------------------- sequencing
class Song:
    def __init__(self, bars, bpb, bpm, tail=2.5):
        self.spb = 60.0 / bpm
        self.length = bars * bpb * self.spb
        self.tail = tail
        self.buf = [0.0] * (int((self.length + tail) * SR))

    def note(self, beat, dur_beats, voice, name, gain=1.0):
        d = dur_beats * self.spb
        mix_into(self.buf, voice(hz(name), d + 0.05), beat * self.spb, gain)

    def hit(self, beat, sample, gain=1.0):
        mix_into(self.buf, sample, beat * self.spb, gain)

    def render_loop(self):
        """Fold the ring-out tail back onto the start so the loop is seamless."""
        n = int(self.length * SR)
        out = self.buf[:n]
        for i in range(len(self.buf) - n):
            out[i % n] += self.buf[n + i]
        return out

    def render_oneshot(self, extra=0.3):
        return self.buf[: int((self.length + extra) * SR)]


def jingle(notes, voice, gap=0.11, dur=0.28, gain=0.8, extra=0.9):
    s = Song(1, 1, 60, tail=0)
    s.length = len(notes) * gap + extra
    s.buf = [0.0] * int((s.length + 0.5) * SR)
    for i, name in enumerate(notes):
        mix_into(s.buf, voice(hz(name), dur + 0.1), i * gap, gain)
    return s.render_oneshot(0.4)


# ----------------------------------------------------------------- sound effects
def sfx_table():
    T = {}

    def add(name, fn):
        T[name] = fn

    def pops(n, gap, f0):
        out = silence(gap * n + 0.1)
        for i in range(n):
            mix_into(out, sweep(f0 * (1 + 0.12 * i), f0 * 0.38, 0.09, tau=0.03), i * gap)
            mix_into(out, noise(0.015, hp=2000, tau=0.006, vol=0.3), i * gap)
        return out

    add("jump", lambda: sweep(300, 760, 0.14, vib=0.02, tau=0.09))
    add("land", lambda: [a + b for a, b in zip(sweep(130, 55, 0.12, tau=0.045), noise(0.12, lp=700, tau=0.03, vol=0.35))])
    add("throw_acorn", lambda: pops(1, 0, 760))
    add("throw_spread", lambda: pops(3, 0.045, 720))
    add("throw_boomerang", lambda: [a + b * 0.3 for a, b in zip(swept_noise(0.4, 400, 3000, 0.9), sweep(260, 520, 0.4, tau=0.3, vib=0.04))])
    add("throw_chestnut", lambda: sweep(220, 520, 0.22, vib=0.05, tau=0.12))
    add("throw_pinecone", lambda: [a + b for a, b in zip(sweep(160, 70, 0.2, tau=0.07), noise(0.2, lp=900, tau=0.05, vol=0.4))])
    add("throw_rainbow", lambda: sweep(1800, 280, 0.28, shape="saw", tau=0.16, harmonics=5))
    add("throw_homing", lambda: (lambda o: (mix_into(o, sweep(620, 900, 0.08, tau=0.05), 0), mix_into(o, sweep(820, 1250, 0.1, tau=0.06), 0.09), o)[2])(silence(0.25)))
    add("boom", lambda: [a + b for a, b in zip(swept_noise(0.7, 2500, 90, 1.2, "down"), sweep(95, 38, 0.7, tau=0.2))] )
    add("hit", lambda: [a + b for a, b in zip(noise(0.07, lp=3500, tau=0.02, vol=0.9), sweep(320, 140, 0.1, tau=0.04))])
    add("enemy_defeat", lambda: (lambda o: (mix_into(o, sweep(420, 980, 0.1, tau=0.07), 0), mix_into(o, sweep(980, 190, 0.18, tau=0.08, vib=0.03), 0.1), mix_into(o, noise(0.1, hp=1500, tau=0.03, vol=0.3), 0.1), o)[3])(silence(0.35)))
    add("coin", lambda: (lambda o: (mix_into(o, bell(1318, 0.25, 0.7), 0), mix_into(o, bell(1760, 0.35, 0.7), 0.07), o)[2])(silence(0.45)))
    add("rainbow_collect", lambda: (lambda o: ([mix_into(o, bell(hz(nm), 0.4, 0.5), i * 0.07) for i, nm in enumerate(["C6", "E6", "G6", "C7", "E7", "G7"])], o)[1])(silence(0.9)))
    add("box_bump", lambda: [a + b for a, b in zip(sweep(340, 230, 0.1, tau=0.04, shape="tri"), noise(0.05, lp=2000, tau=0.01, vol=0.5))])
    add("shield_clang", lambda: (lambda o: ([mix_into(o, [math.sin(TAU * f * i / SR) * math.exp(-i / SR / 0.12) for i in range(n_samples(0.5))], 0, g) for f, g in ((820, 1), (1330, 0.7), (2110, 0.5), (3170, 0.3))], o)[1])(silence(0.5)))
    add("warn", lambda: (lambda o: (mix_into(o, sweep(700, 900, 0.06, shape="square", tau=0.1), 0, 0.5), mix_into(o, sweep(900, 1150, 0.06, shape="square", tau=0.1), 0.09, 0.5), o)[2])(silence(0.2)))
    add("whoosh", lambda: swept_noise(0.4, 300, 4000, 0.9))
    add("stomp", lambda: (lambda o: (mix_into(o, sweep(110, 50, 0.12, tau=0.05), 0), mix_into(o, sweep(110, 50, 0.12, tau=0.05), 0.14), o)[2])(silence(0.3)))
    add("dive", lambda: sweep(1900, 520, 0.5, vib=0.03, tau=0.35))
    add("pounce", lambda: [a + b for a, b in zip(sweep(280, 520, 0.12, tau=0.07), noise(0.12, hp=800, lp=4000, tau=0.04, vol=0.4))])
    add("roll", lambda: tremolo(noise(0.55, lp=380, tau=0.35, vol=1.0), 18, 0.6))
    add("hiss", lambda: noise(0.6, hp=2500, tau=0.3, vol=0.8))
    add("fireball", lambda: [a + b for a, b in zip(swept_noise(0.5, 500, 3500, 1.0), noise(0.5, hp=4000, tau=0.25, vol=0.25))])
    add("splat", lambda: [a + b for a, b in zip(noise(0.13, lp=1800, tau=0.04, vol=0.9), sweep(210, 80, 0.12, tau=0.05))])
    add("mole_pop", lambda: [a + b for a, b in zip(noise(0.22, lp=900, tau=0.06, vol=0.8), sweep(150, 90, 0.16, tau=0.06))])
    add("boss_roar", lambda: tremolo([a + b for a, b in zip(sweep(95, 62, 1.1, shape="saw", tau=0.7, harmonics=6), noise(1.1, lp=400, tau=0.6, vol=0.5))], 22, 0.55))
    add("life_lost", lambda: sweep(620, 190, 0.45, vib=0.05, tau=0.3))
    add("respawn", lambda: [a + b for a, b in zip(sweep(300, 900, 0.3, tau=0.2), sweep(600, 1800, 0.3, tau=0.14))])
    add("shop_bell", lambda: bell(880, 1.0, 0.8))
    add("buy", lambda: (lambda o: (mix_into(o, noise(0.03, hp=3000, tau=0.01, vol=0.6), 0), mix_into(o, bell(1760, 0.5, 0.7), 0.02), mix_into(o, bell(2637, 0.6, 0.6), 0.1), mix_into(o, bell(1318, 0.4, 0.4), 0.18), o)[4])(silence(0.8)))
    add("no_money", lambda: (lambda o: (mix_into(o, sweep(125, 120, 0.13, shape="square", tau=0.3), 0, 0.6), mix_into(o, sweep(110, 105, 0.16, shape="square", tau=0.3), 0.17, 0.6), o)[2])(silence(0.4)))
    add("ui_move", lambda: sweep(900, 880, 0.035, tau=0.03))
    add("ui_select", lambda: sweep(700, 1100, 0.08, tau=0.05))
    add("ui_back", lambda: sweep(620, 400, 0.08, tau=0.05))
    add("pause", lambda: sweep(900, 450, 0.18, tau=0.1, shape="tri"))
    add("fist_start", lambda: (lambda o: (mix_into(o, sweep(85, 38, 1.0, tau=0.5), 0), mix_into(o, swept_noise(1.0, 120, 900, 0.5), 0), mix_into(o, sweep(70, 45, 0.15, tau=0.05), 0.25), mix_into(o, sweep(70, 45, 0.15, tau=0.05), 0.5), o)[4])(silence(1.1)))
    add("fist_dash", lambda: (lambda o: (mix_into(o, swept_noise(0.9, 250, 5000, 0.9), 0), mix_into(o, tremolo(sweep(2200, 3200, 0.9, tau=0.7), 14, 0.7), 0, 0.12), o)[2])(silence(0.95)))
    add("fist_hit", lambda: [a + b + c for a, b, c in zip(sweep(105, 38, 0.3, tau=0.1), noise(0.3, lp=1800, tau=0.05, vol=0.7), sweep(230, 160, 0.3, shape="tri", tau=0.06))])
    add("fist_turn", lambda: [a + b for a, b in zip(sweep(75, 32, 0.6, tau=0.2), swept_noise(0.6, 1800, 120, 0.8, "down"))])
    add("fist_end", lambda: [a + b * 0.4 for a, b in zip(swept_noise(0.9, 120, 6000, 0.9), sweep(180, 1500, 0.9, tau=0.7, shape="tri"))])
    add("fade", lambda: swept_noise(0.5, 250, 1800, 0.35))
    add("smash", lambda: (lambda o: ([mix_into(o, noise(0.07, lp=2500, tau=0.02, vol=0.8), i * 0.06) for i in range(4)], mix_into(o, sweep(180, 80, 0.2, tau=0.08), 0), o)[2])(silence(0.35)))
    add("dwarf_blip", lambda: sweep(300, 295, 0.05, shape="tri", tau=0.06))
    add("dwarf_laugh", lambda: (lambda o: ([mix_into(o, sweep(f, f * 0.93, 0.11, shape="tri", tau=0.1, vib=0.03), i * 0.16) for i, f in enumerate([380, 350, 320])], o)[1])(silence(0.6)))
    add("oneup", lambda: jingle(["C5", "E5", "G5", "C6", "E6"], marimba, 0.08, 0.3, 0.9, 0.5))
    return T


def main(args):
    sfx = sfx_table()
    names = args or list(sfx)
    unknown = [a for a in names if a not in sfx]
    if unknown:
        sys.exit("unknown sound(s): %s" % ", ".join(unknown))
    for name in names:
        x = sfx[name]()
        write_wav(os.path.join(OUT, "sfx", name + ".wav"), fade_edges(x), 0.85)
        print("sfx  %-16s %.2fs" % (name, len(x) / SR))


if __name__ == "__main__":
    main(sys.argv[1:])
