#!/usr/bin/env python3
"""Makes the Last Stand dry-fire click from scratch and writes them as mp3 files.
Usage: python3 tools/zombie_sounds.py   (needs numpy, scipy and ffmpeg)"""
import os, subprocess, tempfile, wave
import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "StillHere", "Audio")
rng = np.random.default_rng(7)


def t(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def bp(x, lo, hi, order=2): return signal.sosfilt(signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)
def lp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, "lowpass", fs=SR, output="sos"), x)
def hp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, "highpass", fs=SR, output="sos"), x)
def env_exp(d, tau): return np.exp(-t(d) / tau)
def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def smooth_rand(d, rate, amount):
    """slowly wandering value around 0"""
    n = max(int(d * rate) + 2, 3)
    pts = rng.normal(0, amount, n)
    return np.interp(t(d), np.linspace(0, d, n), pts)


def voice(d, f0s, vowels, rough=0.5, breath=0.3, fry=0.0):
    """A throat: a pulse train whose pitch follows f0s (start..end), shaped by vowel formants."""
    tt = t(d)
    f0 = np.interp(tt, np.linspace(0, d, len(f0s)), f0s) * (1 + smooth_rand(d, 6, 0.04)) * (1 + rng.normal(0, 0.02, len(tt)))
    phase = np.cumsum(f0 / SR)
    src = 2 * (phase % 1) - 1                                   # sawtooth
    src *= 1 + rough * np.sin(2 * np.pi * phase * 0.5)          # subharmonic growl
    src *= 1 + smooth_rand(d, 25, 0.35 * rough)                 # shimmer
    if fry:
        clicks = (rng.random(len(tt)) < fry * 40 / SR).astype(float)
        src += lp(clicks, 1200) * 30
    src += noise(d) * breath
    # each vowel filters the whole sound; the result glides from one vowel to the next
    shaped = [sum(bp(src, f * 0.85, f * 1.15) * g for f, g in v) for v in vowels]
    if len(shaped) == 1: return shaped[0]
    pos = np.linspace(0, len(shaped) - 1, len(tt))
    out = np.zeros_like(tt)
    for i, y in enumerate(shaped):
        out += y * np.clip(1 - np.abs(pos - i), 0, 1)
    return out


UH = [(550, 1.0), (1000, 0.6), (2400, 0.25)]
AH = [(750, 1.0), (1200, 0.55), (2600, 0.2)]
OH = [(450, 1.0), (800, 0.6), (2500, 0.15)]
ER = [(500, 1.0), (1350, 0.5), (1700, 0.4)]


def swell(d, attack=0.35, release=0.6):
    tt = t(d)
    return np.minimum(1, tt / attack) * np.minimum(1, (d - tt) / release) ** 1.5


def normalize(x, peak=0.89):
    x = x - np.mean(x)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    x = normalize(x)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-codec:a", "libmp3lame", "-b:a", "128k", os.path.join(OUT, name + ".mp3")], check=True)
    os.unlink(path)
    print(name, f"{len(x) / SR:.2f}s")


def groan(seed, d, f0a, f0b, vowels):
    global rng
    rng = np.random.default_rng(seed)
    v = voice(d, [f0a, f0a * 1.08, f0b], vowels, rough=0.7, breath=0.45, fry=0.6)
    # wet throat: a gurgle under it
    gurgle = bp(noise(d), 150, 600) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(9 + smooth_rand(d, 4, 4)) / SR)) * 0.25
    return np.tanh((v + gurgle) * 1.4) * swell(d, 0.45, 0.8)


def shuffle(seed):
    global rng
    rng = np.random.default_rng(seed)
    d = 1.5
    out = np.zeros(int(d * SR))
    for at, scale in [(0.05, 1.0), (0.75, 0.85)]:
        drag = bp(noise(0.45), 250, 2200) * np.sin(np.pi * np.linspace(0, 1, int(0.45 * SR))) ** 2 * 0.5
        grit = (rng.random(int(0.45 * SR)) < 0.004) * rng.uniform(-1, 1, int(0.45 * SR))
        grit = bp(grit, 1500, 6000) * 1.0
        place(out, (drag + grit * np.linspace(1, 0.2, len(grit))) * scale, at)
        thump = lp(noise(0.12), 180) * env_exp(0.12, 0.03) * 2.5
        place(out, thump * scale, at + 0.36)
    return out


def gunshot():
    d = 1.1
    out = np.zeros(int(d * SR))
    crack = hp(noise(0.02), 1500) * env_exp(0.02, 0.003) * 3
    body = lp(noise(0.25), 2500) * env_exp(0.25, 0.04) * 1.6
    thump = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 38, int(0.2 * SR))) / SR) * env_exp(0.2, 0.05) * 1.4
    tail = lp(noise(1.0), 900) * env_exp(1.0, 0.25) * 0.18
    place(out, crack, 0); place(out, body, 0.001); place(out, thump, 0); place(out, tail, 0.03)
    return np.tanh(out * 1.6)


def click(f=3500, dur=0.006, g=1.0):
    return bp(noise(dur), f * 0.6, min(f * 1.6, 18000)) * env_exp(dur, dur / 4) * g


def dryfire():
    out = np.zeros(int(0.25 * SR))
    place(out, click(4000, 0.008, 1), 0.0)
    place(out, click(2200, 0.012, 0.7), 0.028)
    return out


def scrape(d, lo=800, hi=5000, g=0.4):
    return bp(noise(d), lo, hi) * np.sin(np.pi * np.linspace(0, 1, int(d * SR))) * g


def reload_():
    out = np.zeros(int(1.5 * SR))
    place(out, click(3000, 0.01, 0.9), 0.00)            # release button
    place(out, scrape(0.08), 0.03)                      # magazine slides out
    place(out, lp(noise(0.15), 400) * env_exp(0.15, 0.03) * 1.5, 0.35)  # magazine drops
    place(out, click(1500, 0.02, 0.6), 0.35)
    place(out, scrape(0.12, 600, 4000, 0.45), 0.62)     # new one goes in
    place(out, click(2500, 0.015, 1.4), 0.75)           # seats
    place(out, lp(noise(0.05), 600) * env_exp(0.05, 0.01), 0.75)
    place(out, scrape(0.09, 900, 6000, 0.5), 1.05)      # slide back
    place(out, click(3200, 0.012, 1.3), 1.15)           # slide forward
    place(out, click(1800, 0.02, 0.9), 1.152)
    return out


def die(seed):
    global rng
    rng = np.random.default_rng(seed)
    d = 1.9
    out = np.zeros(int(d * SR))
    shriek = voice(0.55, [210, 230, 110], [AH, ER], rough=0.9, breath=0.5, fry=0.4) * swell(0.55, 0.03, 0.3)
    place(out, np.tanh(shriek * 2.5) * 0.9, 0.0)
    wet = bp(noise(0.25), 200, 1500) * env_exp(0.25, 0.05) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t(0.25))) * 1.2
    place(out, wet, 0.02)
    gasp = voice(0.5, [95, 70], [UH], rough=0.8, breath=0.8) * swell(0.5, 0.05, 0.4) * 0.5
    place(out, gasp, 0.6)
    for at, g in [(1.15, 1.0), (1.32, 0.5)]:
        thud = lp(noise(0.35), 220) * env_exp(0.35, 0.07) * 2.2 * g
        thud += np.sin(2 * np.pi * np.cumsum(np.linspace(70, 40, int(0.35 * SR))) / SR) * env_exp(0.35, 0.08) * 0.8 * g
        place(out, thud, at)
    return out


def bite():
    global rng
    rng = np.random.default_rng(99)
    d = 1.6
    out = np.zeros(int(d * SR))
    snarl = voice(0.6, [130, 160, 120], [AH, ER], rough=1.0, breath=0.7, fry=0.8) * swell(0.6, 0.05, 0.2)
    place(out, np.tanh(snarl * 3) * 0.8, 0.0)
    for at in [0.42, 0.55]:
        place(out, click(3000, 0.01, 2.2), at)          # teeth
    squelch = bp(noise(0.3), 300, 2000) * env_exp(0.3, 0.06) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 31 * t(0.3)))) * 1.3
    place(out, squelch, 0.58)
    grunt = voice(0.4, [150, 175, 120], [UH, AH], rough=0.15, breath=0.4) * swell(0.4, 0.03, 0.25) * 0.9
    place(out, grunt, 0.72)
    return out


if __name__ == "__main__":
    # The other Last Stand sounds are real recordings now (tools/import_zombie_sounds.py).
    save("z_click", dryfire())
