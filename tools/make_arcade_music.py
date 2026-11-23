#!/usr/bin/env python3
"""Arcade fighting-game music, synthesized from scratch (pure Python).

Street-Fighter-II-style: the real thing was FM synthesis + drum samples, so this
is the one style a software synthesizer can do honestly - slap-bass riffs, FM
electric piano and brass, a gritty saw lead, distorted power chords, punchy
gated-reverb drums, and tension from minor keys, dominant chords and fills.

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


def guitar(freq, dur, mute=False, vol=0.55):
    """Distorted power chord (root + fifth + octave), palm-muted when short."""
    n = ms.n_samples(dur + 0.04)
    out = [0.0] * n
    for mult in (1.0, 1.5, 2.0):
        ph, f = 0.0, freq * mult
        for i in range(n):
            ph += f / SR
            out[i] += (2.0 * (ph - math.floor(ph)) - 1.0) * (1.0 if mult < 2 else 0.7)
    tau = 0.07 if mute else max(0.2, dur * 0.7)
    out = [math.tanh(3.2 * v * math.exp(-i / SR / tau) * 0.5 * (min(1.0, i / (0.002 * SR) + 0.001))) for i, v in enumerate(out)]
    out = ms.lowpass(out, 3800)
    return ms.fade_edges([v * vol for v in out], 1, 12)


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
    for bar, chord in enumerate(RUN_PROG):
        root, tones = CHORDS[chord]
        for e, off in enumerate(BASS_RIFF):  # syncopated slap-bass riff
            t.tone(bar, e * 2, 1.7, slap_bass, root + off, 0.85 if e % 2 == 0 else 0.7)
        for step in (3, 7, 10):  # FM piano stabs
            for iv in tones:
                t.tone(bar, step, 1.5, epiano, root + 24 + iv, 0.45)
        # drums
        t.drum(bar, 0, kick(), 0.9)
        t.drum(bar, 6, kick(), 0.8)
        t.drum(bar, 8, kick(), 0.85)
        t.drum(bar, 4, snare(), 0.8)
        t.drum(bar, 12, snare(), 0.8)
        for s in range(0, 16, 2):
            t.drum(bar, s, hat(s == 14), 0.5)
        if bar % 4 == 0:
            t.drum(bar, 0, crash(), 0.55)
        if bar % 4 == 3:  # tension: a tom roll into the next phrase
            for k, f in enumerate((200, 170, 140, 110)):
                t.drum(bar, 12 + k, tom(f), 0.8)
        if layers >= 2:  # distorted power chords
            for step, ln in ((0, 3), (6, 2), (10, 2), (12, 4)):
                t.tone(bar, step, ln, guitar, root + 12, 0.5, mute=ln < 3)
            for s in range(1, 16, 2):
                t.drum(bar, s, hat(False), 0.3)
        if layers >= 3:  # palm-muted sixteenths + double kick
            for s in range(16):
                t.tone(bar, s, 0.8, guitar, root + 12, 0.28 if s % 4 else 0.4, mute=True)
            t.drum(bar, 2, kick(), 0.6)
            t.drum(bar, 14, kick(), 0.6)
    melody(t, RUN_LEAD, lead, 0, 0.55)
    if layers >= 3:
        melody(t, RUN_LEAD, lead, 12, 0.18)
    return t.render()


BOSS_PROG = ["Em", "F", "Em", "B7", "Em", "F", "G", "B7"] * 2
BOSS_LEAD = [
    (0, 0, 2, "E5"), (0, 2, 1, "F5"), (0, 3, 1, "E5"), (0, 4, 4, "B4"), (0, 10, 2, "G5"), (0, 12, 2, "F5"), (0, 14, 2, "E5"),
    (1, 0, 2, "F5"), (1, 2, 1, "G5"), (1, 3, 1, "F5"), (1, 4, 4, "C5"), (1, 8, 4, "A5"), (1, 12, 4, "G5"),
    (2, 0, 2, "E5"), (2, 2, 1, "F5"), (2, 3, 1, "E5"), (2, 4, 4, "B5"), (2, 8, 2, "A5"), (2, 10, 2, "G5"), (2, 12, 4, "F5"),
    (3, 0, 2, "D#6"), (3, 2, 2, "E6"), (3, 4, 2, "D#6"), (3, 6, 2, "B5"), (3, 8, 2, "A5"), (3, 10, 2, "G5"), (3, 12, 2, "F#5"), (3, 14, 2, "D#5"),
    (4, 0, 2, "B5"), (4, 2, 1, "C6"), (4, 3, 1, "B5"), (4, 4, 4, "E5"), (4, 10, 2, "B5"), (4, 12, 2, "A5"), (4, 14, 2, "G5"),
    (5, 0, 2, "C6"), (5, 2, 1, "D6"), (5, 3, 1, "C6"), (5, 4, 4, "F5"), (5, 8, 4, "C6"), (5, 12, 4, "A5"),
    (6, 0, 4, "D6"), (6, 4, 2, "B5"), (6, 6, 2, "G5"), (6, 8, 4, "B5"), (6, 12, 4, "D6"),
    (7, 0, 2, "F#6"), (7, 2, 2, "D#6"), (7, 4, 2, "B5"), (7, 6, 2, "A5"), (7, 8, 4, "F#5"), (7, 12, 4, "D#5"),
]


def boss_theme(bpm=160):
    t = Track(16, bpm)
    for bar, chord in enumerate(BOSS_PROG):
        root, tones = CHORDS[chord]
        for s in range(16):  # chugging sixteenth-note bass
            off = 1 if (s == 14 and chord == "Em") else (12 if s in (3, 11) else 0)
            t.tone(bar, s, 0.9, slap_bass, root + off, 0.85 if s % 4 == 0 else 0.6)
            t.tone(bar, s, 0.8, guitar, root + 12, 0.3 if s % 4 else 0.45, mute=True)
        for step, ln in ((0, 1), (3, 1), (6, 1), (10, 2)):  # staccato brass stabs
            for iv in tones[:3]:
                t.tone(bar, step, ln, fm_brass, root + 24 + iv, 0.5)
        t.drum(bar, 0, kick(), 1.0)
        t.drum(bar, 2, kick(), 0.7)
        t.drum(bar, 6, kick(), 0.8)
        t.drum(bar, 8, kick(), 0.9)
        t.drum(bar, 10, kick(), 0.7)
        t.drum(bar, 4, snare(), 0.9)
        t.drum(bar, 12, snare(), 0.9)
        for s in range(0, 16):
            t.drum(bar, s, hat(s in (6, 14)), 0.4 if s % 2 == 0 else 0.25)
        if bar % 4 == 0:
            t.drum(bar, 0, crash(), 0.6)
        if bar % 4 == 3:
            for k, f in enumerate((230, 210, 190, 170, 150, 130, 110, 90)):
                t.drum(bar, 8 + k, tom(f), 0.85)
                if k % 2 == 0:
                    t.drum(bar, 8 + k, snare(), 0.5)
    melody(t, BOSS_LEAD, lead, 0, 0.6)
    melody(t, BOSS_LEAD, lead, 12, 0.35, bar_offset=8)
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
    melody(t, SHOP_LEAD, epiano, 12, 0.7)
    return t.render(0.2)


def continue_sting():
    """A tense 'continue?' sting: ticking clock, low drone, a falling diminished line, a heavy hit."""
    t = Track(1, 60)
    t.length = 4.2
    t.buf = [0.0] * (SR * 7)
    spb = 1.0
    ms.mix_into(t.buf, fm(hzm(28), 4.0, index=1.2, a=0.5, d=0.1, s=0.9, r=1.0, vol=0.6), 0, 0.9)
    for k in range(8):
        ms.mix_into(t.buf, tick(), k * 0.5, 0.9)
    for k, name in enumerate(["E5", "C5", "A#4", "F#4"]):
        ms.mix_into(t.buf, epiano(hzm(nm(name)), 0.8, 0.7), k * 0.6, 0.8)
    for name in ("E2", "B2", "F3"):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 1.6, 0.8), 2.6, 0.6)
    ms.mix_into(t.buf, crash(), 2.6, 0.5)
    ms.mix_into(t.buf, kick(), 2.6, 1.0)
    return reverb(t.buf[: int(SR * 5.5)], 0.25)


def round_win():
    t = Track(1, 60)
    t.buf = [0.0] * (SR * 5)
    for k, name in enumerate(["E5", "G5", "B5", "E6"]):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 0.25, 0.8), k * 0.13, 0.7)
    for name in ("E4", "G4", "B4", "E5"):
        ms.mix_into(t.buf, fm_brass(hzm(nm(name)), 1.4, 0.8), 0.55, 0.55)
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
    ms.mix_into(t.buf, guitar(hzm(nm("E2")), 2.0, vol=0.8), 1.5, 0.9)
    ms.mix_into(t.buf, crash(0.7), 1.5, 0.8)
    for k, f in enumerate((220, 180, 150, 120)):
        ms.mix_into(t.buf, tom(f), 1.0 + k * 0.1, 0.8)
    return reverb(t.buf[: int(SR * 4.8)], 0.22)


TRACKS = {
    "run_a": lambda: run_theme(1, 144),
    "run_b": lambda: run_theme(2, 150),
    "run_c": lambda: run_theme(3, 158),
    "boss": boss_theme,
    "shop": shop_theme,
    "game_over": continue_sting,
    "run_complete": round_win,
    "boss_defeated": ko_fanfare,
}
ONE_SHOT = ("game_over", "run_complete", "boss_defeated")


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
