extends Node
## Arayüz ikonları ve yazı tipi oyun başında bir kez yüklenir.

const UI_ICONS: Array[String] = ["ad", "ai", "ball", "coin", "eye", "gear", "glove", "home", "info", "jersey", "lock", "pause", "play", "retry", "shop", "skip", "star", "star_empty", "trophy"]

var ui: Dictionary = {}
var font: Font
var missing: Array[String] = []


func _ready() -> void:
	for n in UI_ICONS:
		var p := "res://assets/ui/%s.png" % n
		if ResourceLoader.exists(p):
			ui[n] = load(p)
		else:
			missing.append(p)
	font = _make_font()


func _make_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans CJK KR", "Noto Sans", "Roboto", "sans-serif"])
	sys.font_weight = 700
	var path := "res://assets/fonts/Nunito.ttf"
	if ResourceLoader.exists(path):
		var f: FontFile = load(path) as FontFile
		if f != null:
			var v := FontVariation.new()
			v.base_font = f
			var ts: TextServer = TextServerManager.get_primary_interface()
			v.variation_opentype = {ts.name_to_tag("wght"): 850}
			var fb: Array[Font] = [sys]
			f.fallbacks = fb
			return v
	return sys
