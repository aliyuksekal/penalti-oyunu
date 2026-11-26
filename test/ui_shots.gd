extends Node
## Sadece test: dil/tema/yardım/ipucu ekran görüntüleri (oyuna dahil değil)
var main: Node

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/ui_" + n + ".png")

func _w(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await _w(7.0)
	Lang.tips_reset()
	await _shot("1_menu_en")
	main.open_settings()
	await _w(0.4)
	await _shot("2_settings_en")
	main._close_settings()
	main.open_help()
	await _w(0.4)
	await _shot("3_help_en")
	main.help_panel.queue_free()
	main.help_panel = null
	Lang.set_lang("zh")
	Lang.set_theme("light")
	await _w(0.3)
	main.open_settings()
	await _w(0.4)
	await _shot("4_settings_zh_light")
	main._close_settings()
	Lang.set_lang("ko")
	main.show_tip("tip_pedals")
	await _w(0.4)
	await _shot("5_tip_ko_light")
	Lang.set_theme("dark")
	Lang.set_lang("ru")
	main.tip_panel.queue_free()
	main.tip_panel = null
	main.confirm_quit()
	await _w(0.4)
	await _shot("6_quit_ru")
	get_tree().quit()
