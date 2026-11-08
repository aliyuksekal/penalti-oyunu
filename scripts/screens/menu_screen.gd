extends "res://scripts/screens/common.gd"
## Ana menü: canlı 3D stadyum arka planı, logo, kariyer / hızlı maç / formalar / mağaza.


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.world.setup_kits(Save.my_kit, Save.rival_kit)
	main.world.place_menu()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := UiTheme.hbox(10)
	var info := UiTheme.button("", "blue", "info", 76, 20)
	info.custom_minimum_size.x = 76
	info.pressed.connect(func() -> void: main.show_screen("about"))
	top.add_child(info)
	var gear := UiTheme.button("", "gray", "gear", 76, 20)
	gear.name = "SettingsButton"
	gear.custom_minimum_size.x = 76
	gear.pressed.connect(func() -> void: main.open_settings("menu"))
	top.add_child(gear)
	top.add_child(UiTheme.hspacer())
	var stars := UiTheme.panel("panel", 30, 12)
	var sr := UiTheme.hbox(6)
	sr.add_child(UiTheme.icon("star", 40))
	sr.add_child(UiTheme.label(str(Save.total_stars()), 28, "text"))
	stars.add_child(sr)
	top.add_child(stars)
	top.add_child(coin_chip())
	root.add_child(top)
	var portrait: bool = main.is_portrait()
	root.add_child(UiTheme.spacer(4, portrait))
	var logo := UiTheme.vbox(0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := UiTheme.title(I18n.t("app_title").to_upper(), 92 if not portrait else 70, Color("ffffff"), Color("0a2a6b"), 18)
	t1.add_theme_color_override("font_shadow_color", Color(0, 0.6, 1.0, 0.55))
	t1.add_theme_constant_override("shadow_offset_y", 8)
	logo.add_child(t1)
	var t2 := UiTheme.title(I18n.t("tagline") + " ★", 40, Color("ffd23f"), Color("3a1f00"), 10)
	logo.add_child(t2)
	_pulse(t2)
	root.add_child(logo)
	root.add_child(UiTheme.spacer(4, true))
	var grid := GridContainer.new()
	grid.columns = 2 if portrait else 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var items: Array = [
		["campaign", "primary", "trophy", "levels"], ["quick_match", "blue", "ball", "quick"],
		["kits", "purple", "jersey", "kits"], ["shop", "orange", "shop", "shop"]]
	for it in items:
		var b := UiTheme.button(I18n.t(str(it[0])), str(it[1]), str(it[2]), 110, 30)
		b.name = "Menu_" + str(it[3])
		b.custom_minimum_size.x = 250 if not portrait else 300
		b.pressed.connect(_on_item.bind(str(it[3])))
		grid.add_child(b)
	root.add_child(grid)
	var ver := UiTheme.label(I18n.t("version", {"v": str(ProjectSettings.get_setting("application/config/version", "1.0.0"))}), 18, "text")
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	root.add_child(ver)


func _pulse(c: Control) -> void:
	c.pivot_offset = Vector2(300, 24)
	var tw := create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _on_item(id: String) -> void:
	match id:
		"levels":
			main.show_screen("levels")
		"quick":
			var m = main.new_modal(I18n.t("choose_role"), "ball")
			add_role_buttons(m, -1)
			m.add_button(I18n.t("close"), "gray", Callable())
		"kits":
			main.show_screen("kits")
		"shop":
			main.show_screen("shop")
