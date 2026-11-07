extends Node
## Penaltı serisi mantığı: 5+5 atış, sonra seri penaltı. Sıra: oyuncu şut atar, sonra
## yapay zekâ şut atar (oyuncu kaleci). Yapay zekâ kaleci, oyuncunun alışkanlıklarından
## öğrendiği tahminle köşe seçer; yapay zekâ şutçu, oyuncunun dalış alışkanlığının
## tersine vurmaya çalışır.

signal phase_changed(phase: String)
signal outcome(kind: String, player_shooting: bool, zone: int)
signal score_changed
signal taunt(text: String)
signal reading_changed(pct: int)
signal finished(win: bool, summary: Dictionary)

const Brain = preload("res://scripts/game/brain.gd")
const World = preload("res://scripts/world/world.gd")
const DIFF_BONUS: Array[float] = [-0.22, 0.0, 0.14, 0.28]
const COIN_MULT: Array[float] = [0.8, 1.0, 1.3, 1.7]
const AI_MISS: Array[float] = [0.2, 0.12, 0.07, 0.04]

var world: World
var brain := Brain.new()
var rng := RandomNumberGenerator.new()

var level: int = -1
var diff: int = 1
var style: int = 0
var skill: float = 0.4
var follow: float = 0.5

var my_goals: int = 0
var ai_goals: int = 0
var my_marks: Array[int] = []
var ai_marks: Array[int] = []
var turn: int = 0
var phase: String = "idle"
var sudden: bool = false

var _pred: Array[float] = []
var _keeper_zone: int = 4
var _pressure: int = 1
var _ai_target: Vector2 = Vector2.ZERO
var _ai_power: float = 0.7
var _kick_at: float = 0.0
var _phase_t: float = 0.0
var _dive: Vector2 = Vector2(0, 1.0)
var _dive_time: float = -1.0
var _dived: bool = false
var hint_zone: int = -1

# maç özeti
var match_shot_zones: Array[int] = []
var match_pred_side_hits: int = 0
var match_saves: int = 0
var _running: bool = false


func setup(w: World, level_idx: int, difficulty: int) -> void:
	world = w
	rng.randomize()
	level = level_idx
	diff = difficulty
	var lv: int = level_idx if level_idx >= 0 else 8
	style = lv % 4
	skill = clampf(0.28 + lv * 0.026 + DIFF_BONUS[diff], 0.08, 0.95)
	follow = clampf(0.38 + lv * 0.025 + DIFF_BONUS[diff], 0.1, 0.95)
	if style == 3:
		follow = minf(0.97, follow + 0.12)
	elif style == 1:
		follow = maxf(0.1, follow - 0.1)
	my_goals = 0
	ai_goals = 0
	my_marks.assign([-1, -1, -1, -1, -1])
	ai_marks.assign([-1, -1, -1, -1, -1])
	turn = 0
	sudden = false
	match_shot_zones.assign([0, 0, 0, 0, 0, 0, 0, 0, 0])
	match_pred_side_hits = 0
	match_saves = 0


func start() -> void:
	_running = true
	reading_changed.emit(brain.reading_percent())
	score_changed.emit()
	await get_tree().create_timer(0.4, false).timeout
	_next_turn()


func stop() -> void:
	_running = false
	phase = "over"


func _process(delta: float) -> void:
	_phase_t += delta


func _decided() -> int:
	## 1 = oyuncu kazandı, -1 = kaybetti, 0 = devam
	var my_shots: int = int((turn + 1) / 2)
	var ai_shots: int = int(turn / 2)
	if not sudden:
		var my_left: int = 5 - my_shots
		var ai_left: int = 5 - ai_shots
		if my_goals > ai_goals + ai_left:
			return 1
		if ai_goals > my_goals + my_left:
			return -1
		if my_shots == 5 and ai_shots == 5 and my_goals == ai_goals:
			sudden = true
		return 0
	if my_shots == ai_shots:
		if my_goals > ai_goals:
			return 1
		if ai_goals > my_goals:
			return -1
	return 0


func _next_turn() -> void:
	if not _running:
		return
	var d: int = _decided()
	if d != 0:
		_finish(d > 0)
		return
	if sudden and turn % 2 == 0 and turn >= 10:
		my_marks.append(-1)
		ai_marks.append(-1)
		taunt.emit(I18n.t("sudden_death"))
		score_changed.emit()
	if turn % 2 == 0:
		_begin_player_shot()
	else:
		_begin_ai_shot()


# ---------------- oyuncu şut atıyor ----------------
func _begin_player_shot() -> void:
	world.place_for_shoot()
	_pressure = Brain.pressure_index(my_goals, ai_goals)
	_pred = brain.predict_shot(_pressure)
	# kaleci köşesini ŞUTTAN ÖNCE seçer (yalnızca geçmiş alışkanlıklara göre)
	if rng.randf() < follow:
		var sharp: float = 3.0 if style == 3 else (2.0 if style == 2 else 1.5)
		_keeper_zone = Brain.sample(_pred, rng, sharp)
	else:
		_keeper_zone = rng.randi_range(0, 8)
	hint_zone = -1
	# laf atma: analizci gerçek tahminini söyler, kurnaz blöf yapar
	if rng.randf() < 0.55:
		var shown: int = Brain.argmax(_pred)
		if style == 2:
			shown = (shown + 2 + rng.randi_range(0, 4)) % 9
		taunt.emit(I18n.t("hint_watch", {"v": I18n.t("zone_%d" % shown)}))
	phase = "aim"
	_phase_t = 0.0
	phase_changed.emit("shoot")


func reveal_keeper() -> int:
	hint_zone = _keeper_zone
	return _keeper_zone


## Kaydırma bilgisinden şut: hedef (kale düzleminde x,y), güç 0..1, falso -1..1
func on_shot(target: Vector2, power: float, curl: float) -> void:
	if phase != "aim":
		return
	phase = "flight"
	phase_changed.emit("flight")
	# isabet sapması: aşırı güç kontrolü bozar
	var spread: float = 0.12 + 0.55 * maxf(0.0, power - 0.85)
	var cross := target + Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread * 0.8))
	cross.y = maxf(0.11, cross.y)
	var zone: int = Brain.zone_of(clampf(cross.x, -3.5, 3.5), clampf(cross.y, 0.1, 2.4))
	var flight: float = lerpf(0.95, 0.42, power)
	var kind: String = _resolve_vs_keeper(cross, power, curl, flight)
	# öğrenme
	var best: int = Brain.argmax(_pred)
	if best % 3 == zone % 3:
		match_pred_side_hits += 1
	match_shot_zones[zone] += 1
	brain.record_shot(zone, _pressure, _pred)
	Save.stats["shots"] = int(Save.stats["shots"]) + 1
	# animasyon
	await world.run_up(0.55)
	Sfx.play("kick")
	var kz: Vector2 = Brain.zone_center(_keeper_zone)
	var dive_target: Vector2 = cross if kind == "saved" else kz.lerp(cross, _late_adjust(flight, curl) * 0.5)
	world.dive(dive_target, flight * 0.95)
	await world.fly(cross, flight, curl, kind)
	var mark: int = 1 if kind == "goal" else 0
	my_marks[mini(int(turn / 2), my_marks.size() - 1)] = mark
	if kind == "goal":
		my_goals += 1
		Save.stats["goals"] = int(Save.stats["goals"]) + 1
	outcome.emit(kind, true, zone)
	score_changed.emit()
	reading_changed.emit(brain.reading_percent())
	await get_tree().create_timer(2.4, false, false, true).timeout
	turn += 1
	_next_turn()


func _late_adjust(flight: float, curl: float) -> float:
	var adj: float = clampf(skill * 0.9 * (flight - 0.35) / 0.4, 0.0, 0.75)
	if style == 1:
		adj *= 1.3
	elif style == 0:
		adj *= 0.7
	return clampf(adj * (1.0 - 0.3 * absf(curl)), 0.0, 0.85)


func _resolve_vs_keeper(cross: Vector2, power: float, curl: float, flight: float) -> String:
	var ax: float = absf(cross.x)
	# direk / üst direk
	if (ax > 3.56 and ax < 3.80 and cross.y < 2.52) or (cross.y > 2.36 and cross.y < 2.56 and ax < 3.80):
		return "post"
	if ax >= 3.80 or cross.y >= 2.56:
		return "miss"
	var k: Vector2 = Brain.zone_center(_keeper_zone)
	var d: Vector2 = k.lerp(cross, _late_adjust(flight, curl))
	var reach: float = 0.55 + 0.35 * skill
	if cross.y > 1.8 and ax > 2.5:
		reach -= 0.18  # üst köşe
	if power > 0.7:
		reach -= (power - 0.7) * 0.45
	if _keeper_zone == 4 and ax < 0.95:
		return "saved"
	return "saved" if d.distance_to(cross) < reach else "goal"


# ---------------- yapay zekâ şut atıyor (oyuncu kaleci) ----------------
func _begin_ai_shot() -> void:
	world.place_for_keep()
	_dived = false
	_dive_time = -1.0
	_dive = Vector2(0, 1.0)
	var pd: Array[float] = brain.predict_dive()
	# oyuncunun en az dalış yaptığı bölgeleri tercih et
	var inv: Array[float] = []
	for i in 9:
		inv.append(maxf(0.02, 1.15 - pd[i] * 3.0))
	var z: int = Brain.sample(inv, rng, 1.0 + skill * 2.0)
	_ai_target = Brain.zone_center(z) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.25, 0.25))
	_ai_power = clampf(0.55 + skill * 0.4 + rng.randf_range(-0.1, 0.1), 0.4, 1.0)
	phase = "keep"
	_phase_t = 0.0
	phase_changed.emit("keep")
	_kick_at = 1.7
	_run_ai_shot()


func on_dive(d: Vector2) -> void:
	if phase != "keep" or _dived:
		return
	_dived = true
	_dive = Vector2(clampf(d.x, -3.4, 3.4), clampf(d.y, 0.15, 2.4))
	_dive_time = _phase_t


func _run_ai_shot() -> void:
	await get_tree().create_timer(_kick_at - 0.55, false).timeout
	if not _running:
		return
	await world.run_up(0.55)
	# oyuncu çok erken atladıysa akıllı şutçu öbür köşeye vurur
	if _dived and _dive_time < _kick_at - 0.3 and rng.randf() < 0.25 + skill * 0.6:
		_ai_target.x = -signf(_dive.x if absf(_dive.x) > 0.5 else rng.randf_range(-1, 1)) * rng.randf_range(2.0, 3.1)
		taunt.emit(I18n.t("hint_watch", {"v": I18n.t("zone_%d" % Brain.zone_of(_ai_target.x, _ai_target.y))}))
	var cross: Vector2 = _ai_target
	if rng.randf() < AI_MISS[diff]:
		cross.x = signf(cross.x + 0.01) * rng.randf_range(3.6, 4.4)
	Sfx.play("kick")
	phase = "keep_flight"
	var flight: float = lerpf(0.95, 0.45, _ai_power)
	# dalış: kale çizgisine varmadan yapılmalı
	var dive_ok: bool = _dived and _dive_time < _kick_at + flight - 0.12
	var d: Vector2 = _dive if dive_ok else Vector2(0, 1.0)
	var ax: float = absf(cross.x)
	var kind: String = "goal"
	if (ax > 3.56 and ax < 3.8 and cross.y < 2.52) or (cross.y > 2.36 and cross.y < 2.56 and ax < 3.8):
		kind = "post"
	elif ax >= 3.8 or cross.y >= 2.56:
		kind = "miss"
	else:
		var reach: float = 0.85 - maxf(0.0, _ai_power - 0.8) * 0.4
		if not dive_ok:
			reach = 0.7
		if d.distance_to(cross) < reach:
			kind = "saved"
	brain.record_dive(Brain.zone_of(d.x, d.y) if dive_ok else 4)
	world.dive(cross if kind == "saved" else d, flight * 0.9)
	await world.fly(cross, flight, rng.randf_range(-0.3, 0.3), kind)
	var mark: int = 1 if kind == "goal" else 0
	ai_marks[mini(int(turn / 2), ai_marks.size() - 1)] = mark
	if kind == "goal":
		ai_goals += 1
	if kind == "saved":
		match_saves += 1
		Save.stats["saves"] = int(Save.stats["saves"]) + 1
	outcome.emit(kind, false, Brain.zone_of(clampf(cross.x, -3.5, 3.5), clampf(cross.y, 0.1, 2.4)))
	score_changed.emit()
	await get_tree().create_timer(2.2, false, false, true).timeout
	turn += 1
	_next_turn()


# ---------------- bitiş ----------------
func _finish(win: bool) -> void:
	phase = "over"
	_running = false
	var stars_n: int = 0
	if win:
		stars_n = 1
		if my_goals - ai_goals >= 2:
			stars_n += 1
		if ai_goals <= 1:
			stars_n += 1
	var coins: int = int(round((my_goals * 10 + match_saves * 15 + (60 if win else 10)) * COIN_MULT[diff]))
	Save.stats["matches"] = int(Save.stats["matches"]) + 1
	if win:
		Save.stats["wins"] = int(Save.stats["wins"]) + 1
	var my_shots: int = 0
	for z in match_shot_zones:
		my_shots += z
	var fav: int = Brain.argmax(brain.predict_shot(1))
	var summary := {
		"win": win, "stars": stars_n, "coins": coins, "my_goals": my_goals, "ai_goals": ai_goals,
		"zones": match_shot_zones.duplicate(), "read_pct": int(round(100.0 * match_pred_side_hits / maxf(1.0, my_shots))),
		"overall_pct": brain.reading_percent(), "fav": fav, "level": level,
	}
	if level >= 0 and win:
		Save.complete_level(level, stars_n)
	Save.add_coins(coins)
	finished.emit(win, summary)
