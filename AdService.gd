extends Node
## Reklam ve uygulama içi satın alma katmanı.
##
## Android'de AdMob eklentisi varsa GERÇEK AdMob reklamları (AdMobBridge.gd) gösterilir.
## Masaüstünde ve otomatik testlerde aynı akış tam ekran bir "TEST REKLAMI" ile çalışır.
## Jeton paketleri henüz test modunda (Google Play Billing bağlanınca gerçek ödeme).
## Alt banner reklamı bilerek YOK. Tam ekran reklam en fazla 3 dakikada bir çıkar.

## AdMob yayıncı: pub-9672960376821171
## Uygulama kimliği project.godot -> [admob] general/android/app_id içinde.
## Gerçek reklam birimi kimlikleri gelince aşağıdakiler değiştirilecek
## (şimdilik Google'ın resmi TEST birimleri: gerçek SDK, para kazandırmaz, hesabı riske atmaz).
const AD_UNITS := {
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"banner": "ca-app-pub-3940256099942544/6300978111",
}

signal tokens_purchased(amount: int)

@export var test_mode: bool = true      # jeton satın alma (Billing gelene kadar)
## İki tam ekran reklam arasındaki en kısa süre (sn): reklamı abartmayalım
@export var interstitial_min_gap: float = 180.0
@export var test_interstitial_seconds: float = 3.0
@export var test_rewarded_seconds: float = 5.0

## Mağazadaki jeton paketleri (fiyatlar Play Console'dan gelir)
const PACKS: Array = [
	{"id": "jeton_300", "name": "Küçük Kasa", "tokens": 300, "price": "₺ —"},
	{"id": "jeton_800", "name": "Orta Kasa (+%15)", "tokens": 800, "price": "₺ —"},
	{"id": "jeton_2000", "name": "Büyük Kasa (+%30)", "tokens": 2000, "price": "₺ —"},
]

var autoclose: bool = false   # sadece otomatik testler için
var _last_interstitial_ms: int = -1000000
var _layer: CanvasLayer
var _bridge: Node = null   # gerçek AdMob (sadece Android)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	# oyunun ilk 3 dakikasında tam ekran reklam yok
	_last_interstitial_ms = Time.get_ticks_msec()
	if OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob"):
		_bridge = load("res://AdMobBridge.gd").new()
		_bridge.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_bridge)
		_bridge.start(String(AD_UNITS["interstitial"]), String(AD_UNITS["rewarded"]), String(AD_UNITS["banner"]))


func is_live() -> bool:
	return _bridge != null


# ---------------- BANNER ----------------
## Oyun sırasında alt ortada küçük banner (320x50). Masaüstünde/testte aynı yerde yer tutucu kutu.
var banner_on: bool = false
var _banner_box: Panel


func set_banner(on: bool) -> void:
	banner_on = on
	if _bridge != null:
		_bridge.set_banner(on)
		return
	if _banner_box == null:
		_banner_box = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.95, 0.97)
		sb.border_color = Color(0.6, 0.62, 0.68)
		sb.set_border_width_all(2)
		_banner_box.add_theme_stylebox_override("panel", sb)
		_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = "Reklam (test banner)"
		l.add_theme_color_override("font_color", Color(0.3, 0.32, 0.38))
		l.add_theme_font_size_override("font_size", 18)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_banner_box.add_child(l)
		_layer.add_child(_banner_box)
	_banner_box.visible = on
	_place_box()


## Banner'ın oyun ekranındaki (mantıksal) boyutu: alt orta. Yoksa sıfır.
var _last_logged: Vector2 = Vector2(-1, -1)


func banner_size_logical() -> Vector2:
	if not banner_on:
		return Vector2.ZERO
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _bridge != null:
		if not _bridge.banner_present():
			return Vector2.ZERO
		var win: Vector2i = DisplayServer.window_get_size()
		if win.y <= 0:
			return Vector2.ZERO
		var px: Vector2 = Vector2(_bridge.banner_px())
		if px.x <= 0.0 or px.y <= 0.0:
			# eklenti boyut vermediyse: standart banner 320x50 dp, ekran yoğunluğuyla piksele çevir
			var density: float = float(DisplayServer.screen_get_dpi()) / 160.0
			if density < 0.5 or density > 8.0:
				density = maxf(DisplayServer.screen_get_scale(), 1.0)
			px = Vector2(320.0, 50.0) * density
		var k: float = vp.y / float(win.y)
		var out: Vector2 = px * k
		if not out.is_equal_approx(_last_logged):
			_last_logged = out
			print("[reklam] banner %dx%d px, pencere %dx%d, oyun ekranı %dx%d -> %dx%d" % [int(px.x), int(px.y), win.x, win.y, int(vp.x), int(vp.y), int(out.x), int(out.y)])
		return out
	# yer tutucu: tipik telefonda 320x50 dp'nin kapladığı alan (kısa kenar ~393 dp)
	var dp: float = minf(vp.x, vp.y) / 393.0
	return Vector2(320.0, 50.0) * dp


func _place_box() -> void:
	if _banner_box == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sz: Vector2 = banner_size_logical()
	_banner_box.size = sz
	_banner_box.position = Vector2((vp.x - sz.x) * 0.5, vp.y - sz.y)


func is_showing() -> bool:
	return _layer.get_child_count() > 0


## Tam ekran reklam; kapanınca done çağrılır (reklam yüklenemezse de çağrılır, oyuncu bekletilmez)
func show_interstitial(done: Callable) -> void:
	var gap_ok: bool = Time.get_ticks_msec() - _last_interstitial_ms >= int(interstitial_min_gap * 1000.0)
	if not gap_ok:
		done.call()
		return
	_last_interstitial_ms = Time.get_ticks_msec()
	if _bridge != null:
		_real_interstitial(done)
		return
	_overlay("REKLAM", "Tam ekran reklam (TEST)", test_interstitial_seconds, "KAPAT  ✕", func(_watched: bool) -> void: done.call(), false)


## Ödüllü reklam; sonuna kadar izlenirse on_reward çağrılır
func show_rewarded(on_reward: Callable, on_cancel: Callable = Callable()) -> void:
	if _bridge != null:
		_real_rewarded(on_reward, on_cancel)
		return
	var finish := func(watched: bool) -> void:
		if watched:
			on_reward.call()
		elif on_cancel.is_valid():
			on_cancel.call()
	_overlay("ÖDÜLLÜ REKLAM", "Sonuna kadar izle, ödülünü al (TEST)", test_rewarded_seconds, "ÖDÜLÜ AL", finish, true)


## Jeton paketi satın al
func buy_pack(pack: Dictionary, on_success: Callable) -> void:
	if not test_mode:
		_real_purchase(pack, on_success)
		return
	var finish := func(watched: bool) -> void:
		if watched:
			on_success.call()
			tokens_purchased.emit(int(pack["tokens"]))
	_overlay("SATIN ALMA (TEST)", "%s: %d jeton\nTest modunda gerçek ödeme alınmaz." % [pack["name"], int(pack["tokens"])], 1.0, "ONAYLA", finish, true)


# ---------------- gerçek SDK bağlantı noktaları ----------------
func _real_interstitial(done: Callable) -> void:
	_bridge.show_interstitial(done)


## Ödüllü reklam hazır değilse en fazla 8 sn "Reklam yükleniyor" bekle; gelmezse haber ver
func _real_rewarded(on_reward: Callable, on_cancel: Callable) -> void:
	if _bridge.show_rewarded(on_reward, on_cancel):
		return
	_bridge.ensure_rewarded()
	var root := ColorRect.new()
	root.color = Color(0.02, 0.02, 0.04, 0.9)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var lbl := Label.new()
	lbl.text = "Reklam yükleniyor..."
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	root.add_child(lbl)
	var waited: float = 0.0
	while waited < 8.0 and not _bridge.has_rewarded():
		await get_tree().create_timer(0.25, true).timeout
		waited += 0.25
	if _bridge.has_rewarded():
		root.queue_free()
		_bridge.show_rewarded(on_reward, on_cancel)
		return
	lbl.text = "Şu an reklam yok.\nİnternet bağlantını kontrol edip tekrar dene."
	await get_tree().create_timer(2.2, true).timeout
	root.queue_free()
	if on_cancel.is_valid():
		on_cancel.call()


func _real_purchase(pack: Dictionary, on_success: Callable) -> void:
	# Google Play Billing eklentisi eklenince: pack["id"] ürününü satın al, onaylanınca on_success.call()
	pass


# ---------------- TEST reklam ekranı ----------------
func _overlay(title: String, sub: String, secs: float, close_text: String, on_close: Callable, cancellable: bool) -> void:
	var root := ColorRect.new()
	root.color = Color(0.02, 0.02, 0.04, 0.97)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -170
	box.offset_bottom = 170
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	root.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 54)
	t.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	box.add_child(t)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 26)
	box.add_child(s)
	var cnt := Label.new()
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 40)
	box.add_child(cnt)
	var btn := Button.new()
	btn.text = close_text
	btn.custom_minimum_size = Vector2(320, 70)
	btn.add_theme_font_size_override("font_size", 28)
	btn.disabled = true
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.flat = true
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.visible = cancellable
	box.add_child(cancel)

	var state := {"left": secs, "done": false}
	var finish := func(watched: bool) -> void:
		if state["done"]:
			return
		state["done"] = true
		root.queue_free()
		on_close.call(watched)
	btn.pressed.connect(finish.bind(true))
	cancel.pressed.connect(finish.bind(false))
	while float(state["left"]) > 0.0 and not bool(state["done"]) and is_instance_valid(cnt):
		cnt.text = "%d" % ceili(float(state["left"]))
		await get_tree().create_timer(0.1, true).timeout
		state["left"] = float(state["left"]) - 0.1
	if not bool(state["done"]) and is_instance_valid(cnt):
		cnt.text = ""
		btn.disabled = false
		if autoclose:
			finish.call(true)
