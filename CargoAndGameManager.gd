extends Node2D
## Kargo fiziği, dokunmatik kontroller, HUD, teslimat, oyun sonu, ekonomi (altın/jeton) ve kayıt.
## Menü/garaj/mağaza ekranı MenuScreen.gd'de, reklam/satın alma AdService.gd'de.
## Main sahnesinin kök düğümüne bağlanır. Çocukları: "Terrain" (TerrainGenerator.gd)
## ve "Truck" (TruckController.gd). Geri kalan her şey (UI, yükler, gökyüzü) kodla kurulur.

const PX_PER_M := 50.0
const CARGO_COUNT := 5
const SAVE_PATH := "user://kargo_kayit.cfg"
const MAX_LEVEL := 10

const TruckCatalog = preload("res://TruckCatalog.gd")
const TruckArt = preload("res://TruckArt.gd")
const CargoTypes = preload("res://CargoTypes.gd")
const MenuScreen = preload("res://MenuScreen.gd")
const AdService = preload("res://AdService.gd")
const SoundManager = preload("res://SoundManager.gd")

## Yükseltmeler (ALTIN ile, her kamyonun kendi seviyeleri var)
const UPGRADES: Array = [
	{"id": "engine", "name": "Motor Gücü", "step": 0.12},
	{"id": "stiffness", "name": "Yay Sertliği", "step": 0.10},
	{"id": "damping", "name": "Amortisör", "step": 0.15},
	{"id": "grip", "name": "Lastik Tutuşu", "step": 0.10},
	{"id": "fuel", "name": "Yakıt Deposu", "step": 0.20},
]
const GOLD_PER_TOKEN_STEP := 100     # 100 altın ...
const TOKENS_PER_STEP := 10          # ... = 10 jeton
const REWARDED_TOKENS := 50          # ödüllü reklam başına jeton

## Sahne yeniden yüklenince menüyü atla ("Yeniden başla" için). static = yeniden yüklemede korunur.
static var skip_menu: bool = false
static var restarts: int = 0

@export var gold_per_cargo: int = 20
@export var station_bonus: int = 15
@export var perfect_bonus: int = 25
@export var flip_time_limit: float = 3.0
@export var leg_time: float = 105.0          # bir teslimat için süre (sn)
@export var leg_time_bonus: float = 8.0      # her yeni bölgede eklenen süre (zor yollar)

const ZONES: Array = ["Çayır Yolu", "Tepeler", "Orman Yolu", "Dağ Geçidi", "Kayalık Vadi", "Zirve Yolu", "Kartal Yuvası", "Bulutların Üstü"]

@onready var terrain = $Terrain   # TerrainGenerator.gd
@onready var truck = $Truck       # TruckController.gd

var cargo: Array[RigidBody2D] = []      # kasadaki sağlam yükler
var dropped: Array[RigidBody2D] = []    # yola düşenler
var _out_time: Dictionary = {}          # yük -> kasa dışında geçen süre
var gold_run: int = 0
var total_gold: int = 0
var best_m: float = 0.0
var tokens: int = 0
var cargo_total: int = 5          # bu teslimatta yüklenen yük sayısı
var dev_mode: bool = false        # geliştirici modu: tüm kamyonlar seçilebilir
var owned: Array = ["tosun"]
var selected: String = "tosun"
var up_levels: Dictionary = {}     # "kamyon:yükseltme" -> seviye
var state: String = "menu"         # menu / play / over
var ads: Node
var menu: Control
var _hud_nodes: Array[Control] = []
var _ui_root: Control
var _gas_hint: Label
var _saved_run: Dictionary = {}   # kaldığı yerden devam: istasyondaki durum
var settings_panel: Control
var _doubled: bool = false
var night: bool = false
var next_cp: int = 1
var delivered: int = 0
var flip_t: float = 0.0
var empty_t: float = 0.0
var empty_total: float = 0.0
var game_over: bool = false
var start_x: float = 0.0
var _good_x: float = 60.0          # kamyonun en son sağlıklı (sonlu, yerde) konumu
var _good_t: float = 0.0
var _last_delivery_ms: int = -100000
var _recoveries: int = 0
var end_reason: String = ""

# UI
var ui: CanvasLayer
var fuel_bar: ProgressBar
var speed_gauge: Gauge
var heat_gauge: Gauge
var pause_btn: Button
var pause_panel: Control
var snd: Node
var music_on: bool = true
var sfx_on: bool = true
var _air_t: float = 0.0
var _prev_overheat: bool = false
var _crash_cd: Dictionary = {}   # yük -> son çarpma sesi zamanı
var time_left: float = 0.0
var _brake_hold: float = 0.0
var _prev_gas: bool = false
var _last_road: String = ""
var _gas_release_t: float = -10.0
var blip_count: int = 0
var _tap_streak: int = 0
var _beep_t: float = 0.0
var _last_sec: int = -1
var turbo_btn: TurboButton
var timer_lbl: Label
var zone_lbl: Label
var cargo_lbl: Label
var dist_lbl: Label
var gold_lbl: Label
var next_lbl: Label
var warn_lbl: Label
var toast_lbl: Label
var gas_btn: Pedal
var brake_btn: Pedal
var over_panel: Control
var _toast_t: float = 0.0
var _modulate: CanvasModulate
var _sky: TextureRect

# dokunma takibi (çoklu dokunma: aynı anda gaz + başka parmak)
var _touches: Dictionary = {}
var _mouse_down: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO


## Büyük dokunmatik pedal (kodla çizilir)
class Pedal extends Control:
	var text: String = ""
	var base_color: Color = Color.GREEN
	var down: bool = false
	var arrow: int = 1

	func set_down(v: bool) -> void:
		if v != down:
			down = v
			queue_redraw()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = base_color.darkened(0.25) if down else base_color
		sb.bg_color.a = 0.9 if down else 0.6
		sb.set_corner_radius_all(28)
		sb.border_color = Color(1, 1, 1, 0.85 if down else 0.45)
		sb.set_border_width_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c: Vector2 = size * 0.5 + Vector2(0, -22)
		var a: float = 30.0
		var tri := PackedVector2Array([c + Vector2(a * arrow, 0), c + Vector2(-a * 0.6 * arrow, -a), c + Vector2(-a * 0.6 * arrow, a)])
		draw_colored_polygon(tri, Color(1, 1, 1, 0.95))
		var f: Font = ThemeDB.fallback_font
		var fs: int = 30
		var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2((size.x - ts.x) * 0.5, size.y - 30.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Ayarlar çarkı (kodla çizilir)
class GearButton extends Button:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(0.1, 0.12, 0.17, 0.85))
		var col := Color(0.93, 0.94, 0.97) if not is_pressed() else Color(1.0, 0.7, 0.3)
		var teeth: int = 8
		var pts := PackedVector2Array()
		for i in range(teeth * 4):
			var a: float = TAU * float(i) / float(teeth * 4)
			var rr: float = r * (0.72 if (i % 4) < 2 else 0.55)
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
		draw_circle(c, r * 0.24, Color(0.1, 0.12, 0.17))


## Yuvarlak TURBO düğmesi: dolum halkası gösterir
class TurboButton extends Control:
	var charge: float = 1.0
	var active: bool = false

	func set_state(c: float, a: bool) -> void:
		if absf(c - charge) > 0.01 or a != active:
			charge = c
			active = a
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 6.0
		var ready_: bool = charge >= 1.0
		var bg: Color = Color(1.0, 0.45, 0.05, 0.92) if active else (Color(0.95, 0.55, 0.1, 0.8) if ready_ else Color(0.25, 0.27, 0.33, 0.7))
		draw_circle(c, r, bg)
		draw_arc(c, r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(1.0, 0.85, 0.2), 6.0)
		var f: Font = ThemeDB.fallback_font
		var t: String = "TURBO"
		var ts: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(f, c + Vector2(-ts.x * 0.5, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE if (ready_ or active) else Color(0.7, 0.72, 0.78))
		# alev simgesi
		var fl := PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.22, -r * 0.25), c + Vector2(0, -r * 0.33), c + Vector2(-r * 0.22, -r * 0.25)])
		draw_colored_polygon(fl, Color(1, 1, 1, 0.9 if ready_ or active else 0.4))


## Yuvarlak gösterge (hız / hararet), kodla çizilir
class Gauge extends Control:
	var title: String = ""
	var unit: String = ""
	var max_v: float = 100.0
	var red_from: float = -1.0
	var value: float = 0.0
	var major: int = 6
	var labels: Array = []      # boşsa sayılar yazılır
	var _shown: float = 0.0

	func set_value(v: float, delta: float) -> void:
		value = v
		var nv: float = lerpf(_shown, v, clampf(delta * 8.0, 0.0, 1.0))
		if absf(nv - _shown) > 0.05:
			_shown = nv
			queue_redraw()

	func _ang(v: float) -> float:
		return deg_to_rad(135.0 + 270.0 * clampf(v / max_v, 0.0, 1.0))

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r + 3.0, Color(0.75, 0.77, 0.82, 0.9))
		draw_circle(c, r, Color(0.06, 0.07, 0.1, 0.88))
		if red_from >= 0.0:
			draw_arc(c, r - 9.0, _ang(red_from), _ang(max_v), 24, Color(0.9, 0.15, 0.12), 8.0)
		var f: Font = ThemeDB.fallback_font
		for i in range(major + 1):
			var v: float = max_v * float(i) / float(major)
			var a: float = _ang(v)
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * (r - 16.0), c + dir * (r - 4.0), Color.WHITE, 3.0)
			var txt: String = str(int(v)) if labels.is_empty() else (String(labels[i]) if i < labels.size() else "")
			if txt != "":
				var ts: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
				draw_string(f, c + dir * (r - 30.0) - Vector2(ts.x * 0.5, -5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.88, 0.95))
			if i < major:
				var a2: float = _ang(v + max_v / float(major) * 0.5)
				var d2 := Vector2(cos(a2), sin(a2))
				draw_line(c + d2 * (r - 10.0), c + d2 * (r - 4.0), Color(1, 1, 1, 0.6), 2.0)
		var ts2: Vector2 = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var ty: float = r * 0.42 if unit != "" else -r * 0.3   # hararette yazı ortanın üstünde (S/H ile çakışmasın)
		draw_string(f, c + Vector2(-ts2.x * 0.5, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.3))
		if unit != "":
			var val: String = "%d %s" % [int(round(value)), unit]
			var ts3: Vector2 = f.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			draw_string(f, c + Vector2(-ts3.x * 0.5, r * 0.78), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		var na: float = _ang(_shown)
		var nd := Vector2(cos(na), sin(na))
		var side := Vector2(-nd.y, nd.x)
		var col: Color = Color(1.0, 0.25, 0.15) if (red_from >= 0.0 and _shown >= red_from) else Color(1.0, 0.55, 0.1)
		draw_colored_polygon(PackedVector2Array([c + nd * (r - 14.0), c + side * 5.0 - nd * 10.0, c - side * 5.0 - nd * 10.0]), col)
		draw_circle(c, 8.0, Color(0.85, 0.87, 0.9))


func _ready() -> void:
	randomize()
	_load()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	snd = SoundManager.new()
	add_child(snd)
	snd.music_on = music_on
	snd.sfx_on = sfx_on
	snd.apply()
	ads = AdService.new()
	add_child(ads)
	_build_background()
	_build_ui()
	_build_truck()
	_update_sky(0.2)
	if skip_menu:
		skip_menu = false
		start_game()
	else:
		open_menu()
	if not intro_done:
		intro_done = true
		var testing: bool = false
		for a in OS.get_cmdline_user_args():
			if String(a).begins_with("--case"):
				testing = true
		if not testing:
			_play_intro()
	if _gold_fixed:
		_save()
		_toast("Eski sürümdeki hata yüzünden fazladan yazılan altın düzeltildi: %d altın" % total_gold, 5.0)


## Açılış animasyonu: simgedeki sahne (gece, yokuş, sandıklı kamyon) belirir; kamyon tozlu yolda
## patinaj çekip tekerlerini boşa döndürür, sonra tutunup sola-yukarı gazlayarak simgeden çıkar.
## Ardından oyun açılır. Dokununca atlanır.
static var intro_done: bool = false


func _play_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bgc := Color(0.08, 0.08, 0.18)
	var bg := ColorRect.new()
	bg.color = bgc
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var isz: float = minf(vp.x, vp.y) * 0.56
	# simge çerçevesi: içindeki sahne kırpılır (köşeler arka plan rengiyle yuvarlatılır)
	var icon := Control.new()
	icon.size = Vector2(isz, isz)
	icon.position = vp * 0.5 - icon.size * 0.5 - Vector2(0, isz * 0.12)
	icon.pivot_offset = icon.size * 0.5
	icon.clip_contents = true
	icon.scale = Vector2(0.7, 0.7)
	icon.modulate.a = 0.0
	bg.add_child(icon)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.12, 0.12, 0.3), Color(0.33, 0.2, 0.33), Color(0.93, 0.45, 0.3)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var sky := TextureRect.new()
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = icon.size
	icon.add_child(sky)
	var world := Node2D.new()
	icon.add_child(world)
	# yamaç: sola doğru yükselen koyu tepe (simgedeki gibi)
	var y_left: float = isz * 0.6
	var y_right: float = isz * 0.86
	var hill := Polygon2D.new()
	hill.polygon = PackedVector2Array([Vector2(-10, y_left), Vector2(isz * 0.35, y_left + (y_right - y_left) * 0.3 - 6), Vector2(isz * 0.7, y_left + (y_right - y_left) * 0.72), Vector2(isz + 10, y_right), Vector2(isz + 10, isz + 10), Vector2(-10, isz + 10)])
	hill.color = Color(0.07, 0.06, 0.12)
	world.add_child(hill)
	# kamyon: simgedeki gibi koyu gövde, altın sandıklar, sola-yukarı bakar
	var d: Dictionary = {"cab": "offroad", "wheel_r": 32.0, "body": Color(0.34, 0.2, 0.22), "accent": Color(0.12, 0.1, 0.14),
		"bed": Color(0.13, 0.11, 0.16), "rim": Color(0.25, 0.25, 0.3), "tread": "offroad", "extras": ["stack", "lightbar"]}
	var truck_node := Node2D.new()
	var sc: float = isz / 430.0
	truck_node.scale = Vector2(-sc, sc)     # aynalı: burnu sola
	var slope: float = atan2(y_right - y_left, isz)
	truck_node.rotation = slope              # burun yukarı
	var start := Vector2(isz * 0.56, y_left + (y_right - y_left) * 0.56 - 68.0 * sc)
	truck_node.position = start
	world.add_child(truck_node)
	var body_n := Node2D.new()
	truck_node.add_child(body_n)
	TruckArt.paint_body(body_n, d, 32.0, 36.0)
	for c in [Vector2(-86, -34), Vector2(-50, -34), Vector2(-14, -34), Vector2(-66, -64)]:
		var crate := Polygon2D.new()
		crate.polygon = PackedVector2Array([c + Vector2(-16, -14), c + Vector2(16, -14), c + Vector2(16, 14), c + Vector2(-16, 14)])
		crate.color = Color(0.9, 0.66, 0.26)
		crate.z_index = 1
		body_n.add_child(crate)
		var cl := Line2D.new()
		cl.points = PackedVector2Array([c + Vector2(-16, -14), c + Vector2(16, -14), c + Vector2(16, 14), c + Vector2(-16, 14), c + Vector2(-16, -14), c + Vector2(16, 14)])
		cl.width = 3.0
		cl.default_color = Color(0.6, 0.4, 0.15)
		cl.z_index = 1
		body_n.add_child(cl)
	var wheels_n: Array = []
	for side in [-1.0, 1.0]:
		var w := Node2D.new()
		w.position = Vector2(78.0 * side, 36.0)
		w.z_index = 2
		truck_node.add_child(w)
		TruckArt.paint_wheel(w, d, 32.0)
		wheels_n.append(w)
	# toz: arka tekerden (ekranda sağ alt) yumuşak bulutlar
	var puff_g := Gradient.new()
	puff_g.set_color(0, Color(1, 1, 1, 1))
	puff_g.set_color(1, Color(1, 1, 1, 0))
	var puff := GradientTexture2D.new()
	puff.gradient = puff_g
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 32
	puff.height = 32
	var dust := CPUParticles2D.new()
	dust.texture = puff
	dust.amount = 60
	dust.lifetime = 1.1
	dust.local_coords = false
	dust.direction = Vector2(-1, -0.45)      # kamyonun yerel ekseninde geriye (aynalı: ekranda sağa)
	dust.position = Vector2(-78, 64)          # arka tekerin yere değdiği yer
	dust.spread = 28.0
	dust.initial_velocity_min = 60.0 * sc * 2.0
	dust.initial_velocity_max = 220.0 * sc * 2.0
	dust.gravity = Vector2(0, -15)
	dust.damping_min = 40.0
	dust.damping_max = 90.0
	dust.scale_amount_min = 0.6 * sc * 2.0
	dust.scale_amount_max = 1.8 * sc * 2.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.98, 0.66, 0.5, 0.85))
	fade.set_color(1, Color(0.7, 0.45, 0.45, 0.0))
	dust.color_ramp = fade
	dust.emitting = false
	truck_node.add_child(dust)
	# köşe yuvarlatma
	var rr: float = isz * 0.16
	for corner in [Vector2(0, 0), Vector2(isz, 0), Vector2(isz, isz), Vector2(0, isz)]:
		var cx: float = rr if corner.x == 0.0 else isz - rr
		var cy: float = rr if corner.y == 0.0 else isz - rr
		var pts := PackedVector2Array([corner])
		var a0: float = atan2(corner.y - cy, corner.x - cx) - PI * 0.25
		for q in range(9):
			var a: float = a0 + PI * 0.5 * float(q) / 8.0
			pts.append(Vector2(cx, cy) + Vector2(cos(a), sin(a)) * rr)
		var m := Polygon2D.new()
		m.polygon = pts
		m.color = bgc
		m.z_index = 5
		icon.add_child(m)
	var title := _label(bg, "DROP ZERO", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 80)
	title.position = Vector2(0, icon.position.y + isz + 14)
	title.modulate.a = 0.0
	var sub := _label(bg, "Heavy Hauler", 32)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(vp.x, 50)
	sub.position = Vector2(0, title.position.y + 74)
	sub.modulate.a = 0.0
	# motor sesi (yüksek devir döngüsü, perdesi yükselir)
	var roar := AudioStreamPlayer.new()
	roar.bus = "Efekt"
	roar.stream = load("res://audio/motor_ford_yuksek.wav")
	roar.volume_db = -60.0
	roar.pitch_scale = 0.75
	layer.add_child(roar)

	var done := {"v": false}
	var finish := func() -> void:
		if done["v"]:
			return
		done["v"] = true
		var tf := create_tween()
		tf.tween_property(bg, "modulate:a", 0.0, 0.35)
		tf.parallel().tween_property(roar, "volume_db", -60.0, 0.35)
		tf.tween_callback(layer.queue_free)
	var on_tap := func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			finish.call()
	bg.gui_input.connect(on_tap)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "modulate:a", 1.0, 0.3)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.4).set_delay(0.3)
	tw.tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(0.5)
	tw.set_parallel(false)
	# patinaj: tekerler boşta döner, toz kalkar, motor kükrer
	var spin := func() -> void:
		dust.emitting = true
		roar.play()
		var ag := AudioStreamPlayer.new()
		ag.bus = "Efekt"
		ag.stream = load("res://audio/aragaz_2.wav")
		layer.add_child(ag)
		ag.play()
	tw.tween_callback(spin)
	tw.set_parallel(true)
	tw.tween_property(roar, "volume_db", -4.0, 0.25)
	tw.tween_property(roar, "pitch_scale", 1.25, 0.9)
	for wn in wheels_n:
		tw.tween_property(wn, "rotation", -TAU * 5.0, 0.9)
	for q in range(6):
		tw.tween_property(truck_node, "position", start + Vector2(0, (-2.0 if q % 2 == 0 else 1.5) * sc * 2.0), 0.07).set_delay(0.15 * float(q))
	tw.set_parallel(false)
	# tutunur ve sola-yukarı gazlayıp simgeden çıkar
	var go := func() -> void:
		snd.sfx("patlama", -6.0, 1.0)
	tw.tween_callback(go)
	var dir := Vector2(-cos(slope), -sin(slope))
	tw.set_parallel(true)
	tw.tween_property(truck_node, "position", start + dir * isz * 1.25, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for wn in wheels_n:
		tw.tween_property(wn, "rotation", -TAU * 9.0, 0.85)
	tw.tween_property(roar, "pitch_scale", 1.4, 0.85)
	tw.set_parallel(false)
	var stop_dust := func() -> void:
		dust.emitting = false
	tw.tween_callback(stop_dust)
	tw.tween_property(roar, "volume_db", -30.0, 0.5)
	tw.tween_callback(finish)



func set_dev_mode(on: bool) -> void:
	dev_mode = on
	if not dev_mode and not owned.has(selected):
		selected = "tosun"
		_build_truck()
	_save()
	if menu:
		menu.refresh()
	_toast("Geliştirici modu " + ("AÇIK: tüm kamyonlar seçilebilir" if on else "KAPALI"), 2.2)


## Android geri tuşu: oyunda duraklat, duraklatmada devam et, menüde çık
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# arka plana atıldı: oyunu duraklat, kaydet
		if state == "play" and not game_over and pause_panel == null and rescue_panel == null:
			pause_game()
		_save()
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ads != null and ads.is_showing():
			return
		if rescue_panel != null:
			return
		if state == "play" and pause_panel == null:
			pause_game()
		elif pause_panel != null:
			resume_game()
		elif state == "over":
			_to_garage()
		else:
			get_tree().quit()


# ======================= KALDIĞI YERDEN DEVAM =======================
## Her teslimat istasyonunda yolculuk kaydedilir. Oyun kapansa bile menüde "DEVAM ET" çıkar,
## aynı arazide (aynı tohum) son ulaşılan istasyondan aynı bölüm ve kazançla sürülür.
func has_saved_run() -> bool:
	return not _saved_run.is_empty() and int(_saved_run.get("cp", 1)) >= 2


func saved_run_label() -> String:
	if not has_saved_run():
		return ""
	var cp: int = int(_saved_run["cp"])
	return "▶  DEVAM ET  •  Bölge %d (%d m)" % [cp, int((cp - 1) * terrain.checkpoint_interval_m)]


func _save_run() -> void:
	if state != "play" or game_over:
		return
	_saved_run = {"cp": next_cp, "gold": gold_run, "seed": terrain.get_seed(), "truck": selected,
		"fuel_ads": fuel_ads, "flips": flip_rescues, "delivered": delivered}
	_save()


func start_new_game() -> void:
	_saved_run = {}
	_save()
	start_game()


func resume_run() -> void:
	if not has_saved_run():
		start_new_game()
		return
	var r: Dictionary = _saved_run
	var cp: int = clampi(int(r.get("cp", 1)), 1, 500)
	var tid: String = String(r.get("truck", selected))
	if owned.has(tid) or dev_mode:
		selected = tid
	next_cp = cp
	gold_run = clampi(int(r.get("gold", 0)), 0, 100000)
	delivered = clampi(int(r.get("delivered", 0)), 0, 100000)
	fuel_ads = clampi(int(r.get("fuel_ads", 0)), 0, FUEL_AD_STEPS.size())
	flip_rescues = clampi(int(r.get("flips", 0)), 0, MAX_RESCUES)
	var x: float = terrain.checkpoint_x(cp - 1) + 80.0
	terrain.reseed(int(r.get("seed", 1)), x)
	_build_truck(x)
	if menu:
		menu.close_panel()
	start_game()
	_enter_station()   # son istasyonda: yükünü seç, yola çık
	_toast("Kaldığın yerden devam: Bölge %d - yükünü seç" % cp, 2.5)


func _truck_finite() -> bool:
	var parts: Array = [truck.body]
	parts.append_array(truck.wheels)
	for b in parts:
		var rb: RigidBody2D = b
		if not (rb.global_position.is_finite() and rb.linear_velocity.is_finite() and is_finite(rb.angular_velocity) and is_finite(rb.global_rotation)):
			return false
	return true


## Fizik motoru patlamasın: aşırı hızları sınırla (gerçek oyunda asla bu kadar hızlanılmaz)
func _limit_speeds() -> void:
	var parts: Array = [truck.body]
	parts.append_array(truck.wheels)
	for b in parts:
		var rb: RigidBody2D = b
		if rb.linear_velocity.length() > 6000.0:
			rb.linear_velocity = rb.linear_velocity.limit_length(6000.0)
		rb.angular_velocity = clampf(rb.angular_velocity, -400.0, 400.0)
	for c in cargo:
		if is_instance_valid(c) and not c.global_position.is_finite():
			c.global_position = truck.bed_to_global(Vector2(0, -40))
			c.linear_velocity = Vector2.ZERO


## Fizik bozulduysa: kamyonu son sağlam noktada yeniden kur, yük sayısını koru
func _recover_truck() -> void:
	_recoveries += 1
	if _recoveries > 20 and state == "play":
		_end("ŞASİ HASARI", "Kamyon yola geri konamadı.")
		return
	_rebuild_truck_at(_good_x if is_finite(_good_x) else 60.0)
	flip_t = 0.0
	if state == "play":
		_toast("Kamyon yola geri kondu", 1.5)


## Kamyonu x'te yeniden kur: yük sayısı, yakıt, hararet ve turbo aynen kalır
func _rebuild_truck_at(x: float) -> void:
	var keep: int = cargo.size()
	var total: int = cargo_total
	var fuel0: float = truck.fuel if is_finite(truck.fuel) else truck.fuel_capacity
	var heat0: float = truck.heat
	var turbo0: float = truck.turbo_charge
	x = maxf(x, 60.0)
	terrain.update_around(x)
	_build_truck(x)
	if at_station:
		_respawn_station_cargo()
		total = cargo_total
		keep = cargo.size()
	while cargo.size() > maxi(keep, 1):
		var c: RigidBody2D = cargo.pop_back()
		c.queue_free()
	cargo_total = total
	truck.fuel = clampf(fuel0, 0.0, truck.fuel_capacity)
	truck.heat = clampf(heat0, 0.0, 100.0)
	truck.turbo_charge = clampf(turbo0, 0.0, 1.0)
	for d in dropped.duplicate():
		if not is_instance_valid(d) or not d.global_position.is_finite():
			dropped.erase(d)
			if is_instance_valid(d):
				d.queue_free()
	_out_time.clear()
	_good_x = x
	_stuck_t = 0.0
	stuck = false
	_stuck_ref_x = x


# ======================= ÇUKURDA SIKIŞMA =======================
## Kamyon gaz/geri verildiği halde ileri de geri de gidemiyorsa "sıkıştı" sayılır.
## O zaman menüde (çark ya da telefonun geri tuşu) "Reklam izle, 50 m geriden başla" çıkar.
const STUCK_SECONDS := 4.0
const STUCK_MOVE_PX := 70.0
const UNSTUCK_BACK_M := 50.0
var stuck: bool = false
var _stuck_t: float = 0.0
var _stuck_ref_x: float = 0.0
var _stuck_hint_shown: bool = false


func _update_stuck(delta: float, x: float, trying: bool) -> void:
	if absf(x - _stuck_ref_x) > STUCK_MOVE_PX:
		_stuck_ref_x = x
		_stuck_t = 0.0
		stuck = false
		_stuck_hint_shown = false
		return
	if trying and not truck.overheated and truck.fuel > 0.0 and not truck.is_flipped():
		_stuck_t += delta
	if _stuck_t >= STUCK_SECONDS and not stuck:
		stuck = true
		if not _stuck_hint_shown:
			_stuck_hint_shown = true
			_toast("Sıkıştın! Çarka (ya da geri tuşuna) bas:\nReklam izle, 50 m geriden başla", 4.0)


## Reklam izlendi: kamyonu 50 m geriye, yola koy
func unstuck() -> void:
	var x: float = truck.body.global_position.x
	if not is_finite(x):
		x = _good_x
	_rebuild_truck_at(x - UNSTUCK_BACK_M * PX_PER_M)
	flip_t = 0.0
	_toast("50 m geriden devam!", 1.6)


## Kamyonu x noktasına koyarken gövde merkezinin y'si: iki tekerin de altındaki en yüksek
## zeminin üstünde kalır (yokuşta tekerlek toprağın içine gömülüp düşmesin)
func safe_drop_y(x: float, gap: float) -> float:
	var top: float = terrain.height_at(x)
	for dx in [-110.0, -78.0, -40.0, 40.0, 78.0, 110.0]:
		top = minf(top, terrain.height_at(x + dx))
	return top - gap - (truck.wheel_r - 26.0)


## Seçili kamyonu (ve yükseltmelerini) başlangıç noktasında kur, kasayı yükle
func _build_truck(at_x: float = 60.0) -> void:
	for c in cargo:
		c.queue_free()
	cargo.clear()
	_out_time.clear()
	if truck.built:
		truck.teardown()
	truck.apply_model(TruckCatalog.by_id(selected), levels_of(selected))
	var sx: float = at_x
	truck.build(Vector2(sx, safe_drop_y(sx, 95.0)))
	start_x = 60.0
	_spawn_cargo()


func open_menu() -> void:
	state = "menu"
	_reset_station()
	truck.menu_view = true
	for n in _hud_nodes:
		n.visible = false
	if menu == null:
		menu = MenuScreen.new()
		menu.manager = self
		menu.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ui_root.add_child(menu)
		_ui_root.move_child(menu, 0)   # bildirim yazısı menünün üstünde kalsın
	menu.visible = true
	menu.refresh()
	snd.play_music("garaj")


func start_game() -> void:
	state = "play"
	_recoveries = 0
	_good_x = truck.body.global_position.x if truck.body != null else 60.0
	stuck = false
	_stuck_t = 0.0
	_stuck_ref_x = _good_x
	_stuck_hint_shown = false
	time_left = _leg_time(next_cp)
	truck.menu_view = false
	truck.refuel()
	if menu:
		menu.visible = false
	for n in _hud_nodes:
		n.visible = true
	_reset_station()
	snd.play_music("yol")


# ======================= OYUN DÖNGÜSÜ =======================
func _physics_process(delta: float) -> void:
	if game_over or truck.body == null:
		return
	# fizik bozulursa (sonsuz/NaN konum) kamyonu son sağlam noktaya geri koy;
	# bu olmadan NaN konum "istasyonu geçti" sayılıp her karede altın yağabiliyordu
	if not _truck_finite():
		_recover_truck()
		return
	_limit_speeds()
	var x: float = truck.body.global_position.x
	if state == "play":
		_good_t += delta
		if _good_t >= 0.5 and truck.wheels_on_ground() and not truck.is_flipped():
			_good_t = 0.0
			_good_x = x
	terrain.update_around(x)
	if state != "play":
		truck.gas_pressed = false
		truck.brake_pressed = false
		return
	if at_station:
		_hold_at_station(delta)
		_update_sounds(delta)
		return

	var gas: bool = _pedal_down(gas_btn) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_UP)
	var brk: bool = _pedal_down(brake_btn) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_DOWN)
	truck.gas_pressed = gas
	truck.brake_pressed = brk and not gas
	# ara gaz: gaza peş peşe en az 3 kez hızlı basınca motor kükrer
	if gas and not _prev_gas:
		var now_s: float = Time.get_ticks_msec() / 1000.0
		_tap_streak = _tap_streak + 1 if now_s - _gas_release_t < 0.45 else 1
		if _tap_streak >= 3:
			snd.blip()
			blip_count += 1
			_tap_streak = 0   # bir sonraki ara gaz için yine 3 hızlı basış gerekir
	elif not gas and _prev_gas:
		_gas_release_t = Time.get_ticks_msec() / 1000.0
	_prev_gas = gas
	_brake_hold = _brake_hold + delta if truck.brake_pressed else 0.0
	truck.brake_hold = _brake_hold
	gas_btn.set_down(gas)
	brake_btn.set_down(brk)
	brake_btn.text = "◀ GERİ VİTES" if truck.reversing else "FREN / GERİ"
	if truck.reversing:
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 0.55
			snd.sfx("bip", -10.0)
	else:
		_beep_t = 0.0

	# teslimat süresi
	time_left -= delta
	var sec: int = int(ceil(time_left))
	if sec != _last_sec:
		_last_sec = sec
		if sec <= 10 and sec > 0:
			snd.sfx("tik", -2.0, 1.5)
	if time_left <= 0.0:
		_end("TESLİMAT GECİKTİ", "Yük zamanında teslim edilemedi.")
		return

	_update_stuck(delta, x, gas or brk)
	_check_cargo(delta)
	_check_checkpoint()
	if at_station:
		return   # teslimat yeni yapıldı, kasa boş: oyun sonu kontrolü yapılmaz
	_check_game_over(delta)
	_update_sounds(delta)


## Motor sesi devirle değişir; havadan iniş, aşırı ısınma sesleri
func _update_sounds(delta: float) -> void:
	var rpm: float = 0.0
	if not truck.wheels.is_empty():
		rpm = absf(truck.wheels[0].angular_velocity) / maxf(truck.max_wheel_speed, 1.0)
	var running: bool = truck.engine_enabled and truck.fuel > 0.0 and not game_over
	var thr: float = 1.0 if (truck.gas_pressed and not truck.overheated) else (0.5 if truck.brake_pressed else 0.0)
	snd.engine(running, rpm, thr if running else 0.0, delta)
	if truck.overheated and not _prev_overheat:
		snd.sfx("hararet", -4.0)
	_prev_overheat = truck.overheated
	if truck.wheels_on_ground():
		if _air_t > 0.45:
			snd.sfx("inis", clampf(-14.0 + _air_t * 8.0, -14.0, 0.0), randf_range(0.9, 1.1))
		_air_t = 0.0
	else:
		_air_t += delta

func _process(delta: float) -> void:
	if not get_tree().paused:
		_update_sky(delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_lbl.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	if truck.body == null:
		return
	if state != "play":
		snd.engine(state == "menu", 0.0, 0.0, delta)   # menüde rölanti
		return
	_update_hud(delta)


# ======================= YÜKLER =======================
## Kasayı yükle: her teslimatta yük listesi büyür ve çeşitlenir (CargoTypes.load_plan)
func _spawn_cargo(chosen: Array = []) -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var kinds: Array = chosen if not chosen.is_empty() else CargoTypes.load_plan(next_cp, r)
	var pos: Array = CargoTypes.pack(kinds)
	cargo_total = kinds.size()
	for i in range(kinds.size()):
		var c: RigidBody2D = CargoTypes.make(String(kinds[i]), r)
		c.set_meta("deger", cargo_price(String(kinds[i]), next_cp))
		c.contact_monitor = true
		c.max_contacts_reported = 2
		c.body_entered.connect(_on_cargo_hit.bind(c))
		add_child(c)
		c.global_position = truck.bed_to_global(pos[i])
		c.global_rotation = truck.body.global_rotation
		c.linear_velocity = truck.body.linear_velocity
		cargo.append(c)


## Kalan yükleri kasaya yeniden diz (reklamla kurtarmada)
func _repack_cargo() -> void:
	var kinds: Array = []
	for c in cargo:
		kinds.append(String(c.get_meta("tur", "sandik")))
	var pos: Array = CargoTypes.pack(kinds)
	for i in range(cargo.size()):
		var c: RigidBody2D = cargo[i]
		c.global_transform = Transform2D(truck.body.global_rotation, truck.bed_to_global(pos[i]))
		c.linear_velocity = Vector2.ZERO
		c.angular_velocity = 0.0


## Sandık bir yere çarpınca: hızına göre "tak" sesi (kasada sallanırken de, yere düşünce de)
func _on_cargo_hit(_other: Node, c: RigidBody2D) -> void:
	if not is_instance_valid(c) or state == "menu":
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_crash_cd.get(c, -10.0)) < 0.22:
		return
	var rel: Vector2 = c.linear_velocity
	if truck.body != null and cargo.has(c):
		rel -= truck.body.linear_velocity
	var spd: float = rel.length()
	if spd < 150.0:
		return
	_crash_cd[c] = now
	snd.sfx("yuk_dustu", clampf(-22.0 + spd / 40.0, -22.0, 0.0), randf_range(0.85, 1.25))


func _check_cargo(delta: float) -> void:
	for c in cargo.duplicate():
		if truck.is_in_bed(c.global_position):
			_out_time[c] = 0.0
			continue
		var t: float = float(_out_time.get(c, 0.0)) + delta
		_out_time[c] = t
		if t > 0.7:
			cargo.erase(c)
			_out_time.erase(c)
			dropped.append(c)
			c.modulate = Color(1, 0.75, 0.75, 0.8)
			_toast("%s düştü! %d/%d" % [CargoTypes.TYPES[String(c.get_meta("tur", "sandik"))]["name"], cargo.size(), cargo_total], 1.3)
			snd.sfx("yuk_dustu", 0.0, 0.8)
	# geride kalan düşmüş yükleri sil (bellek)
	var bx: float = truck.body.global_position.x
	for d in dropped.duplicate():
		if d.global_position.x < bx - 2500.0 or d.global_position.y > 6000.0:
			dropped.erase(d)
			d.queue_free()


# ======================= TESLİMAT =======================
func _leg_time(k: int) -> float:
	return leg_time + leg_time_bonus * float(mini(k - 1, 5))


func zone_name(k: int) -> String:
	return ZONES[mini(k - 1, ZONES.size() - 1)]


func _check_checkpoint() -> void:
	var cx: float = terrain.checkpoint_x(next_cp)
	var tx: float = truck.body.global_position.x
	if not is_finite(tx) or tx < cx:
		return
	# iki teslimat arasında en az 3 sn (bir şey ters giderse bile altın yağmaz)
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_delivery_ms < 3000:
		return
	_last_delivery_ms = now_ms
	# önce durumu ilerlet: sonraki satırlarda bir şey ters gitse bile bu teslimat
	# bir daha sayılmaz (ödül tek sefer verilir)
	var leg: int = next_cp
	next_cp += 1
	var intact: int = cargo.size()
	var time_bonus: int = clampi(int(maxf(time_left, 0.0) / 2.0), 0, 200)
	var cargo_value: int = 0
	for c in cargo:
		if is_instance_valid(c):
			cargo_value += clampi(int(c.get_meta("deger", gold_per_cargo)), 0, 400)
	var reward: int = cargo_value + station_bonus * leg + time_bonus
	if intact == cargo_total:
		reward += perfect_bonus
	reward = clampi(reward, 0, 4000)   # bir teslimatta olabilecek en yüksek ödül
	gold_run += reward
	delivered += intact
	truck.refuel()
	truck.heat = minf(truck.heat, 40.0)
	time_left = _leg_time(next_cp)
	# sağlam yükler teslim edildi, kasa boşaltılıp yeniden yükleniyor
	for c in cargo:
		if is_instance_valid(c):
			c.queue_free()
	cargo.clear()
	_out_time.clear()
	var msg: String = "TESLİMAT %d m!  %d sağlam yük  +%d altın (süre bonusu %d)\nYeni bölge: %s - yollar zorlaşıyor!" % [int(leg * terrain.checkpoint_interval_m), intact, reward, time_bonus, zone_name(next_cp)]
	if intact == cargo_total:
		msg = "KUSURSUZ! " + msg
	_toast(msg, 3.0)
	snd.sfx("teslimat")
	_save_run()      # kaldığı yerden devam için istasyonda kayıt
	_enter_station() # kamyon durur, yeni yükü oyuncu seçer


# ======================= İSTASYONDA YÜK SEÇME =======================
## Teslimattan sonra kamyon durur, "YÜKLE" tuşu çıkar. Basınca o istasyondaki yükler ve
## teslim edince her birinden kazanılacak altın görünür; dokundukça kasaya yüklenir.
const STATION_MAX_ITEMS := 10
var at_station: bool = false
var station_panel: Control
var load_btn: Button
var _station_kinds: Array = []
var _station_offer: Array = []
var _station_info: Label
var _station_go: Button
var _station_items: Array = []


## Bir yükün o bölgede teslim edilince kazandırdığı altın (ileride daha değerli)
func cargo_price(kind: String, leg: int) -> int:
	if not CargoTypes.TYPES.has(kind):
		return 0
	var base: float = float(CargoTypes.TYPES[kind]["value"])
	return clampi(int(round(base * (1.0 + 0.2 * float(clampi(leg, 1, 40) - 1)))), 1, 400)


## Kasa dolu mu: dizilince en üst sıra kasa duvarını çok aşmasın
func station_fits(kinds: Array) -> bool:
	if kinds.size() > STATION_MAX_ITEMS:
		return false
	var pos: Array = CargoTypes.pack(kinds)
	for i in range(kinds.size()):
		var sz: Vector2 = CargoTypes.TYPES[String(kinds[i])]["size"]
		if float(pos[i].y) - sz.y * 0.5 < CargoTypes.BED_FLOOR - 72.0:
			return false
	return true


func _station_offer_for(leg: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("istasyon:%d:%d" % [terrain.get_seed(), leg])
	var pool: Array = ["sandik", "cuval", "koli", "balya"]
	if leg >= 2:
		pool += ["varil"]
	if leg >= 3:
		pool += ["tomruk"]
	if leg >= 4:
		pool += ["tup"]
	var offer: Array = ["sandik"]
	while offer.size() < mini(5, pool.size()):
		var k: String = pool[r.randi_range(0, pool.size() - 1)]
		if not offer.has(k):
			offer.append(k)
	return offer


func _enter_station() -> void:
	at_station = true
	_station_kinds = []
	_station_offer = _station_offer_for(next_cp)
	for c in cargo:
		if is_instance_valid(c):
			c.queue_free()
	cargo.clear()
	_out_time.clear()
	cargo_total = 0
	_set_drive_controls(false)
	if load_btn == null:
		load_btn = Button.new()
		load_btn.text = "📦  YÜKLE"
		load_btn.name = "YukleBtn"
		load_btn.add_theme_font_size_override("font_size", 40)
		_style_btn(load_btn, Color(0.95, 0.55, 0.1))
		load_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		load_btn.offset_left = -170
		load_btn.offset_right = 170
		load_btn.offset_top = -150
		load_btn.offset_bottom = -50
		load_btn.pressed.connect(open_station)
		ui.add_child(load_btn)
	load_btn.visible = false   # kamyon durunca görünür


func _reset_station() -> void:
	at_station = false
	_station_kinds = []
	_station_items.clear()
	if station_panel != null:
		station_panel.queue_free()
		station_panel = null
	if load_btn != null:
		load_btn.visible = false
	if state == "play":
		_set_drive_controls(true)


func _set_drive_controls(on: bool) -> void:
	if gas_btn:
		gas_btn.visible = on
	if brake_btn:
		brake_btn.visible = on
	if turbo_btn:
		turbo_btn.visible = on
	if _gas_hint:
		_gas_hint.visible = on


## İstasyonda: kamyonu yumuşakça durdur ve yerinde tut
func _hold_at_station(delta: float) -> void:
	truck.gas_pressed = false
	truck.brake_pressed = false
	var b: RigidBody2D = truck.body
	b.linear_velocity = b.linear_velocity.move_toward(Vector2(0, b.linear_velocity.y), 900.0 * delta)
	for w in truck.wheels:
		w.angular_velocity = move_toward(w.angular_velocity, 0.0, 60.0 * delta)
	if load_btn != null and station_panel == null:
		load_btn.visible = absf(b.linear_velocity.x) < 25.0


func open_station() -> void:
	if not at_station or station_panel != null:
		return
	_click()
	load_btn.visible = false
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	sb.set_corner_radius_all(20)
	sb.border_color = Color(0.95, 0.6, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -268
	panel.offset_bottom = -12
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)
	station_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := _label(v, "YÜK SEÇ  •  %s" % zone_name(next_cp), 28)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	_station_items.clear()
	for k in _station_offer:
		var kind: String = k
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.text = "%s\n+%d altın" % [CargoTypes.TYPES[kind]["name"], cargo_price(kind, next_cp)]
		b.set_meta("tur", kind)
		_style_btn(b, Color(0.2, 0.42, 0.7))
		b.pressed.connect(station_add.bind(kind))
		grid.add_child(b)
		_station_items.append(b)
	_station_info = _label(v, "", 22)
	_station_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var clear := Button.new()
	clear.text = "BOŞALT"
	clear.custom_minimum_size = Vector2(220, 60)
	clear.add_theme_font_size_override("font_size", 24)
	_style_btn(clear, Color(0.35, 0.37, 0.45))
	clear.pressed.connect(station_clear)
	row.add_child(clear)
	_station_go = Button.new()
	_station_go.text = "YOLA ÇIK  ▶"
	_station_go.custom_minimum_size = Vector2(300, 60)
	_station_go.add_theme_font_size_override("font_size", 26)
	_style_btn(_station_go, Color(0.15, 0.62, 0.3))
	_station_go.pressed.connect(leave_station)
	row.add_child(_station_go)
	_portrait_scale(panel)
	_station_refresh()


## Dokununca bir yük daha kasaya
func station_add(kind: String) -> void:
	if not at_station or not _station_offer.has(kind):
		return
	var next: Array = _station_kinds.duplicate()
	next.append(kind)
	if not station_fits(next):
		_toast("Kasa doldu!", 1.0)
		return
	_station_kinds = next
	_click()
	_respawn_station_cargo()
	_station_refresh()


func station_clear() -> void:
	_station_kinds = []
	_respawn_station_cargo()
	_station_refresh()


## Yükleri yeniden diz: tomruklar altta (uzun olduğu için), gerisi üstte
func _respawn_station_cargo() -> void:
	for c in cargo:
		if is_instance_valid(c):
			c.queue_free()
	cargo.clear()
	_out_time.clear()
	var logs: Array = _station_kinds.filter(func(k): return k == "tomruk")
	var rest: Array = _station_kinds.filter(func(k): return k != "tomruk")
	var order: Array = logs + rest
	cargo_total = order.size()
	if not order.is_empty():
		_spawn_cargo(order)


func station_value() -> int:
	var sum: int = 0
	for k in _station_kinds:
		sum += cargo_price(String(k), next_cp)
	return sum


func _station_refresh() -> void:
	if _station_info == null or not is_instance_valid(_station_info):
		return
	var n: int = _station_kinds.size()
	if n == 0:
		_station_info.text = "Yüklemek için yüke dokun. Hepsi sağlam giderse +%d bonus!" % perfect_bonus
	else:
		_station_info.text = "Kasada %d yük  •  Teslimde: +%d altın  (+istasyon ve süre bonusu)" % [n, station_value()]
	var any_fit: bool = false
	for b in _station_items:
		var next: Array = _station_kinds.duplicate()
		next.append(String(b.get_meta("tur")))
		b.disabled = not station_fits(next)
		any_fit = any_fit or not b.disabled
	if n > 0 and not any_fit:
		_station_info.text = "KASA DOLU  •  %d yük  •  Teslimde: +%d altın  (+bonus)" % [n, station_value()]
	_station_go.disabled = n == 0


func leave_station() -> void:
	if not at_station or _station_kinds.is_empty():
		return
	at_station = false
	if station_panel != null:
		station_panel.queue_free()
		station_panel = null
	if load_btn != null:
		load_btn.visible = false
	_station_items.clear()
	_set_drive_controls(true)
	_out_time.clear()
	time_left = _leg_time(next_cp)
	_stuck_ref_x = truck.body.global_position.x
	_stuck_t = 0.0
	_toast("Yola çık! %d yük, teslimde +%d altın" % [_station_kinds.size(), station_value()], 2.0)


## Testler ve hızlı yükleme için: bölgenin standart yükünü koy ve yola çık
func station_autoload() -> void:
	if not at_station:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 7
	_station_kinds = []
	for k in CargoTypes.load_plan(next_cp, r):
		var next: Array = _station_kinds.duplicate()
		next.append(k)
		if station_fits(next):
			_station_kinds = next
	_respawn_station_cargo()
	leave_station()


# ======================= OYUN SONU =======================
func _check_game_over(delta: float) -> void:
	if truck.is_flipped():
		flip_t += delta
		if flip_t >= flip_time_limit:
			if flip_rescues < MAX_RESCUES:
				_offer_rescue("flip")
			else:
				_end("ŞASİ HASARI", "Kamyon ters döndü ve %d saniye öyle kaldı." % int(flip_time_limit))
			return
	else:
		flip_t = 0.0

	if truck.fuel <= 0.0:
		# yakıt bitti: kamyon durunca (ya da en geç 10 sn sonra) oyun biter
		var spd: float = absf(truck.body.linear_velocity.x)
		empty_t = empty_t + delta if spd < 40.0 else 0.0
		empty_total += delta
		if empty_t >= 2.0 or empty_total >= 10.0:
			if fuel_ads < FUEL_AD_STEPS.size():
				_offer_rescue("fuel")
			else:
				_end("YAKIT BİTTİ", "Depo boşaldı, kamyon yolda kaldı.")
			return

	if cargo.is_empty():
		_end("TÜM YÜKLER DÖKÜLDÜ", "Kasada hiç yük kalmadı (0/%d)." % cargo_total)
		return

	# kamyon zeminin altına düştüyse (fizik hatası) oyun bitmez: son sağlam yere geri konur
	var bx: float = truck.body.global_position.x
	if truck.body.global_position.y > terrain.height_at(bx) + 260.0:
		_recover_truck()
		return
	for w in truck.wheels:
		if w.global_position.y > terrain.height_at(w.global_position.x) + 200.0:
			_recover_truck()
			return


# ======================= REKLAMLA KURTARMA =======================
## Kamyon devrilince ya da yakıt bitince: "Reklam izle, devam et" teklifi
const FUEL_AD_STEPS: Array = [0.10, 0.15, 0.25]   # 1. reklam %10, 3 reklamda toplam %50 (yarım depo)
const MAX_RESCUES := 3
var fuel_ads: int = 0
var flip_rescues: int = 0
var rescue_panel: Control


func _offer_rescue(kind: String) -> void:
	if rescue_panel != null or game_over:
		return
	get_tree().paused = true
	gas_btn.visible = false
	brake_btn.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	rescue_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.97)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.95, 0.6, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title: String = "YAKIT BİTTİ!" if kind == "fuel" else "KAMYON DEVRİLDİ!"
	var t := _label(v, title, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(1, 0.45, 0.3))
	var info: String
	var btn_text: String
	if kind == "fuel":
		var add: float = float(FUEL_AD_STEPS[fuel_ads])
		var total: float = 0.0
		for i in range(fuel_ads + 1):
			total += float(FUEL_AD_STEPS[i])
		info = "Reklam izle, depoya %%%d yakıt koyalım.\n3 reklamda depo yarıya kadar dolar (%d/3)." % [int(add * 100.0), fuel_ads + 1]
		btn_text = "▶  Reklam izle: +%%%d yakıt" % int(add * 100.0)
	else:
		info = "Reklam izle, kamyonu düzeltip yola devam et.\n(%d/%d)" % [flip_rescues + 1, MAX_RESCUES]
		btn_text = "▶  Reklam izle: kamyonu düzelt"
	var d := _label(v, info, 22)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var watch := func() -> void:
		var ok := func() -> void:
			_apply_rescue(kind)
		var cancel := func() -> void:
			pass
		ads.show_rewarded(ok, cancel)
	_menu_btn(v, btn_text, Color(0.15, 0.6, 0.3), watch)
	var give_up := func() -> void:
		_close_rescue()
		if kind == "fuel":
			_end("YAKIT BİTTİ", "Depo boşaldı, kamyon yolda kaldı.")
		else:
			_end("ŞASİ HASARI", "Kamyon ters döndü ve %d saniye öyle kaldı." % int(flip_time_limit))
	_menu_btn(v, "Hayır, oyunu bitir", Color(0.35, 0.37, 0.45), give_up)


func _apply_rescue(kind: String) -> void:
	if kind == "fuel":
		truck.fuel = minf(truck.fuel + truck.fuel_capacity * float(FUEL_AD_STEPS[fuel_ads]), truck.fuel_capacity)
		fuel_ads += 1
		empty_t = 0.0
		empty_total = 0.0
		_toast("Yakıt eklendi! Devam!", 1.6)
	else:
		flip_rescues += 1
		var x: float = truck.body.global_position.x
		truck.upright_at(Vector2(x, safe_drop_y(x, 100.0)))
		# kasada kalan yükleri yerine koy
		_repack_cargo()
		_out_time.clear()
		flip_t = 0.0
		_toast("Kamyon düzeltildi! Devam!", 1.6)
	_close_rescue()


func _close_rescue() -> void:
	if rescue_panel != null:
		rescue_panel.queue_free()
		rescue_panel = null
	gas_btn.visible = true
	brake_btn.visible = true
	_touches.clear()
	_mouse_down = false
	get_tree().paused = false


func _end(title: String, detail: String) -> void:
	if game_over:
		return
	game_over = true
	state = "over"
	end_reason = title
	_saved_run = {}   # bitti: kaldığı yerden devam kaydı silinir
	truck.engine_enabled = false
	var dist_m: float = _distance_m()
	var dist_bonus: int = int(dist_m / 20.0)
	gold_run += dist_bonus
	total_gold += gold_run
	var new_best: bool = dist_m > best_m
	best_m = maxf(best_m, dist_m)
	_save()
	snd.engine(false, 0.0, 0.0, 1.0)
	_show_game_over(title, detail, dist_m, dist_bonus, new_best)
	get_tree().paused = true


## Yeniden başla: her 2 oyunda bir, oyunlar arası doğal molada tam ekran reklam
func _restart() -> void:
	restarts += 1
	var go := func() -> void:
		skip_menu = true
		get_tree().paused = false
		get_tree().reload_current_scene()
	if restarts % 2 == 0:
		ads.show_interstitial(go)
	else:
		go.call()


func _to_garage() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()


## Yarıda bırakılan oyunda teslimatlardan kazanılan altın kaybolmasın
func _bank_run() -> void:
	if state == "play" and not game_over and gold_run > 0:
		total_gold += gold_run
		gold_run = 0
		best_m = maxf(best_m, _distance_m())
		if not _saved_run.is_empty():
			_saved_run["gold"] = 0     # kasaya girdi, devam edince tekrar sayılmasın
		_save()


# ======================= DURAKLATMA MENÜSÜ =======================
func pause_game() -> void:
	if state != "play" or game_over or pause_panel != null or rescue_panel != null:
		return
	get_tree().paused = true
	gas_btn.visible = false
	brake_btn.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	pause_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.97)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.95, 0.6, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := _label(v, "DURAKLATILDI", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if stuck:
		var hint := _label(v, "Kamyon sıkıştı, ileri de geri de gidemiyor.", 22)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var watch := func() -> void:
			var ok := func() -> void:
				resume_game()
				unstuck()
			ads.show_rewarded(ok)
		var sb_btn := _menu_btn(v, "▶  Reklam izle, 50 m geriden başla", Color(0.55, 0.25, 0.75), watch)
		sb_btn.name = "SikismaBtn"
	_menu_btn(v, "DEVAM ET  ▶", Color(0.15, 0.68, 0.3), resume_game)
	var again := func() -> void:
		_bank_run()
		_restart()
	_menu_btn(v, "YENİDEN BAŞLA", Color(0.2, 0.45, 0.8), again)
	var home := func() -> void:
		_bank_run()
		_to_garage()
	_menu_btn(v, "ANA MENÜ / GARAJ", Color(0.85, 0.5, 0.1), home)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	add_settings_toggles(row)
	_portrait_scale(panel)


func resume_game() -> void:
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	_set_drive_controls(not at_station)
	_touches.clear()
	_mouse_down = false
	get_tree().paused = false


func _menu_btn(parent: Control, text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 62)
	b.add_theme_font_size_override("font_size", 26)
	_style_btn(b, col)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Müzik / Efekt / Gece düğmeleri (duraklatma menüsü ve ana menü ortak)
func add_settings_toggles(parent: Control) -> void:
	var items: Array = [["Müzik", "music"], ["Ses", "sfx"]]
	for it in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(122, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var key: String = it[1]
		var label: String = it[0]
		var paint := func() -> void:
			var on: bool = music_on if key == "music" else sfx_on
			b.text = "%s: %s" % [label, "AÇIK" if on else "KAPALI"]
			_style_btn(b, Color(0.15, 0.55, 0.35) if on else Color(0.3, 0.32, 0.38))
		var flip := func() -> void:
			match key:
				"music":
					music_on = not music_on
				"sfx":
					sfx_on = not sfx_on
			snd.music_on = music_on
			snd.sfx_on = sfx_on
			snd.apply()
			_save()
			paint.call()
		paint.call()
		b.pressed.connect(flip)
		parent.add_child(b)


func _distance_m() -> float:
	var x: float = truck.body.global_position.x
	if not is_finite(x):
		x = _good_x
	return clampf((x - start_x) / PX_PER_M, 0.0, 1000000.0)


# ======================= GİRİŞ (çoklu dokunma) =======================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
			if state == "play" and turbo_btn != null and turbo_btn.is_visible_in_tree() and turbo_btn.get_global_rect().has_point(st.position):
				_try_turbo()
		else:
			_touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = mb.pressed
			_mouse_pos = mb.position
			if mb.pressed and not mb.is_echo() and _touches.is_empty() and state == "play" and turbo_btn != null and turbo_btn.is_visible_in_tree() and turbo_btn.get_global_rect().has_point(mb.position):
				_try_turbo()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and (k.physical_keycode == KEY_SPACE or k.physical_keycode == KEY_SHIFT) and state == "play":
			_try_turbo()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_mouse_pos = mm.position


func _try_turbo() -> void:
	if truck.use_turbo():
		snd.sfx("turbo", -2.0)
		_toast("TURBO!", 0.8)


func _pedal_down(p: Control) -> bool:
	if p == null or not p.is_visible_in_tree():
		return false
	var r: Rect2 = p.get_global_rect()
	for k in _touches:
		var pos: Vector2 = _touches[k]
		if r.has_point(pos):
			return true
	return _mouse_down and r.has_point(_mouse_pos)


# ======================= UI =======================
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_ui_root = root
	_apply_safe_area(root)

	# --- üst bilgi şeridi ---
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.72)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", sb)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)

	fuel_bar = _bar_block(row, "YAKIT", Color(0.98, 0.65, 0.12))
	cargo_lbl = _label(row, "YÜK 5/5", 26)
	dist_lbl = _label(row, "0 m", 26)
	gold_lbl = _label(row, "ALTIN 0", 26)
	next_lbl = _label(row, "", 22)
	timer_lbl = _label(row, "", 26)
	zone_lbl = _label(root, "", 20)
	zone_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	zone_lbl.offset_left = 26
	zone_lbl.offset_top = 82
	zone_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	pause_btn = make_gear_button(pause_game)   # sağ üst: ayarlar / duraklat çarkı
	pause_btn.custom_minimum_size = Vector2(64, 64)
	row.add_child(pause_btn)

	# --- uyarı ve bildirim yazıları ---
	warn_lbl = _label(root, "", 34)
	warn_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn_lbl.offset_top = 110
	warn_lbl.offset_left = -400
	warn_lbl.offset_right = 400
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	toast_lbl = _label(root, "", 30)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER)
	toast_lbl.offset_left = -520
	toast_lbl.offset_right = 520
	toast_lbl.offset_top = -170
	toast_lbl.offset_bottom = -60
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.4))

	# --- pedallar ---
	brake_btn = Pedal.new()
	brake_btn.text = "FREN / GERİ"
	brake_btn.base_color = Color(0.85, 0.2, 0.2)
	brake_btn.arrow = -1
	brake_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brake_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brake_btn.offset_left = 28
	brake_btn.offset_right = 268
	brake_btn.offset_top = -240
	brake_btn.offset_bottom = -28
	root.add_child(brake_btn)

	gas_btn = Pedal.new()
	gas_btn.text = "GAZ"
	gas_btn.base_color = Color(0.15, 0.72, 0.3)
	gas_btn.arrow = 1
	gas_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gas_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	gas_btn.offset_left = -268
	gas_btn.offset_right = -28
	gas_btn.offset_top = -240
	gas_btn.offset_bottom = -28
	root.add_child(gas_btn)
	var hint := _label(root, "Ara gaz için\n3 kere bas", 17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -440
	hint.offset_right = -280
	hint.offset_top = -92
	hint.offset_bottom = -30
	_gas_hint = hint

	# --- göstergeler (alt orta): hız ve hararet ---
	var gauges := HBoxContainer.new()
	gauges.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	gauges.offset_left = -180
	gauges.offset_right = 180
	gauges.offset_top = -186
	gauges.offset_bottom = -16
	gauges.alignment = BoxContainer.ALIGNMENT_CENTER
	gauges.add_theme_constant_override("separation", 20)
	gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gauges)
	speed_gauge = Gauge.new()
	speed_gauge.title = "HIZ"
	speed_gauge.unit = "km/s"
	speed_gauge.max_v = 120.0
	speed_gauge.major = 6
	speed_gauge.custom_minimum_size = Vector2(170, 170)
	speed_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauges.add_child(speed_gauge)
	heat_gauge = Gauge.new()
	heat_gauge.title = "HARARET"
	heat_gauge.max_v = 100.0
	heat_gauge.red_from = 80.0
	heat_gauge.major = 4
	heat_gauge.labels = ["S", "", "", "", "H"]
	heat_gauge.custom_minimum_size = Vector2(150, 150)
	heat_gauge.size_flags_vertical = Control.SIZE_SHRINK_END
	heat_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauges.add_child(heat_gauge)
	turbo_btn = TurboButton.new()
	turbo_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turbo_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	turbo_btn.offset_left = -236
	turbo_btn.offset_right = -76
	turbo_btn.offset_top = -420
	turbo_btn.offset_bottom = -260
	root.add_child(turbo_btn)
	_hud_nodes = [top, warn_lbl, brake_btn, gas_btn, gauges, turbo_btn, zone_lbl, _gas_hint]


## Telefon çentiği / yuvarlak köşeler: arayüzü güvenli alanın içine al (sadece mobilde).
## Ekran döndürülünce yeniden hesaplanır; yatayda sadece yanlardan, dikeyde sadece üstten pay bırakılır
## (üst bilgi şeridi her zaman en üstte kalır).
func _apply_safe_area(root: Control) -> void:
	if not get_viewport().size_changed.is_connected(_on_resized):
		get_viewport().size_changed.connect(_on_resized)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	if not OS.has_feature("mobile"):
		return
	# ön kamera deliği / çentik: güvenli alanın dışında kalan kenarlar kadar arayüzü içeri al
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var scr: Vector2i = DisplayServer.screen_get_size()
	if scr.x <= 0 or scr.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return
	# döndürme anında güvenli alan eski yönde kalmış olabilir: yönler uyuşmuyorsa sonra tekrar denenir
	if (safe.size.x >= safe.size.y) != (scr.x >= scr.y):
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: Vector2 = vp / Vector2(scr)
	var left: float = float(safe.position.x) * k.x
	var top: float = float(safe.position.y) * k.y
	var right: float = float(scr.x - safe.end.x) * k.x
	var bottom: float = float(scr.y - safe.end.y) * k.y
	root.offset_left = clampf(left, 0.0, 140.0)
	root.offset_top = clampf(top, 0.0, 140.0)
	root.offset_right = -clampf(right, 0.0, 140.0)
	root.offset_bottom = -clampf(bottom, 0.0, 60.0)


func _on_resized() -> void:
	if _ui_root == null:
		return
	_apply_safe_area(_ui_root)
	# Android döndürmeden sonra güvenli alanı biraz geç bildirir: kısa süre sonra bir kez daha
	get_tree().create_timer(0.4, true).timeout.connect(func() -> void: _apply_safe_area(_ui_root))


func _bar_block(parent: Control, title: String, col: Color) -> ProgressBar:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	_label(box, title, 18)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(190, 20)
	pb.show_percentage = false
	pb.max_value = 100.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.16, 0.2)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(8)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	box.add_child(pb)
	return pb


func _label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	parent.add_child(l)
	return l


func _update_hud(delta: float) -> void:
	fuel_bar.value = truck.fuel / maxf(truck.fuel_capacity, 1.0) * 100.0
	speed_gauge.set_value(absf(truck.speed_kmh()), delta)
	heat_gauge.set_value(truck.heat, delta)
	cargo_lbl.text = "YÜK %d/%d" % [cargo.size(), cargo_total]
	cargo_lbl.add_theme_color_override("font_color", Color.WHITE if cargo.size() > 2 else Color(1, 0.45, 0.35))
	dist_lbl.text = "%d m" % int(_distance_m())
	gold_lbl.text = "ALTIN %d" % gold_run
	var to_next: float = (terrain.checkpoint_x(next_cp) - truck.body.global_position.x) / PX_PER_M
	next_lbl.text = "TESLİMAT: %d m" % maxi(int(to_next), 0)
	var tl: int = maxi(int(ceil(time_left)), 0)
	timer_lbl.text = "SÜRE %d:%02d" % [tl / 60, tl % 60]
	timer_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if time_left < 15.0 else Color.WHITE)
	var rk: String = terrain.road_at(truck.body.global_position.x)
	zone_lbl.text = "Bölge %d: %s   •   %s" % [next_cp, zone_name(next_cp), terrain.ROADS[rk]["name"]]
	if rk != _last_road:
		if _last_road != "":
			var extra: String = ""
			if rk == "camur" or rk == "kar":
				extra = "\nKaygan! Yavaş ve dikkatli"
			elif rk == "dag":
				extra = "\nDik yokuşlar başlıyor"
			elif rk == "asfalt":
				extra = "\nRahat yol, gaza bas"
			_toast(String(terrain.ROADS[rk]["name"]) + extra, 1.8)
		_last_road = rk
	turbo_btn.set_state(truck.turbo_charge, truck.turbo_active)

	var warn: String = ""
	if truck.overheated:
		warn = "MOTOR AŞIRI ISINDI! Güç kesildi..."
	elif truck.heat > 80.0:
		warn = "Hararet yüksek - gazı biraz bırak"
	if flip_t > 0.0 and not game_over:
		warn = "ŞASİ TEHLİKEDE! %.1f" % maxf(flip_time_limit - flip_t, 0.0)
	elif truck.fuel <= 0.0:
		warn = "YAKIT BİTTİ!"
	elif fuel_bar.value < 20.0:
		warn = "Yakıt azaldı!"
	elif time_left < 15.0:
		warn = "ACELE ET! Teslimata %d sn kaldı" % int(ceil(time_left))
	warn_lbl.text = warn
	warn_lbl.visible = warn != "" and (fmod(Time.get_ticks_msec() / 1000.0, 0.7) < 0.5 or flip_t > 0.0)



func _toast(text: String, secs: float) -> void:
	toast_lbl.text = text
	_toast_t = secs
	toast_lbl.modulate.a = 1.0


func _show_game_over(title: String, detail: String, dist_m: float, dist_bonus: int, new_best: bool) -> void:
	gas_btn.visible = false
	brake_btn.visible = false
	over_panel = ColorRect.new()
	(over_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(over_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.97)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.95, 0.6, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var t := _label(v, title, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	var d := _label(v, detail, 22)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats := "Mesafe: %d m%s   •   Teslim edilen yük: %d\nBu sefer: %d altın (mesafe bonusu %d)   •   Toplam altın: %d" % [
		int(dist_m), "  (YENİ REKOR!)" if new_best else "", delivered, gold_run, dist_bonus, total_gold]
	var s := _label(v, stats, 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var dbl := Button.new()
	dbl.text = "Reklam izle: kazancı 2 katına çıkar (+%d altın)" % gold_run
	dbl.custom_minimum_size = Vector2(0, 58)
	dbl.add_theme_font_size_override("font_size", 24)
	dbl.disabled = gold_run <= 0
	_style_btn(dbl, Color(0.85, 0.55, 0.1))
	var do_double := func() -> void:
		var reward := func() -> void:
			if _doubled:
				return
			_doubled = true
			total_gold += gold_run
			_save()
			dbl.disabled = true
			dbl.text = "Kazanç ikiye katlandı! (+%d altın)" % gold_run
			s.text = "Mesafe: %d m   •   Teslim edilen yük: %d\nBu sefer: %d altın   •   Toplam altın: %d" % [int(dist_m), delivered, gold_run * 2, total_gold]
		ads.show_rewarded(reward)
	dbl.pressed.connect(do_double)
	v.add_child(dbl)

	var garage := Button.new()
	garage.text = "GARAJ / MAĞAZA"
	garage.custom_minimum_size = Vector2(0, 58)
	garage.add_theme_font_size_override("font_size", 26)
	_style_btn(garage, Color(0.2, 0.4, 0.75))
	garage.pressed.connect(_to_garage)
	v.add_child(garage)

	var again := Button.new()
	again.text = "YENİDEN BAŞLA"
	again.custom_minimum_size = Vector2(0, 64)
	again.add_theme_font_size_override("font_size", 30)
	_style_btn(again, Color(0.15, 0.68, 0.3))
	again.pressed.connect(_restart)
	v.add_child(again)


func make_gear_button(cb: Callable) -> Button:
	var g := GearButton.new()
	g.flat = true
	g.focus_mode = Control.FOCUS_NONE
	g.custom_minimum_size = Vector2(76, 76)
	g.tooltip_text = "Ayarlar"
	g.pressed.connect(_click)
	g.pressed.connect(cb)
	return g


## Menüdeki çark: ses ayarları
func open_settings() -> void:
	if settings_panel != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	settings_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.97)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.95, 0.6, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := _label(v, "AYARLAR", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	add_settings_toggles(row)
	var close := func() -> void:
		if settings_panel != null:
			settings_panel.queue_free()
			settings_panel = null
	_menu_btn(v, "KAPAT", Color(0.3, 0.32, 0.4), close)
	_portrait_scale(panel)


## Dikey ekranda pencere küçük kalıyordu: dikeyde %50 büyüt (yatayda aynı kalır).
## Kapsayıcılar (CenterContainer) çocuğun ölçeğini sıfırladığı için, varsa kapsayıcının kendisi büyütülür.
func _portrait_scale(panel: Control) -> void:
	var target: Control = panel
	var bottom: bool = true
	if panel.get_parent() is CenterContainer:
		target = panel.get_parent() as Control
		bottom = false
	var fit := func() -> void:
		if not is_instance_valid(panel) or not is_instance_valid(target):
			return
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var k: float = 1.5 if vs.y > vs.x else 1.0
		if k > 1.0 and panel.size.x > 0.0:
			k = maxf(1.0, minf(k, (vs.x - 24.0) / panel.size.x))   # ekrandan taşmasın
		target.pivot_offset = Vector2(target.size.x * 0.5, target.size.y if bottom else target.size.y * 0.5)
		target.scale = Vector2(k, k)
	panel.resized.connect(fit)
	target.resized.connect(fit)
	get_viewport().size_changed.connect(fit)
	var vp: Viewport = get_viewport()
	var unhook := func() -> void:
		if vp.size_changed.is_connected(fit):
			vp.size_changed.disconnect(fit)
	panel.tree_exiting.connect(unhook)
	fit.call_deferred()


func _click() -> void:
	if snd:
		snd.sfx("tik", -8.0)


func _style_btn(b: Button, col: Color) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if st != "disabled" else col.darkened(0.55)
		if st == "pressed":
			sb.bg_color = col.darkened(0.2)
		if st == "focus":
			sb.draw_center = false
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override(st, sb)
	b.focus_mode = Control.FOCUS_NONE
	if not b.has_meta("tik"):
		b.set_meta("tik", true)
		b.pressed.connect(_click)


# ======================= EKONOMİ (menü bunları çağırır) =======================
## Her satın alma / yükseltme / dönüştürme önce TAM EKRAN reklam gösterir, sonra işlem yapılır.

func levels_of(truck_id: String) -> Dictionary:
	var d := {}
	for up in UPGRADES:
		d[up["id"]] = int(up_levels.get(truck_id + ":" + String(up["id"]), 0))
	return d


func upgrade_cost(truck_id: String, up_id: String) -> int:
	var lvl: int = int(levels_of(truck_id).get(up_id, 0))
	var tier: float = 1.0 + float(TruckCatalog.by_id(truck_id)["price"]) / 2500.0   # pahalı kamyonun parçası da pahalı
	return int(60.0 * pow(1.55, float(lvl)) * tier)


func buy_truck(id: String) -> void:
	var def: Dictionary = TruckCatalog.by_id(id)
	var price: int = int(def["price"])
	if owned.has(id) or dev_mode:
		select_truck(id)
		return
	if tokens < price:
		_toast("Jetonun yetmiyor: %d / %d\nMağaza'dan jeton al ya da reklam izle" % [tokens, price], 2.5)
		return
	var buy := func() -> void:
		if tokens < price or owned.has(id):
			return
		tokens -= price
		owned.append(id)
		_save()
		select_truck(id)
		_toast("%s artık senin!" % def["name"], 2.5)
		snd.sfx("satin_al")
	ads.show_interstitial(buy)


func select_truck(id: String) -> void:
	if not owned.has(id) and not dev_mode:
		return
	selected = id
	_save()
	_build_truck()
	if menu:
		menu.refresh()


func buy_upgrade(up_id: String) -> void:
	var lvl: int = int(levels_of(selected).get(up_id, 0))
	if lvl >= MAX_LEVEL:
		return
	var cost: int = upgrade_cost(selected, up_id)
	if total_gold < cost:
		_toast("Altının yetmiyor: %d / %d" % [total_gold, cost], 2.0)
		return
	var buy := func() -> void:
		if total_gold < cost:
			return
		total_gold -= cost
		up_levels[selected + ":" + up_id] = lvl + 1
		_save()
		_build_truck()
		if menu:
			menu.refresh()
		_toast("Yükseltildi! Seviye %d" % (lvl + 1), 1.8)
		snd.sfx("satin_al")
	ads.show_interstitial(buy)


## 100 altın = 10 jeton. steps: kaç adım (1 adım = 100 altın), -1 = hepsi
func convert_gold(steps: int) -> void:
	var max_steps: int = total_gold / GOLD_PER_TOKEN_STEP
	var n: int = max_steps if steps < 0 else steps
	if n <= 0 or n > max_steps:
		_toast("En az %d altın gerekli" % (GOLD_PER_TOKEN_STEP * maxi(n, 1)), 2.0)
		return
	var conv := func() -> void:
		if total_gold < n * GOLD_PER_TOKEN_STEP:
			return
		total_gold -= n * GOLD_PER_TOKEN_STEP
		tokens += n * TOKENS_PER_STEP
		_save()
		if menu:
			menu.refresh()
		_toast("%d altın → %d jeton" % [n * GOLD_PER_TOKEN_STEP, n * TOKENS_PER_STEP], 2.0)
		snd.sfx("satin_al")
	ads.show_interstitial(conv)


func watch_ad_for_tokens() -> void:
	var reward := func() -> void:
		tokens += REWARDED_TOKENS
		_save()
		if menu:
			menu.refresh()
		_toast("+%d jeton!" % REWARDED_TOKENS, 2.0)
		snd.sfx("satin_al")
	ads.show_rewarded(reward)


func buy_pack(pack: Dictionary) -> void:
	var ok := func() -> void:
		tokens += int(pack["tokens"])
		_save()
		if menu:
			menu.refresh()
		_toast("+%d jeton eklendi" % int(pack["tokens"]), 2.0)
		snd.sfx("satin_al")
	ads.buy_pack(pack, ok)


# ======================= GÖKYÜZÜ / GECE MODU =======================
func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = TextureRect.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(_sky)

	var pb := ParallaxBackground.new()
	pb.layer = -5
	add_child(pb)
	# bulutlar: dağların arkasında, yavaşça süzülür
	_cloud_layer = ParallaxLayer.new()
	_cloud_layer.motion_scale = Vector2(0.06, 0.03)
	_cloud_layer.motion_mirroring = Vector2(3600, 0)
	pb.add_child(_cloud_layer)
	var clouds := Node2D.new()
	_cloud_layer.add_child(clouds)
	_mountains.append(clouds)
	var cr := RandomNumberGenerator.new()
	cr.seed = 77
	for ci in range(9):
		var cloud := Node2D.new()
		cloud.position = Vector2(float(ci) * 400.0 + cr.randf_range(0, 200), cr.randf_range(40, 260))
		var sc: float = cr.randf_range(0.7, 1.5)
		cloud.scale = Vector2(sc, sc)
		var puffs: int = cr.randi_range(4, 6)
		for k in range(puffs):
			var px: float = (float(k) - float(puffs - 1) * 0.5) * 34.0
			var r: float = cr.randf_range(26.0, 44.0) * (1.0 - absf(float(k) / float(puffs - 1) - 0.5) * 0.6)
			var under := _disc(r, Color(0.82, 0.86, 0.93, 0.9))
			under.position = Vector2(px, 6)
			cloud.add_child(under)
		for k in range(puffs):
			var px2: float = (float(k) - float(puffs - 1) * 0.5) * 34.0
			var r2: float = cr.randf_range(24.0, 40.0) * (1.0 - absf(float(k) / float(puffs - 1) - 0.5) * 0.6)
			var top_puff := _disc(r2, Color(1, 1, 1, 0.95))
			top_puff.position = Vector2(px2, -4 - cr.randf_range(0, 14))
			cloud.add_child(top_puff)
		clouds.add_child(cloud)
	for li in range(2):
		var pl := ParallaxLayer.new()
		var far: bool = li == 0
		pl.motion_scale = Vector2(0.15, 0.05) if far else Vector2(0.35, 0.12)
		pl.motion_mirroring = Vector2(2400, 0)
		pb.add_child(pl)
		var pts := PackedVector2Array()
		var n: int = 24
		for i in range(n + 1):
			var x: float = 2400.0 * float(i) / float(n)
			var y: float = (330.0 if far else 430.0) - sin(x * (0.004 if far else 0.007) + li) * (90.0 if far else 60.0) - sin(x * 0.013) * 25.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(2400, 3000))
		pts.append(Vector2(0, 3000))
		var poly := Polygon2D.new()
		poly.polygon = pts
		poly.color = Color(0.45, 0.6, 0.72) if far else Color(0.36, 0.55, 0.42)
		pl.add_child(poly)
		_mountains.append(poly)

	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_build_sky_objects(sky_layer)


## ---------------- GÜNDÜZ / GECE DÖNGÜSÜ ----------------
## 0 = şafak, 0.06-0.42 gündüz (güneş), 0.5 gün batımı, 0.56-0.94 gece (ay + yıldızlar)
const DAY_LENGTH := 240.0      # bir tam gün (sn)
const SKY_KEYS: Array = [
	# t, gök üst, gök alt, dünya rengi, dağ rengi
	[0.00, Color(0.35, 0.42, 0.72), Color(1.0, 0.72, 0.52), Color(0.92, 0.84, 0.84), Color(0.85, 0.75, 0.8)],
	[0.07, Color(0.33, 0.6, 0.92), Color(0.78, 0.9, 1.0), Color(1, 1, 1), Color(1, 1, 1)],
	[0.42, Color(0.33, 0.6, 0.92), Color(0.78, 0.9, 1.0), Color(1, 1, 1), Color(1, 1, 1)],
	[0.50, Color(0.27, 0.25, 0.52), Color(1.0, 0.55, 0.3), Color(1.0, 0.78, 0.66), Color(0.85, 0.6, 0.6)],
	[0.57, Color(0.02, 0.03, 0.09), Color(0.1, 0.13, 0.28), Color(0.42, 0.47, 0.72), Color(0.3, 0.33, 0.5)],
	[0.93, Color(0.02, 0.03, 0.09), Color(0.1, 0.13, 0.28), Color(0.42, 0.47, 0.72), Color(0.3, 0.33, 0.5)],
	[1.00, Color(0.35, 0.42, 0.72), Color(1.0, 0.72, 0.52), Color(0.92, 0.84, 0.84), Color(0.85, 0.75, 0.8)],
]
static var day_t: float = 0.1      # sahne yeniden yüklense de gün devam etsin
var _sky_grad: Gradient
var _sun: Node2D
var _moon: Node2D
var _stars: Node2D
var _mountains: Array[Node2D] = []
var _sky_acc: float = 1.0
var _cloud_layer: ParallaxLayer


func _build_sky_objects(sky_layer: CanvasLayer) -> void:
	_sky_grad = Gradient.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _sky_grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	_sky.texture = tex
	# yıldızlar
	_stars = Node2D.new()
	sky_layer.add_child(_stars)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in range(90):
		var st := Polygon2D.new()
		var sz: float = r.randf_range(1.0, 2.6)
		st.polygon = PackedVector2Array([Vector2(-sz, 0), Vector2(0, -sz), Vector2(sz, 0), Vector2(0, sz)])
		st.position = Vector2(r.randf_range(0, 2600), r.randf_range(0, 900))
		st.color = Color(1, 1, 0.9, r.randf_range(0.5, 1.0))
		_stars.add_child(st)
	# güneş (ışıltılı)
	_sun = Node2D.new()
	sky_layer.add_child(_sun)
	_sun.add_child(_disc(95.0, Color(1.0, 0.85, 0.4, 0.18)))
	_sun.add_child(_disc(68.0, Color(1.0, 0.85, 0.4, 0.3)))
	_sun.add_child(_disc(46.0, Color(1.0, 0.93, 0.55)))
	# ay (kraterli)
	_moon = Node2D.new()
	sky_layer.add_child(_moon)
	_moon.add_child(_disc(70.0, Color(0.85, 0.9, 1.0, 0.12)))
	_moon.add_child(_disc(38.0, Color(0.93, 0.94, 0.88)))
	for c in [[Vector2(-10, -8), 8.0], [Vector2(12, 6), 6.0], [Vector2(-4, 14), 5.0], [Vector2(14, -14), 4.0]]:
		var cr := _disc(float(c[1]), Color(0.78, 0.79, 0.74))
		cr.position = c[0]
		_moon.add_child(cr)


func _disc(r: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(32):
		var a: float = TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	p.color = col
	return p


func _sky_at(t: float) -> Array:
	for k in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[k]
		var b: Array = SKY_KEYS[k + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var f: float = smoothstep(float(a[0]), float(b[0]), t)
			var out: Array = []
			for c in range(1, 5):
				out.append((a[c] as Color).lerp(b[c] as Color, f))
			return out
	return [SKY_KEYS[1][1], SKY_KEYS[1][2], SKY_KEYS[1][3], SKY_KEYS[1][4]]


## Gece ne kadar koyu: 0 gündüz .. 1 tam gece
func night_amount() -> float:
	var w: Color = _sky_at(day_t)[2]
	return clampf((1.0 - w.r) / 0.58, 0.0, 1.0)


func _update_sky(delta: float) -> void:
	day_t = fmod(day_t + delta / DAY_LENGTH, 1.0)
	if _cloud_layer:
		_cloud_layer.motion_offset.x -= delta * 14.0   # rüzgâr
	_sky_acc += delta
	if _sky_acc < 0.1:
		return
	_sky_acc = 0.0
	var k: Array = _sky_at(day_t)
	_sky_grad.set_color(0, k[0])
	_sky_grad.set_color(1, k[1])
	RenderingServer.set_default_clear_color(k[1])
	_modulate.color = k[2]
	for m in _mountains:
		m.modulate = k[3]
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var na: float = night_amount()
	_stars.modulate.a = clampf(na * 1.3 - 0.3, 0.0, 1.0)
	# güneş: t 0..0.52 arasında soldan sağa yay çizer; ay: 0.5..1.02
	var ps: float = day_t / 0.52
	_sun.visible = ps <= 1.0
	_sun.position = Vector2(lerpf(-0.05, 1.05, ps) * vp.x, vp.y * (0.62 - 0.5 * sin(PI * clampf(ps, 0.0, 1.0))))
	var pm: float = fposmod(day_t - 0.5, 1.0) / 0.52
	_moon.visible = pm <= 1.0
	_moon.position = Vector2(lerpf(-0.05, 1.05, pm) * vp.x, vp.y * (0.62 - 0.48 * sin(PI * clampf(pm, 0.0, 1.0))))
	# gece farlar daha parlak
	if truck.body != null:
		var far: Node = truck.body.get_node_or_null("Far")
		if far is CanvasItem:
			(far as CanvasItem).modulate = Color(1, 1, 1, 0.45 + 0.55 * na)


# ======================= KAYIT =======================
## Kayıt: şifreli (AES) ve bütünlük korumalı dosya. Elle değiştirilirse açılmaz, yedekten
## yüklenir. Anahtar cihaza özgü: kayıt başka telefona kopyalanıp kullanılamaz.
## Tüm değerler yüklenirken sınırlanır (eksi/aşırı altın, olmayan kamyon vb. kabul edilmez).
const SAVE_FILE := "user://dropzero.dat"
const GOLD_FIX_CAP := 20000     # hatadan önce dürüst oyunla ulaşılabilecek makul üst sınır
const TOKEN_FIX_CAP := 2000
var _gold_fixed: bool = false
const SAVE_SALT := "dz-heavy-hauler-7f3c91"


func _save_key() -> String:
	var dev: String = OS.get_unique_id()
	if dev == "":
		dev = "cihaz"
	return (SAVE_SALT + ":" + dev).sha256_text()


func _load() -> void:
	var cf := ConfigFile.new()
	var ok: bool = cf.load_encrypted_pass(SAVE_FILE, _save_key()) == OK
	if not ok:
		cf = ConfigFile.new()
		ok = cf.load_encrypted_pass(SAVE_FILE + ".bak", _save_key()) == OK
	if not ok:
		# eski sürümün şifresiz kaydını bir kez içeri al
		cf = ConfigFile.new()
		if cf.load(SAVE_PATH) != OK:
			return
	total_gold = clampi(int(cf.get_value("oyun", "altin", 0)), 0, 1000000000)
	tokens = clampi(int(cf.get_value("oyun", "jeton", 0)), 0, 10000000)
	# eski sürümlerdeki "altın yağması" hatasından kalan şişkin bakiyeyi bir kez düzelt
	if int(cf.get_value("oyun", "surum", 1)) < 2:
		if total_gold > GOLD_FIX_CAP:
			total_gold = GOLD_FIX_CAP
			_gold_fixed = true
		if tokens > TOKEN_FIX_CAP:
			tokens = TOKEN_FIX_CAP
			_gold_fixed = true
	best_m = float(cf.get_value("oyun", "rekor", 0.0))
	best_m = clampf(best_m, 0.0, 10000000.0) if is_finite(best_m) else 0.0
	music_on = bool(cf.get_value("ayar", "muzik", true))
	sfx_on = bool(cf.get_value("ayar", "efekt", true))
	var ids: Array = []
	for t in TruckCatalog.all():
		ids.append(t["id"])
	owned = ["tosun"]
	var raw = cf.get_value("oyun", "sahip", ["tosun"])
	if raw is Array:
		for o in raw:
			if ids.has(String(o)) and not owned.has(String(o)):
				owned.append(String(o))
	dev_mode = bool(cf.get_value("ayar", "gelistirici", false))
	selected = String(cf.get_value("oyun", "secili", "tosun"))
	if not ids.has(selected) or (not owned.has(selected) and not dev_mode):
		selected = "tosun"
	up_levels = {}
	for k in (cf.get_section_keys("garaj") if cf.has_section("garaj") else PackedStringArray()):
		var key: String = k
		var v: int = clampi(int(cf.get_value("garaj", key, 0)), 0, MAX_LEVEL)
		if not key.contains(":"):
			key = "tosun:" + key   # eski sürüm kaydı
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2 and ids.has(parts[0]):
			up_levels[key] = v
	_saved_run = {}
	var run = cf.get_value("yolculuk", "durum", {})
	if run is Dictionary and int((run as Dictionary).get("cp", 0)) >= 2:
		_saved_run = run
	if FileAccess.file_exists(SAVE_PATH):
		_save()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("oyun", "surum", 2)
	cf.set_value("oyun", "altin", clampi(total_gold, 0, 1000000000))
	cf.set_value("oyun", "jeton", clampi(tokens, 0, 10000000))
	cf.set_value("oyun", "rekor", best_m)
	cf.set_value("ayar", "muzik", music_on)
	cf.set_value("ayar", "efekt", sfx_on)
	cf.set_value("ayar", "gelistirici", dev_mode)
	cf.set_value("oyun", "sahip", owned)
	cf.set_value("oyun", "secili", selected)
	for k in up_levels:
		cf.set_value("garaj", String(k), int(up_levels[k]))
	cf.set_value("yolculuk", "durum", _saved_run)
	# önce geçici dosyaya yaz, sonra eskisini yedekle ve yerine koy (yarıda kalan yazım kaydı bozmaz)
	if cf.save_encrypted_pass(SAVE_FILE + ".tmp", _save_key()) != OK:
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("dropzero.dat"):
		if dir.file_exists("dropzero.dat.bak"):
			dir.remove("dropzero.dat.bak")
		dir.rename("dropzero.dat", "dropzero.dat.bak")
	dir.rename("dropzero.dat.tmp", "dropzero.dat")
