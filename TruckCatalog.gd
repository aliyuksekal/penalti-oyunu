extends RefCounted
## Kamyon kataloğu. Fiyatlar JETON cinsinden (jeton yalnızca araç almak için).
## Çarpanlar TruckController'daki temel değerlere uygulanır.
## cab: classic / rounded / cabover / hood / offroad
## drive: "rwd" = arkadan itiş (standart kamyon), "awd" = 4x4 (sadece en pahalı kamyon)
## extras: stack, stacks2, stripe, spoiler, lightbar, bullbar, snorkel, visor
## kind: truck (kasalı) / tir (çekici + dorse) / bus (otobüs; sadece Otobüs Hattı haritasında)
## ext: kasanın arkaya uzaması (px) = daha çok yük; axles: aks konumları; zoom: kamera
## Pahalı araç = daha uzun kasa / dorse = daha çok yük = daha çok altın

static func all() -> Array:
	return [
		{"id": "tosun", "name": "Tosun", "desc": "Herkesin ilk kamyonu. Dürüst, sağlam.",
			"price": 0, "cab": "classic", "wheel_r": 26.0,
			"body": Color.html("#2f74d0"), "accent": Color.html("#f2f4f7"), "bed": Color.html("#e8902a"), "rim": Color.html("#c9ced6"),
			"power": 1.0, "grip": 1.0, "fuel": 1.0, "stiff": 1.0, "damp": 1.0, "speed": 1.0, "mass": 1.0,
			"tread": "road", "extras": ["stack", "stripe"]},
		{"id": "kartal", "name": "Kartal", "desc": "Daha güçlü motor, daha büyük depo.",
			"price": 500, "cab": "rounded", "wheel_r": 27.0,
			"body": Color.html("#d23b30"), "accent": Color.html("#1d1f24"), "bed": Color.html("#3a3d44"), "rim": Color.html("#dfe3e8"),
			"power": 1.25, "grip": 1.05, "fuel": 1.15, "stiff": 1.05, "damp": 1.1, "speed": 1.08, "mass": 1.0,
			"tread": "road", "extras": ["stack", "stripe", "spoiler"]},
		{"id": "bozkurt", "name": "Bozkurt", "desc": "Büyük teker, yumuşak süspansiyon. Tepelerin kurdu.",
			"price": 1000, "cab": "offroad", "wheel_r": 32.0,
			"body": Color.html("#5f7d3b"), "accent": Color.html("#2a2d22"), "bed": Color.html("#4a5a2e"), "rim": Color.html("#3a3a3a"),
			"power": 1.35, "grip": 1.3, "fuel": 1.2, "stiff": 1.15, "damp": 1.35, "speed": 1.0, "mass": 1.05,
			"tread": "offroad", "extras": ["lightbar", "bullbar", "snorkel"]},
		{"id": "yildirim", "name": "Yıldırım", "desc": "Önü düz şehirlerarası. Hız onun işi.",
			"price": 1800, "cab": "cabover", "wheel_r": 27.0,
			"body": Color.html("#f2c22a"), "accent": Color.html("#1b1b1b"), "bed": Color.html("#2d2f35"), "rim": Color.html("#eeeeee"),
			"power": 1.6, "grip": 1.1, "fuel": 1.3, "stiff": 1.1, "damp": 1.15, "speed": 1.25, "mass": 1.05,
			"tread": "road", "extras": ["stripe", "stack", "spoiler"]},
		{"id": "dagkecisi", "name": "Dağ Keçisi", "desc": "Dev tekerler, yapışan lastikler. Dik yokuş sevmez değil, bayılır.",
			"price": 3000, "cab": "offroad", "wheel_r": 34.0,
			"body": Color.html("#ef7d22"), "accent": Color.html("#262626"), "bed": Color.html("#3b3b3b"), "rim": Color.html("#ffd23a"),
			"power": 1.75, "grip": 1.55, "fuel": 1.4, "stiff": 1.3, "damp": 1.5, "speed": 1.1, "mass": 1.1,
			"tread": "offroad", "extras": ["lightbar", "bullbar", "stack"]},
		{"id": "titan", "name": "Titan", "desc": "Uzun burunlu dev, 4x4 çekiş. Krom, güç ve koca bir depo.",
			"price": 5000, "cab": "hood", "wheel_r": 30.0,
			"body": Color.html("#1d2129"), "accent": Color.html("#d4af4f"), "bed": Color.html("#2a2e37"), "rim": Color.html("#e6e8ec"),
			"power": 2.1, "grip": 1.35, "fuel": 1.9, "stiff": 1.25, "damp": 1.4, "speed": 1.3, "mass": 1.3,
			"tread": "road", "drive": "awd", "extras": ["stacks2", "stripe", "visor"]},
		{"id": "kirkayak", "name": "Kırkayak 6x4", "desc": "Üç akslı uzun kasa. Arkadaki iki aks çeker, yükün iki katını alır.",
			"price": 6500, "cab": "cabover", "wheel_r": 29.0, "ext": 56.0, "axles": [-152.0, -86.0, 78.0], "zoom": 0.86,
			"body": Color.html("#1f8a8a"), "accent": Color.html("#f4f4f4"), "bed": Color.html("#3d4450"), "rim": Color.html("#e9edf2"),
			"power": 2.35, "grip": 1.25, "fuel": 2.0, "stiff": 1.45, "damp": 1.5, "speed": 1.15, "mass": 1.45,
			"tread": "road", "drive": "rwd", "extras": ["stack", "stripe", "spoiler"]},
		{"id": "mamut", "name": "Mamut 6x6", "desc": "Altı teker birden çeker. Dev kasa, dev tekerler, durdurulamaz.",
			"price": 9000, "cab": "offroad", "wheel_r": 34.0, "ext": 70.0, "axles": [-168.0, -92.0, 80.0], "zoom": 0.82,
			"body": Color.html("#8a1e1e"), "accent": Color.html("#1a1a1a"), "bed": Color.html("#4a3b2a"), "rim": Color.html("#ffcf3a"),
			"power": 2.9, "grip": 1.55, "fuel": 2.3, "stiff": 1.6, "damp": 1.7, "speed": 1.1, "mass": 1.6,
			"tread": "offroad", "drive": "6x6", "extras": ["lightbar", "bullbar", "snorkel", "stacks2"]},
		{"id": "tir", "name": "Kral TIR", "desc": "Dorseli çekici: kasası üç kamyon eder. Uzun ve ağır, düzgün yolları sever.",
			"price": 14000, "kind": "tir", "cab": "cabover", "wheel_r": 28.0, "axles": [-52.0, 78.0], "trailer_len": 440.0, "trailer_mass": 0.85, "zoom": 0.66,
			"body": Color.html("#f4f6f9"), "accent": Color.html("#1e5fb4"), "bed": Color.html("#59606c"), "rim": Color.html("#dfe3e8"),
			"power": 3.6, "grip": 1.3, "fuel": 3.0, "stiff": 1.5, "damp": 1.6, "speed": 1.3, "mass": 1.7,
			"tread": "road", "drive": "rwd", "smooth": 0.82, "pay": 0.65, "extras": ["stacks2", "stripe", "visor"]},
		# ---------------- OTOBÜSLER (yolcu taşır; koltuk sayısı gövde uzunluğundan) ----------------
		{"id": "minibus", "name": "Dolmuş Minibüs", "desc": "Üstü açık şehir turu minibüsü. 9 yolcu, her yokuşa tırmanır.",
			"price": 0, "kind": "bus", "cab": "cabover", "wheel_r": 26.0, "ext": -40.0, "axles": [-80.0, 80.0], "zoom": 0.92,
			"body": Color.html("#f3c623"), "accent": Color.html("#1d3c78"), "bed": Color.html("#444a55"), "rim": Color.html("#d9dde3"),
			"power": 1.6, "grip": 1.1, "fuel": 1.3, "stiff": 1.2, "damp": 1.6, "speed": 1.15, "mass": 1.15,
			"tread": "road", "drive": "rwd", "extras": []},
		{"id": "otobus", "name": "Şehirlerarası Otobüs", "desc": "Üstü açık turizm otobüsü. 13 yolcu üst katta ayakta.",
			"price": 4500, "kind": "bus", "cab": "cabover", "wheel_r": 28.0, "ext": 60.0, "axles": [-158.0, 86.0], "zoom": 0.78,
			"body": Color.html("#f2f2f2"), "accent": Color.html("#d6262b"), "bed": Color.html("#444a55"), "rim": Color.html("#d9dde3"),
			"power": 2.4, "grip": 1.2, "fuel": 2.2, "stiff": 1.35, "damp": 1.8, "speed": 1.2, "mass": 1.5,
			"tread": "road", "drive": "rwd", "smooth": 0.85, "extras": []},
		{"id": "luks", "name": "Lüks Turizm", "desc": "Havalı süspansiyon ve tutamaklar: yolcular zor düşer. 13 yolcu, hızlı.",
			"price": 8000, "kind": "bus", "cab": "cabover", "wheel_r": 29.0, "ext": 60.0, "axles": [-158.0, 86.0], "zoom": 0.78, "comfort": 1.5,
			"body": Color.html("#1b2a4a"), "accent": Color.html("#e0b13a"), "bed": Color.html("#444a55"), "rim": Color.html("#e9edf2"),
			"power": 2.8, "grip": 1.3, "fuel": 2.4, "stiff": 1.3, "damp": 2.2, "speed": 1.3, "mass": 1.55,
			"tread": "road", "drive": "rwd", "smooth": 0.85, "extras": []},
		{"id": "uzunyol", "name": "Uzun Yol 3 Akslı", "desc": "Dev turizm otobüsü: 18 yolcu, üç aks. Sefer başı en çok bilet.",
			"price": 12000, "kind": "bus", "cab": "cabover", "wheel_r": 29.0, "ext": 160.0, "axles": [-262.0, -196.0, 86.0], "zoom": 0.7,
			"body": Color.html("#ffffff"), "accent": Color.html("#1e8c4e"), "bed": Color.html("#444a55"), "rim": Color.html("#d9dde3"),
			"power": 3.3, "grip": 1.3, "fuel": 2.8, "stiff": 1.45, "damp": 2.0, "speed": 1.25, "mass": 1.75,
			"tread": "road", "drive": "rwd", "smooth": 0.85, "extras": []},
	]


## Mağazada satılan araçlar (hepsi her haritada sürülebilir)
static func shop() -> Array:
	return all().filter(func(t): return not bool(t.get("hidden", false)))


static func by_id(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return all()[0]
