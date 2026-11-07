extends Node
## Ses efektleri ve müzik. Sınırlı sayıda AudioStreamPlayer havuzu kullanılır.

const NAMES: Array[String] = ["tap", "button", "kick", "whistle", "roar", "ooh", "save", "post", "net", "coin", "win", "lose"]
const POOL_SIZE := 6

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var p := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in POOL_SIZE:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	var mp := "res://assets/audio/crowd_loop.wav"
	if ResourceLoader.exists(mp):
		_music.stream = load(mp)
	_music.finished.connect(_on_music_finished)
	Settings.changed.connect(_on_settings_changed)
	update_music()


func play(n: String, volume_db: float = 0.0) -> void:
	if not Settings.flag("sfx") or not _streams.has(n):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(n, -1000)) < 40:
		return  # aynı sesin üst üste binmesini engelle
	_last_play[n] = now
	var pl: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	pl.stream = _streams[n]
	pl.volume_db = volume_db
	pl.play()


func vibrate(ms: int = 25) -> void:
	if Settings.flag("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func update_music() -> void:
	if _music.stream == null:
		return
	if Settings.flag("music"):
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


func _on_music_finished() -> void:
	if Settings.flag("music"):
		_music.play()


func _on_settings_changed(key: String) -> void:
	if key == "music" or key == "all":
		update_music()
