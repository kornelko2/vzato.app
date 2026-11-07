#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Synthesizes Vzato's notification sounds (no third-party audio, no licence questions).

    python3 Scripts/make-sounds.py   # writes Vzato/Resources/Sounds/*.caf (needs macOS afconvert)

Medication reminders are meant to get attention; "you can eat now" sounds are meant to be gentle.
Keep the file names in sync with `ReminderSound` in Vzato/App/AppSettings.swift.
"""
import math, os, random, struct, subprocess, tempfile, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Vzato", "Resources", "Sounds")

# Timbres: (frequency multiple, amplitude) partials, attack seconds, decay rate, vibrato
TIMBRES = {
    "bell":    ([(1.0, 1.0), (2.01, 0.35), (2.76, 0.18), (5.4, 0.06)], 0.006, 3.2, 0.0),
    "glock":   ([(1.0, 1.0), (2.76, 0.4), (5.4, 0.2), (8.93, 0.08)], 0.003, 4.5, 0.0),
    "marimba": ([(1.0, 1.0), (3.93, 0.25), (9.2, 0.05)], 0.004, 7.0, 0.0),
    "beep":    ([(1.0, 1.0), (2.0, 0.12), (3.0, 0.05)], 0.010, 2.0, 0.0),
    "pluck":   ([(1.0, 1.0), (2.0, 0.5), (3.0, 0.3), (4.0, 0.15), (5.0, 0.08)], 0.002, 5.5, 0.0),
    "flute":   ([(1.0, 1.0), (2.0, 0.18), (3.0, 0.06)], 0.12, 1.1, 5.0),
    "gong":    ([(1.0, 1.0), (1.48, 0.6), (2.1, 0.45), (2.9, 0.3), (4.2, 0.15)], 0.02, 1.0, 0.0),
}

def tone(timbre, freq, length, volume, decay=None):
    partials, attack, default_decay, vibrato = TIMBRES[timbre]
    decay = default_decay if decay is None else decay
    n = int(length * RATE)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        if timbre in ("beep", "flute"):
            env *= min(1.0, (length - t) / 0.05)   # soft release, no click
        wobble = 1 + (0.004 * math.sin(2 * math.pi * vibrato * t) if vibrato else 0)
        yield i, volume * env * sum(a * math.sin(2 * math.pi * freq * m * wobble * t) for m, a in partials)

def render(name, notes, total):
    """notes: (timbre, frequency Hz, start s, length s, volume[, decay])"""
    buf = [0.0] * int(total * RATE)
    for note in notes:
        timbre, freq, start, length, volume, *rest = note
        offset = int(start * RATE)
        for i, value in tone(timbre, freq, length, volume, rest[0] if rest else None):
            if offset + i < len(buf):
                buf[offset + i] += value
    peak = max(abs(v) for v in buf) or 1
    frames = b"".join(struct.pack("<h", int(32000 * v / peak * 0.9)) for v in buf)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "s.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(frames)
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", path, os.path.join(OUT, name)], check=True)
    print("wrote", name)

C5, D5, E5, F5, G5, A5, B5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77
C6, E6, G6, C4, G4, A4 = 1046.5, 1318.5, 1567.98, 261.63, 392.0, 440.0

os.makedirs(OUT, exist_ok=True)

# --- Medication reminders: clear, get attention, about 2–3 s -----------------------------------
render("vzato-dose.caf", [  # Chime: rising two-tone bell, twice (the original)
    ("bell", A5, 0.00, 1.2, 0.6, 3.0), ("bell", E6, 0.18, 1.2, 0.6, 3.0),
    ("bell", A5, 1.10, 1.2, 0.6, 3.0), ("bell", E6, 1.28, 1.4, 0.6, 2.6)], 2.7)
render("vzato-dose-twotone.caf", [  # Two-tone: high-low marimba, three times
    *[("marimba", note, i * 0.22, 0.6, 0.7) for i, note in enumerate([B5, G5, B5, G5, B5, G5])]], 2.0)
render("vzato-dose-glock.caf", [  # Glockenspiel: fast rising run, twice
    *[("glock", note, i * 0.11, 1.0, 0.55) for i, note in enumerate([C6, E6, G6])],
    *[("glock", note, 1.0 + i * 0.11, 1.2, 0.55) for i, note in enumerate([C6, E6, G6, 2 * C6])]], 2.6)
render("vzato-dose-alert.caf", [  # Alert: three firm beeps, twice
    *[("beep", C6, t, 0.16, 0.6) for t in (0.0, 0.25, 0.5, 1.2, 1.45, 1.7)]], 2.1)
render("vzato-dose-droplets.caf", [  # Droplets: falling plucked notes
    *[("pluck", note, i * 0.16, 0.8, 0.6) for i, note in enumerate([2 * C6, G6, E6, C6, G6, E6, C6])]], 2.1)
render("vzato-dose-dingdong.caf", [  # Ding-dong: doorbell, twice
    ("bell", E5 * 2, 0.0, 1.0, 0.7, 2.4), ("bell", C5 * 2, 0.45, 1.3, 0.7, 2.0),
    ("bell", E5 * 2, 1.4, 1.0, 0.7, 2.4), ("bell", C5 * 2, 1.85, 1.3, 0.7, 2.0)], 3.0)

# --- "You can eat now": gentle, lower, unmistakably different ----------------------------------
render("vzato-meal.caf", [  # Soft melody: C E G bell (the original)
    ("bell", C5, 0.00, 1.0, 0.45, 4.0), ("bell", E5, 0.30, 1.0, 0.45, 4.0), ("bell", G5, 0.60, 1.4, 0.5, 3.0)], 2.0)
render("vzato-meal-marimba.caf", [  # Marimba: C E G C
    *[("marimba", note, i * 0.24, 0.9, 0.6) for i, note in enumerate([C5, E5, G5, C6])]], 1.9)
render("vzato-meal-harp.caf", [  # Harp: slow arpeggio up
    *[("pluck", note, i * 0.13, 1.4, 0.45, 3.0) for i, note in enumerate([C4, 329.63, G4, C5, E5, G5])]], 2.3)
render("vzato-meal-flute.caf", [  # Flute: two calm long notes
    ("flute", G5, 0.0, 0.9, 0.5), ("flute", C6, 0.85, 1.2, 0.5)], 2.2)
render("vzato-meal-gong.caf", [  # Gong: one low, warm stroke
    ("gong", 196.0, 0.0, 2.8, 0.8, 1.3)], 2.9)
render("vzato-meal-bell.caf", [  # Meal bell: small hand bell, three quick rings
    *[("glock", A5, t, 0.9, 0.5, 5.0) for t in (0.0, 0.28, 0.56)]], 1.8)
