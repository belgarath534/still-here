#!/usr/bin/env python3
"""Cuts and levels Stranded's island sounds. All CC0 from OpenGameArt.org (credited in Credits):
sea and river waves (RandomMind), beach ocean waves and sand footsteps (qubodup), seagulls (Rango Mango),
splashes and sand (Peludo), crickets (Wolfgang_), night bird and frog (Aj_), fireplace (PagDev),
woodcutting (fvcalderan), ship sinking (Thimras), water (rubberduck).
Usage: python3 tools/import_island_sounds.py SOURCE_DIR"""
import os, subprocess, sys, glob
import numpy as np

SR = 44100
SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "StillHere", "Audio")


def find(name):
    hits = sorted(h for h in glob.glob(os.path.join(SRC, "**", name), recursive=True) if "/flac/" not in h)
    assert hits, name
    return hits[0]


def load(name, start=0.0, dur=None):
    args = ["ffmpeg", "-v", "error", "-ss", str(start)] + (["-t", str(dur)] if dur else []) + ["-i", find(name), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(args, capture_output=True, check=True).stdout, np.float32).astype(np.float64)


def loud_db(x):
    w = 2205
    r = np.array([np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, max(len(x) - w, 1), w)])
    r = np.sort(r)[::-1][:max(1, int(len(r) * 0.3))]
    return 20 * np.log10(np.mean(r) + 1e-12)


def trim(x, thresh=0.02, tail=0.1):
    on = np.abs(x) > thresh * np.max(np.abs(x))
    a = max(np.argmax(on) - int(0.005 * SR), 0)
    b = min(len(x) - np.argmax(on[::-1]) + int(tail * SR), len(x))
    y = x[a:b].copy(); n = min(int(0.03 * SR), len(y) // 4); y[-n:] *= np.linspace(1, 0, n)
    return y


def seamless(x, fade=2.0):
    """a loop with no click: the end crossfades into the start"""
    n = int(fade * SR)
    body, tail = x[:-n].copy(), x[-n:]
    k = np.linspace(0, 1, n)
    body[:n] = body[:n] * k + tail * (1 - k)
    return body


def save(name, x, target):
    x = x - np.mean(x)
    for _ in range(6):
        x = x * 10 ** ((target - loud_db(x)) / 20)
        if np.max(np.abs(x)) > 0.97: x = 0.97 * np.tanh(x / 0.97)
        if abs(loud_db(x) - target) < 0.5: break
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-codec:a", "libmp3lame", "-b:a", "96k",
                    os.path.join(OUT, name + ".mp3")], input=x.astype(np.float32).tobytes(), check=True)
    print(name, f"{len(x) / SR:.1f}s")


BED, FX = -22.0, -16.0
if __name__ == "__main__":
    save("st_ocean", seamless(load("VistulaShort_0.mp3", 20, 62)), BED)
    save("st_crickets", seamless(load("crickets_1.mp3"), 1.0), BED)
    save("st_fire", seamless(load("fire.wav"), 1.5), BED)
    for i in range(4): save(f"st_wave{i}", trim(load(f"wave_0{i + 1}_cc0-18363__jasinski__alkaibeach.flac")), FX)
    for i in range(6): save(f"st_gull{i}", trim(load(f"Seagull_Ambient_{i + 1}.wav")), FX)
    for i, n in enumerate(["SandL1", "SandR1", "SandL2", "SandR2", "SandL3", "SandR3"]): save(f"st_sand{i}", trim(load(f"Fantozzi-{n}.ogg")), FX)
    save("st_splash0", trim(load("splash1_0.wav")), FX)
    save("st_splash1", trim(load("splash2_0.wav")), FX)
    save("st_wade", trim(load("water_splash-04.flac")), FX)
    save("st_drink", trim(load("loop_water_01.ogg")), FX)
    save("st_chop", trim(load("woodcutting_0.ogg")), FX)
    save("st_sink", trim(load("ship_destroyed_0.ogg")), FX)
    save("st_drown", trim(load("drowning_0.wav")), FX)
    save("st_nightbird", trim(load("birdNight.wav")), FX)
    save("st_frog", trim(load("frog.wav")), FX)
