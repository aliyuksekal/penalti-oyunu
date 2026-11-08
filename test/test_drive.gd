extends Node
## Sadece otomatik test (oyuna dahil değil).
## --case=drive | flip | fuel | cargo | economy | alltrucks | shots
var main: Node
var t := 0.0
var next_print := 0.0
var _done := false
var _driving := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kargo_kayit.cfg"))
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ads.autoclose = true
	main.ads.test_interstitial_seconds = 0.3
	main.ads.test_rewarded_seconds = 0.3
	var cs := _case()
	if cs == "economy":
		await _economy()
		get_tree().quit()
	elif cs == "alltrucks":
		await _alltrucks()
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
		Input.parse_input_event(e)
		await _wait(6.0)
		_check(main.gas_btn.down, "GAZ pedalı basılı görünüyor")
		_check(main._distance_m() > 25.0, "dokunmatik gazla gidildi: %d m" % int(main._distance_m()))
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = r.get_center()
		up.pressed = false
		Input.parse_input_event(up)
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
	for d in main.TruckCatalog.all():
		if not main.owned.has(d["id"]):
			main.owned.append(d["id"])
	main.tokens = 1200
	main.total_gold = 3400
	main.owned = ["tosun", "kartal", "bozkurt"]
	main.menu.refresh()
	await _wait(1.0)
	await _shot("m_trucks.png")
	main.menu._scroll.scroll_vertical = 700
	await _wait(0.3)
	await _shot("m_trucks2.png")
	main.menu.tab = "upgrades"
	main.menu.refresh()
	await _wait(0.3)
	await _shot("m_upgrades.png")
	main.menu.tab = "shop"
	main.menu.refresh()
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
	main.night = false
	main._set_night(true)
	main.select_truck("dagkecisi" if main.owned.has("dagkecisi") else "titan")
	main.open_menu()
	await _wait(0.6)
	await _shot("m_night.png")

func _physics_process(delta: float) -> void:
	if _done or not _driving or _case() in ["economy", "alltrucks", "shots", "touch"]:
		return
	t += delta
	var tr = main.truck
	if tr.body == null:
		return
	var cs: String = _case()
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
		elif t > 12.0:
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
