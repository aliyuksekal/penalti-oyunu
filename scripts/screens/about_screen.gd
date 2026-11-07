extends "res://scripts/screens/common.gd"
## Hakkında: açıklama, veri politikası, geliştirici, lisanslar.


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	main.world.place_menu()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(make_header(I18n.t("about")))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var pc := glass_panel()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pc)
	var v := UiTheme.vbox(14)
	pc.add_child(v)
	v.add_child(UiTheme.title(I18n.t("app_title"), 48, Color.WHITE, Color("0a2a6b"), 12))
	v.add_child(UiTheme.label(I18n.t("version", {"v": str(ProjectSettings.get_setting("application/config/version", "1.0.0"))}), 22, "text_dim"))
	v.add_child(UiTheme.label(I18n.t("about_body"), 24, "text", HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(UiTheme.label(I18n.t("about_data"), 24, "text_dim", HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(UiTheme.label(I18n.t("developer") + " · matali.truz@gmail.com", 24, "text"))
	var lic := UiTheme.button("Open source licenses", "gray", "info", 72, 22)
	lic.name = "LicensesButton"
	lic.pressed.connect(_licenses)
	v.add_child(lic)


func _licenses() -> void:
	var m = main.new_modal("Licenses", "", 760.0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, minf(600.0, get_viewport_rect().size.y * 0.6))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var l := UiTheme.label("", 16, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = "Godot Engine — MIT License\n\n" + Engine.get_license_text() + "\n\nNunito font — SIL Open Font License 1.1."
	sc.add_child(l)
	m.add(sc)
	m.add_button(I18n.t("close"), "gray", Callable())
