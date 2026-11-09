extends Node2D
## Sonsuz, aşamalı zorlaşan 2D arazi (chunk sistemi).
## - Her parça: StaticBody2D + CollisionPolygon2D + Polygon2D (toprak) + Line2D (çim çizgisi)
## - Önde yeni parçalar üretilir, geride kalanlar bellekten silinir.
## - Her 500 metrede düz bir "Teslimat Noktası" alanı oluşur.
## Hiç görsel dosya kullanılmaz; her şey kodla çizilir.

const PX_PER_M := 50.0          # 1 metre = 50 piksel

@export var chunk_width: float = 1024.0
@export var point_spacing: float = 32.0
@export var chunks_ahead: int = 3
@export var chunks_behind: int = 2
@export var base_y: float = 560.0
@export var checkpoint_interval_m: float = 500.0
@export var flat_half_width: float = 380.0     # teslimat alanının yarı genişliği (px)
@export var flat_blend: float = 320.0          # düzlükten tepeye yumuşak geçiş (px)
@export var easy_until_m: float = 500.0         # ilk teslimata kadar yol rahat
@export var max_difficulty_at_m: float = 6000.0 # zorluk yavaş yavaş artar, burada tavan yapar (yol sonsuz)
@export var feature_len_m: float = 200.0        # her yol kesiminin uzunluğu (tümsek, dik yokuş, rampa...)
@export var features_start_m: float = 600.0     # ilk engel (tümsek, yokuş...) ilk teslimattan sonra
@export var noise_seed: int = 0                 # 0 = her oyunda farklı arazi

@export_group("Renkler")
@export var ground_color: Color = Color(0.45, 0.31, 0.19)
@export var deep_color: Color = Color(0.33, 0.22, 0.14)
@export var grass_color: Color = Color(0.40, 0.74, 0.27)
@export var grass_dark: Color = Color(0.22, 0.47, 0.16)

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _chunks: Dictionary = {}   # int -> Node2D
var _ground_mat := PhysicsMaterial.new()
var _rock_noise := FastNoiseLite.new()
var _features: Dictionary = {}   # kesim no -> {kind, center, half, h}
var _seed: int = 0
var _start_wall: StaticBody2D

## Bölge renkleri (her teslimat noktasında yeni bölge başlar): çim, toprak, derin toprak
const ZONE_COLORS: Array = [
	[Color(0.40, 0.74, 0.27), Color(0.45, 0.31, 0.19), Color(0.33, 0.22, 0.14)],   # Çayır
	[Color(0.62, 0.70, 0.25), Color(0.52, 0.38, 0.22), Color(0.38, 0.27, 0.16)],   # Tepeler (kuru ot)
	[Color(0.18, 0.50, 0.22), Color(0.36, 0.26, 0.17), Color(0.25, 0.18, 0.12)],   # Orman
	[Color(0.55, 0.55, 0.42), Color(0.48, 0.44, 0.40), Color(0.35, 0.32, 0.30)],   # Dağ geçidi
	[Color(0.72, 0.56, 0.36), Color(0.62, 0.42, 0.28), Color(0.46, 0.30, 0.20)],   # Kayalık vadi (kızıl)
	[Color(0.90, 0.93, 0.97), Color(0.50, 0.50, 0.54), Color(0.36, 0.36, 0.40)],   # Zirve (karlı)
]

## ---------------- YOL TÜRLERİ ----------------
## Her 250 m'de yol türü değişir: yüzey rengi, tutuş (sürtünme), engebe ve süslemeler farklı.
@export var road_len_m: float = 250.0
const ROADS := {
	"asfalt": {"name": "ASFALT YOL", "friction": 1.15, "bumps": 0.15, "amp": 0.8, "feat": 0.45, "surface": Color(0.24, 0.25, 0.28), "under": Color(0.16, 0.16, 0.18)},
	"toprak": {"name": "TOPRAK YOL", "friction": 1.0, "bumps": 1.0, "amp": 1.0, "feat": 1.0, "surface": Color(0.62, 0.46, 0.3), "under": Color(0.44, 0.31, 0.2)},
	"dag": {"name": "DAĞ YOLU", "friction": 0.95, "bumps": 1.25, "amp": 1.35, "feat": 1.25, "surface": Color(0.58, 0.57, 0.55), "under": Color(0.38, 0.37, 0.36)},
	"orman": {"name": "ORMAN PATİKASI", "friction": 0.9, "bumps": 1.7, "amp": 1.0, "feat": 1.0, "surface": Color(0.27, 0.4, 0.2), "under": Color(0.2, 0.15, 0.1)},
	"camur": {"name": "ÇAMURLU YOL", "friction": 0.5, "bumps": 0.8, "amp": 0.9, "feat": 0.9, "surface": Color(0.33, 0.24, 0.16), "under": Color(0.22, 0.15, 0.1)},
	"kar": {"name": "KARLI YOL", "friction": 0.33, "bumps": 0.7, "amp": 1.1, "feat": 1.0, "surface": Color(0.95, 0.97, 1.0), "under": Color(0.75, 0.82, 0.9)},
	# Şehirlerarası / Otobüs Hattı
	"otoyol": {"name": "OTOYOL", "friction": 1.2, "bumps": 0.05, "amp": 0.6, "feat": 0.5, "surface": Color(0.2, 0.21, 0.24), "under": Color(0.13, 0.13, 0.15)},
	"sehir": {"name": "ŞEHİR İÇİ", "friction": 1.15, "bumps": 0.1, "amp": 0.35, "feat": 0.3, "surface": Color(0.3, 0.3, 0.33), "under": Color(0.2, 0.2, 0.22)},
	# Ay
	"regolit": {"name": "AY TOZU", "friction": 0.8, "bumps": 0.7, "amp": 1.0, "feat": 1.0, "surface": Color(0.74, 0.74, 0.76), "under": Color(0.5, 0.5, 0.53)},
	"krater": {"name": "KRATER ALANI", "friction": 0.75, "bumps": 1.3, "amp": 1.2, "feat": 1.25, "surface": Color(0.6, 0.6, 0.63), "under": Color(0.4, 0.4, 0.43)},
	# Uzay
	"uzay": {"name": "IŞIK YOLU", "friction": 1.05, "bumps": 0.2, "amp": 1.0, "feat": 1.0, "surface": Color(0.3, 0.95, 1.0), "under": Color(0.3, 0.1, 0.5)},
	"meteor": {"name": "METEOR KUŞAĞI", "friction": 0.95, "bumps": 1.1, "amp": 1.15, "feat": 1.2, "surface": Color(0.95, 0.4, 1.0), "under": Color(0.25, 0.08, 0.4)},
}

## ---------------- HARİTALAR (bölümler) ----------------
## Menüden seçilir. Her haritanın kendi yolları, renkleri, yer çekimi ve gökyüzü var.
const MAPS := {
	"koy": {"name": "Köy Yolları", "desc": "Asfalt, toprak, dağ, orman, çamur, kar. Klasik yük taşıma.",
		"roads": [], "amp": 1.0, "bumps": 1.0, "feat": 1.0, "feats": [], "gravity": 1.0, "sky": "",
		"station": "TESLİMAT", "price": 0, "tint": true},
	"sehir": {"name": "Şehirlerarası", "desc": "Otoyol ve şehir yolları: düzgün ve hızlı. Tırlar için ideal.",
		"roads": ["otoyol", "asfalt", "sehir"], "amp": 0.55, "bumps": 0.35, "feat": 0.4, "feats": ["none", "steep", "valley", "bumps"],
		"gravity": 1.0, "sky": "", "station": "TESLİMAT", "price": 0, "tint": true},
	"otobus": {"name": "Otobüs Hattı", "desc": "Şehirlerarası otobüsle yolcu taşı. Sarsarsan yolcu düşer!",
		"roads": ["otoyol", "sehir", "asfalt"], "amp": 0.6, "bumps": 0.4, "feat": 0.45, "feats": ["none", "steep", "valley", "bumps"],
		"gravity": 1.0, "sky": "", "station": "OTOGAR", "price": 0, "tint": true, "vehicle": "otobus"},
	"ay": {"name": "Ay Yolu", "desc": "Az yer çekimi, kraterler ve uçuşlar. Yükler havada süzülür!",
		"roads": ["regolit", "krater"], "amp": 1.05, "bumps": 0.8, "feat": 1.0, "feats": ["none", "valley", "ramp", "bumps", "rocky"],
		"gravity": 0.38, "sky": "ay", "station": "AY ÜSSÜ", "price": 300, "tint": false},
	"uzay": {"name": "Uzay Yolu", "desc": "Yıldızların arasında ışık yolu. Rampalar, meteorlar, düşük yer çekimi.",
		"roads": ["uzay", "meteor"], "amp": 1.2, "bumps": 0.9, "feat": 1.2, "feats": ["none", "ramp", "steep", "valley", "bumps"],
		"gravity": 0.55, "sky": "uzay", "station": "UZAY İSTASYONU", "price": 600, "tint": false},
}
const MAP_ZONES := {
	"sehir": [
		[Color(0.42, 0.72, 0.3), Color(0.45, 0.33, 0.21), Color(0.33, 0.24, 0.15)],
		[Color(0.58, 0.68, 0.28), Color(0.5, 0.37, 0.23), Color(0.36, 0.26, 0.16)],
		[Color(0.3, 0.6, 0.28), Color(0.42, 0.32, 0.22), Color(0.3, 0.22, 0.15)],
	],
	"ay": [
		[Color(0.82, 0.82, 0.84), Color(0.55, 0.55, 0.58), Color(0.36, 0.36, 0.39)],
		[Color(0.76, 0.75, 0.72), Color(0.5, 0.49, 0.47), Color(0.33, 0.32, 0.31)],
		[Color(0.7, 0.71, 0.75), Color(0.44, 0.45, 0.49), Color(0.28, 0.29, 0.33)],
	],
	"uzay": [
		[Color(0.3, 0.95, 1.0), Color(0.2, 0.08, 0.35), Color(0.1, 0.04, 0.2)],
		[Color(0.95, 0.4, 1.0), Color(0.22, 0.06, 0.32), Color(0.1, 0.03, 0.18)],
		[Color(0.5, 1.0, 0.6), Color(0.08, 0.14, 0.3), Color(0.04, 0.06, 0.16)],
	],
}
var map_id: String = "koy"
var smooth_k: float = 1.0   # tır/otobüs gibi uzun araçlarda yollar daha düzgün (0.5..1)


func map_def() -> Dictionary:
	return MAPS.get(map_id, MAPS["koy"])


## Haritayı ve araca göre yol düzgünlüğünü ayarla (sonra reseed çağrılmalı)
func configure(id: String, smooth: float) -> void:
	map_id = id if MAPS.has(id) else "koy"
	smooth_k = clampf(smooth, 0.4, 1.0)
var _roads: Dictionary = {}     # yol kesimi no -> tür
var _road_mats: Dictionary = {}


func road_at_index(idx: int) -> String:
	if _roads.has(idx):
		return _roads[idx]
	var kind: String = "asfalt"
	var mroads: Array = map_def()["roads"]
	if not mroads.is_empty():
		kind = String(mroads[0])
		if idx >= 2:
			var mr := RandomNumberGenerator.new()
			mr.seed = hash("yol:%d:%d:%s" % [_seed, idx, map_id])
			var prv: String = road_at_index(idx - 1)
			var opts: Array = mroads.filter(func(k): return k != prv)
			if opts.is_empty() or mr.randf() < 0.35:
				kind = prv
			else:
				kind = String(opts[mr.randi_range(0, opts.size() - 1)])
		_roads[idx] = kind
		return kind
	if idx < 2:
		kind = "asfalt"            # ilk 500 m asfalt: rahat başlangıç
	elif idx < 4:
		kind = "toprak"
	else:
		var r := RandomNumberGenerator.new()
		r.seed = hash("yol:%d:%d" % [_seed, idx])
		var d: float = difficulty_at((float(idx) + 0.5) * road_len_m * PX_PER_M)
		var kinds: Array = ["asfalt", "toprak", "dag", "orman", "camur", "kar"]
		var w: Array = [maxf(1.6 - d * 1.4, 0.2), 1.4, 0.4 + d * 1.6, 0.7 + d * 0.8, 0.25 + d * 1.2, d * 1.5]
		var prev: String = road_at_index(idx - 1)
		var total: float = 0.0
		for i in range(kinds.size()):
			if kinds[i] == prev:
				w[i] = float(w[i]) * 0.25   # aynı yol art arda pek gelmesin
			total += float(w[i])
		var pick: float = r.randf() * total
		for i in range(kinds.size()):
			pick -= float(w[i])
			if pick <= 0.0:
				kind = kinds[i]
				break
	_roads[idx] = kind
	return kind


func road_at(x: float) -> String:
	return road_at_index(floori(x / (road_len_m * PX_PER_M)))


## Yol özelliği (geçişlerde 300 px yumuşak karışım, arazi kopmasın)
func road_factor(x: float, key: String) -> float:
	var L: float = road_len_m * PX_PER_M
	var idx: int = floori(x / L)
	var t: float = x - float(idx) * L
	var cur: float = float(ROADS[road_at_index(idx)][key])
	if t < 150.0:
		var prv: float = float(ROADS[road_at_index(idx - 1)][key])
		return lerpf(prv, cur, smoothstep(-150.0, 150.0, t))
	if t > L - 150.0:
		var nxt: float = float(ROADS[road_at_index(idx + 1)][key])
		return lerpf(cur, nxt, smoothstep(-150.0, 150.0, t - L))
	return cur


func road_color(x: float, key: String) -> Color:
	var L: float = road_len_m * PX_PER_M
	var idx: int = floori(x / L)
	var t: float = x - float(idx) * L
	var cur: Color = ROADS[road_at_index(idx)][key]
	if t < 60.0:
		return (ROADS[road_at_index(idx - 1)][key] as Color).lerp(cur, smoothstep(-60.0, 60.0, t))
	if t > L - 60.0:
		return cur.lerp(ROADS[road_at_index(idx + 1)][key], smoothstep(-60.0, 60.0, t - L))
	return cur


## Yol kesimi türleri ve uyarı tabelaları
const SIGNS := {"bumps": "TÜMSEKLİ YOL", "steep": "DİK YOKUŞ", "ramp": "RAMPA!", "rocky": "KAYALIK", "valley": "ÇUKUR"}


func _ready() -> void:
	reseed(noise_seed if noise_seed != 0 else randi())


## Araziyi belirli bir tohumla yeniden kur (kayıtlı yolculuğa devam ederken aynı yollar gelsin)
func reseed(s: int, focus_x: float = 0.0) -> void:
	for k in _chunks.keys():
		(_chunks[k] as Node).queue_free()
	_chunks.clear()
	_features.clear()
	_roads.clear()
	if _start_wall != null and is_instance_valid(_start_wall):
		_start_wall.queue_free()
	_noise.seed = s
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0011
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_detail.seed = s + 17
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.011
	_detail.fractal_octaves = 1
	_seed = s
	_rock_noise.seed = s + 31
	_rock_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_rock_noise.frequency = 0.03
	_ground_mat.friction = 1.0
	_ground_mat.bounce = 0.0
	_build_start_wall()
	update_around(focus_x)


func get_seed() -> int:
	return _seed


## 0 (başlangıç) .. 1 (en zor)
## Hill Climb benzeri eğri: ilk 500 m kolay, 4.-5. teslimatta (2-2,5 km) zorluk belirgin, 6 km'de tavan
func difficulty_at(x: float) -> float:
	var m: float = maxf(x, 0.0) / PX_PER_M
	return clampf((m - easy_until_m) / (max_difficulty_at_m - easy_until_m), 0.0, 1.0)


func _raw_height(x: float) -> float:
	var d: float = difficulty_at(x)
	var md: Dictionary = map_def()
	var amp: float = lerpf(55.0, 320.0, d) * road_factor(x, "amp") * float(md["amp"]) * smooth_k   # tepe yüksekliği artar
	var stretch: float = lerpf(1.0, 1.6, d) * lerpf(0.75, 1.0, smooth_k)   # tepeler sıklaşır = daha dik
	var big: float = _noise.get_noise_1d(x * stretch)
	var bumps: float = _detail.get_noise_1d(x) * lerpf(3.0, 28.0, d) * road_factor(x, "bumps") * float(md["bumps"]) * smooth_k  # engebe artar
	return base_y - big * amp + bumps + _feature_offset(x) * road_factor(x, "feat") * float(md["feat"]) * smooth_k


## Kesim kesim yol karakteri: mesafe arttıkça zor kesimler hem sıklaşır hem büyür
func feature_at(idx: int) -> Dictionary:
	if _features.has(idx):
		return _features[idx]
	var L: float = feature_len_m * PX_PER_M
	var f := {"kind": "none", "center": (float(idx) + 0.5) * L, "half": 0.0, "h": 0.0}
	if float(idx) * L >= features_start_m * PX_PER_M:
		var r := RandomNumberGenerator.new()
		r.seed = hash("%d:%d:%s" % [_seed, idx, map_id])
		var d: float = difficulty_at(f["center"])
		var kinds: Array = ["none", "bumps", "steep", "ramp", "rocky", "valley"]
		var weights: Array = [lerpf(3.0, 0.25, d), 1.0, 0.5 + d * 2.3, 0.25 + d * 1.5, 0.15 + d * 1.9, 0.45 + d * 1.4]
		var allowed: Array = map_def()["feats"]
		if not allowed.is_empty():
			for wi in range(kinds.size()):
				if not allowed.has(kinds[wi]):
					weights[wi] = 0.0
		var total: float = 0.0
		for w in weights:
			total += float(w)
		var pick: float = r.randf() * total
		for i in range(kinds.size()):
			pick -= float(weights[i])
			if pick <= 0.0:
				f["kind"] = kinds[i]
				break
		f["center"] = float(f["center"]) + r.randf_range(-0.12, 0.12) * L
		match f["kind"]:
			"bumps":
				f["half"] = r.randf_range(500.0, 900.0)
				f["h"] = lerpf(6.0, 28.0, d)
				f["period"] = r.randf_range(85.0, 140.0)
			"steep":
				f["half"] = lerpf(1000.0, 760.0, d)
				f["h"] = lerpf(60.0, 470.0, d) * r.randf_range(0.85, 1.1)
			"ramp":
				f["half"] = 400.0
				f["h"] = lerpf(28.0, 120.0, d)
			"rocky":
				f["half"] = r.randf_range(600.0, 1000.0)
				f["h"] = lerpf(8.0, 36.0, d)
			"valley":
				f["half"] = lerpf(800.0, 620.0, d)
				f["h"] = lerpf(50.0, 360.0, d)
	_features[idx] = f
	return f


func _feature_offset(x: float) -> float:
	var L: float = feature_len_m * PX_PER_M
	var idx: int = floori(x / L)
	var off: float = 0.0
	for i in [idx - 1, idx, idx + 1]:
		var f: Dictionary = feature_at(i)
		if f["kind"] == "none":
			continue
		var c: float = f["center"]
		var half: float = f["half"]
		var h: float = f["h"]
		var u: float = (x - c) / half
		if absf(u) > 1.0:
			continue
		var win: float = clampf((1.0 - absf(u)) * 4.0, 0.0, 1.0)   # kenarlarda yumuşak giriş/çıkış
		match f["kind"]:
			"bumps":
				off -= h * (0.5 - 0.5 * cos(TAU * (x - c) / float(f["period"]))) * win
			"steep":
				off -= h * (cos(PI * u) + 1.0) * 0.5
			"valley":
				off += h * (cos(PI * u) + 1.0) * 0.5
			"rocky":
				off -= h * absf(_rock_noise.get_noise_1d(x)) * 1.6 * win
			"ramp":
				# 300 px'lik yükselen rampa, sonra sert bir iniş: kamyon havalanır
				var v: float = x - c
				if v > -300.0 and v <= 0.0:
					off -= h * smoothstep(-300.0, 0.0, v)
				elif v > 0.0 and v < 70.0:
					off -= h * (1.0 - v / 70.0)
	return off


func checkpoint_px() -> float:
	return checkpoint_interval_m * PX_PER_M


## k. teslimat noktasının x konumu (k = 1 -> 500 m)
func checkpoint_x(k: int) -> float:
	return float(k) * checkpoint_px()


## Arazinin x noktasındaki yüzey yüksekliği (y aşağı doğru artar)
func height_at(x: float) -> float:
	var cp: float = checkpoint_px()
	var k: int = maxi(roundi(x / cp), 0)
	var cx: float = float(k) * cp
	var raw: float = _raw_height(x)
	var dist: float = absf(x - cx)
	if dist < flat_half_width + flat_blend:
		var flat_h: float = _raw_height(cx)
		var w: float = 1.0
		if dist > flat_half_width:
			w = 1.0 - smoothstep(0.0, 1.0, (dist - flat_half_width) / flat_blend)
		return lerpf(raw, flat_h, w)
	return raw


## Araç nereye giderse etrafındaki parçaları hazırla, uzaktakileri sil
func update_around(x: float) -> void:
	var ci: int = floori(x / chunk_width)
	for i in range(ci - chunks_behind, ci + chunks_ahead + 1):
		if not _chunks.has(i):
			var c: Node2D = _build_chunk(i)
			add_child(c)
			_chunks[i] = c
	for key in _chunks.keys():
		var k: int = key
		if k < ci - chunks_behind or k > ci + chunks_ahead + 1:
			var old: Node2D = _chunks[k]
			old.queue_free()
			_chunks.erase(k)


## x noktasındaki bölge renkleri (istasyonlarda yumuşak geçiş)
func zone_colors_at(x: float) -> Array:
	var zones: Array = MAP_ZONES.get(map_id, ZONE_COLORS) if map_id != "otobus" else MAP_ZONES["sehir"]
	var cp: float = checkpoint_px()
	var z: float = x / cp
	var zi: int = clampi(floori(z), 0, zones.size() - 1)
	var zn: int = clampi(zi + 1, 0, zones.size() - 1)
	if map_id != "koy":   # özel haritalarda renkler döngüsel
		zi = posmod(floori(z), zones.size())
		zn = posmod(zi + 1, zones.size())
	var f: float = smoothstep(0.92, 1.0, z - float(floori(z))) if x > 0.0 else 0.0
	var a: Array = zones[zi]
	var b: Array = zones[zn]
	return [(a[0] as Color).lerp(b[0], f), (a[1] as Color).lerp(b[1], f), (a[2] as Color).lerp(b[2], f)]


func _build_chunk(i: int) -> Node2D:
	var x0: float = float(i) * chunk_width
	var root := Node2D.new()
	root.name = "Chunk_%d" % i

	var top := PackedVector2Array()
	var n: int = int(chunk_width / point_spacing)
	for j in range(n + 1):
		var x: float = x0 + float(j) * point_spacing
		top.append(Vector2(x, height_at(x)))
	var bottom_y: float = base_y + 1600.0

	var poly := PackedVector2Array(top)
	poly.append(Vector2(x0 + chunk_width, bottom_y))
	poly.append(Vector2(x0, bottom_y))

	# --- fizik ---
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var rk: String = road_at(x0 + chunk_width * 0.5)
	if not _road_mats.has(rk):
		var pm := PhysicsMaterial.new()
		pm.friction = float(ROADS[rk]["friction"])
		pm.bounce = 0.0
		_road_mats[rk] = pm
	body.physics_material_override = _road_mats[rk]
	var col := CollisionPolygon2D.new()
	col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS   # düz alanlarda da sorunsuz
	col.polygon = poly
	body.add_child(col)
	root.add_child(body)

	# --- görsel: toprak + derin katman + çim ---
	var dirt := Polygon2D.new()
	dirt.polygon = poly
	var dvc := PackedColorArray()
	for p in poly:
		dvc.append(zone_colors_at(p.x)[1])
	dirt.vertex_colors = dvc
	root.add_child(dirt)

	# katmanlı toprak: üst toprak, koyu toprak, kil, çakıllı katman, kaya
	# (her katman yüzeyi dalgalı takip eder; renkler bölgeye göre)
	var strata: Array = [
		[38.0, 1, 0.12, Color(0, 0, 0, 0)],
		[95.0, 1, 0.0, Color(0.62, 0.36, 0.24)],     # kil (kızılımsı)
		[165.0, 2, 0.0, Color(0, 0, 0, 0)],
		[250.0, 2, 0.0, Color(0.42, 0.40, 0.38)],    # kaya katmanı
		[370.0, 2, 0.35, Color(0, 0, 0, 0)],
	]
	for li in range(strata.size()):
		var L: Array = strata[li]
		var depth: float = L[0]
		var pts := PackedVector2Array()
		for p in top:
			var wav: float = _detail.get_noise_1d(p.x * 0.6 + depth * 7.0) * 14.0
			pts.append(p + Vector2(0, depth + wav))
		pts.append(Vector2(x0 + chunk_width, bottom_y))
		pts.append(Vector2(x0, bottom_y))
		var layer := Polygon2D.new()
		layer.polygon = pts
		var vcs := PackedColorArray()
		for p in pts:
			var zc: Array = zone_colors_at(p.x)
			var base: Color = zc[int(L[1])]
			var tint: Color = L[3]
			if tint.a > 0.0 and bool(map_def()["tint"]):
				base = base.lerp(Color(tint.r, tint.g, tint.b), 0.45)
			vcs.append(base.darkened(float(L[2])))
		layer.vertex_colors = vcs
		root.add_child(layer)
		# katman sınırına ince koyu çizgi
		var edge_ln := Line2D.new()
		edge_ln.points = pts.slice(0, top.size())
		edge_ln.width = 3.0
		edge_ln.default_color = Color(0, 0, 0, 0.16)
		root.add_child(edge_ln)
	# toprağın içinde çakıl taşları
	var pr := RandomNumberGenerator.new()
	pr.seed = hash("cakil:%d:%d" % [_seed, i])
	var px: float = x0
	while px < x0 + chunk_width:
		px += pr.randf_range(28.0, 70.0)
		var surf: float = height_at(px)
		var py: float = surf + pr.randf_range(24.0, 420.0)
		var r: float = pr.randf_range(3.0, 9.0)
		var peb := Polygon2D.new()
		var pp := PackedVector2Array()
		for k in range(7):
			var a: float = TAU * float(k) / 7.0
			pp.append(Vector2(cos(a) * r * pr.randf_range(0.8, 1.3), sin(a) * r * 0.75))
		peb.polygon = pp
		peb.position = Vector2(px, py)
		var pc: Color = zone_colors_at(px)[1]
		peb.color = pc.darkened(0.35) if pr.randf() < 0.6 else pc.lightened(0.18)
		root.add_child(peb)
	# çim çizgisi: bölge rengine göre degrade
	var gg := Gradient.new()
	var offs := PackedFloat32Array()
	var gcols := PackedColorArray()
	var gdark := PackedColorArray()
	for k in range(0, top.size(), 4):
		offs.append(float(k) / float(top.size() - 1))
		var rx: float = top[k].x
		var zc: Color = zone_colors_at(rx)[0] if road_at(rx) == "toprak" else road_color(rx, "surface")
		gcols.append(zc)
		gdark.append(road_color(rx, "under") if road_at(rx) != "toprak" else zc.darkened(0.42))
	gg.offsets = offs
	gg.colors = gcols
	var gd := Gradient.new()
	gd.offsets = offs
	gd.colors = gdark

	var edge := Line2D.new()
	edge.points = top
	edge.width = 22.0
	edge.gradient = gd
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	edge.position = Vector2(0, 6)
	root.add_child(edge)

	var grass := Line2D.new()
	grass.points = top
	grass.width = 12.0
	grass.gradient = gg
	grass.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(grass)
	# çim tutamları
	var tr := RandomNumberGenerator.new()
	tr.seed = hash("cim:%d:%d" % [_seed, i])
	var tx: float = x0
	while tx < x0 + chunk_width:
		tx += tr.randf_range(30.0, 90.0)
		var rkt: String = road_at(tx)
		if not ["toprak", "dag", "orman"].has(rkt):
			continue
		var ty: float = height_at(tx)
		var gc: Color = zone_colors_at(tx)[0] if rkt != "orman" else Color(0.22, 0.45, 0.18)
		var tuft := Polygon2D.new()
		var hh: float = tr.randf_range(7.0, 14.0)
		tuft.polygon = PackedVector2Array([Vector2(-7, 2), Vector2(-5, -hh * 0.7), Vector2(-2, 0), Vector2(0, -hh), Vector2(2, 0), Vector2(5, -hh * 0.8), Vector2(7, 2)])
		tuft.position = Vector2(tx, ty - 2)
		tuft.color = gc.darkened(tr.randf_range(0.0, 0.25))
		root.add_child(tuft)

	_build_road_decor(root, x0, top, i)

	# --- uyarı tabelaları ve kayalar ---
	var L: float = feature_len_m * PX_PER_M
	for fi in range(floori(x0 / L) - 1, floori((x0 + chunk_width) / L) + 2):
		var f: Dictionary = feature_at(fi)
		if f["kind"] == "none":
			continue
		var sx: float = float(f["center"]) - float(f["half"]) - 260.0
		if sx >= x0 and sx < x0 + chunk_width and _flat_weight(sx) < 0.5:
			_build_sign(root, sx, String(SIGNS[f["kind"]]))
		if f["kind"] == "rocky":
			var rr := RandomNumberGenerator.new()
			rr.seed = hash("rock:%d:%d" % [_seed, i])
			var rx: float = maxf(x0, float(f["center"]) - float(f["half"]))
			while rx < minf(x0 + chunk_width, float(f["center"]) + float(f["half"])):
				_build_rock(root, Vector2(rx, height_at(rx)), rr)
				rx += rr.randf_range(70.0, 190.0)

	# --- bu parçada teslimat noktası var mı? ---
	var cp: float = checkpoint_px()
	var k0: int = maxi(ceili(x0 / cp), 0)
	var cx: float = float(k0) * cp
	if cx >= x0 and cx < x0 + chunk_width:
		_build_station(root, k0, cx)
	return root


func _build_station(root: Node2D, k: int, cx: float) -> void:
	var y: float = height_at(cx)
	var st := Node2D.new()
	st.name = "Station_%d" % k
	st.position = Vector2(cx, y)
	st.z_index = -1
	root.add_child(st)

	# beton zemin
	var pad := Polygon2D.new()
	var hw: float = flat_half_width - 60.0
	pad.polygon = PackedVector2Array([Vector2(-hw, -3), Vector2(hw, -3), Vector2(hw, 16), Vector2(-hw, 16)])
	pad.color = Color(0.62, 0.62, 0.6)
	st.add_child(pad)
	var stripe := Line2D.new()
	stripe.points = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)])
	stripe.width = 4.0
	stripe.default_color = Color(0.95, 0.8, 0.15)
	st.add_child(stripe)

	if k == 0:
		_add_label(st, "BAŞLANGIÇ", Vector2(-120, -230), 30)
		return

	# depo binası
	var bx: float = 150.0
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([Vector2(bx, -3), Vector2(bx, -150), Vector2(bx + 230, -150), Vector2(bx + 230, -3)])
	wall.color = Color(0.78, 0.36, 0.22)
	st.add_child(wall)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(bx - 16, -150), Vector2(bx + 115, -215), Vector2(bx + 246, -150)])
	roof.color = Color(0.32, 0.33, 0.38)
	st.add_child(roof)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([Vector2(bx + 70, -3), Vector2(bx + 70, -100), Vector2(bx + 160, -100), Vector2(bx + 160, -3)])
	door.color = Color(0.25, 0.25, 0.28)
	st.add_child(door)
	for r in range(5):
		var ln := Line2D.new()
		var yy: float = -90.0 + float(r) * 18.0
		ln.points = PackedVector2Array([Vector2(bx + 72, yy), Vector2(bx + 158, yy)])
		ln.width = 3.0
		ln.default_color = Color(0.4, 0.4, 0.44)
		st.add_child(ln)

	# bayrak direği
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -260)])
	pole.width = 7.0
	pole.default_color = Color(0.85, 0.85, 0.88)
	st.add_child(pole)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(3, -258), Vector2(95, -232), Vector2(3, -206)])
	flag.color = Color(0.1, 0.75, 0.35)
	st.add_child(flag)
	if map_id == "otobus":
		_build_bus_stop(st)
	elif map_id == "ay" or map_id == "uzay":
		wall.color = Color(0.82, 0.84, 0.88) if map_id == "ay" else Color(0.25, 0.2, 0.45)
		roof.color = Color(0.55, 0.6, 0.7) if map_id == "ay" else Color(0.3, 0.9, 1.0)
		flag.color = Color(0.2, 0.5, 1.0) if map_id == "ay" else Color(1.0, 0.4, 0.95)
	_add_label(st, "%s\n%d m" % [String(map_def()["station"]), int(k * checkpoint_interval_m)], Vector2(-110, -380), 30)


## Otogar: durak sundurması ve bekleyen yolcular
func _build_bus_stop(st: Node2D) -> void:
	var shelter := Polygon2D.new()
	shelter.polygon = PackedVector2Array([Vector2(-330, -3), Vector2(-330, -150), Vector2(-160, -165), Vector2(-160, -3)])
	shelter.color = Color(0.55, 0.75, 0.9, 0.35)
	st.add_child(shelter)
	var top := Line2D.new()
	top.points = PackedVector2Array([Vector2(-340, -150), Vector2(-150, -168)])
	top.width = 8.0
	top.default_color = Color(0.85, 0.15, 0.15)
	st.add_child(top)
	var r := RandomNumberGenerator.new()
	r.seed = hash(st.name)
	for i in range(5):
		var px: float = -310.0 + float(i) * 34.0
		var person := Node2D.new()
		person.position = Vector2(px, -3)
		st.add_child(person)
		var shirt := Polygon2D.new()
		shirt.polygon = PackedVector2Array([Vector2(-8, -18), Vector2(8, -18), Vector2(9, -44), Vector2(-9, -44)])
		shirt.color = [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.25, 0.65, 0.35), Color(0.85, 0.65, 0.15)][r.randi_range(0, 3)]
		person.add_child(shirt)
		var legs := Polygon2D.new()
		legs.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(7, -18), Vector2(-7, -18)])
		legs.color = Color(0.2, 0.22, 0.3)
		person.add_child(legs)
		var head := Polygon2D.new()
		var hp := PackedVector2Array()
		for q in range(12):
			var a: float = TAU * float(q) / 12.0
			hp.append(Vector2(cos(a), sin(a)) * 7.0 + Vector2(0, -52))
		head.polygon = hp
		head.color = [Color(0.95, 0.78, 0.62), Color(0.78, 0.56, 0.4), Color(0.6, 0.42, 0.3)][i % 3]
		person.add_child(head)


## Yol türüne göre süslemeler: asfalt şerit + bariyer, orman çam ağaçları, dağ kayaları,
## çamur gölcükleri, kar tümsekleri, toprak yol tekerlek izleri. Her yol başında mavi tabela.
func _build_road_decor(root: Node2D, x0: float, top: PackedVector2Array, ci: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("susler:%d:%d" % [_seed, ci])
	var L: float = road_len_m * PX_PER_M
	# yol tabelası
	for ri in range(floori(x0 / L), floori((x0 + chunk_width) / L) + 1):
		var sx: float = float(ri) * L + 120.0
		if sx >= x0 and sx < x0 + chunk_width and ri > 0 and _flat_weight(sx) < 0.5:
			_build_road_sign(root, sx, String(ROADS[road_at_index(ri)]["name"]))
	# asfalt: kesik şerit çizgisi + bariyer
	var k: int = 0
	while k < top.size() - 1:
		var p0: Vector2 = top[k]
		var rk: String = road_at(p0.x)
		match rk:
			"asfalt":
				if k % 3 == 0 and k + 1 < top.size():
					var dash := Line2D.new()
					dash.points = PackedVector2Array([top[k] + Vector2(0, 3), top[k + 1] + Vector2(-8, 3)])
					dash.width = 3.0
					dash.default_color = Color(0.95, 0.93, 0.8)
					root.add_child(dash)
				if k % 4 == 0:
					var post := Line2D.new()
					post.points = PackedVector2Array([p0 + Vector2(0, 2), p0 + Vector2(0, -26)])
					post.width = 4.0
					post.default_color = Color(0.55, 0.57, 0.6)
					post.z_index = -1
					root.add_child(post)
					if k + 4 < top.size():
						var rail := Line2D.new()
						rail.points = PackedVector2Array([p0 + Vector2(0, -22), top[k + 4] + Vector2(0, -22)])
						rail.width = 5.0
						rail.default_color = Color(0.78, 0.8, 0.83)
						rail.z_index = -1
						root.add_child(rail)
			"toprak":
				if r.randf() < 0.35:
					var rut := Line2D.new()
					rut.points = PackedVector2Array([p0 + Vector2(0, 4), p0 + Vector2(r.randf_range(10, 22), 4.5)])
					rut.width = 2.0
					rut.default_color = Color(0.4, 0.28, 0.18, 0.8)
					root.add_child(rut)
			"orman":
				if r.randf() < 0.22:
					_build_pine(root, p0 + Vector2(0, 4), r)
				if r.randf() < 0.25:
					var root_ln := Line2D.new()
					root_ln.points = PackedVector2Array([p0 + Vector2(-8, 2), p0 + Vector2(0, -3), p0 + Vector2(10, 1)])
					root_ln.width = 3.0
					root_ln.default_color = Color(0.32, 0.22, 0.14)
					root.add_child(root_ln)
			"dag":
				if r.randf() < 0.12:
					var boulder := Polygon2D.new()
					var br: float = r.randf_range(18.0, 40.0)
					var bp := PackedVector2Array()
					for q in range(8):
						var a: float = PI + PI * float(q) / 7.0
						bp.append(Vector2(cos(a), sin(a)) * br * r.randf_range(0.8, 1.15))
					boulder.polygon = bp
					boulder.position = p0 + Vector2(0, 8)
					boulder.color = Color(0.45, 0.44, 0.43).darkened(r.randf_range(0.0, 0.2))
					boulder.z_index = -1
					root.add_child(boulder)
			"camur":
				if r.randf() < 0.18:
					var pud := Polygon2D.new()
					var pw: float = r.randf_range(22.0, 50.0)
					var pp := PackedVector2Array()
					for q in range(12):
						var a2: float = TAU * float(q) / 12.0
						pp.append(Vector2(cos(a2) * pw, sin(a2) * 4.0))
					pud.polygon = pp
					pud.position = p0 + Vector2(0, 2)
					pud.color = Color(0.35, 0.3, 0.26, 0.85)
					root.add_child(pud)
					var shine := Line2D.new()
					shine.points = PackedVector2Array([p0 + Vector2(-pw * 0.5, 1), p0 + Vector2(-pw * 0.1, 1)])
					shine.width = 1.5
					shine.default_color = Color(0.85, 0.9, 1.0, 0.6)
					root.add_child(shine)
			"kar":
				if r.randf() < 0.2:
					var drift := Polygon2D.new()
					var dw: float = r.randf_range(16.0, 34.0)
					var dp := PackedVector2Array()
					for q in range(9):
						var a3: float = PI + PI * float(q) / 8.0
						dp.append(Vector2(cos(a3) * dw, sin(a3) * dw * 0.4))
					drift.polygon = dp
					drift.position = p0 + Vector2(0, 3)
					drift.color = Color(1, 1, 1)
					root.add_child(drift)
			"otoyol", "sehir":
				if k % 3 == 0 and k + 1 < top.size():
					var dash2 := Line2D.new()
					dash2.points = PackedVector2Array([top[k] + Vector2(0, 3), top[k + 1] + Vector2(-8, 3)])
					dash2.width = 3.0
					dash2.default_color = Color(0.98, 0.98, 0.98) if rk == "otoyol" else Color(0.98, 0.82, 0.2)
					root.add_child(dash2)
				if rk == "otoyol" and k % 2 == 0 and k + 2 < top.size():
					var rail2 := Line2D.new()
					rail2.points = PackedVector2Array([p0 + Vector2(0, -20), top[k + 2] + Vector2(0, -20)])
					rail2.width = 6.0
					rail2.default_color = Color(0.8, 0.82, 0.86)
					rail2.z_index = -1
					root.add_child(rail2)
					var post2 := Line2D.new()
					post2.points = PackedVector2Array([p0 + Vector2(0, 2), p0 + Vector2(0, -24)])
					post2.width = 4.0
					post2.default_color = Color(0.5, 0.52, 0.56)
					post2.z_index = -1
					root.add_child(post2)
				if k % 14 == 0:
					_build_lamp(root, p0)
				if rk == "sehir" and k % 5 == 0:
					_build_building(root, p0, r)
			"regolit", "krater":
				if r.randf() < (0.1 if rk == "regolit" else 0.22):
					_build_crater(root, p0, r)
			"uzay", "meteor":
				if k % 6 == 0:
					var beacon := Line2D.new()
					beacon.points = PackedVector2Array([p0 + Vector2(0, 2), p0 + Vector2(0, -30)])
					beacon.width = 3.0
					beacon.default_color = Color(0.6, 0.6, 0.75)
					beacon.z_index = -1
					root.add_child(beacon)
					var glow := Polygon2D.new()
					var gpts := PackedVector2Array()
					for q in range(10):
						var a4: float = TAU * float(q) / 10.0
						gpts.append(Vector2(cos(a4), sin(a4)) * 6.0)
					glow.polygon = gpts
					glow.position = p0 + Vector2(0, -32)
					glow.color = road_color(p0.x, "surface")
					glow.z_index = -1
					root.add_child(glow)
				if rk == "meteor" and r.randf() < 0.12:
					_build_rock(root, p0 + Vector2(0, 4), r)
				if r.randf() < 0.05:
					_build_crystal(root, p0, r)
		k += 1


func _build_lamp(root: Node2D, p: Vector2) -> void:
	var lamp := Node2D.new()
	lamp.position = p
	lamp.z_index = -2
	root.add_child(lamp)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 2), Vector2(0, -150), Vector2(26, -158)])
	pole.width = 5.0
	pole.default_color = Color(0.45, 0.47, 0.52)
	lamp.add_child(pole)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(18, -162), Vector2(40, -162), Vector2(36, -154), Vector2(20, -154)])
	head.color = Color(1.0, 0.92, 0.6)
	lamp.add_child(head)


func _build_building(root: Node2D, p: Vector2, r: RandomNumberGenerator) -> void:
	var b := Node2D.new()
	b.position = p + Vector2(0, 30)
	b.z_index = -3
	root.add_child(b)
	var w: float = r.randf_range(70.0, 130.0)
	var h: float = r.randf_range(140.0, 330.0)
	var col: Color = [Color(0.62, 0.6, 0.58), Color(0.72, 0.55, 0.45), Color(0.5, 0.56, 0.64), Color(0.8, 0.76, 0.66)][r.randi_range(0, 3)]
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-w * 0.5, -h), Vector2(w * 0.5, -h), Vector2(w * 0.5, 0)])
	wall.color = col.darkened(0.15)
	b.add_child(wall)
	var yy: float = -h + 16.0
	while yy < -46.0:
		var xx: float = -w * 0.5 + 10.0
		while xx + 14.0 < w * 0.5 - 6.0:
			var win := Polygon2D.new()
			win.polygon = PackedVector2Array([Vector2(xx, yy), Vector2(xx + 14, yy), Vector2(xx + 14, yy + 18), Vector2(xx, yy + 18)])
			win.color = Color(1.0, 0.88, 0.5) if r.randf() < 0.35 else Color(0.35, 0.45, 0.58)
			b.add_child(win)
			xx += 22.0
		yy += 30.0


func _build_crater(root: Node2D, p: Vector2, r: RandomNumberGenerator) -> void:
	var cw: float = r.randf_range(24.0, 60.0)
	var rim := Polygon2D.new()
	var pts := PackedVector2Array()
	for q in range(14):
		var a: float = TAU * float(q) / 14.0
		pts.append(Vector2(cos(a) * cw, sin(a) * cw * 0.18))
	rim.polygon = pts
	rim.position = p + Vector2(0, 4)
	rim.color = Color(0.42, 0.42, 0.45, 0.9)
	root.add_child(rim)
	var lip := Line2D.new()
	lip.points = PackedVector2Array([p + Vector2(-cw, 3), p + Vector2(-cw * 0.4, 0), p + Vector2(cw * 0.4, 0), p + Vector2(cw, 3)])
	lip.width = 2.0
	lip.default_color = Color(0.9, 0.9, 0.92, 0.7)
	root.add_child(lip)


func _build_crystal(root: Node2D, p: Vector2, r: RandomNumberGenerator) -> void:
	var c := Polygon2D.new()
	var h: float = r.randf_range(26.0, 60.0)
	c.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(0, -h), Vector2(8, 0), Vector2(0, 6)])
	c.position = p + Vector2(r.randf_range(-6, 6), 2)
	c.color = Color(0.55, 0.95, 1.0, 0.85) if r.randf() < 0.5 else Color(1.0, 0.5, 0.95, 0.85)
	c.z_index = -2
	root.add_child(c)


func _build_pine(root: Node2D, p: Vector2, r: RandomNumberGenerator) -> void:
	var tree := Node2D.new()
	tree.position = p
	tree.z_index = -2
	var sc: float = r.randf_range(0.8, 1.4)
	tree.scale = Vector2(sc, sc)
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(4, -40), Vector2(-4, -40)])
	trunk.color = Color(0.35, 0.24, 0.15)
	tree.add_child(trunk)
	var g: Color = Color(0.13, 0.36, 0.2).darkened(r.randf_range(0.0, 0.2))
	for t in range(3):
		var w: float = 38.0 - float(t) * 9.0
		var y0: float = -28.0 - float(t) * 30.0
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([Vector2(-w, y0), Vector2(w, y0), Vector2(0, y0 - 46.0)])
		tri.color = g.lightened(float(t) * 0.06)
		tree.add_child(tri)
	root.add_child(tree)


func _build_road_sign(root: Node2D, x: float, text: String) -> void:
	var y: float = height_at(x)
	var sg := Node2D.new()
	sg.position = Vector2(x, y)
	sg.z_index = -1
	root.add_child(sg)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 4), Vector2(0, -120)])
	pole.width = 6.0
	pole.default_color = Color(0.55, 0.57, 0.6)
	sg.add_child(pole)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(-80, -170), Vector2(80, -170), Vector2(80, -118), Vector2(-80, -118)])
	board.color = Color(0.1, 0.3, 0.7)
	sg.add_child(board)
	var frame := Line2D.new()
	frame.points = PackedVector2Array([Vector2(-76, -166), Vector2(76, -166), Vector2(76, -122), Vector2(-76, -122), Vector2(-76, -166)])
	frame.width = 2.5
	frame.default_color = Color.WHITE
	sg.add_child(frame)
	var lb := Label.new()
	lb.text = text
	lb.position = Vector2(-80, -166)
	lb.custom_minimum_size = Vector2(160, 44)
	lb.size = Vector2(160, 44)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 17)
	lb.add_theme_color_override("font_color", Color.WHITE)
	sg.add_child(lb)


func _flat_weight(x: float) -> float:
	var cp: float = checkpoint_px()
	var k: int = maxi(roundi(x / cp), 0)
	var dist: float = absf(x - float(k) * cp)
	if dist < flat_half_width:
		return 1.0
	if dist < flat_half_width + flat_blend:
		return 1.0 - smoothstep(0.0, 1.0, (dist - flat_half_width) / flat_blend)
	return 0.0


func _build_sign(root: Node2D, x: float, text: String) -> void:
	var y: float = height_at(x)
	var sg := Node2D.new()
	sg.position = Vector2(x, y)
	sg.z_index = -1
	root.add_child(sg)
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 4), Vector2(0, -120)])
	pole.width = 6.0
	pole.default_color = Color(0.55, 0.57, 0.6)
	sg.add_child(pole)
	var border := Polygon2D.new()
	border.polygon = PackedVector2Array([Vector2(0, -190), Vector2(40, -150), Vector2(0, -110), Vector2(-40, -150)])
	border.color = Color(0.1, 0.1, 0.1)
	sg.add_child(border)
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(0, -184), Vector2(34, -150), Vector2(0, -116), Vector2(-34, -150)])
	face.color = Color(1.0, 0.8, 0.1)
	sg.add_child(face)
	var ex := Line2D.new()
	ex.points = PackedVector2Array([Vector2(0, -170), Vector2(0, -146)])
	ex.width = 6.0
	ex.default_color = Color(0.1, 0.1, 0.1)
	sg.add_child(ex)
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([Vector2(-3, -138), Vector2(3, -138), Vector2(3, -132), Vector2(-3, -132)])
	dot.color = Color(0.1, 0.1, 0.1)
	sg.add_child(dot)
	_add_label(sg, text, Vector2(-110, -240), 22)


func _build_rock(root: Node2D, p: Vector2, r: RandomNumberGenerator) -> void:
	var rad: float = r.randf_range(10.0, 26.0)
	var pts := PackedVector2Array()
	var n: int = 7
	for i in range(n):
		var a: float = PI + PI * float(i) / float(n - 1)
		pts.append(Vector2(cos(a), sin(a) * 0.8) * rad * r.randf_range(0.75, 1.15))
	pts.append(Vector2(rad * 0.9, 8))
	pts.append(Vector2(-rad * 0.9, 8))
	var rock := Polygon2D.new()
	rock.polygon = pts
	rock.position = p + Vector2(0, 6)
	rock.color = Color(0.52, 0.5, 0.48).darkened(r.randf_range(0.0, 0.25))
	rock.z_index = -1
	root.add_child(rock)


func _add_label(parent: Node, text: String, pos: Vector2, size: int) -> void:
	var lb := Label.new()
	lb.text = text
	lb.position = pos
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.custom_minimum_size = Vector2(220, 0)
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.add_theme_constant_override("outline_size", 8)
	parent.add_child(lb)


## Başlangıcın gerisine kalın bir kaya duvarı: geri giderken boşluğa düşülmesin
func _build_start_wall() -> void:
	var wx: float = -flat_half_width - flat_blend - 120.0
	var y: float = height_at(wx)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.physics_material_override = _ground_mat
	var pts := PackedVector2Array([Vector2(wx - 80, y - 700), Vector2(wx + 40, y - 700), Vector2(wx + 40, y + 300), Vector2(wx - 80, y + 300)])
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	wall.add_child(col)
	var vis := Polygon2D.new()
	vis.polygon = pts
	vis.color = Color(0.4, 0.38, 0.36)
	wall.add_child(vis)
	add_child(wall)
	_start_wall = wall
