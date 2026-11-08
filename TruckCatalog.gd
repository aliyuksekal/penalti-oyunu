extends RefCounted
## Kamyon kataloğu. Fiyatlar JETON cinsinden (jeton yalnızca araç almak için).
## Çarpanlar TruckController'daki temel değerlere uygulanır.
## cab: classic / rounded / cabover / hood / offroad
## extras: stack, stacks2, stripe, spoiler, lightbar, bullbar, snorkel, visor

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
		{"id": "bozkurt", "name": "Bozkurt 4x4", "desc": "Büyük teker, yumuşak süspansiyon. Tepelerin kurdu.",
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
		{"id": "titan", "name": "Titan", "desc": "Uzun burunlu dev. Krom, güç ve koca bir depo.",
			"price": 5000, "cab": "hood", "wheel_r": 30.0,
			"body": Color.html("#1d2129"), "accent": Color.html("#d4af4f"), "bed": Color.html("#2a2e37"), "rim": Color.html("#e6e8ec"),
			"power": 2.1, "grip": 1.35, "fuel": 1.9, "stiff": 1.25, "damp": 1.4, "speed": 1.3, "mass": 1.3,
			"tread": "road", "extras": ["stacks2", "stripe", "visor"]},
	]


static func by_id(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return all()[0]
