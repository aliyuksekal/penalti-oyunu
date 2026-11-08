extends Node
## Ses yöneticisi: müzik, motor sesi ve efektler. "Muzik" ve "Efekt" ses kanalları
## ayrı ayrı açılıp kapatılır. Tüm sesler tools/make_audio.py ile sıfırdan sentezlendi.

const MUSIC := {
	"garaj": preload("res://audio/muzik_garaj.wav"),
	"yol": preload("res://audio/muzik_yol.wav"),
}
const SFX := {
	"yuk_dustu": preload("res://audio/yuk_dustu.wav"),
	"teslimat": preload("res://audio/teslimat.wav"),
	"oyun_bitti": preload("res://audio/oyun_bitti.wav"),
	"tik": preload("res://audio/tik.wav"),
	"inis": preload("res://audio/inis.wav"),
	"hararet": preload("res://audio/hararet.wav"),
	"satin_al": preload("res://audio/satin_al.wav"),
}
const ENGINE := preload("res://audio/motor.wav")

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
	for s in MUSIC.values():
		_make_loop(s)
	_make_loop(ENGINE)

	_music = AudioStreamPlayer.new()
	_music.bus = "Muzik"
	_music.volume_db = -6.0
	add_child(_music)

	_engine = AudioStreamPlayer.new()
	_engine.bus = "Efekt"
	_engine.stream = ENGINE
	_engine.volume_db = -30.0
	_engine.process_mode = Node.PROCESS_MODE_PAUSABLE   # oyun duraklayınca motor susar
	add_child(_engine)

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


func sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_on or not SFX.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = SFX[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Motor: rpm 0..1 (teker devri), throttle 0..1 (gaz). active=false -> sus
func engine(active: bool, rpm: float, throttle: float, delta: float) -> void:
	if not active:
		if _engine.playing:
			_engine.volume_db = move_toward(_engine.volume_db, -40.0, delta * 60.0)
			if _engine.volume_db <= -39.0:
				_engine.stop()
		return
	if not _engine.playing:
		_engine.volume_db = -30.0
		_engine.play()
	var target_pitch: float = 0.72 + clampf(rpm, 0.0, 1.0) * 1.25 + throttle * 0.22
	_engine.pitch_scale = lerpf(_engine.pitch_scale, target_pitch, clampf(delta * 4.0, 0.0, 1.0))
	var target_db: float = lerpf(-17.0, -5.0, clampf(0.35 * rpm + 0.65 * throttle, 0.0, 1.0))
	_engine.volume_db = lerpf(_engine.volume_db, target_db, clampf(delta * 5.0, 0.0, 1.0))
