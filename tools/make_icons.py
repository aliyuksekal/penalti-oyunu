#!/usr/bin/env python3
"""Arayüz ikonlarını prosedürel üretir (assets/ui/*.png, 128x128, şeffaf, metinsiz)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui")
S = 512  # süper örnekleme


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def radial(size, c_in, c_out, center=(0.38, 0.32)):
    im = Image.new("RGBA", (size, size))
    px = im.load()
    cx, cy = center[0] * size, center[1] * size
    md = size * 0.85
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x - cx, y - cy) / md)
            px[x, y] = tuple(int(c_in[i] * (1 - t) + c_out[i] * t) for i in range(3)) + (255,)
    return im


def disc(im, box, c_in, c_out, outline=None, ow=0):
    x0, y0, x1, y1 = [int(v) for v in box]
    w = x1 - x0
    g = radial(w, c_in, c_out)
    m = Image.new("L", (w, w), 0)
    ImageDraw.Draw(m).ellipse([0, 0, w - 1, w - 1], fill=255)
    im.paste(g, (x0, y0), m)
    if outline:
        ImageDraw.Draw(im).ellipse(box, outline=outline, width=ow)


def shine(im, box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    L = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(L).ellipse([x0 + w * .18, y0 + h * .08, x0 + w * .62, y0 + h * .38], fill=(255, 255, 255, 110))
    im.alpha_composite(L.filter(ImageFilter.GaussianBlur(S / 60)))


BIG = {}


def finish(im, name, shadow=True):
    BIG[name] = im.copy()
    if shadow:
        a = im.split()[3]
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        blk = Image.new("RGBA", im.size, (0, 10, 30, 255)); blk.putalpha(a.point(lambda v: v * 0.35))
        sh.alpha_composite(blk, (0, S // 40))
        sh = sh.filter(ImageFilter.GaussianBlur(S / 50))
        sh.alpha_composite(im)
        im = sh
    im.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def star_pts(cx, cy, r, inner=0.45, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def ball():
    im = canvas()
    disc(im, (40, 40, 472, 472), (255, 255, 255), (196, 206, 222))
    d = ImageDraw.Draw(im)
    c = 256
    d.polygon(star_pts(c, c, 70, 1.0, 5, -90), fill=(24, 30, 46))
    for k in range(5):
        a = math.radians(-90 + k * 72)
        x, y = c + 175 * math.cos(a), c + 175 * math.sin(a)
        d.polygon(star_pts(x, y, 55, 1.0, 5, -90 + k * 72 + 36), fill=(24, 30, 46))
        d.line([(c + 70 * math.cos(a), c + 70 * math.sin(a)), (x - 50 * math.cos(a), y - 50 * math.sin(a))], fill=(60, 70, 90), width=10)
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).ellipse([40, 40, 472, 472], fill=255)
    clip = Image.new("RGBA", (S, S), (0, 0, 0, 0)); clip.paste(im, (0, 0), m); im = clip
    ImageDraw.Draw(im).ellipse([40, 40, 472, 472], outline=(150, 160, 180), width=8)
    shine(im, (40, 40, 472, 472))
    finish(im, "ball")


def coin():
    im = canvas()
    disc(im, (48, 48, 464, 464), (255, 236, 140), (226, 150, 10), (176, 110, 0), 14)
    disc(im, (112, 112, 400, 400), (255, 214, 80), (235, 165, 20))
    ImageDraw.Draw(im).polygon(star_pts(256, 262, 105), fill=(255, 246, 200))
    shine(im, (48, 48, 464, 464))
    finish(im, "coin")


def star(name, fill_in, fill_out, outline):
    im = canvas()
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).polygon(star_pts(256, 276, 230), fill=255)
    g = radial(S, fill_in, fill_out)
    im.paste(g, (0, 0), m)
    ImageDraw.Draw(im).polygon(star_pts(256, 276, 230), outline=outline, width=16)
    shine(im, (90, 60, 420, 420))
    finish(im, name)


def trophy():
    im = canvas()
    d = ImageDraw.Draw(im)
    gold, dark = (255, 200, 40), (190, 120, 0)
    d.ellipse([70, 110, 190, 250], outline=gold, width=26)
    d.ellipse([322, 110, 442, 250], outline=gold, width=26)
    cup = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cup).pieslice([130, -40, 382, 330], 0, 180, fill=255)
    ImageDraw.Draw(cup).rectangle([130, 60, 382, 145], fill=255)
    im.paste(radial(S, (255, 240, 150), (215, 140, 0)), (0, 0), cup)
    d.rectangle([228, 320, 284, 390], fill=dark)
    d.rounded_rectangle([150, 385, 362, 450], radius=18, fill=(120, 70, 20))
    d.polygon(star_pts(256, 175, 55), fill=(255, 250, 220))
    shine(im, (130, 40, 382, 300))
    finish(im, "trophy")


def lock():
    im = canvas()
    d = ImageDraw.Draw(im)
    d.arc([150, 60, 362, 300], 180, 360, fill=(170, 180, 200), width=44)
    d.line([(172, 180), (172, 240)], fill=(170, 180, 200), width=44)
    d.line([(340, 180), (340, 240)], fill=(170, 180, 200), width=44)
    body = Image.new("L", (S, S), 0); ImageDraw.Draw(body).rounded_rectangle([100, 220, 412, 460], radius=40, fill=255)
    im.paste(radial(S, (255, 214, 90), (210, 140, 0), (0.4, 0.5)), (0, 0), body)
    d.ellipse([226, 290, 286, 350], fill=(110, 70, 0)); d.rectangle([244, 330, 268, 400], fill=(110, 70, 0))
    finish(im, "lock")


def gear():
    im = canvas()
    m = Image.new("L", (S, S), 0); dm = ImageDraw.Draw(m)
    dm.ellipse([110, 110, 402, 402], fill=255)
    for k in range(8):
        a = math.radians(k * 45)
        cx, cy = 256 + 175 * math.cos(a), 256 + 175 * math.sin(a)
        dm.regular_polygon((cx, cy, 52), 4, rotation=k * 45, fill=255)
    dm.ellipse([196, 196, 316, 316], fill=0)
    im.paste(radial(S, (220, 232, 255), (110, 130, 170)), (0, 0), m)
    finish(im, "gear")


def glove():
    im = canvas()
    m = Image.new("L", (S, S), 0); dm = ImageDraw.Draw(m)
    dm.rounded_rectangle([150, 220, 380, 450], radius=70, fill=255)
    for i, (x, h) in enumerate([(150, 150), (205, 110), (262, 100), (318, 130)]):
        dm.rounded_rectangle([x, h, x + 54, 300], radius=27, fill=255)
    dm.rounded_rectangle([60, 250, 190, 330], radius=40, fill=255)
    im.paste(radial(S, (120, 255, 170), (10, 160, 80)), (0, 0), m)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([150, 380, 380, 460], radius=30, fill=(255, 255, 255))
    d.rounded_rectangle([150, 400, 380, 430], radius=10, fill=(30, 120, 220))
    shine(im, (150, 100, 380, 400))
    finish(im, "glove")


def play_icon():
    im = canvas()
    disc(im, (40, 40, 472, 472), (120, 240, 150), (20, 150, 70))
    ImageDraw.Draw(im).polygon([(205, 150), (205, 362), (370, 256)], fill=(255, 255, 255))
    shine(im, (40, 40, 472, 472))
    finish(im, "play")


def pause_icon():
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([140, 110, 230, 402], radius=26, fill=(255, 255, 255))
    d.rounded_rectangle([282, 110, 372, 402], radius=26, fill=(255, 255, 255))
    finish(im, "pause")


def brain():
    im = canvas()
    disc(im, (40, 40, 472, 472), (140, 230, 255), (40, 110, 230))
    d = ImageDraw.Draw(im)
    pts = [(150, 330), (190, 230), (256, 280), (322, 180), (362, 300)]
    d.line(pts, fill=(255, 255, 255), width=18, joint="curve")
    for (x, y) in pts:
        d.ellipse([x - 30, y - 30, x + 30, y + 30], fill=(255, 255, 255))
        d.ellipse([x - 14, y - 14, x + 14, y + 14], fill=(60, 140, 240))
    shine(im, (40, 40, 472, 472))
    finish(im, "ai")


def eye():
    im = canvas()
    d = ImageDraw.Draw(im)
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([40, 140, 472, 372], fill=255)
    im.paste(radial(S, (255, 255, 255), (200, 215, 235)), (0, 0), m)
    disc(im, (166, 166, 346, 346), (90, 200, 255), (20, 80, 200))
    d.ellipse([220, 220, 292, 292], fill=(10, 16, 30))
    d.ellipse([236, 222, 262, 248], fill=(255, 255, 255))
    finish(im, "eye")


def tv():
    im = canvas()
    d = ImageDraw.Draw(im)
    body = Image.new("L", (S, S), 0); ImageDraw.Draw(body).rounded_rectangle([50, 110, 462, 400], radius=50, fill=255)
    im.paste(radial(S, (255, 170, 80), (230, 80, 30)), (0, 0), body)
    d.rounded_rectangle([90, 150, 422, 360], radius=30, fill=(30, 20, 40))
    d.polygon([(220, 200), (220, 310), (310, 255)], fill=(255, 255, 255))
    d.line([(190, 110), (140, 50)], fill=(230, 90, 30), width=18)
    d.line([(322, 110), (372, 50)], fill=(230, 90, 30), width=18)
    finish(im, "ad")


def arrow_icon(name, color):
    im = canvas()
    disc(im, (40, 40, 472, 472), tuple(min(255, c + 70) for c in color), color)
    d = ImageDraw.Draw(im)
    if name == "skip":
        d.polygon([(150, 150), (150, 362), (270, 256)], fill=(255, 255, 255))
        d.polygon([(260, 150), (260, 362), (380, 256)], fill=(255, 255, 255))
    elif name == "retry":
        d.arc([140, 140, 372, 372], 40, 330, fill=(255, 255, 255), width=40)
        d.polygon([(330, 110), (400, 200), (300, 210)], fill=(255, 255, 255))
    elif name == "home":
        d.polygon([(256, 120), (390, 250), (122, 250)], fill=(255, 255, 255))
        d.rectangle([160, 245, 352, 380], fill=(255, 255, 255))
        d.rectangle([230, 300, 282, 380], fill=color)
    elif name == "info":
        d.ellipse([228, 130, 284, 186], fill=(255, 255, 255))
        d.rounded_rectangle([230, 210, 282, 390], radius=20, fill=(255, 255, 255))
    elif name == "shop":
        d.rounded_rectangle([140, 200, 372, 390], radius=30, fill=(255, 255, 255))
        d.arc([190, 120, 322, 260], 180, 360, fill=(255, 255, 255), width=26)
    shine(im, (40, 40, 472, 472))
    finish(im, name)


def jersey():
    im = canvas()
    m = Image.new("L", (S, S), 0); dm = ImageDraw.Draw(m)
    dm.polygon([(170, 80), (342, 80), (450, 160), (400, 250), (360, 225), (360, 450), (152, 450), (152, 225), (112, 250), (62, 160)], fill=255)
    stripes = Image.new("RGBA", (S, S), (240, 240, 245, 255))
    ds = ImageDraw.Draw(stripes)
    for x in range(140, 380, 70):
        ds.rectangle([x, 0, x + 35, S], fill=(40, 120, 230))
    im.paste(stripes, (0, 0), m)
    ImageDraw.Draw(im).arc([210, 40, 302, 130], 0, 180, fill=(255, 255, 255), width=18)
    finish(im, "jersey")


def main():
    os.makedirs(OUT, exist_ok=True)
    ball(); coin(); trophy(); lock(); gear(); glove(); play_icon(); pause_icon(); brain(); eye(); tv(); jersey()
    star("star", (255, 245, 160), (240, 160, 0), (190, 110, 0))
    star("star_empty", (120, 130, 155), (70, 80, 105), (50, 58, 80))
    arrow_icon("skip", (40, 120, 230)); arrow_icon("retry", (230, 140, 20)); arrow_icon("home", (110, 90, 220))
    arrow_icon("info", (40, 160, 220)); arrow_icon("shop", (220, 60, 120))
    app_icons()
    print("ok", len(os.listdir(OUT)))


def app_bg(size):
    import numpy as np
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.28) ** 2)
    c1, c2 = np.array([40, 140, 255]), np.array([6, 18, 60])
    t = np.clip(r / 0.8, 0, 1)[..., None]
    img = (c1 * (1 - t) + c2 * t)
    g = np.clip(1 - np.abs(yy - 0.86) / 0.14, 0, 1)[..., None] * (yy > 0.72)[..., None]
    img = img * (1 - g) + np.array([30, 150, 60]) * g
    return Image.fromarray(img.astype("uint8"), "RGB").convert("RGBA")


def app_icons():
    root = os.path.dirname(OUT)
    icons = os.path.join(root, "icons")
    os.makedirs(icons, exist_ok=True)
    store = os.path.join(os.path.dirname(root), "store")
    os.makedirs(store, exist_ok=True)

    def compose(size, bg=True, safe=1.0):
        im = app_bg(size) if bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))
        b = BIG["ball"].resize((int(size * 0.58 * safe),) * 2, Image.LANCZOS)
        g = BIG["glove"].resize((int(size * 0.5 * safe),) * 2, Image.LANCZOS)
        e = BIG["ai"].resize((int(size * 0.26 * safe),) * 2, Image.LANCZOS)
        cx = size // 2
        im.alpha_composite(g, (int(cx - size * 0.38 * safe), int(size * 0.5 - g.height * 0.55)))
        im.alpha_composite(b, (int(cx - b.width * 0.35), int(size * 0.5 - b.height * 0.42)))
        im.alpha_composite(e, (int(cx + size * 0.12 * safe), int(size * 0.5 - size * 0.36 * safe)))
        return im

    compose(192).save(os.path.join(icons, "icon_192.png"))
    compose(512).convert("RGB").save(os.path.join(store, "icon_512.png"))
    compose(432, bg=False, safe=0.66).save(os.path.join(icons, "adaptive_foreground_432.png"))
    app_bg(432).convert("RGB").save(os.path.join(icons, "adaptive_background_432.png"))
    fg = compose(432, bg=False, safe=0.66)
    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0)); mono.putalpha(fg.split()[3])
    mono.save(os.path.join(icons, "adaptive_monochrome_432.png"))
    compose(256, bg=False).save(os.path.join(icons, "splash.png"))


if __name__ == "__main__":
    main()
