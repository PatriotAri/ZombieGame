#!/usr/bin/env python3
"""Synthesizes the placeholder sound effects in midwest-undead/assets/audio/.

They're crude on purpose: just enough to hear every event in game while the
real sounds are sourced. Replace any file with a real recording of the same
name (see core/sound.gd for how names and numbered variants work).

Standard library only. Run from anywhere:
    python3 tools/make_placeholder_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "midwest-undead", "assets", "audio")
random.seed(1979)


# --- Building blocks ----------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def tone(seconds, freq_start, freq_end=None, shape="sine", vibrato=0.0, vibrato_hz=6.0):
    """A pitched tone that glides from freq_start to freq_end."""
    freq_end = freq_start if freq_end is None else freq_end
    out, phase, n = [], 0.0, int(seconds * RATE)
    for i in range(n):
        t = i / max(n - 1, 1)
        f = freq_start + (freq_end - freq_start) * t
        f *= 1.0 + vibrato * math.sin(2 * math.pi * vibrato_hz * i / RATE)
        phase += f / RATE
        p = phase % 1.0
        if shape == "saw":
            out.append(2.0 * p - 1.0)
        elif shape == "square":
            out.append(1.0 if p < 0.5 else -1.0)
        else:
            out.append(math.sin(2 * math.pi * p))
    return out


def lowpass(samples, cutoff):
    """One-pole low-pass filter: keeps rumble, drops hiss."""
    a = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def envelope(samples, attack=0.005, decay_power=2.0):
    """Fast fade-in, then a curved fade-out to silence at the end."""
    n = len(samples)
    a = max(int(attack * RATE), 1)
    out = []
    for i, x in enumerate(samples):
        gain = i / a if i < a else (1.0 - (i - a) / max(n - a, 1)) ** decay_power
        out.append(x * gain)
    return out


def swell(samples):
    """Fades in then out (a whoosh)."""
    n = len(samples)
    return [x * math.sin(math.pi * i / n) for i, x in enumerate(samples)]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def gain(samples, g):
    return [x * g for x in samples]


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def normalize(samples, peak=0.9):
    top = max((abs(x) for x in samples), default=0.0) or 1.0
    return [x * peak / top for x in samples]


def write(name, samples, peak=0.9):
    samples = normalize(samples, peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in samples))
    print("wrote", os.path.relpath(path))


# --- Recipes ----------------------------------------------------------------------

def thud(seconds, cutoff, pitch):
    """A soft impact: filtered noise plus a falling low tone."""
    return mix(envelope(lowpass(noise(seconds), cutoff), 0.002, 3.0),
               gain(envelope(tone(seconds, pitch, pitch * 0.5), 0.002, 3.0), 0.8))


def click(seconds=0.025, cutoff=3000):
    return envelope(highpass(noise(seconds), cutoff), 0.0005, 4.0)


def growl(seconds, f0, f1, roughness=0.35):
    """A zombie voice: a buzzy low saw with wobble and breath noise, muffled."""
    voice = tone(seconds, f0, f1, "saw", vibrato=0.06, vibrato_hz=random.uniform(4.0, 9.0))
    breath = lowpass(noise(seconds), 900)
    raw = mix(voice, gain(breath, roughness))
    # Amplitude flutter makes it gargle.
    flutter = [0.6 + 0.4 * math.sin(2 * math.pi * random.uniform(9, 15) * i / RATE) for i in range(len(raw))]
    return swell(lowpass([x * f for x, f in zip(raw, flutter)], 1100))


def main():
    os.makedirs(OUT, exist_ok=True)

    # Player
    for i in range(1, 4):
        write("footstep_%d" % i, thud(0.09, random.uniform(500, 800), random.uniform(70, 95)), 0.6)
    write("gunshot", mix(envelope(noise(0.35), 0.0005, 5.0),
                         gain(envelope(lowpass(noise(0.5), 300), 0.001, 2.5), 2.0),
                         gain(envelope(tone(0.3, 120, 40), 0.001, 3.0), 1.2)))
    write("dry_fire", click(0.02, 4000), 0.5)
    write("reload", concat(click(0.03, 2500), silence(0.35), click(0.03, 2000), silence(0.25),
                           gain(click(0.05, 1500), 1.3)), 0.6)
    write("melee_swing", swell(highpass(lowpass(noise(0.22), 2500), 600)), 0.5)
    write("melee_hit", thud(0.16, 900, 110))
    write("pickup", envelope(tone(0.08, 700, 1100, "square"), 0.002, 2.0), 0.35)
    write("rummage", concat(*[concat(envelope(lowpass(noise(random.uniform(0.04, 0.09)), random.uniform(1500, 4000)), 0.002, 2.0),
                                     silence(random.uniform(0.02, 0.08))) for _ in range(8)]), 0.6)
    write("eat", concat(*[concat(envelope(highpass(noise(0.05), 1200), 0.002, 3.0), silence(0.12)) for _ in range(5)]), 0.5)
    write("bandage", concat(swell(highpass(noise(0.35), 1500)), silence(0.1), swell(highpass(noise(0.25), 1800))), 0.5)
    write("flashlight_click", concat(click(0.015, 3500), silence(0.03), click(0.012, 2500)), 0.5)
    write("battery_swap", concat(click(0.03, 2000), silence(0.2), click(0.04, 1500)), 0.5)
    write("player_hurt", swell(lowpass(tone(0.25, 220, 150, "saw", vibrato=0.04), 1200)), 0.6)
    write("stomach_growl", swell(lowpass(mix(tone(1.0, 70, 55, "saw", vibrato=0.25, vibrato_hz=3.0),
                                             gain(lowpass(noise(1.0), 200), 0.5)), 400)), 0.6)

    # Zombies
    for i in range(1, 4):
        write("zombie_groan_%d" % i, growl(random.uniform(0.9, 1.5), random.uniform(80, 110), random.uniform(60, 85)), 0.7)
    write("zombie_alert", growl(0.8, 120, 180, roughness=0.6))
    write("zombie_hit", thud(0.14, 600, 90))
    write("zombie_death", growl(1.4, 110, 45, roughness=0.5))

    # Doors and the gate
    write("door_open", lowpass(swell(tone(0.5, 300, 520, "saw", vibrato=0.08, vibrato_hz=22.0)), 1500), 0.4)
    write("door_close", thud(0.2, 700, 80))
    write("door_bash", mix(thud(0.3, 500, 60), gain(envelope(highpass(noise(0.12), 2000), 0.001, 4.0), 0.3)))
    write("door_break", mix(thud(0.6, 800, 55), gain(envelope(highpass(noise(0.5), 1500), 0.001, 1.5), 0.8)))
    write("gate_slide", swell(mix(lowpass(noise(1.0), 250),
                                  gain(tone(1.0, 180, 200, "square", vibrato=0.02, vibrato_hz=13.0), 0.15))), 0.6)

    # Guards and bandits
    write("rifle_shot", mix(envelope(noise(0.5), 0.0005, 4.0),
                            gain(envelope(lowpass(noise(0.7), 250), 0.001, 2.0), 2.5)))


if __name__ == "__main__":
    main()
