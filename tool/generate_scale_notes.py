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
    'glockenspiel': (72, 1.2, lambda f: additive(
        f, 1.2, [(1, 1.0, 0.8), (2.76, 0.45, 0.25), (5.40, 0.25, 0.12), (8.93, 0.1, 0.06)], 0.001)),
    'musicbox': (72, 1.0, lambda f: additive(
        f, 1.0, [(1, 1.0, 0.55), (2, 0.25, 0.3), (3, 0.12, 0.2), (4.1, 0.06, 0.1)], 0.001, click=0.15)),
    'kalimba': (72, 0.9, lambda f: additive(
        f, 0.9, [(1, 1.0, 0.45), (2.0, 0.08, 0.2), (5.4, 0.18, 0.05)], 0.002, click=0.25)),
    'harp': (60, 1.2, lambda f: karplus(f, 1.2, damping=0.997, bright=0.4)),
    'koto': (60, 1.1, lambda f: karplus(f, 1.1, damping=0.995, bright=0.8, bend=0.35)),
    'soft': (72, 0.6, lambda f: additive(
        f, 0.6, [(1, 1.0, 0.22), (2, 0.12, 0.12)], 0.012)),
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
