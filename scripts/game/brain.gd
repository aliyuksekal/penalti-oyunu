extends RefCounted
## "Seni Okuyor" yapay zekâsı. Oyuncunun şut ve dalış alışkanlıklarını 9 bölgelik
## bir ızgarada sayar; tahmini üç kaynağın ağırlıklı karışımıyla yapar:
##   genel sıklık + bir önceki şuttan sonraki eğilim + skor baskısına göre eğilim.
## Bölgeler: 0 1 2 (üst) / 3 4 5 (orta) / 6 7 8 (alt), oyuncunun bakış açısından sol→sağ.
## Tüm öğrenme cihazda kalır (Save.ai).

const ZONE_X: Array[float] = [-2.55, 0.0, 2.55]
const ZONE_Y: Array[float] = [1.95, 1.2, 0.38]


static func zone_of(x: float, y: float) -> int:
	var col: int = 0 if x < -1.2 else (2 if x > 1.2 else 1)
	var row: int = 0 if y > 1.6 else (1 if y > 0.8 else 2)
	return row * 3 + col


static func zone_center(z: int) -> Vector2:
	return Vector2(ZONE_X[z % 3], ZONE_Y[int(z / 3)])


static func pressure_index(my_score: int, opp_score: int) -> int:
	if my_score < opp_score:
		return 0
	if my_score > opp_score:
		return 2
	return 1


func _row(arr: Array, start: int) -> Array[float]:
	var out: Array[float] = []
	for i in 9:
		out.append(float(arr[start + i]))
	return out


func _norm(v: Array[float], prior: float) -> Array[float]:
	var s: float = 0.0
	for x in v:
		s += x + prior
	var out: Array[float] = []
	for x in v:
		out.append((x + prior) / maxf(s, 0.0001))
	return out


## Oyuncunun bir sonraki şut bölgesi için olasılıklar
func predict_shot(pressure: int) -> Array[float]:
	var a: Dictionary = Save.ai
	var g: Array[float] = _norm(_row(a["shot_global"], 0), 0.6)
	var last: int = int(a["last_shot"])
	var after: Array[float] = _norm(_row(a["shot_after"], last * 9), 0.6) if last >= 0 else g
	var pr: Array[float] = _norm(_row(a["shot_pressure"], pressure * 9), 0.6)
	var n: float = 0.0
	for x in a["shot_global"]:
		n += float(x)
	# az veri varken genel sıklığa, veri arttıkça bağlama daha çok güven
	var w_ctx: float = clampf(n / 40.0, 0.0, 0.6)
	var out: Array[float] = []
	for i in 9:
		out.append(g[i] * (1.0 - w_ctx) + (after[i] * 0.55 + pr[i] * 0.45) * w_ctx)
	return _norm(out, 0.0)


func record_shot(zone: int, pressure: int, predicted: Array[float]) -> void:
	var a: Dictionary = Save.ai
	# tahmin başarısını ölç (bu, oyuncuya gösterilen "seni okuyor" yüzdesidir)
	var best: int = argmax(predicted)
	a["pred_total"] = int(a["pred_total"]) + 1
	if best == zone:
		a["pred_zone_hits"] = int(a["pred_zone_hits"]) + 1
	if best % 3 == zone % 3:
		a["pred_side_hits"] = int(a["pred_side_hits"]) + 1
	# öğrenme (yakın geçmiş daha ağır: eski sayımlar hafifçe sönümlenir)
	var gl: Array = a["shot_global"]
	for i in 9:
		gl[i] = float(gl[i]) * 0.97
	gl[zone] = float(gl[zone]) + 1.0
	var last: int = int(a["last_shot"])
	if last >= 0:
		var af: Array = a["shot_after"]
		af[last * 9 + zone] = float(af[last * 9 + zone]) + 1.0
	var pp: Array = a["shot_pressure"]
	pp[pressure * 9 + zone] = float(pp[pressure * 9 + zone]) + 1.0
	a["last_shot"] = zone


## Oyuncu kaleciyken dalış alışkanlığı
func predict_dive() -> Array[float]:
	var a: Dictionary = Save.ai
	var g: Array[float] = _norm(_row(a["dive_global"], 0), 0.8)
	var last: int = int(a["last_dive"])
	if last < 0:
		return g
	var af: Array[float] = _norm(_row(a["dive_after"], last * 9), 0.8)
	var out: Array[float] = []
	for i in 9:
		out.append(g[i] * 0.6 + af[i] * 0.4)
	return _norm(out, 0.0)


func record_dive(zone: int) -> void:
	var a: Dictionary = Save.ai
	var gl: Array = a["dive_global"]
	for i in 9:
		gl[i] = float(gl[i]) * 0.97
	gl[zone] = float(gl[zone]) + 1.0
	var last: int = int(a["last_dive"])
	if last >= 0:
		var af: Array = a["dive_after"]
		af[last * 9 + zone] = float(af[last * 9 + zone]) + 1.0
	a["last_dive"] = zone


func reading_percent() -> int:
	## Yapay zekânın şut yönünü (sol/orta/sağ) doğru tahmin etme oranı
	var a: Dictionary = Save.ai
	var t: int = int(a["pred_total"])
	# az veride abartmamak için önsel (1 isabet / 3 deneme ≈ %33 şans düzeyi)
	return int(round(100.0 * (float(a["pred_side_hits"]) + 1.0) / (float(t) + 3.0)))


static func argmax(v: Array[float]) -> int:
	var b: int = 0
	for i in v.size():
		if v[i] > v[b]:
			b = i
	return b


static func sample(v: Array[float], rng: RandomNumberGenerator, sharp: float = 1.0) -> int:
	var w: Array[float] = []
	var s: float = 0.0
	for x in v:
		var p: float = pow(maxf(x, 0.0001), sharp)
		w.append(p)
		s += p
	var r: float = rng.randf() * s
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return w.size() - 1
