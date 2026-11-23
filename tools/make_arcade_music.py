#!/usr/bin/env python3
"""Arcade fighting-game music, synthesized from scratch (pure Python).

Street-Fighter-style: the real thing was FM synthesis + drum samples, so this is
the kind of music a software synthesizer can do honestly.
  runs 1-5   arcade rock: slap bass, FM piano, a saw lead, distorted guitar riffs
  runs 6+    synthwave chase: pumping pads, 16th arpeggios, an echoing lead
  boss       taiko storm: shamisen riff, shakuhachi, gong (hirajoshi scale)
  shop       funk groove with chicken-scratch guitar
  game over  a gong and a lone shakuhachi
plus a round-win and a KO fanfare. Tension comes from minor keys, dominant chords,
fills, risers and drum rolls.

    python3 tools/make_arcade_music.py                 # demos -> docs/music-demo/
    python3 tools/make_arcade_music.py run_a boss      # only these
    python3 tools/make_arcade_music.py --install       # into godot/assets/audio/music/

Reuses the helpers of make_sounds.py. Art tooling only; the game is pure Godot.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sounds as ms  # noqa: E402

ms.SR = 32000  # a little crisper than the effects (cymbals)
SR = ms.SR
TAU = math.tau
random.seed(11)


def hzm(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ----------------------------------------------------------------- voices
def fm(freq, dur, ratio=1.0, index=2.0, idx_tau=0.2, a=0.003, d=0.15, s=0.5, r=0.08, fb=0.0, vol=0.6, vib=0.0):
    n = ms.n_samples(dur + r)
    env = ms.adsr(n, a, d, s, r)
    out, ph_c, ph_m, last = [], 0.0, 0.0, 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + vib * math.sin(TAU * 5.6 * t) * min(1.0, t * 4.0)) if vib else freq
        ph_m += TAU * freq * ratio / SR
        m = math.sin(ph_m + fb * last)
        last = m
        ph_c += TAU * f / SR
        out.append(math.sin(ph_c + index * math.exp(-t / idx_tau) * m) * env[i] * vol)
    return out


def slap_bass(freq, dur, vol=0.9):
    body = fm(freq, dur, ratio=1.0, index=3.2, idx_tau=0.045, a=0.001, d=0.14, s=0.3, r=0.04, vol=vol)
    sub = [math.sin(TAU * freq * 0.5 * i / SR) * math.exp(-i / SR / 0.25) * vol * 0.35 for i in range(len(body))]
    click = ms.noise(0.012, hp=1500, tau=0.004, vol=0.25)
    out = [b + s for b, s in zip(body, sub)]
    for i, c in enumerate(click):
        out[i] += c
    return out


def epiano(freq, dur, vol=0.55):
    a = fm(freq, dur, ratio=1.0, index=1.7, idx_tau=0.35, a=0.002, d=0.5, s=0.25, r=0.1, vol=vol)
    b = fm(freq, dur, ratio=14.0, index=0.8, idx_tau=0.03, a=0.001, d=0.1, s=0.0, r=0.02, vol=vol * 0.25)
    return [x + y for x, y in zip(a, b)]


def fm_brass(freq, dur, vol=0.5):
    return fm(freq, dur, ratio=1.0, index=3.0, idx_tau=0.4, a=0.022, d=0.08, s=0.8, r=0.06, vol=vol, vib=0.003)


def lead(freq, dur, vol=0.5):
    """Gritty saw lead: two detuned saws, delayed vibrato, tanh drive."""
    n = ms.n_samples(dur + 0.06)
    env = ms.adsr(n, 0.008, 0.05, 0.85, 0.06)
    out = []
    p1 = p2 = 0.0
    harm = [k for k in range(1, 9) if freq * k < SR / 2.2]
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + 0.006 * math.sin(TAU * 5.8 * t) * min(1.0, max(0.0, (t - 0.12) * 5.0)))
        p1 += TAU * f / SR
        p2 += TAU * f * 1.005 / SR
        v = 0.0
        for k in harm:
            v += (math.sin(p1 * k) + math.sin(p2 * k)) / k
        out.append(math.tanh(1.5 * v * 0.55) * env[i] * vol)
    return out


def guitar(freq, dur, mute=False, vol=0.95, power=True, bend=0.0, bend_t=0.12, vib=0.0):
    """Distorted electric guitar: two detuned saws per string through a hot amp.
    power=True plays a power chord (root + fifth + octave), False a single note
    (leads). `bend` starts that many semitones above the pitch and glides down to
    it over `bend_t` s (use a negative value to scoop up into a note); `vib` adds
    finger vibrato; short notes with mute=True are palm-muted chugs."""
    n = ms.n_samples(dur + 0.05)
    mults = (1.0, 1.5, 2.0) if power else (1.0, 2.0)
    out = [0.0] * n
    bend_curve = [2.0 ** (bend * (1.0 - min(1.0, (i / SR) / bend_t)) / 12.0) for i in range(n)] if bend else None
    for mult in mults:
        ph1 = ph2 = 0.0
        weight = 1.0 if mult < 2 else (0.7 if power else 0.45)
        for i in range(n):
            f = freq * mult
            if bend_curve:
                f *= bend_curve[i]
            if vib:
                t = i / SR
                f *= 1.0 + vib * math.sin(TAU * 5.4 * t) * min(1.0, max(0.0, (t - 0.15) * 4.0))
            ph1 += f / SR
            ph2 += f * 1.004 / SR
            out[i] += ((2.0 * (ph1 - math.floor(ph1)) - 1.0) + (2.0 * (ph2 - math.floor(ph2)) - 1.0)) * 0.5 * weight
    tau = 0.07 if mute else max(0.28, dur * 0.9)
    pre = ms.highpass(out, 110.0)  # keeps the low end tight before the distortion
    driven = [math.tanh(5.0 * v * math.exp(-i / SR / tau) * 0.4 * min(1.0, i / (0.002 * SR) + 0.001)) for i, v in enumerate(pre)]
    pick = ms.noise(0.012, hp=2000, tau=0.004, vol=0.18)
    for i, c in enumerate(pick[:n]):
        driven[i] += c
    driven = ms.lowpass(driven, 3600)
    return ms.fade_edges([v * vol for v in driven], 1, 14)


def scratch(freq, dur, vol=0.5):
    """Funk 'chicken scratch': a short, bright, muted clean chord hit."""
    a = fm(freq, 0.07, ratio=2.0, index=1.8, idx_tau=0.02, a=0.001, d=0.04, s=0.0, r=0.02, vol=vol)
    b = ms.noise(0.05, hp=1200, lp=5000, tau=0.015, vol=vol * 0.5)
    return [x + (b[i] if i < len(b) else 0.0) for i, x in enumerate(a)]


def ghost_scratch(vol=0.25):
    return ms.noise(0.045, hp=1800, lp=6000, tau=0.012, vol=vol)


# drums ----------------------------------------------------------------
def kick(vol=0.95):
    out, ph = [], 0.0
    for i in range(ms.n_samples(0.22)):
        f = 48 + 150 * math.exp(-i / SR / 0.028)
        ph += TAU * f / SR
        out.append(math.sin(ph) * math.exp(-i / SR / 0.075) * vol)
    click = ms.noise(0.006, hp=2500, tau=0.002, vol=0.5)
    for i, c in enumerate(click):
        out[i] += c
    return out


def snare(vol=0.7):
    n = ms.n_samples(0.3)
    body = [math.sin(TAU * 185 * i / SR) * math.exp(-i / SR / 0.05) * 0.6 for i in range(n)]
    crack = ms.noise(0.3, hp=900, tau=0.06, vol=0.8)
    tail = []  # gated reverb: a loud tail that is chopped off hard
    gate = int(0.17 * SR)
    for i, v in enumerate(ms.noise(0.3, lp=6000, vol=0.45)):
        tail.append(v * math.exp(-i / SR / 0.35) if i < gate else 0.0)
    out = [(b + c + t) * vol for b, c, t in zip(body, crack, tail)]
    return ms.fade_edges(out, 0, 6)


def hat(open_=False, vol=0.3):
    return ms.noise(0.2 if open_ else 0.045, hp=7000, tau=0.09 if open_ else 0.012, vol=vol)


def crash(vol=0.5):
    return ms.noise(1.4, hp=3500, tau=0.55, vol=vol)


def tom(freq, vol=0.8):
    out, ph = [], 0.0
    for i in range(ms.n_samples(0.28)):
        f = freq * (0.6 + 0.4 * math.exp(-i / SR / 0.05))
        ph += TAU * f / SR
        out.append(math.sin(ph) * math.exp(-i / SR / 0.09) * vol)
    nz = ms.noise(0.04, hp=1500, tau=0.01, vol=0.25)
    for i, c in enumerate(nz):
        out[i] += c
    return out


def tick(vol=0.4):
    return [math.sin(TAU * 1700 * i / SR) * math.exp(-i / SR / 0.004) * vol for i in range(ms.n_samples(0.03))]


# ----------------------------------------------------------------- mixing
def reverb(x, wet=0.16):
    """A small Schroeder reverb (4 combs + 2 allpasses)."""
    def comb(sig, delay_ms, fb):
        d = int(delay_ms / 1000 * SR)
        buf = [0.0] * d
        out = []
        for i, v in enumerate(sig):
            j = i % d
            y = buf[j]
            buf[j] = v + y * fb
            out.append(y)
        return out

    def allpass(sig, delay_ms, g=0.5):
        d = int(delay_ms / 1000 * SR)
        buf = [0.0] * d
        out = []
        for i, v in enumerate(sig):
            j = i % d
            b = buf[j]
            y = -g * v + b
            buf[j] = v + g * y
            out.append(y)
        return out

    combs = [comb(x, dms, fb) for dms, fb in ((29.7, 0.80), (37.1, 0.78), (41.1, 0.77), (43.7, 0.75))]
    mixed = [sum(c[i] for c in combs) * 0.25 for i in range(len(x))]
    mixed = allpass(allpass(mixed, 5.0), 1.7)
    return [v + m * wet for v, m in zip(x, mixed)]


class Track(ms.Song):
    """A song on a 16th-note grid: (bar, step) positions."""

    def __init__(self, bars, bpm, tail=2.5):
        super().__init__(bars, 4, bpm, tail)

    def at(self, bar, step):
        return bar * 4 + step / 4.0

    def tone(self, bar, step, steps, voice, midi_note, gain=1.0, **kw):
        d = steps / 4.0
        mix_into_ = ms.mix_into
        sample = voice(hzm(midi_note), d * self.spb, **kw) if kw else voice(hzm(midi_note), d * self.spb)
        mix_into_(self.buf, sample, self.at(bar, step) * self.spb, gain)

    def drum(self, bar, step, sample, gain=1.0):
        ms.mix_into(self.buf, sample, self.at(bar, step) * self.spb, gain)

    def render(self, wet=0.14):
        self.buf = reverb(self.buf, wet)
        return self.render_loop()


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def nm(name):
    """'E5' -> MIDI number."""
    base = name[:-1]
    return 12 * (int(name[-1]) + 1) + NOTE[base]


# chord = (bass root midi, triad intervals for the keys)
CHORDS = {
    "Em": (28, [0, 3, 7]), "C": (36, [0, 4, 7]), "D": (38, [0, 4, 7]), "G": (31, [0, 4, 7]),
    "Am": (33, [0, 3, 7]), "B7": (35, [0, 4, 7, 10]), "F": (29, [0, 4, 7]),
    "Am7": (33, [0, 3, 7, 10]), "D7": (38, [0, 4, 7, 10]), "Fmaj7": (29, [0, 4, 7, 11]), "E7": (40, [0, 4, 7, 10]),
}


def melody(track, notes, voice, octave_shift=0, gain=1.0, bar_offset=0):
    for bar, step, steps, name in notes:
        track.tone(bar + bar_offset, step, steps * 0.97, voice, nm(name) + octave_shift, gain)


# ----------------------------------------------------------------- guitar riffs
# (step, length in steps, semitones above the chord root, palm-muted?)
RIFF_RUN_A = [(0, 2, 0, False), (2, 1, 0, True), (3, 1, 0, True), (4, 2, 3, False), (6, 2, 5, False),
              (8, 2, 7, False), (10, 1, 5, True), (11, 1, 3, True), (12, 2, 0, False), (14, 1, 0, True), (15, 1, 0, True)]
RIFF_RUN_B = [(0, 3, 0, False), (3, 1, 0, True), (4, 1, 0, True), (5, 1, 3, True), (6, 2, 5, False),
              (8, 2, 7, False), (10, 2, 10, False), (12, 2, 7, False), (14, 2, 5, False)]
MAJOR_CHORDS = ("C", "D", "G", "B7", "F", "Fmaj7", "D7", "E7")


def riff(t, bar, events, chord, gain, until=16):
    """Play a riff on `chord` (its third turns major on major chords)."""
    root, _ = CHORDS[chord]
    for step, ln, off, mute in events:
        if step >= until:
            continue
        if off == 3 and chord in MAJOR_CHORDS:
            off = 4
        t.tone(bar, step, ln, guitar, root + 12 + off, gain, mute=mute)


# ----------------------------------------------------------------- the themes
RUN_PROG = ["Em", "Em", "C", "D", "Em", "G", "C", "B7", "Am", "Am", "Em", "Em", "Am", "B7", "Em", "B7"]
RUN_LEAD = [
    (0, 0, 3, "E5"), (0, 3, 1, "G5"), (0, 4, 4, "B5"), (0, 8, 2, "A5"), (0, 10, 2, "G5"), (0, 12, 4, "E5"),
    (1, 0, 3, "E5"), (1, 3, 1, "G5"), (1, 4, 2, "B5"), (1, 6, 2, "D6"), (1, 8, 4, "B5"), (1, 12, 2, "G5"), (1, 14, 2, "A5"),
    (2, 0, 4, "C6"), (2, 4, 2, "B5"), (2, 6, 2, "A5"), (2, 8, 4, "G5"), (2, 12, 2, "E5"), (2, 14, 2, "G5"),
    (3, 0, 2, "A5"), (3, 2, 2, "B5"), (3, 4, 4, "D6"), (3, 8, 2, "B5"), (3, 10, 2, "A5"), (3, 12, 4, "F#5"),
    (4, 0, 3, "E5"), (4, 3, 1, "G5"), (4, 4, 4, "B5"), (4, 8, 2, "A5"), (4, 10, 2, "G5"), (4, 12, 4, "E5"),
    (5, 0, 3, "D6"), (5, 3, 1, "B5"), (5, 4, 4, "G5"), (5, 8, 2, "B5"), (5, 10, 2, "D6"), (5, 12, 4, "G6"),
    (6, 0, 3, "E6"), (6, 3, 1, "C6"), (6, 4, 4, "G5"), (6, 8, 4, "E5"), (6, 12, 4, "G5"),
    (7, 0, 2, "D#6"), (7, 2, 2, "B5"), (7, 4, 2, "A5"), (7, 6, 2, "F#5"), (7, 8, 4, "D#5"), (7, 12, 4, "B4"),
    (8, 0, 3, "A5"), (8, 3, 1, "C6"), (8, 4, 4, "E6"), (8, 8, 2, "D6"), (8, 10, 2, "C6"), (8, 12, 4, "A5"),
    (9, 0, 3, "A5"), (9, 3, 1, "C6"), (9, 4, 2, "D6"), (9, 6, 2, "E6"), (9, 8, 4, "C6"), (9, 12, 4, "A5"),
    (10, 0, 3, "G5"), (10, 3, 1, "B5"), (10, 4, 4, "E6"), (10, 8, 2, "D6"), (10, 10, 2, "B5"), (10, 12, 4, "G5"),
    (11, 0, 2, "E6"), (11, 2, 2, "D6"), (11, 4, 4, "B5"), (11, 8, 4, "G5"), (11, 12, 4, "B5"),
    (12, 0, 3, "C6"), (12, 3, 1, "E6"), (12, 4, 4, "A6"), (12, 8, 2, "G6"), (12, 10, 2, "E6"), (12, 12, 4, "C6"),
    (13, 0, 2, "D#6"), (13, 2, 2, "F#6"), (13, 4, 4, "B6"), (13, 8, 2, "A6"), (13, 10, 2, "F#6"), (13, 12, 4, "D#6"),
    (14, 0, 4, "E6"), (14, 4, 2, "G6"), (14, 6, 2, "B6"), (14, 8, 4, "A6"), (14, 12, 4, "G6"),
    (15, 0, 2, "F#6"), (15, 2, 2, "D#6"), (15, 4, 2, "B5"), (15, 6, 2, "A5"), (15, 8, 4, "F#5"), (15, 12, 2, "D#5"),
]
BASS_RIFF = [0, 0, 12, 0, 0, 7, 10, 12]  # eighth notes per bar (semitones above the root)


def run_theme(layers, bpm):
    t = Track(16, bpm)
    riff_gain = {1: 0.5, 2: 0.85}[layers]
    for bar, chord in enumerate(RUN_PROG):
        root, tones = CHORDS[chord]
        for e, off in enumerate(BASS_RIFF):  # syncopated slap-bass riff
            t.tone(bar, e * 2, 1.7, slap_bass, root + off, 0.65 if e % 2 == 0 else 0.5)
        for step in (3, 7, 10):  # FM piano stabs
            for iv in tones:
                t.tone(bar, step, 1.5, epiano, root + 24 + iv, 0.3 if layers >= 2 else 0.4)
        # drums
        t.drum(bar, 0, kick(), 0.9)
        t.drum(bar, 6, kick(), 0.8)
        t.drum(bar, 8, kick(), 0.85)
        t.drum(bar, 4, snare(), 0.8)
        t.drum(bar, 12, snare(), 0.8)
        for s_ in range(0, 16, 2):
            t.drum(bar, s_, hat(s_ == 14), 0.5)
        if bar % 4 == 0:
            t.drum(bar, 0, crash(), 0.55)
        fill = bar % 4 == 3
        if fill:  # tension: a tom roll into the next phrase
            for k, f in enumerate((200, 170, 140, 110)):
                t.drum(bar, 12 + k, tom(f), 0.8)
        # the guitar riff: it is there from the first run and gets louder
        riff(t, bar, RIFF_RUN_A if bar % 2 == 0 else RIFF_RUN_B, chord, riff_gain, until=12 if fill else 16)
        if fill:  # a falling run of power chords instead of the end of the riff
            for k, off in enumerate((7, 5, 3, 0)):
                t.tone(bar, 12 + k, 1, guitar, root + 12 + off, riff_gain, mute=False)
        if layers >= 2:
            for s_ in range(1, 16, 2):
                t.drum(bar, s_, hat(False), 0.3)
    melody(t, RUN_LEAD, lead, 0, 0.5)
    return t.render()


SHOP_PROG = ["Am7", "D7", "Am7", "D7", "Fmaj7", "E7", "Am7", "E7"]
SHOP_LEAD = [
    (0, 0, 3, "E5"), (0, 3, 1, "D5"), (0, 4, 2, "C5"), (0, 6, 2, "A4"), (0, 8, 4, "C5"),
    (1, 0, 3, "F#5"), (1, 3, 1, "E5"), (1, 4, 4, "D5"), (1, 8, 2, "A4"), (1, 10, 2, "C5"), (1, 12, 4, "D5"),
    (2, 0, 3, "E5"), (2, 3, 1, "G5"), (2, 4, 2, "E5"), (2, 6, 2, "D5"), (2, 8, 4, "C5"), (2, 12, 4, "A4"),
    (3, 0, 2, "D5"), (3, 2, 2, "F#5"), (3, 4, 4, "A5"), (3, 8, 2, "G5"), (3, 10, 2, "F#5"), (3, 12, 4, "D5"),
    (4, 0, 3, "C6"), (4, 3, 1, "A5"), (4, 4, 4, "F5"), (4, 8, 2, "E5"), (4, 10, 2, "F5"), (4, 12, 4, "A5"),
    (5, 0, 3, "G#5"), (5, 3, 1, "B5"), (5, 4, 4, "E6"), (5, 8, 2, "D6"), (5, 10, 2, "B5"), (5, 12, 4, "G#5"),
    (6, 0, 2, "A5"), (6, 2, 2, "C6"), (6, 4, 4, "E6"), (6, 8, 2, "D6"), (6, 10, 2, "C6"), (6, 12, 4, "A5"),
    (7, 0, 2, "G#5"), (7, 2, 2, "B5"), (7, 4, 2, "D6"), (7, 6, 2, "C6"), (7, 8, 2, "B5"), (7, 10, 2, "G#5"), (7, 12, 4, "E5"),
]


def shop_theme(bpm=104):
    t = Track(8, bpm)
    for bar, chord in enumerate(SHOP_PROG):
        root, tones = CHORDS[chord]
        for step, off, ln in ((0, 0, 2), (3, 0, 1), (6, 12, 1), (8, 0, 2), (10, 7, 1), (12, 10, 1), (14, 12, 2)):  # funky slap line
            t.tone(bar, step, ln, slap_bass, root + off, 0.8)
        for step in (2, 5, 9, 13):  # comping
            for iv in tones:
                t.tone(bar, step, 1.6, epiano, root + 24 + iv, 0.38)
        t.drum(bar, 0, kick(), 0.8)
        t.drum(bar, 7, kick(), 0.6)
        t.drum(bar, 10, kick(), 0.7)
        t.drum(bar, 4, snare(), 0.55)
        t.drum(bar, 12, snare(), 0.55)
        for s in range(16):
            t.drum(bar, s, hat(s == 14), 0.35 if s % 2 == 0 else 0.18)
        for s in range(16):  # chicken-scratch rhythm guitar: accented chord hits, ghost scratches between
            if s in (2, 5, 9, 13):
                for iv in tones:
                    t.tone(bar, s, 0.5, scratch, root + 24 + iv, 0.35)
            elif s % 2 == 1 or s in (0, 8):
                t.drum(bar, s, ghost_scratch(), 0.5)
    melody(t, SHOP_LEAD, epiano, 12, 0.7)
    return t.render(0.2)


def round_win():
    t = Track(1, 60)
    t.buf = [0.0] * (SR * 5)
    for k, name in enumerate(["E5", "G5", "B5", "E6"]):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 0.25, 0.8), k * 0.13, 0.7)
    for name in ("E4", "G4", "B4", "E5"):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 1.4, 0.8), 0.55, 0.55)
    for k, name in enumerate(["E3", "G3", "A3"]):  # a quick power-chord run into the final chord
        ms.mix_into(t.buf, guitar(hzm(nm(name)), 0.11, vol=0.7), k * 0.13, 0.8)
    ms.mix_into(t.buf, guitar(hzm(nm("E3")), 1.2, vol=0.7), 0.55, 0.8)
    ms.mix_into(t.buf, crash(), 0.55, 0.6)
    ms.mix_into(t.buf, kick(), 0.55, 1.0)
    return reverb(t.buf[: int(SR * 3.2)], 0.2)


def ko_fanfare():
    t = Track(1, 60)
    t.buf = [0.0] * (SR * 7)
    for k in range(2):
        for name in ("E3", "B3", "E4"):
            ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 0.3, 0.9), k * 0.4, 0.6)
        ms.mix_into(t.buf, kick(), k * 0.4, 1.0)
        ms.mix_into(t.buf, snare(), k * 0.4, 0.9)
    for k, name in enumerate(["E5", "G5", "B5", "D6", "E6"]):
        ms.mix_into(t.buf, lead(hzm(nm(name)), 0.2, 0.7), 0.9 + k * 0.1, 0.6)
    for name in ("E3", "G3", "B3", "E4", "G4"):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 2.0, 0.9), 1.5, 0.5)
    for k, name in enumerate(["E3", "G3", "A3", "B3"]):  # power-chord riff up to the big hit
        ms.mix_into(t.buf, guitar(hzm(nm(name)), 0.2, vol=0.7), 0.9 + k * 0.15, 0.7)
    ms.mix_into(t.buf, guitar(hzm(nm("E2")), 2.0, vol=0.8), 1.5, 0.9)
    ms.mix_into(t.buf, crash(0.7), 1.5, 0.8)
    for k, f in enumerate((220, 180, 150, 120)):
        ms.mix_into(t.buf, tom(f), 1.0 + k * 0.1, 0.8)
    return reverb(t.buf[: int(SR * 4.8)], 0.22)


# ================================================================= candidates: synthwave / taiko / shakuhachi
def saw_naive(freq, n, detune_cents=0.0):
    """A cheap (aliased) sawtooth; fine once it has been low-passed."""
    f = freq * 2.0 ** (detune_cents / 1200.0)
    out, ph = [], 0.0
    for _ in range(n):
        ph += f / SR
        out.append(2.0 * (ph - math.floor(ph)) - 1.0)
    return out


def saw_pluck(freq, dur, vol=0.5):
    """Synthwave arpeggio pluck: two detuned saws, a fast decay, a closing filter."""
    n = ms.n_samples(dur + 0.05)
    a, b = saw_naive(freq, n, -6), saw_naive(freq, n, 6)
    out = [(x + y) * 0.5 * math.exp(-i / SR / 0.11) * vol for i, (x, y) in enumerate(zip(a, b))]
    return ms.fade_edges(ms.lowpass(out, 2600), 1, 10)


def super_pad(freq, dur, vol=0.4):
    """Warm supersaw pad: five detuned saws with a slow attack, low-passed."""
    n = ms.n_samples(dur + 0.2)
    mix = [0.0] * n
    for cents in (-14, -7, 0, 7, 14):
        for i, v in enumerate(saw_naive(freq, n, cents)):
            mix[i] += v
    env = ms.adsr(n, 0.25, 0.2, 0.85, 0.2)
    return ms.lowpass([v * e * vol * 0.2 for v, e in zip(mix, env)], 1700)


def synth_lead(freq, dur, vol=0.5):
    """Bright three-saw lead with slow vibrato (the echo is added to the whole line)."""
    n = ms.n_samples(dur + 0.06)
    env = ms.adsr(n, 0.01, 0.06, 0.85, 0.07)
    out = [0.0] * n
    for cents in (-8, 0, 8):
        ph, f = 0.0, freq * 2.0 ** (cents / 1200.0)
        for i in range(n):
            t = i / SR
            ph += f * (1.0 + 0.004 * math.sin(TAU * 5.2 * t) * min(1.0, max(0.0, (t - 0.1) * 4.0))) / SR
            out[i] += 2.0 * (ph - math.floor(ph)) - 1.0
    return ms.lowpass([v * e * vol * 0.33 for v, e in zip(out, env)], 6500)


def echo(x, delay_s, fb=0.42, mix=0.5, taps=4):
    d = int(delay_s * SR)
    out = list(x) + [0.0] * (d * taps)
    for k in range(1, taps + 1):
        g = mix * fb ** (k - 1)
        for i, v in enumerate(x):
            out[i + k * d] += v * g
    return out[: len(x)]


def pump(x, spb, depth=0.7, tau=0.12):
    """Sidechain 'pumping': the pad ducks on every kick, then swells back."""
    return [v * (1.0 - depth * math.exp(-((i / SR) % spb) / tau)) for i, v in enumerate(x)]


SYNTH_PROG = ["Em", "C", "G", "D", "Em", "C", "G", "D", "Am", "Em", "C", "B7", "Am", "Em", "B7", "B7"]
SYNTH_LEAD = [
    (0, 0, 4, "B5"), (0, 4, 2, "E6"), (0, 6, 2, "D6"), (0, 8, 4, "B5"), (0, 12, 2, "G5"), (0, 14, 2, "A5"),
    (1, 0, 4, "C6"), (1, 4, 4, "G5"), (1, 8, 8, "G5"),
    (2, 0, 4, "D6"), (2, 4, 2, "B5"), (2, 6, 2, "G5"), (2, 8, 4, "B5"), (2, 12, 4, "D6"),
    (3, 0, 4, "A5"), (3, 4, 4, "F#5"), (3, 8, 4, "A5"), (3, 12, 4, "D6"),
    (4, 0, 4, "E6"), (4, 4, 2, "G6"), (4, 6, 2, "F#6"), (4, 8, 4, "E6"), (4, 12, 4, "B5"),
    (5, 0, 4, "E6"), (5, 4, 2, "D6"), (5, 6, 2, "C6"), (5, 8, 4, "B5"), (5, 12, 4, "G5"),
    (6, 0, 2, "B5"), (6, 2, 2, "D6"), (6, 4, 4, "G6"), (6, 8, 2, "F#6"), (6, 10, 2, "E6"), (6, 12, 4, "D6"),
    (7, 0, 2, "A5"), (7, 2, 2, "D6"), (7, 4, 4, "F#6"), (7, 8, 2, "E6"), (7, 10, 2, "D6"), (7, 12, 4, "A5"),
    (8, 0, 4, "C6"), (8, 4, 4, "E6"), (8, 8, 4, "A6"), (8, 12, 4, "G6"),
    (9, 0, 4, "G6"), (9, 4, 4, "E6"), (9, 8, 4, "B5"), (9, 12, 4, "E6"),
    (10, 0, 4, "E6"), (10, 4, 2, "G6"), (10, 6, 2, "E6"), (10, 8, 4, "C6"), (10, 12, 4, "G5"),
    (11, 0, 4, "D#6"), (11, 4, 4, "F#6"), (11, 8, 4, "B6"), (11, 12, 4, "A6"),
    (12, 0, 4, "A6"), (12, 4, 2, "G6"), (12, 6, 2, "E6"), (12, 8, 4, "C6"), (12, 12, 4, "E6"),
    (13, 0, 4, "B5"), (13, 4, 4, "E6"), (13, 8, 4, "G6"), (13, 12, 4, "B6"),
    (14, 0, 2, "A6"), (14, 2, 2, "F#6"), (14, 4, 4, "D#6"), (14, 8, 4, "F#6"), (14, 12, 4, "A6"),
    (15, 0, 4, "B6"), (15, 4, 2, "F#6"), (15, 6, 2, "D#6"), (15, 8, 4, "B5"), (15, 12, 4, "D#6"),
]


def synthwave_theme(bpm=150):
    """Run 6+: a neon night chase - octave-bouncing bass, 16th arpeggios, pumping pads, an echoing lead."""
    t = Track(16, bpm)
    spb = t.spb
    pad_layer = [0.0] * len(t.buf)
    lead_layer = [0.0] * len(t.buf)
    pattern = [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3]
    for bar, chord in enumerate(SYNTH_PROG):
        root, tones = CHORDS[chord]
        for e in range(8):  # the octave-bouncing bass
            t.tone(bar, e * 2, 1.8, slap_bass, root + (12 if e % 2 else 0), 0.55)
        notes = [root + 24 + iv for iv in tones] + [root + 36]
        for s_ in range(16):  # 16th-note arpeggio
            t.tone(bar, s_, 0.9, saw_pluck, notes[pattern[s_] % len(notes)], 0.5 if s_ % 4 else 0.62)
        for iv in tones:  # the pad
            ms.mix_into(pad_layer, super_pad(hzm(root + 24 + iv), 4 * spb), bar * 4 * spb, 1.0)
        for beat in range(4):  # four on the floor
            t.drum(bar, beat * 4, kick(), 0.95)
        t.drum(bar, 4, snare(), 0.85)
        t.drum(bar, 12, snare(), 0.85)
        for s_ in range(2, 16, 4):
            t.drum(bar, s_, hat(True), 0.45)
        for s_ in range(16):
            if s_ % 2 == 1:
                t.drum(bar, s_, hat(False), 0.2)
        if bar % 4 == 0:
            t.drum(bar, 0, crash(), 0.5)
        if bar % 8 == 7:  # a noise riser into the next section
            ms.mix_into(t.buf, ms.swept_noise(2 * spb, 300, 7000, 0.55), (bar * 4 + 2) * spb, 1.0)
        if bar % 4 == 3:
            for k, f in enumerate((210, 175, 145, 115)):
                t.drum(bar, 12 + k, tom(f), 0.7)
    for bar, step, steps, name in SYNTH_LEAD:
        ms.mix_into(lead_layer, synth_lead(hzm(nm(name)), steps * spb / 4 * 0.96), t.at(bar, step) * spb, 1.0)
    pad_layer = pump(pad_layer, spb, 0.75)
    lead_layer = echo(lead_layer, 0.75 * spb, 0.42, 0.5)  # dotted-eighth echo
    for i in range(len(t.buf)):
        t.buf[i] += pad_layer[i] * 0.9 + lead_layer[i] * 0.55
    # a gentle saturation lifts the average level (the kick peaks otherwise keep it quiet)
    mix = ms.normalize(t.render(0.12), 1.0)
    return [math.tanh(1.5 * v) for v in mix]


# ---- Taiko and Eastern boss ---------------------------------------------------------
def shamisen(freq, dur, vol=0.9):
    """A buzzing, plucked three-string lute: Karplus-Strong with a bachi slap and a gritty edge."""
    n_len = max(2, int(SR / freq))
    buf = ms.lowpass([random.uniform(-1, 1) for _ in range(n_len)], 6000)
    out = []
    for i in range(ms.n_samples(dur + 0.05)):
        j = i % n_len
        v = buf[j]
        buf[j] = 0.5 * (buf[j] + buf[(j + 1) % n_len]) * 0.9985
        out.append(math.tanh(1.8 * v) * vol)
    for i, c in enumerate(ms.noise(0.012, hp=3000, tau=0.004, vol=0.35)):
        if i < len(out):
            out[i] += c
    return ms.fade_edges(out, 1, 20)


def shakuhachi(freq, dur, vol=0.6):
    """A breathy bamboo flute: a scoop into the note, slow vibrato, a lot of air."""
    n = ms.n_samples(dur + 0.1)
    env = ms.adsr(n, 0.09, 0.12, 0.8, 0.18)
    air = ms.lowpass(ms.highpass([random.uniform(-1, 1) for _ in range(n)], freq * 0.8), freq * 3.0)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        scoop = 2.0 ** (-0.9 * math.exp(-t / 0.06) / 12.0)
        vibrato = 1.0 + 0.012 * math.sin(TAU * 5.0 * t) * min(1.0, max(0.0, (t - 0.25) * 2.5))
        ph += TAU * freq * scoop * vibrato / SR
        v = math.sin(ph) + 0.22 * math.sin(2 * ph) + 0.08 * math.sin(3 * ph)
        out.append((v * 0.7 + air[i] * 0.55) * env[i] * vol)
    return out


def gong(freq=70.0, dur=5.0, vol=0.9):
    n = ms.n_samples(dur)
    out = [0.0] * n
    for k, (m, g) in enumerate([(1.0, 1.0), (1.47, 0.7), (2.09, 0.6), (2.56, 0.45), (3.51, 0.3), (4.13, 0.2)]):
        beat = 0.5 + 0.7 * k  # slow beating makes it shimmer
        for i in range(n):
            t = i / SR
            out[i] += math.sin(TAU * freq * m * t + 0.4 * math.sin(TAU * beat * t)) * g * math.exp(-t / (dur / (1.3 + 0.35 * k)))
    swell = ms.noise(dur, lp=2500, vol=0.12)
    for i in range(n):
        out[i] = (out[i] * min(1.0, i / (0.015 * SR)) + swell[i] * math.sin(math.pi * min(1.0, i / (SR * 1.2))) * 0.6) * vol
    return out


def taiko(vol=0.95):
    """A big low taiko hit: a fast pitch drop and a thump of air."""
    out, ph = [], 0.0
    for i in range(ms.n_samples(0.45)):
        f = 55 + 60 * math.exp(-i / SR / 0.05)
        ph += TAU * f / SR
        out.append(math.sin(ph) * math.exp(-i / SR / 0.16) * vol)
    nz = ms.noise(0.45, lp=500, tau=0.05, vol=0.3)
    return [a + b for a, b in zip(out, nz)]


def ka(vol=0.7):
    """The rim of a taiko / a small high drum."""
    out = tom(430, vol)[: ms.n_samples(0.12)]
    for i, c in enumerate(ms.noise(0.02, hp=2500, tau=0.006, vol=0.4)):
        if i < len(out):
            out[i] += c
    return out


BOSS2_ROOTS = [28, 28, 29, 28, 28, 28, 29, 35] * 2  # E, E, F (the tense b2), E ... B
RIFF_SHAM = [(0, 1, 0), (1, 1, 0), (2, 1, 0), (3, 1, 2), (4, 2, 3), (6, 1, 2), (7, 1, 0), (8, 2, 7),
             (10, 1, 8), (11, 1, 7), (12, 2, 3), (14, 1, 2), (15, 1, 0)]  # E hirajoshi: E F# G B C
SHAKU_MELODY = [
    (4, 0, 6, "E5"), (4, 6, 2, "G5"), (4, 8, 4, "F#5"), (4, 12, 4, "E5"),
    (5, 0, 8, "B5"), (5, 8, 4, "C6"), (5, 12, 4, "B5"),
    (6, 0, 4, "G5"), (6, 4, 2, "F#5"), (6, 6, 2, "E5"), (6, 8, 8, "F5"),
    (7, 0, 6, "B5"), (7, 6, 2, "G5"), (7, 8, 4, "F#5"), (7, 12, 4, "E5"),
    (12, 0, 6, "B5"), (12, 6, 2, "C6"), (12, 8, 8, "E6"),
    (13, 0, 4, "C6"), (13, 4, 4, "B5"), (13, 8, 4, "G5"), (13, 12, 4, "F#5"),
    (14, 0, 4, "E5"), (14, 4, 4, "F5"), (14, 8, 8, "B5"),
    (15, 0, 8, "B5"), (15, 8, 4, "C6"), (15, 12, 4, "B5"),
]


def taiko_theme(bpm=156):
    """Boss: a taiko storm with a buzzing shamisen riff, a shakuhachi and a gong."""
    t = Track(16, bpm)
    for bar, root in enumerate(BOSS2_ROOTS):
        shift = root - 28
        for e in range(8):  # driving low pulse
            t.tone(bar, e * 2, 1.7, slap_bass, root + (12 if e in (3, 7) else 0), 0.55)
        for step, ln, off in RIFF_SHAM:  # the shamisen riff, tense and fast
            t.tone(bar, step, ln * 0.9, shamisen, 64 + shift + off + (12 if bar % 4 == 3 and step >= 8 else 0), 0.7)
        # taiko: low "don" on the beat, high "ka" in between
        for step in (0, 4, 8, 12):
            t.drum(bar, step, taiko(), 0.95 if step == 0 else 0.8)
        for step in (3, 6, 10, 11, 14, 15):
            t.drum(bar, step, ka(), 0.6)
        for s_ in range(0, 16, 2):
            t.drum(bar, s_, ka(0.25), 0.4)
        if bar % 4 == 3:  # a drum roll that builds
            for k in range(8):
                t.drum(bar, 8 + k, taiko() if k % 2 == 0 else ka(), 0.7 + 0.04 * k)
        if bar % 8 == 0:
            ms.mix_into(t.buf, gong(), bar * 4 * t.spb, 0.55)
            t.drum(bar, 0, crash(), 0.4)
        if bar % 4 == 0:  # fierce brass stab: root, tritone-ish cluster
            for iv in (0, 1, 7):
                t.tone(bar, 0, 2, fm_brass, root + 24 + iv, 0.4)
    melody(t, SHAKU_MELODY, shakuhachi, 0, 0.9)
    return t.render(0.16)


def shaku_game_over():
    """Game over: a gong, a lone shakuhachi falling through the hirajoshi scale, wind - then silence."""
    buf = [0.0] * (SR * 9)
    ms.mix_into(buf, gong(62.0, 6.5, 1.0), 0.0, 0.9)
    ms.mix_into(buf, ms.swept_noise(6.0, 180, 700, 0.18), 0.0, 1.0)
    for start, name, dur in ((0.4, "E5", 1.5), (2.2, "C5", 1.3), (3.8, "B4", 3.2)):
        ms.mix_into(buf, shakuhachi(hzm(nm(name)), dur, 0.75), start, 0.9)
    ms.mix_into(buf, gong(55.0, 5.0, 0.7), 3.8, 0.5)
    return reverb(buf[: int(SR * 8.2)], 0.38)


TRACKS = {
    "run_a": lambda: run_theme(1, 144),      # runs 1-2: arcade rock, a light guitar riff
    "run_b": lambda: run_theme(2, 150),      # runs 3-5: the same with a full-volume riff
    "run_c": synthwave_theme,                # runs 6+: a neon night chase
    "boss": taiko_theme,                     # the boss: taiko storm, shamisen, shakuhachi, gong
    "shop": shop_theme,                      # the dwarf's funk groove
    "game_over": shaku_game_over,            # a lone shakuhachi and a gong
    "run_complete": round_win,
    "boss_defeated": ko_fanfare,
}


def main(argv):
    install = "--install" in argv
    names = [a for a in argv if not a.startswith("--")] or list(TRACKS)
    unknown = [n for n in names if n not in TRACKS]
    if unknown:
        sys.exit("unknown track(s): %s (choose from %s)" % (", ".join(unknown), ", ".join(TRACKS)))
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out_dir = os.path.join(root, "godot", "assets", "audio", "music") if install else os.path.join(root, "docs", "music-demo")
    for name in names:
        x = TRACKS[name]()
        folder = out_dir
        if install and name == "run_complete":
            folder = os.path.join(root, "godot", "assets", "audio", "sfx")
        ms.write_wav(os.path.join(folder, name + ".wav"), x, 0.85)
        print("%-14s %5.1fs  -> %s" % (name, len(x) / SR, os.path.relpath(folder, root)))


if __name__ == "__main__":
    main(sys.argv[1:])
