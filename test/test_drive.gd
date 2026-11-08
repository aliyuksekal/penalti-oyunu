extends Node
## Sadece otomatik test (oyuna dahil değil).
## --case=drive | flip | fuel | cargo | economy | alltrucks | shots
var main: Node
var t := 0.0
var next_print := 0.0
var _done := false
var _rescued := false
var _driving := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in ["user://kargo_kayit.cfg", "user://dropzero.dat", "user://dropzero.dat.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ads.autoclose = true
	main.ads.interstitial_min_gap = 0.0
	main.ads.test_interstitial_seconds = 0.3
	main.ads.test_rewarded_seconds = 0.3
	var cs := _case()
	if cs == "economy":
		await _economy()
		get_tree().quit()
	elif cs == "alltrucks":
		await _alltrucks()
		get_tree().quit()
	elif cs == "systems":
		await _systems()
		get_tree().quit()
	elif cs == "controls":
		await _controls()
		get_tree().quit()
	elif cs == "touch":
		# dokunmatik GAZ pedalı: pedalın ortasına parmak bas, 6 sn tut
		main.start_game()
		await _wait(0.5)
		var r: Rect2 = main.gas_btn.get_global_rect()
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = r.get_center()
		e.pressed = true
		get_viewport().push_input(e, true)   # konum zaten tuval koordinatında (başsız pencere ölçeğini atla)
		await _wait(6.0)
		_check(main.gas_btn.down, "GAZ pedalı basılı görünüyor")
		_check(main._distance_m() > 25.0, "dokunmatik gazla gidildi: %d m" % int(main._distance_m()))
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = r.get_center()
		up.pressed = false
		get_viewport().push_input(up, true)
		await _wait(0.3)
		_check(not main.gas_btn.down, "parmak kalkınca gaz bırakıldı")
		print("SONUÇ: dokunmatik bitti")
		get_tree().quit()
	elif cs == "shots":
		await _shots()
		get_tree().quit()
	else:
		main.start_game()
		_driving = true

func _key(down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_RIGHT
	e.keycode = KEY_RIGHT
	e.pressed = down
	Input.parse_input_event(e)

func _case() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			return a.substr(7)
	return "drive"

func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  HATA  ") + what)

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout

func _shot(name: String) -> void:
	if not ("--shot" in OS.get_cmdline_user_args()):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + name)

func _press(key: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = down
	Input.parse_input_event(e)


func _controls() -> void:
	main.start_game()
	_check(main.time_left > 100.0, "teslimat süresi başladı: %.0f sn" % main.time_left)
	_check(main.truck._drive_share(0) == 1.0 and main.truck._drive_share(1) == 0.0, "Tosun arkadan itişli")
	_check(main.TruckCatalog.by_id("titan").get("drive", "rwd") == "awd", "Titan 4x4")
	# gaz -> hızlan
	_key(true)
	await _wait(3.0)
	_key(false)
	var v0: float = main.truck.body.linear_velocity.x
	# kısa fren: yavaşla, geri gitme
	_press(KEY_LEFT, true)
	await _wait(0.3)
	_press(KEY_LEFT, false)
	var v1: float = main.truck.body.linear_velocity.x
	_check(v1 < v0 and not main.truck.reversing, "kısa basış fren yaptı (%.0f -> %.0f px/sn)" % [v0, v1])
	# uzun basış: önce durur, sonra geri gider
	_press(KEY_LEFT, true)
	var waited: float = 0.0
	while not main.truck.reversing and waited < 5.0:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	var rev: bool = main.truck.reversing
	var xr: float = main.truck.body.global_position.x
	await _wait(2.0)
	var x1: float = main.truck.body.global_position.x
	_press(KEY_LEFT, false)
	_check(rev, "uzun basış geri vitese geçti (%.1f sn içinde)" % waited)
	_check(x1 < xr - 30.0, "geri vitesle geri gitti (%.0f px)" % (x1 - xr))
	await _wait(0.5)
	# turbo
	main.truck.turbo_charge = 1.0
	_key(true)
	await _wait(1.5)
	var sp0: float = main.truck.body.linear_velocity.length()
	var vx0: float = main.truck.body.linear_velocity.dot(main.truck.body.global_transform.x)
	main._try_turbo()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var vx1: float = main.truck.body.linear_velocity.dot(main.truck.body.global_transform.x)
	_check(vx1 > vx0 + 150.0, "turbo anlık itiş verdi (%.0f -> %.0f px/sn)" % [vx0, vx1])
	_check(main.truck.turbo_active, "turbo açıldı")
	await _wait(1.5)
	var sp1: float = main.truck.body.linear_velocity.length()
	_check(main.truck.flame.emitting, "turbo alevi çıkıyor")
	print("  turbo hız: %.0f -> %.0f px/sn" % [sp0, sp1])
	await _wait(1.5)
	_check(not main.truck.turbo_active and main.truck.turbo_charge < 0.5, "turbo bitti, yeniden doluyor")
	_key(false)
	# gece/gündüz
	var t0: float = main.day_t
	await _wait(1.0)
	_check(main.day_t > t0, "gün ilerliyor (%.4f -> %.4f)" % [t0, main.day_t])
	main.day_t = 0.75
	main._sky_acc = 1.0
	await _wait(0.3)
	_check(main.night_amount() > 0.9 and main._moon.visible and not main._sun.visible, "gece: ay var, güneş yok")
	main.day_t = 0.25
	main._sky_acc = 1.0
	await _wait(0.3)
	_check(main.night_amount() < 0.05 and main._sun.visible and not main._moon.visible, "gündüz: güneş var")
	_check(main.zone_name(1) == "Çayır Yolu" and main.zone_name(3) == "Orman Yolu", "bölge adları")
	# ara gaz: 3 hızlı basış -> bir ara gaz; tek basış -> yok
	var bc0: int = main.blip_count
	for q in range(2):
		_key(true)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_key(false)
		await _wait(0.12)
	_check(main.blip_count == bc0, "2 basışta ara gaz yok")
	_key(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(false)
	await _wait(0.12)
	_check(main.blip_count == bc0 + 1, "3. hızlı basışta ara gaz verdi")
	_key(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(false)
	await _wait(0.6)
	_check(main.blip_count == bc0 + 1, "bırakıp tekrar basınca (3 basış olmadan) ara gaz yok")
	# teslimat ödülü tek sefer
	var cx: float = main.terrain.checkpoint_x(main.next_cp)
	var g0: int = main.gold_run
	var cp0: int = main.next_cp
	main.time_left = 100.0
	# fizik bozulursa (NaN konum) altın yağmamalı: kamyon son sağlam yere geri konur
	var gx: float = main._good_x
	main.truck.body.global_position = Vector2(NAN, NAN)
	await _wait(0.5)
	_check(main.next_cp == cp0 and main.gold_run == g0 and main._recoveries >= 1 and main.truck.body.global_position.is_finite(), "bozulan fizik: altın yağmadı, kamyon geri kondu (x %.0f)" % gx)
	# istasyonun biraz gerisinde yeniden kur (devam etme ile aynı yol), sonra gazla istasyondan geç
	main.terrain.update_around(cx - 220.0)
	main._build_truck(cx - 220.0)
	await _wait(0.8)
	_key(true)
	var dw: float = 0.0
	while main.next_cp == cp0 and dw < 10.0 and not main.game_over:
		await get_tree().physics_frame
		dw += 1.0 / 60.0
	_key(false)
	await _wait(0.5)
	var g1: int = main.gold_run
	var run_now: Dictionary = main._saved_run.duplicate()
	print("  ok  (bilgi) teslimat sonrası: durum=%s bitti=%s neden=%s yük=%d kurtarma=%d kayıt=%s" % [main.state, main.game_over, main.end_reason, main.cargo.size(), main._recoveries, str(run_now)])
	await _wait(1.0)
	_check(main.next_cp == cp0 + 1, "istasyonda teslimat yapıldı")
	_check(g1 > g0 and g1 - g0 <= 2000 and main.gold_run == g1, "ödül bir kez verildi ve sabit kaldı (+%d)" % (g1 - g0))
	_check(main.has_saved_run() and int(main._saved_run["cp"]) == cp0 + 1, "istasyonda kayıt alındı")
	# istasyonda kamyon durur, YÜKLE tuşu çıkar, yük seçilir
	_check(main.at_station and main.cargo.is_empty(), "teslimattan sonra istasyonda bekliyor, kasa boş")
	await _wait(1.5)
	_check(main.load_btn != null and main.load_btn.visible and absf(main.truck.body.linear_velocity.x) < 25.0, "kamyon durdu, YÜKLE tuşu çıktı")
	var tl0: float = main.time_left
	main.open_station()
	await get_tree().process_frame
	_check(main.station_panel != null and main._station_items.size() >= 3, "yük listesi açıldı (%d çeşit)" % main._station_items.size())
	var k0: String = String(main._station_offer[0])
	var price: int = main.cargo_price(k0, main.next_cp)
	main.station_add(k0)
	main.station_add(k0)
	main.station_add(k0)
	await _wait(0.5)
	_check(main.cargo.size() == 3 and main.station_value() == price * 3, "dokundukça yüklendi: 3 x %s = +%d altın" % [k0, price * 3])
	for q in range(20):
		main.station_add(k0)
	_check(main._station_kinds.size() <= main.STATION_MAX_ITEMS and main.station_fits(main._station_kinds), "kasa dolunca fazlası eklenmiyor (%d)" % main._station_kinds.size())
	_check(absf(main.time_left - tl0) < 0.01, "istasyondayken süre işlemiyor")
	main.station_clear()
	main.station_add(k0)
	main.station_add(k0)
	await _wait(0.4)
	main.leave_station()
	await _wait(0.3)
	_check(not main.at_station and main.gas_btn.visible and main.cargo.size() == 2 and main.cargo_total == 2, "yola çıkıldı, 2 yük kasada")
	# şifreli kayıt: düz metin olarak okunamaz, bozulursa yedekten açılır
	main._save()
	main._save()
	var raw: PackedByteArray = FileAccess.get_file_as_bytes("user://dropzero.dat")
	var raw_txt: String = raw.get_string_from_ascii()
	_check(raw.size() > 32 and not raw_txt.contains("altin") and not raw_txt.contains("jeton"), "kayıt şifreli (düz okunamıyor)")
	var fa := FileAccess.open("user://dropzero.dat", FileAccess.READ_WRITE)
	fa.seek(40)
	fa.store_8(fa.get_8() ^ 0xFF)
	fa.close()
	var tok: int = main.tokens
	main.tokens = -5
	main._load()
	_check(main.tokens == tok, "bozulan kayıt yedekten yüklendi")
	# kaldığı yerden devam
	var seed0: int = main.terrain.get_seed()
	var gsave: int = int(main._saved_run.get("gold", -1))
	main.next_cp = 1
	main.gold_run = 0
	main.resume_run()
	await _wait(0.5)
	_check(main.at_station, "devam edince istasyonda yük seçimi")
	main.station_autoload()
	await _wait(0.3)
	_check(main.next_cp == cp0 + 1 and main.gold_run == gsave and main.terrain.get_seed() == seed0, "kaldığı yerden devam: bölge %d, altın %d" % [main.next_cp, main.gold_run])
	_check(absf(main.truck.body.global_position.x - (main.terrain.checkpoint_x(cp0) + 80.0)) < 200.0, "kamyon son istasyonda")
	# çukurda sıkışma: gaz verildiği halde kıpırdamıyorsa menüde reklam seçeneği, 50 m geriden başlar
	await _wait(1.0)
	var sx: float = main.truck.body.global_position.x
	main._stuck_ref_x = sx
	main._stuck_t = 0.0
	for q in range(int(main.STUCK_SECONDS * 60.0) + 5):
		main._update_stuck(1.0 / 60.0, sx, true)
	_check(main.stuck, "hareket edemeyince sıkıştı sayıldı")
	main.pause_game()
	await get_tree().process_frame
	_check(main.pause_panel != null and main.pause_panel.find_child("SikismaBtn", true, false) != null, "menüde 'reklam izle, 50 m geriden başla' var")
	main.resume_game()
	var n_cargo: int = main.cargo.size()
	var fuel_b: float = main.truck.fuel
	main.unstuck()
	await _wait(0.6)
	var back_px: float = sx - main.truck.body.global_position.x
	_check(back_px > 2000.0 and back_px < 3100.0 and main.cargo.size() == n_cargo and absf(main.truck.fuel - fuel_b) < 5.0 and not main.stuck, "50 m geriden başladı (%.0f m), yük %d, yakıt korundu" % [back_px / 50.0, main.cargo.size()])
	main.time_left = 100.0
	# süre dolunca oyun biter
	main.time_left = 0.5
	await _wait(1.0)
	_check(main.game_over and main.end_reason == "TESLİMAT GECİKTİ", "süre dolunca: %s" % main.end_reason)
	print("SONUÇ: kontroller bitti")


func _systems() -> void:
	# arazi: süreklilik ve kesim türleri
	var tg = main.terrain
	var worst: float = 0.0
	var x: float = 0.0
	var prev: float = tg.height_at(0.0)
	while x < 3000.0 * 50.0:
		x += 32.0
		var h: float = tg.height_at(x)
		worst = maxf(worst, absf(h - prev))
		prev = h
	_check(worst < 200.0, "arazi kopuksuz (rampa inişi dahil) (32 px'te en büyük sıçrama %.0f px)" % worst)
	var kinds := {}
	var early: float = 0.0
	for i in range(0, 3):
		early += float(tg.feature_at(i)["h"])
	_check(early == 0.0, "ilk 600 m engelsiz (kolay başlangıç)")
	for i in range(40):
		var k: String = tg.feature_at(i)["kind"]
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("  kesimler (ilk 3 km): ", kinds)
	_check(kinds.size() >= 4, "en az 4 farklı yol türü var")
	var roads := {}
	for i in range(60):
		roads[tg.road_at_index(i)] = true
	print("  yol türleri: ", roads.keys())
	_check(tg.road_at_index(0) == "asfalt" and tg.road_at_index(1) == "asfalt", "ilk 500 m asfalt")
	_check(roads.size() >= 5, "en az 5 yol türü çıkıyor (%d)" % roads.size())
	var CT = load("res://CargoTypes.gd")
	var rr := RandomNumberGenerator.new()
	rr.seed = 3
	var p1: Array = CT.load_plan(1, rr)
	var p6: Array = CT.load_plan(7, rr)
	_check(p1.size() == 5 and p6.size() >= 6 and p6.has("tomruk"), "yük artıyor: 1. teslimat %d, 7. teslimat %d parça %s" % [p1.size(), p6.size(), str(p6)])
	for leg in range(1, 9):
		var kinds2: Array = CT.load_plan(leg, rr)
		var pos2: Array = CT.pack(kinds2)
		var ok_fit: bool = true
		for q in range(pos2.size()):
			var sz2: Vector2 = CT.TYPES[kinds2[q]]["size"]
			if pos2[q].x - sz2.x * 0.5 < -107.0 or pos2[q].x + sz2.x * 0.5 > 23.0:
				ok_fit = false
		_check(ok_fit, "%d. yük kasaya sığıyor (%d parça)" % [leg, kinds2.size()])
	var h_early: float = 0.0
	var h_late: float = 0.0
	for i in range(3, 8):
		h_early += float(tg.feature_at(i)["h"])
	for i in range(40, 45):
		h_late += float(tg.feature_at(i)["h"])
	_check(h_late > h_early, "ileride engeller büyüyor (%.0f -> %.0f)" % [h_early, h_late])
	# ses
	_check(main.snd != null and AudioServer.get_bus_index("Muzik") >= 0 and AudioServer.get_bus_index("Efekt") >= 0, "ses kanalları kuruldu")
	main.music_on = false
	main.snd.music_on = false
	main.snd.apply()
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Muzik")), "müzik kapatılabiliyor")
	main.music_on = true
	main.snd.music_on = true
	main.snd.apply()
	# oyun + gösterge + duraklatma
	main.start_game()
	_key(true)
	await _wait(4.0)
	_check(main.speed_gauge.value > 5.0, "hız göstergesi: %.0f km/s" % main.speed_gauge.value)
	_check(main.snd._engine.playing, "motor sesi çalıyor (perde %.2f)" % main.snd._engine.pitch_scale)
	_check(main.snd._music.playing, "oyun müziği çalıyor")
	main.pause_game()
	await _wait(0.3)
	var x0: float = main.truck.body.global_position.x
	await _wait(1.0)
	_check(get_tree().paused and main.pause_panel != null, "duraklatma menüsü açıldı")
	_check(absf(main.truck.body.global_position.x - x0) < 1.0, "duraklayınca kamyon durdu")
	main.resume_game()
	await _wait(1.0)
	_check(not get_tree().paused and main.truck.body.global_position.x > x0 + 5.0, "devam edince oyun sürüyor")
	_check(main.truck.smoke.emitting, "egzoz dumanı çıkıyor")
	print("SONUÇ: sistemler bitti")


func _economy() -> void:
	main.total_gold = 2000
	main.tokens = 0
	main.convert_gold(-1)
	await _wait(0.8)
	_check(main.tokens == 200 and main.total_gold == 0, "2000 altın -> 200 jeton (jeton=%d, altın=%d)" % [main.tokens, main.total_gold])
	main.watch_ad_for_tokens()
	await _wait(0.8)
	_check(main.tokens == 250, "ödüllü reklam +50 jeton (%d)" % main.tokens)
	main.buy_truck("kartal")
	await _wait(0.8)
	_check(not main.owned.has("kartal") and main.tokens == 250, "jeton yetmeyince kamyon alınmaz")
	main.buy_pack(main.ads.PACKS[0])
	await _wait(1.6)
	_check(main.tokens == 550, "paket +300 jeton (%d)" % main.tokens)
	main.buy_truck("kartal")
	await _wait(0.8)
	_check(main.owned.has("kartal") and main.selected == "kartal" and main.tokens == 50, "Kartal alındı ve seçildi (jeton=%d)" % main.tokens)
	_check(main.truck.model["id"] == "kartal" and main.truck.body != null, "kamyon yeniden kuruldu")
	main.total_gold = 1000
	var cost: int = main.upgrade_cost("kartal", "engine")
	var p0: float = main.truck.engine_power
	main.buy_upgrade("engine")
	await _wait(0.8)
	_check(int(main.levels_of("kartal")["engine"]) == 1 and main.total_gold == 1000 - cost, "motor yükseltildi, %d altın harcandı" % cost)
	_check(main.truck.engine_power > p0 * 1.1, "motor gücü arttı %.0f -> %.0f" % [p0, main.truck.engine_power])
	_check(int(main.levels_of("tosun")["engine"]) == 0, "yükseltme sadece o kamyona işledi")
	main._save()
	main.tokens = 0
	main._load()
	_check(main.tokens == 50 and main.owned.has("kartal") and main.selected == "kartal", "kayıt geri yüklendi")
	main.start_game()
	_driving = true
	_key(true)
	await _wait(10.0)
	_check(main._distance_m() > 60.0, "Kartal ile sürüş: %d m" % int(main._distance_m()))
	main.set_dev_mode(true)
	main.select_truck("titan")
	await _wait(0.3)
	_check(main.selected == "titan" and not main.owned.has("titan"), "geliştirici modu: Titan almadan seçildi")
	main.set_dev_mode(false)
	await _wait(0.3)
	_check(main.selected == "tosun", "geliştirici modu kapanınca sahip olunan kamyona dönüldü")
	print("SONUÇ: ekonomi bitti")

func _alltrucks() -> void:
	for d in main.TruckCatalog.all():
		var id: String = d["id"]
		if not main.owned.has(id):
			main.owned.append(id)
		main.select_truck(id)
		await _wait(0.3)
		main.start_game()
		_key(true)
		var flips := 0
		var tt := 0.0
		while tt < 14.0 and not main.game_over:
			await get_tree().physics_frame
			tt += 1.0 / 60.0
			var rot: float = main.truck.body.global_rotation
			_key(rot > -0.7)
		_key(false)
		print("SONUÇ: %s  %d m  yük=%d/5  bitti=%s %s" % [id, int(main._distance_m()), main.cargo.size(), str(main.game_over), main.end_reason])
		if main.game_over:
			return
		main.open_menu()

func _shots() -> void:
	# açılış animasyonu kareleri
	main._play_intro()
	var prev_t: float = 0.0
	for tt in [0.4, 1.0, 1.7, 2.05]:
		await _wait(tt - prev_t)
		prev_t = tt
		await _shot("intro_%d.png" % int(tt * 100))
	await _wait(1.0)
	for d in main.TruckCatalog.all():
		if not main.owned.has(d["id"]):
			main.owned.append(d["id"])
	main.tokens = 1200
	main.total_gold = 3400
	main.owned = ["tosun", "kartal", "bozkurt"]
	main.menu.refresh()
	await _wait(1.0)
	await _shot("m_home.png")
	main.menu.open_panel("trucks")
	await _wait(0.6)
	await _shot("m_trucks.png")
	main.menu._scroll.scroll_vertical = 700
	await _wait(0.3)
	await _shot("m_trucks2.png")
	main.menu.open_panel("upgrades")
	await _wait(0.3)
	await _shot("m_upgrades.png")
	main.menu.open_panel("shop")
	await _wait(0.3)
	await _shot("m_shop.png")
	main.ads.autoclose = false
	main.ads.test_interstitial_seconds = 3.0
	main.ads.show_interstitial(func() -> void: pass)
	await _wait(0.5)
	await _shot("m_ad.png")
	for c in main.ads._layer.get_children():
		c.queue_free()
	main.ads.autoclose = true
	for id in ["titan", "bozkurt", "yildirim"]:
		main.owned.append(id)
		main.select_truck(id)
		await _wait(0.4)
		main.start_game()
		_key(true)
		await _wait(5.0)
		await _shot("g_%s.png" % id)
		_key(false)
		main.open_menu()
	main.owned.append("kartal")
	main.select_truck("kartal")
	main.start_game()
	_key(true)
	await _wait(6.0)
	await _shot("g_gauges.png")
	main.day_t = 0.485
	main._sky_acc = 1.0
	await _wait(0.4)
	await _shot("g_sunset.png")
	main.day_t = 0.8
	main._sky_acc = 1.0
	main.truck.turbo_charge = 1.0
	main._try_turbo()
	await _wait(0.6)
	await _shot("g_night_turbo.png")
	main.day_t = 0.2
	main._sky_acc = 1.0
	_key(false)
	main.pause_game()
	await _wait(0.4)
	await _shot("g_pause.png")
	main.resume_game()
	main._enter_station()
	await _wait(1.6)
	await _shot("g_station_btn.png")
	main.open_station()
	for k in main._station_offer.slice(0, 3):
		main.station_add(String(k))
		main.station_add(String(k))
	await _wait(0.8)
	await _shot("g_station.png")
	main.station_autoload()
	main.open_menu()
	main.day_t = 0.75   # gece: ay ve yıldızlar
	main._sky_acc = 1.0
	main.select_truck("dagkecisi" if main.owned.has("dagkecisi") else "titan")
	main.open_menu()
	await _wait(0.6)
	await _shot("m_night.png")
	# dikey ekran: ayarlar penceresi %50 büyük
	get_window().size = Vector2i(720, 1280)
	await _wait(0.6)
	main.open_settings()
	await _wait(0.5)
	await _shot("m_settings_portrait.png")
	if main.settings_panel != null:
		main.settings_panel.queue_free()
		main.settings_panel = null
	main.start_game()
	await _wait(0.5)
	main.pause_game()
	await _wait(0.5)
	await _shot("g_pause_portrait.png")
	main.resume_game()
	get_window().size = Vector2i(1280, 720)
	await _wait(0.4)

func _physics_process(delta: float) -> void:
	if _done or not _driving or _case() in ["economy", "alltrucks", "shots", "touch", "systems", "controls"]:
		return
	t += delta
	var tr = main.truck
	if tr.body == null:
		return
	var cs: String = _case()
	if main.at_station:
		main.station_autoload()   # sürüş testinde istasyonda standart yükü al, devam et
		return
	if cs != "drive":
		if t > 1.0 and t - delta <= 1.0:
			if cs == "flip":
				tr.body.global_rotation = PI
				tr.body.global_position += Vector2(0, -120)
				for w in tr.wheels:
					w.global_position += Vector2(0, -400)
			elif cs == "fuel":
				tr.fuel = 0.0
			elif cs == "cargo":
				for c in main.cargo:
					c.global_position += Vector2(-600, -300)
		if main.rescue_panel != null and not _rescued:
			_rescued = true
			print("  ok  reklamla kurtarma teklif edildi (%s)" % cs)
			if cs == "fuel":
				main._apply_rescue("fuel")
				_check(absf(tr.fuel - tr.fuel_capacity * 0.10) < 0.5 and not get_tree().paused, "1. reklam: depo %%10 doldu, oyun sürüyor")
				main.fuel_ads = 3
				tr.fuel = 0.0
			else:
				main._apply_rescue("flip")
				await get_tree().physics_frame
				_check(cos(tr.body.global_rotation) > 0.9 and not get_tree().paused, "reklamla kamyon düzeltildi")
				main.flip_rescues = 3
				tr.body.global_rotation = PI
				tr.body.global_position += Vector2(0, -120)
			return
		if cs == "flip" and t > 1.0:
			main._out_time.clear()
			for c in main.cargo:
				main._out_time[c] = -100.0
		if main.game_over:
			_done = true
			if "--shot" in OS.get_cmdline_user_args():
				await get_tree().create_timer(0.6).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://shot_over.png")
			print("SONUÇ: durum=%s neden=%s t=%.1f panel=%s" % [cs, main.end_reason, t, str(main.over_panel != null)])
			get_tree().quit()
		elif t > 25.0:
			print("SONUÇ: durum=%s OYUN BİTMEDİ (HATA)" % cs)
			get_tree().quit(1)
		return
	var rot: float = tr.body.global_rotation
	_key(rot > -0.7)
	if t >= next_print:
		next_print += 5.0
		print("t=%.0f  x=%d m  hız=%.0f km/s  yük=%d  yakıt=%.0f  hararet=%.0f  altın=%d  cp=%d" % [
			t, int(main._distance_m()), tr.speed_kmh(), main.cargo.size(), tr.fuel, tr.heat, main.gold_run, main.next_cp])
	if main.game_over or t > 70.0:
		print("SONUÇ: mesafe=%d m  yük=%d  teslimat=%d  bitti=%s %s" % [int(main._distance_m()), main.cargo.size(), main.next_cp - 1, str(main.game_over), main.end_reason])
		get_tree().quit()
