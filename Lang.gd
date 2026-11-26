extends Node
## Dil, tema ve ilk kullanım ipuçları ayarları (autoload: Lang).
## Metinlerin anahtarı oyundaki Türkçe metindir; çeviriler LangData.gd'de.
## Control düğümlerinin yazısı otomatik çevrilir; biçimli metinler kodda tr() ile çevrilir.

signal changed

const LangData = preload("res://LangData.gd")
const PATH := "user://ayarlar_dil.cfg"

var lang: String = "en"
var theme: String = "system"      # system / dark / light
var tips_on: bool = true
var tips_seen: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for code in LangData.DATA.keys():
		var t := Translation.new()
		t.locale = code
		var d: Dictionary = LangData.DATA[code]
		for k in d.keys():
			t.add_message(k, d[k])
		if code == "tr":
			# anahtarlar zaten Türkçe: eksikler İngilizce yedeğe düşmesin
			for k in LangData.DATA["en"].keys():
				if not d.has(k):
					t.add_message(k, k)
		TranslationServer.add_translation(t)
	var cf := ConfigFile.new()
	var first := cf.load(PATH) != OK
	if first:
		lang = _guess_lang()
	else:
		lang = String(cf.get_value("s", "lang", _guess_lang()))
		theme = String(cf.get_value("s", "theme", "system"))
		tips_on = bool(cf.get_value("s", "tips_on", true))
		tips_seen = cf.get_value("s", "tips_seen", {})
	if not lang in LangData.LANGS:
		lang = "en"
	# otomatik testler Türkçe metinlerle yazıldı; mağaza görüntüleri için --lang=xx verilebilir
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--case"):
			lang = "tr"
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--lang="):
			lang = String(arg).substr(7)
	if not theme in ["system", "dark", "light"]:
		theme = "system"
	TranslationServer.set_locale(lang)


## Telefonun dili destekleniyorsa o, değilse İngilizce
func _guess_lang() -> String:
	var os_lang: String = OS.get_locale_language()
	return os_lang if os_lang in LangData.LANGS else "en"


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "lang", lang)
	cf.set_value("s", "theme", theme)
	cf.set_value("s", "tips_on", tips_on)
	cf.set_value("s", "tips_seen", tips_seen)
	cf.save(PATH)


func set_lang(code: String) -> void:
	if not code in LangData.LANGS or code == lang:
		return
	lang = code
	TranslationServer.set_locale(lang)
	save()
	changed.emit()


func set_theme(t: String) -> void:
	if not t in ["system", "dark", "light"] or t == theme:
		return
	theme = t
	save()
	changed.emit()


func is_light() -> bool:
	if theme == "light":
		return true
	if theme == "dark":
		return false
	if DisplayServer.is_dark_mode_supported():
		return not DisplayServer.is_dark_mode()
	return false


## Panel arka planı (koyu/açık temaya göre)
func panel_color(alpha: float = 0.97) -> Color:
	return Color(0.96, 0.95, 0.92, alpha) if is_light() else Color(0.09, 0.11, 0.16, alpha)


func card_color() -> Color:
	return Color(0.88, 0.87, 0.84) if is_light() else Color(0.13, 0.16, 0.22)


func text_color() -> Color:
	return Color(0.1, 0.11, 0.14) if is_light() else Color.WHITE


## Bir paneldeki bütün yazıları temaya göre boyar (açık temada koyu yazı, dış çizgisiz).
## Butonların kendi renkli zemini olduğu için onlara dokunulmaz.
func paint_texts(root: Node) -> void:
	if not is_light():
		return
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if l.get_parent() is Button:
			continue
		var c: Color = l.get_theme_color("font_color")
		# altın / jeton gibi renkli vurgular kalsın, sadece beyaz yazılar koyulaşsın
		if c.s < 0.25 and c.v > 0.75:
			l.add_theme_color_override("font_color", text_color())
		l.add_theme_constant_override("outline_size", 0)


func tip_wanted(id: String) -> bool:
	return tips_on and not tips_seen.has(id)


func tip_done(id: String) -> void:
	tips_seen[id] = true
	save()


func tips_reset() -> void:
	tips_on = true
	tips_seen = {}
	save()


func tips_disable() -> void:
	tips_on = false
	save()
