#!/usr/bin/env python3
"""Penaltı Ustası sesleri (prosedürel, lisans sorunu yok): vuruş, düdük, tribün uğultusu,
gol coşkusu, "oooh", kurtarış, direk, ağ, jeton, kazanma/kaybetme, düğme."""
import os, wave, math
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
rng = np.random.default_rng(5)


def env(n, a=0.005, r=0.2):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / max(r, 1e-4))


def tone(f, d, a=0.005, r=0.15, kind="sine"):
    n = int(SR * d); t = np.arange(n) / SR
    ph = 2 * math.pi * f * t
    w = np.sin(ph) if kind == "sine" else 2 / math.pi * np.arcsin(np.sin(ph))
    return w * env(n, a, r)


def lp(x, k):
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = y[i - 1] + k * (x[i] - y[i - 1])
    return y


def bp(x, f, q=4.0):
    # basit rezonans filtresi (iki kutuplu)
    w = 2 * math.pi * f / SR
    r = 1 - w / q
    a1, a2 = -2 * r * math.cos(w), r * r
    y = np.zeros_like(x)
    for i in range(2, len(x)):
        y[i] = x[i] - a1 * y[i - 1] - a2 * y[i - 2]
    return y


def noise(d):
    return rng.normal(0, 1, int(SR * d))


def mix(*parts):
    n = max(len(p) + int(o * SR) for p, o in parts)
    out = np.zeros(n)
    for p, o in parts:
        s = int(o * SR); out[s:s + len(p)] += p
    return out


def save(name, x, gain=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def crowd_bed(d, excite=0.3):
    n = int(SR * d)
    base = lp(noise(d), 0.08)
    murmur = sum(bp(noise(d), f, 6) * w for f, w in [(250, 1.0), (500, 0.7), (900, 0.4), (1600, 0.2)])
    t = np.arange(n) / SR
    swell = 0.75 + 0.25 * np.sin(2 * math.pi * 0.11 * t) + 0.1 * np.sin(2 * math.pi * 0.37 * t)
    return (base * 0.6 + murmur * 0.012 * (1 + excite)) * swell


def main():
    os.makedirs(OUT, exist_ok=True)
    save("tap.wav", tone(900, 0.07, r=0.03), 0.4)
    save("button.wav", mix((tone(620, 0.07, r=0.03, kind="tri"), 0), (tone(930, 0.08, r=0.04, kind="tri"), 0.04)), 0.4)
    kick = mix((tone(95, 0.2, 0.001, 0.06), 0), (lp(noise(0.05), 0.5) * env(int(SR * 0.05), 0.001, 0.01), 0))
    save("kick.wav", kick, 0.9)
    n = int(SR * 0.9); t = np.arange(n) / SR
    trem = 0.6 + 0.4 * np.sign(np.sin(2 * math.pi * 38 * t))
    wh = (np.sin(2 * math.pi * 2900 * t) + 0.4 * np.sin(2 * math.pi * 3200 * t)) * trem * env(n, 0.01, 0.5)
    save("whistle.wav", mix((wh[: int(SR * 0.35)], 0), (wh, 0.42)), 0.45)
    # gol coşkusu: yükselen kalabalık + "ooo"
    d = 3.5; n = int(SR * d); t = np.arange(n) / SR
    roar = crowd_bed(d, 3.0) + sum(bp(noise(d), f, 8) * 0.03 for f in (420, 640, 820))
    shape = np.minimum(1, t / 0.35) * np.exp(-np.maximum(0, t - 1.8) / 0.9)
    save("roar.wav", roar * shape, 0.85)
    d = 1.6; n = int(SR * d); t = np.arange(n) / SR
    ooh = sum(bp(noise(d), f, 10) * 0.05 for f in (380, 520))
    save("ooh.wav", ooh * np.minimum(1, t / 0.15) * np.exp(-t / 0.7), 0.7)
    save("save.wav", mix((tone(140, 0.15, 0.001, 0.05), 0), (lp(noise(0.08), 0.3) * env(int(SR * 0.08), 0.001, 0.03), 0)), 0.8)
    clang = sum(tone(f, 1.2, 0.001, 0.35) * w for f, w in [(523, 1), (1290, 0.6), (2310, 0.4), (3570, 0.25)])
    save("post.wav", clang, 0.7)
    sw = bp(noise(0.5), 3000, 2) * env(int(SR * 0.5), 0.02, 0.15)
    save("net.wav", sw, 0.5)
    save("coin.wav", mix((tone(1318, 0.08, r=0.05), 0), (tone(1760, 0.22, r=0.12), 0.06)), 0.45)
    save("win.wav", mix(*[(tone(f, 0.3, r=0.2, kind="tri"), i * 0.12) for i, f in enumerate([523, 659, 784, 1046, 1318])]), 0.55)
    save("lose.wav", mix(*[(tone(f, 0.4, r=0.3, kind="tri"), i * 0.2) for i, f in enumerate([392, 349, 311, 262])]), 0.5)
    # döngü: 12 sn tribün uğultusu (kesintisiz)
    d = 12.0; L = int(SR * d)
    bed = crowd_bed(d + 1.0, 0.3)
    loop = bed[:L].copy()
    fade = int(SR * 1.0)
    w = np.linspace(0, 1, fade)
    loop[:fade] = loop[:fade] * w + bed[L:L + fade] * (1 - w)
    save("crowd_loop.wav", loop, 0.5)
    print("ok")


if __name__ == "__main__":
    main()
