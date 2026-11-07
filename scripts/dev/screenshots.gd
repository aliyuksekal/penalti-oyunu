extends Node
## Mağaza ekran görüntüleri ve ikon kaynağı (CI'da xvfb + OpenGL).
## godot --rendering-driver opengl3 --resolution 1920x1080 -- --screenshots=/yol

var out: String = ""
var main


func _ready() -> void:
	out = str(get_meta("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	main = get_parent()
	call_deferred("_run")


func _wait(frames: int = 12) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(file: String, frames: int = 14) -> void:
	await _wait(frames)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("shot ", file, " ", img.get_size())


func _set_size(s: Vector2i) -> void:
	get_window().size = s
	await _wait(6)


func _match_shots(prefix: String) -> void:
	main.show_screen("match", {"level": 6, "diff": 1})
	await _wait(30)
	var scr = main.screen
	var game = scr.game
	# nişan anı + yapay zekâ laf atıyor
	scr._show_bubble(I18n.t("hint_watch", {"v": I18n.t("zone_8")}))
	scr._on_reading(74)
	await _shot(prefix + "_02_aim.png", 20)
	# sol üst köşeye gol (kaleci sağa yatsın)
	game._keeper_zone = 8
	game.skill = 0.0
	game.rng.seed = 3
	game.on_shot(Vector2(-3.1, 2.05), 0.95, -0.4)
	await get_tree().create_timer(0.62).timeout
	if prefix == "tr":
		await _shot("dev_kick.png", 1)
	await get_tree().create_timer(0.25).timeout
	await _shot(prefix + "_03_goal.png", 2)
	await get_tree().create_timer(1.6).timeout
	await _shot(prefix + "_04_celebration.png", 2)
	# kaleci görünümü
	while game.phase != "keep":
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _shot(prefix + "_05_keeper.png", 4)
	game.on_dive(Vector2(-2.5, 1.2))
	if prefix == "tr":
		await get_tree().create_timer(0.35).timeout
		await _shot("dev_dive_mid.png", 1)
		await get_tree().create_timer(1.1).timeout
	else:
		await get_tree().create_timer(1.5).timeout
	await _shot(prefix + "_06_dive.png", 2)
	game.stop()
	# sonuç ekranı (örnek veri)
	scr._on_finished(true, {"win": true, "stars": 3, "coins": 140, "my_goals": 5, "ai_goals": 2,
		"zones": [3, 0, 1, 0, 0, 1, 2, 1, 4], "read_pct": 58, "overall_pct": 61, "fav": 8, "level": 6})
	await get_tree().create_timer(1.4).timeout
	await _shot(prefix + "_07_result.png", 6)
	main.close_all_modals()
	Engine.time_scale = 1.0


func _run() -> void:
	Save.reset_all()
	Save.coins = 2350
	Save.unlocked = 9
	for i in 9:
		Save.stars[i] = [3, 3, 2, 3, 1, 2, 3, 2, 1][i]
	Save.my_kit = "red_yellow"
	Save.rival_kit = "yellow_navy"
	for lang in ["tr", "en"]:
		Settings.set_value("language", lang)
		Settings.set_value("theme", "dark")
		await _set_size(Vector2i(1920, 1080))
		main.show_screen("menu")
		await _shot(lang + "_01_menu.png", 40)
		await _match_shots(lang)
		main.show_screen("kits")
		await _shot(lang + "_08_kits.png", 50)
		main.show_screen("levels")
		await _shot(lang + "_09_levels.png", 20)
		Settings.set_value("theme", "light")
		main.show_screen("levels")
		await _shot(lang + "_10_levels_light.png", 20)
	# telefon dikey + tablet
	Settings.set_value("language", "tr")
	Settings.set_value("theme", "dark")
	await _set_size(Vector2i(1080, 1920))
	main.show_screen("menu")
	await _shot("portrait_01_menu.png", 40)
	main.show_screen("match", {"level": 2, "diff": 1})
	await _shot("portrait_02_aim.png", 40)
	main.screen.game.stop()
	await _set_size(Vector2i(2560, 1600))
	main.show_screen("match", {"level": 2, "diff": 1})
	await _shot("tablet_01_aim.png", 40)
	main.screen.game.stop()
	# ikon kaynağı: topa yakın plan, arkada kale
	await _set_size(Vector2i(1024, 1024))
	main.show_screen("menu")
	main.screen.visible = false
	var w = main.world
	w.cam_mode = "icon"
	w.ball.position = Vector3(0, 0.11, 9.0)
	w.camera.fov = 30.0
	w.camera.position = Vector3(0.35, 0.45, 10.2)
	w.camera.look_at(Vector3(0, 0.7, 4.0), Vector3.UP)
	w.keeper.position = Vector3(0, 0, 0.3)
	w.keeper.set_state("keeper_ready")
	w.shooter.visible = false
	await _shot("icon_source.png", 30)
	w.shooter.visible = true
	Settings.set_value("language", "auto")
	Settings.set_value("theme", "auto")
	Save.reset_all()
	print("SCREENSHOTS DONE")
	get_tree().quit(0)
