extends Node
## Ses yöneticisi: müzik, motor sesi ve efektler. "Muzik" ve "Efekt" ses kanalları
## ayrı ayrı açılıp kapatılır. Tüm sesler tools/make_audio.py ile sıfırdan sentezlendi.

const MUSIC_FILES := {"garaj": "res://audio/muzik_garaj.wav", "yol": "res://audio/muzik_yol.wav"}
const SFX_FILES := ["yuk_dustu", "teslimat", "oyun_bitti", "tik", "inis", "hararet", "satin_al", "turbo", "bip", "patlama"]
## Dizel motor: üç devirde kaydedilmiş döngü, devre göre karıştırılır (650 / 1350 / 2200 d/d)
const ENGINE_FILES := ["res://audio/motor_rolanti.wav", "res://audio/motor_orta.wav", "res://audio/motor_yuksek.wav"]
const ENGINE_RPM := [650.0, 1350.0, 2200.0]

var MUSIC: Dictionary = {}
var SFX: Dictionary = {}
var _layers: Array[AudioStreamPlayer] = []
var _rev: float = 0.0        # 0 = rölanti .. 1 = yüksek devir (yumuşatılmış)
var _blip: float = 0.0       # ara gaz
var _pop_ready: bool = false
var _active: bool = false

var music_on: bool = true
var sfx_on: bool = true
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _current: String = ""
var _bus_music: int = -1
var _bus_sfx: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_music = _ensure_bus("Muzik")
	_bus_sfx = _ensure_bus("Efekt")
	for k in MUSIC_FILES:
		MUSIC[k] = load(MUSIC_FILES[k])
	for n in SFX_FILES:
		SFX[n] = load("res://audio/%s.wav" % n)
	for s in MUSIC.values():
		_make_loop(s)

	_music = AudioStreamPlayer.new()
	_music.bus = "Muzik"
	_music.volume_db = -6.0
	add_child(_music)

	for f in ENGINE_FILES:
		var st: AudioStream = load(f)
		_make_loop(st)
		var p := AudioStreamPlayer.new()
		p.bus = "Efekt"
		p.stream = st
		p.volume_db = -60.0
		p.process_mode = Node.PROCESS_MODE_PAUSABLE   # oyun duraklayınca motor susar
		add_child(p)
		_layers.append(p)
	_engine = _layers[1]

	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Efekt"
		add_child(p)
		_pool.append(p)
	apply()


func _ensure_bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * float(w.mix_rate)))


## Ayarları ses kanallarına uygula
func apply() -> void:
	AudioServer.set_bus_mute(_bus_music, not music_on)
	AudioServer.set_bus_mute(_bus_sfx, not sfx_on)


func play_music(track: String) -> void:
	if track == _current and _music.playing:
		return
	_current = track
	_music.stream = MUSIC.get(track)
	_music.play()


func sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_on or not SFX.has(sfx_name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = SFX[sfx_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Ara gaz: gaza hızlı hızlı basınca motor bir anda kükreyip düşer (eski kamyon usulü)
func blip() -> void:
	if not _active or not sfx_on:
		return
	_blip = 1.0
	_pop_ready = true


## Motor: rpm 0..1 (teker devri), throttle 0..1 (gaz). active=false -> sus
func engine(active: bool, rpm: float, throttle: float, delta: float) -> void:
	_active = active
	if not active:
		for p in _layers:
			if p.playing:
				p.volume_db = move_toward(p.volume_db, -60.0, delta * 80.0)
				if p.volume_db <= -59.0:
					p.stop()
		return
	for p in _layers:
		if not p.playing:
			p.volume_db = -60.0
			p.play()
	var target: float = clampf(maxf(rpm, throttle * 0.42), 0.0, 1.0)
	# devir gaza hızlı çıkar, yavaş düşer (motorun ataleti)
	var k: float = 3.5 if target > _rev else 1.6
	_rev = lerpf(_rev, target, clampf(delta * k, 0.0, 1.0))
	_blip = maxf(_blip - delta * 2.4, 0.0)
	if _pop_ready and _blip < 0.35 and throttle < 0.1:
		_pop_ready = false
		if randf() < 0.6:
			sfx("patlama", -7.0, randf_range(0.9, 1.15))
	var e: float = clampf(_rev + _blip * 0.75, 0.0, 1.25)
	var cur_rpm: float = 650.0 + e * 1650.0
	var master_db: float = lerpf(-15.0, -3.0, clampf(0.45 * e + 0.55 * maxf(throttle, _blip), 0.0, 1.0))
	for i in range(_layers.size()):
		var anchor: float = float(ENGINE_RPM[i])
		var w: float = 0.0
		if i == 0:
			w = clampf(1.0 - (cur_rpm - 650.0) / 700.0, 0.0, 1.0)
		elif i == 1:
			w = clampf(1.0 - absf(cur_rpm - 1350.0) / (700.0 if cur_rpm < 1350.0 else 850.0), 0.0, 1.0)
		else:
			w = clampf((cur_rpm - 1350.0) / 850.0, 0.0, 1.0)
		var p: AudioStreamPlayer = _layers[i]
		p.pitch_scale = clampf(cur_rpm / anchor, 0.7, 1.45)
		var db: float = master_db + linear_to_db(maxf(w, 0.001))
		p.volume_db = lerpf(p.volume_db, db, clampf(delta * 10.0, 0.0, 1.0))
