#!/usr/bin/env python3
"""Cuts and levels the real recordings used by Last Stand. All of them are CC0 (public domain),
from OpenGameArt.org; see CREDITS in Story.swift and the list below.
Usage: python3 tools/import_zombie_sounds.py SOURCE_DIR   (SOURCE_DIR holds the downloaded packs)

  zombie-moans-01-by-emopreben, undead-moans, zombie-noises-and-moans  -> groans, snarls
  the-free-firearm-sound-library (1911, near)                          -> gunshots
  gun-reload-sounds (gunreload1)                                        -> reload
  2-wooden-squish-splatter-sequences                                    -> hits, bites
  42-snow-and-gravel-footsteps                                          -> zombie footsteps
  footsteps-0                                                           -> your footsteps
  bio-hazard-menustage, hunter-class-lifeform, the-end-dead-z-pandemic  -> music
"""
import os, subprocess, sys, glob
import numpy as np

SR = 44100
SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "StillHere", "Audio")


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def find(pattern):
    hits = sorted(glob.glob(os.path.join(SRC, "**", "*" + pattern), recursive=True))
    assert hits, pattern
    return hits[0]


def trim(x, thresh=0.02, pre=0.01, tail_fade=0.05):
    """cut leading and trailing silence"""
    e = np.abs(x) > thresh * np.max(np.abs(x))
    if not e.any(): return x
    a = max(np.argmax(e) - int(pre * SR), 0)
    b = len(x) - np.argmax(e[::-1])
    y = x[a:min(b + int(0.15 * SR), len(x))].copy()
    n = min(int(tail_fade * SR), len(y))
    y[-n:] *= np.linspace(1, 0, n)
    return y


def onsets(x, rel=0.3, gap=0.25):
    w = 441
    env = np.array([np.max(np.abs(x[i:i + w])) for i in range(0, len(x) - w, w)])
    out, last = [], -1e9
    for i in range(1, len(env)):
        if env[i] > rel * env.max() and env[i - 1] <= rel * env.max() and (i - last) * w / SR > gap:
            out.append(i * w / SR); last = i
    return out


def cut(x, start, dur, fade=0.03):
    y = x[int(start * SR):int((start + dur) * SR)].copy()
    n = int(fade * SR)
    y[-n:] *= np.linspace(1, 0, n)
    y[:64] *= np.linspace(0, 1, 64)
    return y


def save(name, x, peak=0.89, mono=True, bitrate="128k"):
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    p = subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-codec:a", "libmp3lame", "-b:a", bitrate,
                        os.path.join(OUT, name + ".mp3")], input=x.astype(np.float32).tobytes(), check=True)
    print(name, f"{len(x) / SR:.2f}s")


def music(name, path, seconds=None, lufs=-27):
    args = ["ffmpeg", "-y", "-v", "error", "-i", path]
    if seconds: args += ["-t", str(seconds), "-af", f"afade=t=out:st={seconds - 3}:d=3,loudnorm=I={lufs}:TP=-2"]
    else: args += ["-af", f"loudnorm=I={lufs}:TP=-2"]
    subprocess.run(args + ["-ar", str(SR), "-codec:a", "libmp3lame", "-b:a", "128k", os.path.join(OUT, name + ".mp3")], check=True)
    print(name)


if __name__ == "__main__":
    # groans and moans
    groans = [find("ZombieMoan1.wav"), find("ZombieMoan2.wav"), find("ZombieMoan3.wav"),
              find("undead-1.ogg"), find("undead-2.ogg"), find("undead-3.ogg"), find("undead-4.ogg"),
              find("zombienoise1.ogg"), find("zombienoise2.ogg")]
    for i, g in enumerate(groans):
        save(f"z_groan{i}", trim(load(g)))

    # a 1911 pistol, two different shots
    gun = load(find("A_42P.wav"))
    for i, t in enumerate(onsets(gun)[:2]):
        save(f"z_shot{i}", cut(gun, t - 0.005, 1.4, fade=0.4))

    save("z_reload", trim(load(find("gunreload1.wav"))))

    # hits: a wet impact, then the zombie's last noise
    splat = load(find("crack11.mp3.flac"))
    hits = onsets(splat, 0.4, 0.4)
    last = trim(load(find("zombienoise3.ogg")))
    for i, t in enumerate(hits[:2]):
        x = np.zeros(int(1.6 * SR))
        s = cut(splat, t - 0.005, 0.7, 0.2)
        x[:len(s)] += s
        x[int(0.15 * SR):int(0.15 * SR) + len(last)] += last * 0.8
        save(f"z_die{i}", x)

    # a bite: snarl, then the crunch
    snarl = trim(load(find("fastzombie1.ogg")))
    crunch_src = load(find("crack12.mp3.flac"))
    crunch = cut(crunch_src, onsets(crunch_src, 0.4)[0] - 0.005, 0.6, 0.2)
    x = np.zeros(int(1.2 * SR))
    x[:len(snarl)] += snarl
    at = int(0.25 * SR)
    x[at:at + len(crunch)] += crunch
    save("z_bite", x)

    # zombie footsteps: two dragging steps on gravel, slowed down
    snow = sorted(glob.glob(os.path.join(SRC, "**", "Corsica_S-Walking_on_snow_covered_gravel_*.flac"), recursive=True))
    for i in range(2):
        a, b = load(snow[i * 2]), load(snow[i * 2 + 1])
        x = np.zeros(int(1.5 * SR))
        for at, s in [(0.0, a), (0.7, b)]:
            s = np.interp(np.arange(0, len(s), 0.82), np.arange(len(s)), s)   # heavier, slower
            j = int(at * SR)
            x[j:j + len(s)] += s[:len(x) - j]
        save(f"z_shuffle{i}", x)

    # your own footsteps
    for i, f in enumerate(sorted(glob.glob(os.path.join(SRC, "**", "0?-footstep*.ogg"), recursive=True))[:6]):
        save(f"z_step{i}", trim(load(f)))

    # music
    music("m_zfight", find("biohazardsextended_0.ogg"))
    music("m_zfight2", find("hunter-class_lifeform_1.mp3"))
    music("m_zrest", find("the_end_piano_0.mp3"), seconds=95)
