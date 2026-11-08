extends Node
## Ses yöneticisi: müzik, motor sesi ve efektler. "Muzik" ve "Efekt" ses kanalları
## ayrı ayrı açılıp kapatılır. Tüm sesler tools/make_audio.py ile sıfırdan sentezlendi.

const MUSIC_FILES := {"garaj": "res://audio/muzik_garaj.wav", "yol": "res://audio/muzik_yol.wav"}
const SFX_FILES := ["yuk_dustu", "teslimat", "oyun_bitti", "tik", "inis", "hararet", "satin_al", "turbo", "bip", "patlama"]
## Motor: gerçek Ford kamyon kaydından kesilmiş iki döngü (düşük ve yüksek devir), devire göre karışır.
## Ara gaz: aynı kayıttaki gerçek ara gaz patlamaları (gaza hızlı hızlı basınca çalar).
const ENGINE_FILES := ["res://audio/motor_ford_dusuk.wav", "res://audio/motor_ford_yuksek.wav"]
const BLIP_FILES := ["res://audio/aragaz_1.wav", "res://audio/aragaz_2.wav", "res://audio/aragaz_3.wav"]

var MUSIC: Dictionary = {}
var SFX: Dictionary = {}
var _layers: Array[AudioStreamPlayer] = []
var _rev: float = 0.0        # 0 = rölanti .. 1 = yüksek devir (yumuşatılmış)
var _blip: float = 0.0       # ara gaz
var _blips: Array[AudioStream] = []
var _blip_player: AudioStreamPlayer
var _duck: float = 0.0
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
	for f in BLIP_FILES:
		_blips.append(load(f))
	_blip_player = AudioStreamPlayer.new()
	_blip_player.bus = "Efekt"
	_blip_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_blip_player)

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


## Ara gaz: gaza hızlı hızlı basınca gerçek kayıttaki ara gaz sesi çalar, motor döngüsü kısılır
func blip() -> void:
	if not _active or not sfx_on or _blips.is_empty():
		return
	if _blip_player.playing and _blip_player.get_playback_position() < 0.25:
		return   # bir önceki daha yeni başladı
	_blip_player.stream = _blips[randi() % _blips.size()]
	_blip_player.pitch_scale = randf_range(0.95, 1.06)
	_blip_player.volume_db = -1.0
	_blip_player.play()
	_blip = 1.0
	_duck = 1.0


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
	var target: float = clampf(maxf(rpm, throttle * 0.45), 0.0, 1.0)
	var k: float = 3.0 if target > _rev else 1.5        # devir gaza hızlı çıkar, yavaş düşer
	_rev = lerpf(_rev, target, clampf(delta * k, 0.0, 1.0))
	_blip = maxf(_blip - delta * 2.0, 0.0)
	# ara gaz çalarken döngü geri çekilir, bitince yavaşça geri gelir
	if _blip_player.playing:
		_duck = 1.0
	else:
		_duck = maxf(_duck - delta * 3.0, 0.0)
	var e: float = _rev
	var master_db: float = lerpf(-14.0, -3.0, clampf(0.5 * e + 0.5 * throttle, 0.0, 1.0)) - 12.0 * _duck
	var w_low: float = clampf(1.0 - e * 1.4, 0.0, 1.0)
	var w_high: float = clampf((e - 0.15) * 1.6, 0.0, 1.0)
	var weights: Array = [w_low, w_high]
	var pitches: Array = [0.8 + 0.45 * e, 0.82 + 0.4 * e]
	for i in range(_layers.size()):
		var p: AudioStreamPlayer = _layers[i]
		p.pitch_scale = float(pitches[i])
		var db: float = master_db + linear_to_db(maxf(float(weights[i]), 0.001))
		p.volume_db = lerpf(p.volume_db, db, clampf(delta * 10.0, 0.0, 1.0))
