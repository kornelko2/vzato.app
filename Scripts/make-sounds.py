#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Synthesizes Vzato's notification sounds (no third-party audio, no licence questions).

    python3 Scripts/make-sounds.py   # writes Vzato/Resources/Sounds/*.caf (needs macOS afconvert)
"""
import math, os, struct, subprocess, tempfile, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Vzato", "Resources", "Sounds")

def bell(freq, start, length, volume=0.5, decay=3.2):
    """A struck-bell tone: fundamental plus soft inharmonic partials, exponential decay."""
    partials = [(1.0, 1.0), (2.01, 0.35), (2.76, 0.18), (5.4, 0.06)]
    for i in range(int(length * RATE)):
        t = i / RATE
        attack = min(1.0, t / 0.006)
        env = attack * math.exp(-decay * t)
        sample = sum(a * math.sin(2 * math.pi * freq * m * t) for m, a in partials)
        yield start + i, volume * env * sample / 1.6

def render(name, notes, total):
    buf = [0.0] * int(total * RATE)
    for freq, start, length, volume, decay in notes:
        for index, value in bell(freq, int(start * RATE), length, volume, decay):
            if index < len(buf):
                buf[index] += value
    peak = max(abs(v) for v in buf) or 1
    frames = b"".join(struct.pack("<h", int(32000 * v / peak * 0.9)) for v in buf)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "s.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(frames)
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", path, os.path.join(OUT, name)], check=True)
    print("wrote", name)

os.makedirs(OUT, exist_ok=True)
# Dose: a clear rising two-tone chime, twice, so it is noticed (about 2.6 s).
render("vzato-dose.caf", [
    (880.0, 0.00, 1.2, 0.6, 3.0), (1318.5, 0.18, 1.2, 0.6, 3.0),
    (880.0, 1.10, 1.2, 0.6, 3.0), (1318.5, 1.28, 1.4, 0.6, 2.6),
], 2.7)
# Meal: a soft, low, three-note ascending melody (C5 E5 G5), clearly different (about 2 s).
render("vzato-meal.caf", [
    (523.25, 0.00, 1.0, 0.45, 4.0), (659.25, 0.30, 1.0, 0.45, 4.0), (783.99, 0.60, 1.4, 0.5, 3.0),
], 2.0)
