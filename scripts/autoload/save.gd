extends Node
## İlerleme ve yapay zekânın oyuncu hakkında öğrendikleri (cihazda, atomik JSON kayıt).

signal changed

const PATH := "user://progress.json"
const TMP := "user://progress.tmp"
const BAK := "user://progress.bak"
const VERSION := 1
const LEVELS := 20
const BALL_PRICES: Array[int] = [0, 400, 700, 1000, 1500]

var coins: int = 0
var unlocked: int = 0
var stars: Array[int] = []
var difficulty: int = 1
var play_mode: int = 0   # 0 şutçu, 1 kaleci, 2 klasik seri
var my_kit: String = "red_yellow"
var rival_kit: String = "yellow_navy"
var balls_owned: Array[int] = [0]
var ball_equipped: int = 0
var stats: Dictionary = {"matches": 0, "wins": 0, "goals": 0, "saves": 0, "shots": 0}
## Yapay zekâ hafızası: oyuncunun şut ve dalış alışkanlıkları (9 bölge)
var ai: Dictionary = {}


func _ready() -> void:
	_reset_values()
	load_data()


func _reset_values() -> void:
	coins = 0
	unlocked = 0
	stars.clear()
	for i in LEVELS:
		stars.append(0)
	difficulty = 1
	play_mode = 0
	balls_owned.assign([0])
	ball_equipped = 0
	stats = {"matches": 0, "wins": 0, "goals": 0, "saves": 0, "shots": 0}
	reset_ai()


func reset_ai() -> void:
	ai = {
		"shot_global": _zeros(9), "shot_after": _zeros(81), "shot_pressure": _zeros(27),
		"dive_global": _zeros(9), "dive_after": _zeros(81),
		"pred_total": 0, "pred_side_hits": 0, "pred_zone_hits": 0,
		"last_shot": -1, "last_dive": -1,
	}


func _zeros(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(0.0)
	return a


func total_stars() -> int:
	var t: int = 0
	for s in stars:
		t += s
	return t


func add_coins(n: int) -> void:
	coins = maxi(0, coins + n)
	save_data()
	changed.emit()


func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	save_data()
	changed.emit()
	return true


func complete_level(idx: int, s: int) -> void:
	if idx >= 0 and idx < LEVELS:
		stars[idx] = maxi(stars[idx], s)
		unlocked = maxi(unlocked, mini(LEVELS - 1, idx + 1))
	save_data()
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "coins": coins, "unlocked": unlocked, "stars": stars,
		"difficulty": difficulty, "play_mode": play_mode, "my_kit": my_kit, "rival_kit": rival_kit,
		"balls_owned": balls_owned, "ball_equipped": ball_equipped, "stats": stats, "ai": ai,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) < 1:
		return false
	coins = maxi(0, int(d.get("coins", 0)))
	unlocked = clampi(int(d.get("unlocked", 0)), 0, LEVELS - 1)
	var st: Array = d.get("stars", [])
	stars.clear()
	for i in LEVELS:
		stars.append(clampi(int(st[i]) if i < st.size() else 0, 0, 3))
	difficulty = clampi(int(d.get("difficulty", 1)), 0, 3)
	play_mode = clampi(int(d.get("play_mode", 0)), 0, 2)
	my_kit = str(d.get("my_kit", "red_yellow"))
	rival_kit = str(d.get("rival_kit", "yellow_navy"))
	if not Kits.KITS.has(my_kit):
		my_kit = "red_yellow"
	if not Kits.KITS.has(rival_kit) or rival_kit == my_kit:
		rival_kit = "yellow_navy" if my_kit != "yellow_navy" else "black_white"
	balls_owned.clear()
	for b in d.get("balls_owned", [0]):
		var bi: int = int(b)
		if bi >= 0 and bi < BALL_PRICES.size() and not (bi in balls_owned):
			balls_owned.append(bi)
	if not (0 in balls_owned):
		balls_owned.append(0)
	ball_equipped = int(d.get("ball_equipped", 0))
	if not (ball_equipped in balls_owned):
		ball_equipped = 0
	var s: Dictionary = d.get("stats", {})
	for k in stats.keys():
		stats[k] = int(s.get(k, 0))
	reset_ai()
	var a: Dictionary = d.get("ai", {})
	for k in ai.keys():
		if a.has(k):
			var v: Variant = a[k]
			if typeof(ai[k]) == TYPE_ARRAY:
				if typeof(v) == TYPE_ARRAY and (v as Array).size() == (ai[k] as Array).size():
					var arr: Array = []
					for x in v:
						arr.append(maxf(0.0, float(x)))
					ai[k] = arr
			else:
				ai[k] = int(v)
	return true


func save_data() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var gs: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(BAK):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
		DirAccess.rename_absolute(gs, ProjectSettings.globalize_path(BAK))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP), gs)


func load_data() -> bool:
	for p in [PATH, BAK]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var v: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(v) == TYPE_DICTIONARY and from_dict(v):
			return true
	return false


func reset_all() -> void:
	_reset_values()
	save_data()
	changed.emit()
