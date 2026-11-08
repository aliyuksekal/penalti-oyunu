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

@onready var terrain = $Terrain   # TerrainGenerator.gd
@onready var truck = $Truck       # TruckController.gd

var cargo: Array[RigidBody2D] = []      # kasadaki sağlam yükler
var dropped: Array[RigidBody2D] = []    # yola düşenler
var _out_time: Dictionary = {}          # yük -> kasa dışında geçen süre
var gold_run: int = 0
var total_gold: int = 0
var best_m: float = 0.0
var tokens: int = 0
var owned: Array = ["tosun"]
var selected: String = "tosun"
var up_levels: Dictionary = {}     # "kamyon:yükseltme" -> seviye
var state: String = "menu"         # menu / play / over
var ads: Node
var menu: Control
var _hud_nodes: Array[Control] = []
var _ui_root: Control
var _doubled: bool = false
var night: bool = false
var next_cp: int = 1
var delivered: int = 0
var flip_t: float = 0.0
var empty_t: float = 0.0
var empty_total: float = 0.0
var game_over: bool = false
var start_x: float = 0.0
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
	_set_night(night)
	if skip_menu:
		skip_menu = false
		start_game()
	else:
		open_menu()


## Android geri tuşu: oyunda duraklat, duraklatmada devam et, menüde çık
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ads != null and ads.is_showing():
			return
		if state == "play" and pause_panel == null:
			pause_game()
		elif pause_panel != null:
			resume_game()
		elif state == "over":
			_to_garage()
		else:
			get_tree().quit()


## Seçili kamyonu (ve yükseltmelerini) başlangıç noktasında kur, kasayı yükle
func _build_truck() -> void:
	for c in cargo:
		c.queue_free()
	cargo.clear()
	_out_time.clear()
	if truck.built:
		truck.teardown()
	truck.apply_model(TruckCatalog.by_id(selected), levels_of(selected))
	var sx: float = 60.0
	truck.build(Vector2(sx, terrain.height_at(sx) - 95.0 - (truck.wheel_r - 26.0)))
	start_x = truck.body.global_position.x
	_spawn_cargo()


func open_menu() -> void:
	state = "menu"
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
	truck.menu_view = false
	truck.refuel()
	if menu:
		menu.visible = false
	for n in _hud_nodes:
		n.visible = true
	snd.play_music("yol")


# ======================= OYUN DÖNGÜSÜ =======================
func _physics_process(delta: float) -> void:
	if game_over or truck.body == null:
		return
	var x: float = truck.body.global_position.x
	terrain.update_around(x)
	if state != "play":
		truck.gas_pressed = false
		truck.brake_pressed = false
		return

	var gas: bool = _pedal_down(gas_btn) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_UP)
	var brk: bool = _pedal_down(brake_btn) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_DOWN)
	truck.gas_pressed = gas
	truck.brake_pressed = brk and not gas
	gas_btn.set_down(gas)
	brake_btn.set_down(brk)

	_check_cargo(delta)
	_check_checkpoint()
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
func _spawn_cargo() -> void:
	# 3 alt sıra + 2 üst sıra (üsttekiler kasa duvarından taşar: dikkatli sür!)
	var slots: Array = [Vector2(-86, -34), Vector2(-42, -34), Vector2(2, -34), Vector2(-64, -62), Vector2(-20, -62)]
	var colors: Array = [Color(0.72, 0.5, 0.26), Color(0.62, 0.42, 0.22), Color(0.8, 0.58, 0.3), Color(0.55, 0.62, 0.3), Color(0.35, 0.5, 0.72)]
	for i in range(CARGO_COUNT):
		var c := RigidBody2D.new()
		c.name = "Yuk_%d" % i
		c.mass = randf_range(0.32, 0.5)
		c.collision_layer = 4
		c.collision_mask = 1 | 2 | 4
		c.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		c.can_sleep = false
		c.z_index = 1
		c.contact_monitor = true
		c.max_contacts_reported = 2
		c.body_entered.connect(_on_cargo_hit.bind(c))
		var m := PhysicsMaterial.new()
		m.friction = 0.8
		m.bounce = 0.05
		c.physics_material_override = m
		var size := Vector2(30, 26)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = size
		cs.shape = rs
		c.add_child(cs)
		# sandık görünümü
		var h: Vector2 = size * 0.5
		var col: Color = colors[i % colors.size()]
		var box := Polygon2D.new()
		box.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
		box.color = col
		c.add_child(box)
		var frame := Line2D.new()
		frame.points = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)])
		frame.width = 3.0
		frame.default_color = col.darkened(0.45)
		c.add_child(frame)
		var cross := Line2D.new()
		cross.points = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, h.y)])
		cross.width = 2.5
		cross.default_color = col.darkened(0.35)
		c.add_child(cross)
		add_child(c)
		var slot: Vector2 = slots[i % slots.size()]
		c.global_position = truck.bed_to_global(slot)
		c.global_rotation = truck.body.global_rotation
		c.linear_velocity = truck.body.linear_velocity
		cargo.append(c)


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
			_toast("Yük düştü! %d/%d" % [cargo.size(), CARGO_COUNT], 1.3)
			snd.sfx("yuk_dustu", 0.0, 0.8)
	# geride kalan düşmüş yükleri sil (bellek)
	var bx: float = truck.body.global_position.x
	for d in dropped.duplicate():
		if d.global_position.x < bx - 2500.0 or d.global_position.y > 6000.0:
			dropped.erase(d)
			d.queue_free()


# ======================= TESLİMAT =======================
func _check_checkpoint() -> void:
	var cx: float = terrain.checkpoint_x(next_cp)
	if truck.body.global_position.x < cx:
		return
	var intact: int = cargo.size()
	var reward: int = intact * gold_per_cargo + station_bonus * next_cp
	if intact == CARGO_COUNT:
		reward += perfect_bonus
	gold_run += reward
	delivered += intact
	truck.refuel()
	truck.heat = minf(truck.heat, 40.0)
	# sağlam yükler teslim edildi, kasa boşaltılıp yeniden yükleniyor
	for c in cargo:
		c.queue_free()
	cargo.clear()
	_out_time.clear()
	_spawn_cargo()
	var msg: String = "TESLİMAT %d m!  %d sağlam yük  +%d altın\nDepo dolduruldu • Yeni yük alındı" % [int(next_cp * terrain.checkpoint_interval_m), intact, reward]
	if intact == CARGO_COUNT:
		msg = "KUSURSUZ! " + msg
	_toast(msg, 3.0)
	snd.sfx("teslimat")
	next_cp += 1


# ======================= OYUN SONU =======================
func _check_game_over(delta: float) -> void:
	if truck.is_flipped():
		flip_t += delta
		if flip_t >= flip_time_limit:
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
			_end("YAKIT BİTTİ", "Depo boşaldı, kamyon yolda kaldı.")
			return

	if cargo.is_empty():
		_end("TÜM YÜKLER DÖKÜLDÜ", "Kasada hiç yük kalmadı (0/%d)." % CARGO_COUNT)
		return

	if truck.body.global_position.y > terrain.base_y + 3000.0:
		_end("ŞASİ HASARI", "Kamyon yoldan çıktı.")


func _end(title: String, detail: String) -> void:
	if game_over:
		return
	game_over = true
	state = "over"
	end_reason = title
	truck.engine_enabled = false
	var dist_m: float = _distance_m()
	var dist_bonus: int = int(dist_m / 20.0)
	gold_run += dist_bonus
	total_gold += gold_run
	var new_best: bool = dist_m > best_m
	best_m = maxf(best_m, dist_m)
	_save()
	snd.sfx("oyun_bitti")
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
		_save()


# ======================= DURAKLATMA MENÜSÜ =======================
func pause_game() -> void:
	if state != "play" or game_over or pause_panel != null:
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


func resume_game() -> void:
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	gas_btn.visible = true
	brake_btn.visible = true
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
	var items: Array = [["Müzik", "music"], ["Ses", "sfx"], ["Gece", "night"]]
	for it in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(122, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var key: String = it[1]
		var label: String = it[0]
		var paint := func() -> void:
			var on: bool = music_on if key == "music" else (sfx_on if key == "sfx" else night)
			b.text = "%s: %s" % [label, "AÇIK" if on else "KAPALI"]
			_style_btn(b, Color(0.15, 0.55, 0.35) if on else Color(0.3, 0.32, 0.38))
		var flip := func() -> void:
			match key:
				"music":
					music_on = not music_on
				"sfx":
					sfx_on = not sfx_on
				"night":
					_set_night(not night)
			snd.music_on = music_on
			snd.sfx_on = sfx_on
			snd.apply()
			_save()
			paint.call()
		paint.call()
		b.pressed.connect(flip)
		parent.add_child(b)


func _distance_m() -> float:
	return maxf((truck.body.global_position.x - start_x) / PX_PER_M, 0.0)


# ======================= GİRİŞ (çoklu dokunma) =======================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
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
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_mouse_pos = mm.position


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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	pause_btn = Button.new()
	pause_btn.text = "II  MENÜ"
	pause_btn.custom_minimum_size = Vector2(130, 50)
	pause_btn.add_theme_font_size_override("font_size", 22)
	_style_btn(pause_btn, Color(0.25, 0.28, 0.36))
	pause_btn.pressed.connect(pause_game)
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
	_hud_nodes = [top, warn_lbl, brake_btn, gas_btn, gauges]


## Telefon çentiği / yuvarlak köşeler: arayüzü güvenli alanın içine al (sadece mobilde)
func _apply_safe_area(root: Control) -> void:
	if not OS.has_feature("mobile"):
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var k: Vector2 = vp / Vector2(win)
	root.offset_left = clampf(float(safe.position.x) * k.x, 0.0, 120.0)
	root.offset_top = clampf(float(safe.position.y) * k.y, 0.0, 120.0)
	root.offset_right = -clampf(float(win.x - safe.end.x) * k.x, 0.0, 120.0)
	root.offset_bottom = -clampf(float(win.y - safe.end.y) * k.y, 0.0, 120.0)


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
	cargo_lbl.text = "YÜK %d/%d" % [cargo.size(), CARGO_COUNT]
	cargo_lbl.add_theme_color_override("font_color", Color.WHITE if cargo.size() > 2 else Color(1, 0.45, 0.35))
	dist_lbl.text = "%d m" % int(_distance_m())
	gold_lbl.text = "ALTIN %d" % gold_run
	var to_next: float = (terrain.checkpoint_x(next_cp) - truck.body.global_position.x) / PX_PER_M
	next_lbl.text = "TESLİMAT: %d m" % maxi(int(to_next), 0)

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
	if owned.has(id):
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
	if not owned.has(id):
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

	_modulate = CanvasModulate.new()
	add_child(_modulate)


func _set_night(v: bool) -> void:
	night = v
	var g := Gradient.new()
	if night:
		g.set_color(0, Color(0.02, 0.03, 0.09))
		g.set_color(1, Color(0.12, 0.15, 0.3))
		_modulate.color = Color(0.5, 0.55, 0.78)
	else:
		g.set_color(0, Color(0.33, 0.6, 0.92))
		g.set_color(1, Color(0.78, 0.9, 1.0))
		_modulate.color = Color.WHITE
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	_sky.texture = tex
	RenderingServer.set_default_clear_color(g.get_color(1))
	_save()


# ======================= KAYIT =======================
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	total_gold = int(cf.get_value("oyun", "altin", 0))
	tokens = int(cf.get_value("oyun", "jeton", 0))
	best_m = float(cf.get_value("oyun", "rekor", 0.0))
	night = bool(cf.get_value("oyun", "gece", false))
	music_on = bool(cf.get_value("ayar", "muzik", true))
	sfx_on = bool(cf.get_value("ayar", "efekt", true))
	owned = cf.get_value("oyun", "sahip", ["tosun"])
	if not owned.has("tosun"):
		owned.append("tosun")
	selected = String(cf.get_value("oyun", "secili", "tosun"))
	if not owned.has(selected):
		selected = "tosun"
	for k in (cf.get_section_keys("garaj") if cf.has_section("garaj") else PackedStringArray()):
		var key: String = k
		var v: int = clampi(int(cf.get_value("garaj", key, 0)), 0, MAX_LEVEL)
		if key.contains(":"):
			up_levels[key] = v
		else:
			up_levels["tosun:" + key] = v   # eski sürüm kaydı


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("oyun", "altin", total_gold)
	cf.set_value("oyun", "jeton", tokens)
	cf.set_value("oyun", "rekor", best_m)
	cf.set_value("oyun", "gece", night)
	cf.set_value("ayar", "muzik", music_on)
	cf.set_value("ayar", "efekt", sfx_on)
	cf.set_value("oyun", "sahip", owned)
	cf.set_value("oyun", "secili", selected)
	for k in up_levels:
		cf.set_value("garaj", String(k), int(up_levels[k]))
	cf.save(SAVE_PATH)
