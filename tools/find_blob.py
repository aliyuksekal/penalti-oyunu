#!/usr/bin/env python3
"""Ekran görüntüsünde yeşil bir tuşu (BAŞLA / GAZ) bulur ve ortasının piksel konumunu yazar.

Kullanım: find_blob.py goruntu.png x0 y0 x1 y1
  x0..y1: aranacak bölge (0-1 arası oran). Çıktı: "x y" (bulunamazsa çıkış kodu 1).
Emülatör testinde dokunulacak yeri ekrandan bulmak için: tuşların yeri banner'a göre
değiştiğinden sabit koordinat kullanılmaz (yanlışlıkla reklama dokunulmasın).
"""
import sys
from PIL import Image


def main() -> int:
    path = sys.argv[1]
    fx0, fy0, fx1, fy1 = (float(v) for v in sys.argv[2:6])
    im = Image.open(path).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = int(fx0 * w), int(fy0 * h), int(fx1 * w), int(fy1 * h)
    px = im.load()
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = px[x, y]
            if g >= 90 and g >= 1.45 * r and g >= 1.35 * b:
                xs.append(x)
                ys.append(y)
    if len(xs) < max(40, (w * h) // 4000):
        return 1
    xs.sort()
    ys.sort()
    print(xs[len(xs) // 2], ys[len(ys) // 2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
