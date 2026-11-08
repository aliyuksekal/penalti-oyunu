"""Ağır Yük - tüm sesleri ve müzikleri sıfırdan sentezler (dış ses dosyası yok).

    python3 tools/make_audio.py   ->  audio/*.wav

- muzik_yol.wav   : oyun içi müzik "Yol Türküsü" (Mi Hicaz, 130 bpm, Endülüs kadansı Am-G-F-E)
- muzik_garaj.wav : menü müziği "Garaj" (Sol majör, 96 bpm, parmakla çalınan gitar + ıslık)
- motor.wav       : kusursuz döngü dizel motor uğultusu (oyunda devir ile perdesi değişir)
- efektler        : yuk_dustu, teslimat, oyun_bitti, tik, inis, hararet, satin_al
"""
import os
import numpy as np
from scipy.signal import butter, lfilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def lp(x, fc, sr, order=2):
    b, a = butter(order, min(fc / (sr / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, fc, sr, order=2):
    b, a = butter(order, min(fc / (sr / 2), 0.99), "high")
    return lfilter(b, a, x)


def bp(x, f1, f2, sr):
    b, a = butter(2, [f1 / (sr / 2), min(f2 / (sr / 2), 0.99)], "band")
    return lfilter(b, a, x)


def write(name, x, sr, peak=0.89):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    pcm = (x * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        data = pcm.tobytes()
        f.write(b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVEfmt ")
        f.write((16).to_bytes(4, "little") + (1).to_bytes(2, "little") + (1).to_bytes(2, "little"))
        f.write(sr.to_bytes(4, "little") + (sr * 2).to_bytes(4, "little") + (2).to_bytes(2, "little") + (16).to_bytes(2, "little"))
        f.write(b"data" + len(data).to_bytes(4, "little") + data)
    print(f"{name}: {len(x) / sr:.1f} sn, {os.path.getsize(path) // 1024} KB")


# ---------------- enstrümanlar ----------------
def pluck(freq, dur, sr, bright=0.5, decay=0.996):
    """Karplus-Strong telli çalgı (gitar / bağlama) - periyot blokları halinde, hızlı"""
    n = int(dur * sr)
    period = max(2, int(round(sr / freq)))
    buf = lp(rng.uniform(-1, 1, period), 800 + bright * 6000, sr, 1)
    blocks = []
    total = 0
    while total < n:
        blocks.append(buf)
        total += period
        buf = decay * 0.5 * (buf + np.roll(buf, -1))
    out = np.concatenate(blocks)[:n]
    env = np.minimum(1.0, np.arange(n) / (0.003 * sr))
    return out * env


def bass_note(freq, dur, sr):
    t = np.arange(int(dur * sr)) / sr
    tri = 2 * np.abs(2 * ((t * freq) % 1) - 1) - 1
    x = 0.7 * np.sin(2 * np.pi * freq * t) + 0.35 * tri
    env = np.exp(-t * 3.5) * np.minimum(1, t / 0.005)
    rel = np.minimum(1, (dur - t) / 0.02)
    return lp(x * env * rel, 900, sr)


def kick(sr):
    t = np.arange(int(0.35 * sr)) / sr
    f = 45 + 80 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) * np.exp(-t * 9) + 0.15 * rng.normal(0, 1, len(t)) * np.exp(-t * 120)


def snare(sr):
    t = np.arange(int(0.22 * sr)) / sr
    noise = bp(rng.normal(0, 1, len(t)), 1200, 7000, sr) * np.exp(-t * 18)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return 0.8 * noise + 0.5 * tone


def hat(sr, open_=False):
    t = np.arange(int((0.18 if open_ else 0.05) * sr)) / sr
    return hp(rng.normal(0, 1, len(t)), 7000, sr) * np.exp(-t * (14 if open_ else 70))


def shaker(sr):
    t = np.arange(int(0.08 * sr)) / sr
    return hp(rng.normal(0, 1, len(t)), 5000, sr) * np.sin(np.pi * t / t[-1]) ** 2


def whistle(freq, dur, sr):
    t = np.arange(int(dur * sr)) / sr
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25)
    ph = 2 * np.pi * np.cumsum(freq * vib) / sr
    x = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.02 * rng.normal(0, 1, len(t))
    env = np.minimum(1, t / 0.06) * np.minimum(1, (dur - t) / 0.08)
    return x * env


def place(track, x, start_s, sr, gain=1.0):
    i = int(start_s * sr)
    j = min(len(track), i + len(x))
    if j > i:
        track[i:j] += x[: j - i] * gain


def loop_fold(x, loop_len):
    """Döngü sonundaki taşan kuyruğu başa ekle -> kusursuz döngü"""
    out = x[:loop_len].copy()
    tail = x[loop_len:]
    out[: len(tail)] += tail
    return out


def reverb(x, sr, mix=0.18):
    out = x.copy()
    for d, g in [(0.029, 0.5), (0.037, 0.42), (0.043, 0.36), (0.053, 0.3), (0.071, 0.22), (0.089, 0.16)]:
        k = int(d * sr)
        y = np.zeros_like(x)
        y[k:] = x[:-k] * g
        out += lp(y, 3500, sr) * mix
    return out


# ---------------- OYUN MÜZİĞİ: "Yol Türküsü" ----------------
def song_road():
    sr = 32000
    bpm = 130
    e = 60.0 / bpm / 2  # sekizlik süresi
    bars = 24
    total = bars * 8 * e
    n = int((total + 2.0) * sr)
    drums = np.zeros(n); bass = np.zeros(n); gtr = np.zeros(n); lead = np.zeros(n)
    prog = ["Am", "G", "F", "E"]
    chords = {"Am": [57, 60, 64, 69], "G": [55, 59, 62, 67], "F": [53, 57, 60, 65], "E": [52, 56, 59, 64]}
    roots = {"Am": 45, "G": 43, "F": 41, "E": 40}
    K, S, H, HO = kick(sr), snare(sr), hat(sr), hat(sr, True)
    for b in range(bars):
        c = prog[b % 4]
        t0 = b * 8 * e
        # davul: 1 ve 3'te davul, 2 ve 4'te trampet, sekizlik zil; son ölçüde dolgu
        for i in range(8):
            ts = t0 + i * e
            if i in (0, 4) or (i == 5 and b % 2 == 1):
                place(drums, K, ts, sr, 1.0)
            if i in (2, 6):
                place(drums, S, ts, sr, 0.7)
            place(drums, HO if i == 7 else H, ts, sr, 0.25 if i % 2 else 0.18)
        if b % 8 == 7:
            for k in range(4):
                place(drums, S, t0 + (4 + k) * e, sr, 0.35 + 0.12 * k)
        # bas: kök-kök-beşli-kök sekizlikler
        r = roots[c]
        pattern = [r, r, r + 7, r, r + 12, r, r + 7, r + 5 if c != "E" else r + 4]
        for i, nn in enumerate(pattern):
            place(bass, bass_note(midi(nn), e * 0.95, sr), t0 + i * e, sr, 0.9)
        # gitar ritmi: A . A Ü . Ü A Ü (aşağı/yukarı vuruş)
        for i, d in [(0, 1), (2, 1), (3, -1), (5, -1), (6, 1), (7, -1)]:
            notes = chords[c] if d > 0 else chords[c][::-1]
            for k, nn in enumerate(notes):
                place(gtr, pluck(midi(nn), 0.6, sr, 0.35, 0.993), t0 + i * e + k * 0.012, sr, 0.22 if d > 0 else 0.15)
    # bağlama benzeri ezgi (Mi Hicaz)
    A = [(69, 2), (72, 1), (71, 1), (69, 2), (64, 2),
         (74, 2), (72, 1), (71, 1), (69, 1), (71, 1), (71, 2),
         (72, 2), (69, 1), (65, 1), (69, 2), (72, 2),
         (71, 2), (68, 1), (65, 1), (64, 4),
         (76, 2), (74, 1), (72, 1), (71, 1), (72, 1), (69, 2),
         (71, 2), (74, 2), (71, 1), (69, 1), (67, 2),
         (69, 1), (71, 1), (72, 2), (77, 2), (76, 2),
         (74, 1), (72, 1), (71, 1), (69, 1), (68, 2), (64, 2)]
    B = [(81, 3), (80, 1), (81, 2), (76, 2),
         (74, 2), (76, 1), (74, 1), (71, 4),
         (72, 2), (74, 1), (76, 1), (77, 2), (81, 2),
         (80, 2), (77, 1), (76, 1), (76, 4)]
    melody = A + B + A[20:]   # 16 ölçü ezgi, sonra 8 ölçü saz arası
    t = 0.0
    for nn, d in melody:
        dur = d * e
        x = pluck(midi(nn), dur + 0.35, sr, 0.8, 0.995)
        # hafif tremolo (mızrap)
        if d >= 2:
            tt = np.arange(len(x)) / sr
            x = x * (0.85 + 0.15 * np.cos(2 * np.pi * 12 * tt))
        place(lead, x, t, sr, 0.55)
        t += dur
    mix = 0.55 * drums + 0.65 * bass + 0.75 * reverb(gtr, sr) + 1.25 * reverb(lead, sr, 0.25)
    loop = int(total * sr)
    write("muzik_yol.wav", loop_fold(mix, loop), sr, 0.8)


# ---------------- MENÜ MÜZİĞİ: "Garaj" ----------------
def song_garage():
    sr = 32000
    bpm = 96
    e = 60.0 / bpm / 2
    bars = 16
    total = bars * 8 * e
    n = int((total + 2.5) * sr)
    gtr = np.zeros(n); bass = np.zeros(n); perc = np.zeros(n); mel = np.zeros(n)
    prog = ["G", "Em", "C", "D"]
    arp = {"G": [43, 55, 59, 62, 67, 62, 59, 55], "Em": [40, 52, 55, 59, 64, 59, 55, 52],
           "C": [36, 48, 52, 55, 60, 55, 52, 48], "D": [38, 50, 54, 57, 62, 57, 54, 50]}
    SH = shaker(sr)
    K = kick(sr)
    for b in range(bars):
        c = prog[b % 4]
        t0 = b * 8 * e
        for i, nn in enumerate(arp[c]):
            place(gtr, pluck(midi(nn + 12 if i else nn + 12), 1.4, sr, 0.25, 0.9965), t0 + i * e, sr, 0.3 if i else 0.4)
            place(perc, SH, t0 + i * e, sr, 0.12 if i % 2 else 0.2)
        place(bass, bass_note(midi(arp[c][0]), 4 * e, sr), t0, sr, 0.8)
        place(bass, bass_note(midi(arp[c][0] + 7), 4 * e, sr), t0 + 4 * e, sr, 0.6)
        if b >= 4:
            place(perc, K * 0.6, t0, sr, 0.6)
            place(perc, K * 0.6, t0 + 4 * e, sr, 0.45)
    q = 2 * e  # dörtlük
    phrase = [(71, 2), (74, 1), (71, 1), (67, 2), (71, 2), (72, 1), (71, 1), (69, 1), (67, 1), (69, 4),
              (71, 1), (72, 1), (74, 2), (76, 2), (74, 1), (71, 1), (72, 2), (69, 1), (67, 1), (66, 2), (69, 2)]
    t = 0.0
    for nn, d in phrase:
        place(mel, whistle(midi(nn), d * q * 0.95, sr), t, sr, 0.35)
        t += d * q
    t = 12 * 8 * e
    for nn, d in phrase[:10]:
        place(mel, whistle(midi(nn), d * q * 0.95, sr), t, sr, 0.3)
        t += d * q
    mix = 0.8 * reverb(gtr, sr, 0.25) + 0.6 * bass + 0.7 * perc + 0.8 * reverb(mel, sr, 0.3)
    write("muzik_garaj.wav", loop_fold(mix, int(total * sr)), sr, 0.7)


# ---------------- MOTOR ----------------
def engine():
    sr = 22050
    f = 40.0          # rölantide ateşleme frekansı
    L = 1.0           # 1 sn = 40 tam çevrim -> kusursuz döngü
    n = int(L * sr)
    m = int((L + 0.3) * sr)
    x = np.zeros(m)
    t = np.arange(m) / sr
    period = sr / f
    for k in range(int((L + 0.3) * f)):
        i0 = int(k * period)
        seg = np.arange(int(period * 2.2))
        amp = 0.8 + 0.25 * np.sin(k * 2.1) + 0.1 * rng.uniform(-1, 1)
        pulse = amp * np.exp(-seg / (period * 0.35)) * np.sin(2 * np.pi * seg / period * 1.5)
        j = min(m, i0 + len(seg))
        x[i0:j] += pulse[: j - i0]
    saw = ((t * f) % 1) * 2 - 1
    rumble = lp(rng.normal(0, 1, m), 220, sr) * 0.6
    y = lp(x, 900, sr) + 0.25 * lp(saw, 300, sr) + rumble
    y += 0.08 * bp(rng.normal(0, 1, m), 1500, 4000, sr) * (0.6 + 0.4 * np.sin(2 * np.pi * f * t))  # egzoz cızırtısı
    write("motor.wav", loop_fold(y, n), sr, 0.8)


# ---------------- EFEKTLER ----------------
def effects():
    sr = 22050

    def T(d):
        return np.arange(int(d * sr)) / sr

    t = T(0.45)
    thud = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * 11)
    wood = bp(rng.normal(0, 1, len(t)), 300, 1800, sr) * np.exp(-t * 35)
    clack = np.zeros(len(t)); k = int(0.07 * sr)
    clack[k:k + 400] = bp(rng.normal(0, 1, 400), 800, 3000, sr) * np.exp(-np.arange(400) / 80)
    write("yuk_dustu.wav", thud + 0.7 * wood + 0.5 * clack, sr)

    out = np.zeros(int(1.4 * sr))
    for i, nn in enumerate([72, 76, 79, 84, 88]):
        tt = T(0.9)
        bell = sum(a * np.sin(2 * np.pi * midi(nn) * h * tt) for h, a in [(1, 1), (2.76, 0.4), (5.4, 0.2)])
        place(out, bell * np.exp(-tt * 5), i * 0.08, sr, 0.5)
    tt = T(0.25)
    place(out, hp(rng.normal(0, 1, len(tt)), 5000, sr) * np.exp(-tt * 30), 0.42, sr, 0.4)
    write("teslimat.wav", out, sr)

    out = np.zeros(int(2.6 * sr))
    for i, (nn, d) in enumerate([(55, 0.45), (54, 0.45), (53, 0.45), (52, 1.1)]):
        tt = T(d)
        vib = 1 + (0.03 * np.sin(2 * np.pi * 6 * tt) if i == 3 else 0)
        ph = 2 * np.pi * np.cumsum(midi(nn) * vib) / sr
        saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
        env = np.minimum(1, tt / 0.04) * np.minimum(1, (d - tt) / 0.08)
        place(out, lp(saw, 900, sr) * env, i * 0.5, sr, 0.7)
    write("oyun_bitti.wav", out, sr)

    tt = T(0.05)
    write("tik.wav", np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 120) + 0.3 * hp(rng.normal(0, 1, len(tt)), 3000, sr) * np.exp(-tt * 200), sr, 0.6)

    tt = T(0.5)
    land = np.sin(2 * np.pi * (50 + 40 * np.exp(-tt * 20)) * tt) * np.exp(-tt * 8) + 0.4 * lp(rng.normal(0, 1, len(tt)), 400, sr) * np.exp(-tt * 15)
    sq = np.zeros(len(tt)); k = int(0.12 * sr)
    tq = np.arange(int(0.18 * sr)) / sr
    sq[k:k + len(tq)] = 0.15 * np.sin(2 * np.pi * (900 - 300 * tq) * tq) * np.sin(np.pi * tq / tq[-1])   # yay gıcırtısı
    write("inis.wav", land + sq, sr)

    tt = T(1.4)
    write("hararet.wav", hp(rng.normal(0, 1, len(tt)), 2500, sr) * np.minimum(1, tt / 0.1) * np.exp(-tt * 1.6), sr, 0.6)

    out = np.zeros(int(1.0 * sr))
    tt = T(0.08)
    place(out, bp(rng.normal(0, 1, len(tt)), 1500, 5000, sr) * np.exp(-tt * 60), 0.0, sr, 0.6)
    for i, nn in enumerate([84, 91]):
        t2 = T(0.7)
        place(out, (np.sin(2 * np.pi * midi(nn) * t2) + 0.3 * np.sin(2 * np.pi * midi(nn) * 2.4 * t2)) * np.exp(-t2 * 6), 0.06 + i * 0.09, sr, 0.5)
    write("satin_al.wav", out, sr)


if __name__ == "__main__":
    effects()
    engine()
    song_garage()
    song_road()
