"""Synthesize 7 instruments x 15 notes (C major, two octaves) as 16-bit mono WAV.

usage: python3 -I tool/generate_scale_notes.py <out_dir>
then convert each WAV to AAC: afconvert -f m4af -d aac -b 64000 in.wav out.m4a
(the app reads assets/sounds/scale/<instrument>/NN.m4a)
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
# 折り返し雑音を避けるため、これより高い倍音は作らない。
NYQUIST_SAFE = 18000
OUT = sys.argv[1]

# C major, two octaves: C D E F G A B C D E F G A B C (semitones from C)
STEPS = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24]


def freq(base_midi, step):
    return 440.0 * 2 ** ((base_midi + step - 69) / 12)


def env(t, attack, decay):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)


def additive(f, dur, partials, attack=0.003, click=0.0):
    """partials: list of (ratio, amp, decay_seconds)."""
    n = int(SR * dur)
    out = []
    rnd = random.Random(1)
    for i in range(n):
        t = i / SR
        s = 0.0
        for ratio, amp, dec in partials:
            s += amp * math.sin(2 * math.pi * f * ratio * t) * env(t, attack, dec)
        if click and t < 0.004:
            s += click * (rnd.random() * 2 - 1) * (1 - t / 0.004)
        out.append(s)
    return out


def karplus(f, dur, damping=0.996, bright=0.5, bend=0.0):
    """Plucked string. bend: initial pitch offset in semitones that settles quickly."""
    n = int(SR * dur)
    period = SR / f
    size = int(period) + 2
    rnd = random.Random(int(f))
    buf = [rnd.random() * 2 - 1 for _ in range(size)]
    # soften the excitation (less bright -> rounder tone)
    for _ in range(int((1 - bright) * 4)):
        buf = [(buf[i] + buf[i - 1]) / 2 for i in range(size)]
    out = []
    pos = 0.0
    for i in range(n):
        t = i / SR
        p = period / (2 ** ((bend * math.exp(-t / 0.05)) / 12))
        idx = int(pos) % size
        nxt = (idx + 1) % size
        s = buf[idx]
        out.append(s)
        buf[idx] = damping * 0.5 * (buf[idx] + buf[nxt])
        pos += size / p
    # gentle fade-in to avoid click, natural decay already present
    return [s * min(1.0, i / (SR * 0.002)) for i, s in enumerate(out)]


def music_box(f, dur):
    """Metal comb tine: high, bright, two slightly detuned tines (shimmer), click."""
    n = int(SR * dur)
    rnd = random.Random(int(f))
    out = []
    for i in range(n):
        t = i / SR
        detune = 2 ** (4 / 1200)  # +4 cents: slow beating like a real comb
        s = (
            math.sin(2 * math.pi * f * t) * env(t, 0.0008, 0.9)
            + 0.8 * math.sin(2 * math.pi * f * detune * t) * env(t, 0.0008, 0.9)
            + (0.35 * math.sin(2 * math.pi * f * 4.2 * t) * env(t, 0.0005, 0.06)
               if f * 4.2 < NYQUIST_SAFE else 0.0)
            + (0.18 * math.sin(2 * math.pi * f * 9.8 * t) * env(t, 0.0005, 0.02)
               if f * 9.8 < NYQUIST_SAFE else 0.0)
        )
        if t < 0.003:
            s += 0.6 * (rnd.random() * 2 - 1) * (1 - t / 0.003)
        out.append(s)
    return out


def koto(f, dur):
    """Plucked silk string: many harmonics, pitch drops into place, slow 'yuri' vibrato."""
    n = int(SR * dur)
    rnd = random.Random(int(f) + 3)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        bend = 2 ** ((70 * math.exp(-t / 0.035)) / 1200)  # starts ~70 cents high
        yuri = 1 + 0.006 * math.sin(2 * math.pi * 5.5 * t) * min(1.0, max(0.0, (t - 0.25) / 0.2))
        phase += 2 * math.pi * f * bend * yuri / SR
        s = 0.0
        for k in range(1, 11):
            if f * k >= NYQUIST_SAFE:
                break
            # odd/even mix with a nasal bump around the 3rd-5th harmonics
            amp = (1 / k ** 0.75) * (1.6 if k in (3, 4, 5) else 1.0)
            s += amp * math.sin(phase * k) * math.exp(-t * (1.6 + 0.9 * k))
        if t < 0.006:
            s += 0.5 * (rnd.random() * 2 - 1) * (1 - t / 0.006)
        out.append(s)
    return out


def soft_tone(f, dur):
    """Gentle electronic swell: near-pure sine that rises softly and fades slowly."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        a = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / 0.12))  # 120 ms swell
        r = math.exp(-max(0.0, t - 0.15) / 0.35)
        s = math.sin(2 * math.pi * f * t) + 0.06 * math.sin(2 * math.pi * f * 2 * t)
        out.append(s * a * r)
    return out


def finish(samples, dur, peak=0.45):
    n = int(SR * dur)
    samples = samples[:n]
    fade = int(SR * 0.08)
    for i in range(fade):
        samples[n - fade + i] *= 1 - i / fade
    m = max(abs(s) for s in samples) or 1.0
    return [s / m * peak for s in samples]


INSTRUMENTS = {
    # name: (base midi of the lowest C, duration, builder)
    'marimba': (72, 0.9, lambda f: additive(
        f, 0.9, [(1, 1.0, 0.35), (3.93, 0.35, 0.08), (9.2, 0.08, 0.03)], 0.002)),
    'musicbox': (84, 1.0, lambda f: music_box(f, 1.0)),
    'harp': (60, 1.2, lambda f: karplus(f, 1.2, damping=0.997, bright=0.4)),
    'koto': (72, 1.1, lambda f: koto(f, 1.1)),
    'soft': (72, 0.8, lambda f: soft_tone(f, 0.8)),
}


def write(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))


for name, (base, dur, build) in INSTRUMENTS.items():
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    for i, step in enumerate(STEPS):
        write(os.path.join(d, f'{i:02d}.wav'), finish(build(freq(base, step)), dur))
    print(name, 'ok')

# パチンコ風（assets/sounds/scale/pachinko/）は提供素材の free_sound*.mp3 を使うので、ここでは作らない。
