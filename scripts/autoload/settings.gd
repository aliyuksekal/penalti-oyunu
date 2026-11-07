extends Node
## Oyuncu ayarları (dil, tema, ses, titreşim). user://settings.cfg içinde saklanır.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"language": "auto",
	"theme": "auto",
	"sfx": true,
	"music": true,
	"vibration": true,
	"intro_seen": false,
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS.keys():
			_values[k] = cfg.get_value("settings", k, DEFAULTS[k])
	I18n.apply_setting(str(_values["language"]))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		cfg.set_value("settings", k, _values[k])
	var tmp := PATH + ".tmp"
	if cfg.save(tmp) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	if key == "language":
		I18n.apply_setting(str(value))
	changed.emit(key)


func flag(key: String) -> bool:
	return bool(get_value(key))


func reset_to_defaults() -> void:
	var seen: bool = flag("intro_seen")
	_values = DEFAULTS.duplicate()
	_values["intro_seen"] = seen
	save_settings()
	I18n.apply_setting("auto")
	changed.emit("all")
