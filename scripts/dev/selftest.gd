extends Node
## CI testleri: çeviri, yapay zekâ öğrenmesi, kaydırma eşlemesi, seri penaltı kuralları,
## kayıt/yedek, tam bir maçın baştan sona oynatılması, tüm ekranlar x 6 dil x 2 tema.

const Brain = preload("res://scripts/game/brain.gd")
const MatchScreen = preload("res://scripts/screens/match_screen.gd")
const Match = preload("res://scripts/game/match.gd")

var fails: Array[String] = []
var checks: int = 0


func check(c: bool, what: String) -> void:
	checks += 1
	print("  ok  " if c else "  FAIL ", what)
	if not c:
		fails.append(what)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = get_parent()
	print("=== SELFTEST ===")
	check(I18n.missing_report().is_empty(), "çeviriler tam: %s" % str(I18n.missing_report()))
	check(Assets.missing.is_empty(), "ikonlar tam: %s" % str(Assets.missing))
	# gerçek karakter (Mixamo)
	var w = main.world
	if ResourceLoader.exists("res://assets/models/remy.glb"):
		check(w.shooter.has_method("dive_to"), "Mixamo karakteri kullanılıyor")
		check(w.shooter.ap != null and w.shooter.ap.get_animation_list().size() >= 20, "animasyonlar yüklendi: %d" % (w.shooter.ap.get_animation_list().size() if w.shooter.ap else 0))
		check(w.shooter.bone("Hips") >= 0 and w.shooter.bone("RightHand") >= 0, "Mixamo kemikleri bulundu")
		check(w.keeper._mats.has("top"), "forma ağı (tişört) boyanabiliyor")
		print("  bilgi: ", w.keeper._info.get("gk_dive", {}), " / ", w.keeper._info.get("gk_dive2", {}), " / kick ", w.shooter._info.get("penalty_kick", {}))
	# yapay zekâ öğrenmesi
	Save.reset_ai()
	var b := Brain.new()
	for i in 30:
		var pr: Array[float] = b.predict_shot(1)
		b.record_shot(8, 1, pr)
	var p2: Array[float] = b.predict_shot(1)
	check(Brain.argmax(p2) == 8, "30 kez sağ alta vurunca yapay zekâ sağ altı bekliyor")
	check(b.reading_percent() > 60, "okuma yüzdesi yükseldi: %d" % b.reading_percent())
	for i in 20:
		b.record_dive(0)
	check(Brain.argmax(b.predict_dive()) == 0, "dalış alışkanlığı öğrenildi")
	check(Brain.zone_of(-3.0, 2.2) == 0 and Brain.zone_of(3.0, 0.2) == 8 and Brain.zone_of(0.0, 1.2) == 4, "bölge hesabı")
	# kaydırma eşlemesi
	var vs := Vector2(1280, 720)
	var up_right: Dictionary = MatchScreen.swipe_to_shot(PackedVector2Array([Vector2(640, 650), Vector2(700, 500), Vector2(800, 300)]), 0.15, vs)
	check(bool(up_right["valid"]) and Vector2(up_right["target"]).x > 1.0 and float(up_right["power"]) > 0.5, "yukarı-sağ hızlı kaydırma: sağa güçlü şut")
	var down: Dictionary = MatchScreen.swipe_to_shot(PackedVector2Array([Vector2(640, 300), Vector2(640, 600)]), 0.2, vs)
	check(not bool(down["valid"]), "aşağı kaydırma şut değil")
	var dv: Vector2 = MatchScreen.swipe_to_dive(PackedVector2Array([Vector2(640, 400), Vector2(300, 300)]), vs)
	check(dv.x < -1.0 and dv.y > 0.6, "sola-yukarı kaydırma: sola dalış")
	# seri penaltı kuralları
	var m := Match.new()
	add_child(m)
	m.my_goals = 3; m.ai_goals = 0; m.turn = 6
	check(m._decided() == 1, "3-0, 3'er atış sonrası kazanıldı")
	m.my_goals = 2; m.ai_goals = 2; m.turn = 8; m.sudden = false
	check(m._decided() == 0, "2-2, 4'er atış: devam")
	m.my_goals = 4; m.ai_goals = 4; m.turn = 10; m.sudden = false
	check(m._decided() == 0 and m.sudden, "5'er atış eşit: seri penaltı")
	m.my_goals = 5; m.ai_goals = 4; m.turn = 12
	check(m._decided() == 1, "seri penaltıda öne geçen kazanır")
	m.queue_free()
	# kayıt
	Save.coins = 777
	Save.save_data()
	Save.save_data()
	Save.coins = 1
	check(Save.load_data() and Save.coins == 777, "kayıt yüklendi")
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	check(Save.load_data() and Save.coins == 777, "bozuk kayıtta yedek kullanıldı")
	# tam maç (hızlandırılmış)
	Save.reset_all()
	Engine.time_scale = 6.0
	main.show_screen("match", {"level": 0, "diff": 0})
	await get_tree().process_frame
	var scr = main.screen
	var game = scr.game
	var done: Array = [false, {}]
	var on_fin := func(win: bool, s: Dictionary) -> void:
		done[0] = true
		done[1] = s
	game.finished.connect(on_fin)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t0: int = Time.get_ticks_msec()
	while not bool(done[0]) and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if game.phase == "aim":
			game.on_shot(Vector2(rng.randf_range(-3.2, 3.2), rng.randf_range(0.2, 2.2)), rng.randf_range(0.5, 0.9), 0.0)
		elif game.phase == "keep" and not game._dived:
			game.on_dive(Vector2(rng.randf_range(-3, 3), rng.randf_range(0.3, 2.0)))
	Engine.time_scale = 1.0
	check(bool(done[0]), "maç sonuna kadar oynandı")
	if bool(done[0]):
		var s: Dictionary = done[1]
		check(int(s["my_goals"]) != int(s["ai_goals"]), "maç bir kazananla bitti: %d-%d" % [int(s["my_goals"]), int(s["ai_goals"])])
		check(int(Save.stats["matches"]) == 1, "istatistik kaydedildi")
		await get_tree().create_timer(1.2).timeout
		check(main.has_modal(), "sonuç penceresi açıldı")
	# ekranlar x diller x temalar
	for theme_mode in ["light", "dark"]:
		Settings.set_value("theme", theme_mode)
		for lang in I18n.LANGS:
			Settings.set_value("language", lang)
			for scn in ["menu", "kits", "levels", "shop", "settings", "about", "howto"]:
				main.show_screen(scn)
				await get_tree().process_frame
				check(main.screen_name == scn, "ekran %s (%s/%s)" % [scn, lang, theme_mode])
			main.show_screen("match", {"level": 3, "diff": 2})
			await get_tree().process_frame
			main.screen._open_pause()
			await get_tree().process_frame
			main.handle_back()
			await get_tree().process_frame
			main.show_screen("menu")
			await get_tree().process_frame
	get_tree().paused = false
	Settings.set_value("theme", "auto")
	Settings.set_value("language", "auto")
	Save.reset_all()
	print("=== SELFTEST %d kontrol, %d hata ===" % [checks, fails.size()])
	for x in fails:
		print("HATA: ", x)
	print("SELFTEST PASS" if fails.is_empty() else "SELFTEST FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)
