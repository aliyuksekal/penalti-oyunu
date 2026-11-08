"""Kullanıcının verdiği gerçek Ford kamyon kaydından (ara gaz) oyun seslerini keser.

    python3 tools/make_ford_audio.py kayit.mp3

- motor_ford_dusuk.wav  : sabit, düşük devir (2-6 sn)        -> döngü
- motor_ford_yuksek.wav : sabit, yüksek devir (11-16 sn)     -> döngü
- aragaz_1..3.wav       : ara gaz patlamaları (17-21 sn arası) -> tek seferlik
"""
import os, subprocess, sys, tempfile, wave
import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def load(path):
    tmp = os.path.join(tempfile.mkdtemp(), "k.wav")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SR), tmp], check=True)
    w = wave.open(tmp)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    b, a = butter(2, 25 / (SR / 2), "high")   # DC / rüzgâr uğultusunu at
    return lfilter(b, a, x)


def write(name, x, peak=0.9):
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    pcm = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
    print(name, f"{len(x) / SR:.2f} sn")


def seg(x, a, b):
    return x[int(a * SR):int(b * SR)].copy()


def make_loop(s, xf=0.35):
    """Sonu başa yumuşak geçişle bağla -> kusursuz döngü"""
    X = int(xf * SR)
    out = s[: len(s) - X].copy()
    fade = np.linspace(0, 1, X)
    out[:X] = s[len(s) - X:] * (1 - fade) + s[:X] * fade
    return out


def one_shot(s, fi=0.015, fo=0.08):
    n = len(s)
    env = np.ones(n)
    a, b = int(fi * SR), int(fo * SR)
    env[:a] = np.linspace(0, 1, a)
    env[n - b:] = np.linspace(1, 0, b)
    return s * env


if __name__ == "__main__":
    x = load(sys.argv[1])
    write("motor_ford_dusuk.wav", make_loop(seg(x, 2.0, 6.0)), 0.85)
    write("motor_ford_yuksek.wav", make_loop(seg(x, 11.0, 16.0)), 0.85)
    write("aragaz_1.wav", one_shot(seg(x, 18.40, 19.05)), 0.95)
    write("aragaz_2.wav", one_shot(seg(x, 18.85, 20.35), fo=0.25), 0.95)
    write("aragaz_3.wav", one_shot(seg(x, 20.40, 21.30), fo=0.15), 0.95)
