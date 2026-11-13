#!/usr/bin/env python3
"""Records Last Stand's spoken lines with free, offline Piper voices (public domain / CC0 voice
models: Joe and Kristin from rhasspy/piper-voices). Writes StillHere/Audio/zv_<voice>_<key>.mp3.
Usage: python3 tools/make_voices.py MODELS_DIR   (needs piper-tts, numpy, ffmpeg)"""
import io, json, os, subprocess, sys, wave
import numpy as np
from piper import PiperVoice
from piper.config import SynthesisConfig

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "StillHere", "Audio")
PHRASES = json.load(open(os.path.join(HERE, "zvoice_phrases.json")))
# (Norman was tried and dropped: on single words it adds stray sounds after a long gap)
VOICES = {"joe": "en_US-joe-medium", "kristin": "en_US-kristin-medium"}
SR = 44100


def loud_db(x):
    w = 2205
    r = np.array([np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, max(len(x) - w, 1), w)])
    r = np.sort(r)[::-1][:max(1, int(len(r) * 0.3))]
    return 20 * np.log10(np.mean(r) + 1e-12)


def render(voice, text, speed):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        voice.synthesize_wav(text, w, syn_config=SynthesisConfig(length_scale=speed))
    buf.seek(0)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", "-", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], input=buf.read(), capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    # trim the silence around it, so joined words follow each other quickly
    on = np.abs(x) > 0.02 * np.max(np.abs(x))
    a, b = max(np.argmax(on) - int(0.01 * SR), 0), len(x) - np.argmax(on[::-1]) + int(0.04 * SR)
    x = x[a:min(b, len(x))]
    x = x * 10 ** ((-16.0 - loud_db(x)) / 20)          # every clip at the same loudness
    pk = np.max(np.abs(x))
    if pk > 0.97: x = 0.97 * np.tanh(x / 0.97)
    return x


if __name__ == "__main__":
    models = sys.argv[1]
    for name, model in VOICES.items():
        v = PiperVoice.load(os.path.join(models, model + ".onnx"))
        for key, text in PHRASES.items():
            x = render(v, text, 0.85)                       # a little quicker than normal, like a callout
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-codec:a", "libmp3lame", "-b:a", "64k",
                            os.path.join(OUT, f"zv_{name}_{key}.mp3")], input=x.astype(np.float32).tobytes(), check=True)
        print(name, len(PHRASES), "clips")
