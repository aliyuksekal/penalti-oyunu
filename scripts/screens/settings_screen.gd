extends "res://scripts/screens/common.gd"
## Ayarlar: dil, tema (açık/koyu/otomatik), ses, stadyum sesi, titreşim, sıfırlamalar, gizlilik.

const PRIVACY_URL := "https://aliyuksekal.github.io/gizlilik/penalti-ustasi-gizlilik.html"


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	main.world.place_menu()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var h := make_header(I18n.t("settings"))
	var back: Button = h.get_node("BackButton")
	for c in back.pressed.get_connections():
		back.pressed.disconnect(c["callable"])
	back.pressed.connect(func() -> void: main.back_from_settings())
	back.pressed.connect(UiTheme._btn_feedback)
	root.add_child(h)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var col := UiTheme.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	var lp := _section(col, I18n.t("language"))
	var lg := GridContainer.new()
	lg.columns = 4 if not main.is_portrait() else 2
	lg.add_theme_constant_override("h_separation", 10)
	lg.add_theme_constant_override("v_separation", 10)
	var cur: String = str(Settings.get_value("language"))
	var opts: Array[String] = ["auto"]
	opts.append_array(I18n.LANGS)
	for code in opts:
		var txt: String = I18n.t("lang_auto") if code == "auto" else str(I18n.LANG_NAMES[code])
		var b := UiTheme.button(txt, "primary" if code == cur else "gray", "", 70, 24)
		b.name = "Lang_" + code
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_lang.bind(code))
		lg.add_child(b)
	lp.add_child(lg)
	var tp := _section(col, I18n.t("theme"))
	var th := UiTheme.hbox(10)
	var curt: String = str(Settings.get_value("theme"))
	for mode in ["auto", "light", "dark"]:
		var b := UiTheme.button(I18n.t("theme_" + mode), "primary" if mode == curt else "gray", "", 70, 24)
		b.name = "Theme_" + mode
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_theme.bind(mode))
		th.add_child(b)
	tp.add_child(th)
	var sp := _section(col, I18n.t("sound"))
	sp.add_child(_toggle(I18n.t("sound"), "sfx"))
	sp.add_child(_toggle(I18n.t("music"), "music"))
	sp.add_child(_toggle(I18n.t("vibration"), "vibration"))
	var op := _section(col, I18n.t("about"))
	var how := UiTheme.button(I18n.t("how_to_play"), "blue", "info", 76, 24)
	how.pressed.connect(func() -> void: main.show_screen("howto"))
	op.add_child(how)
	var pv := UiTheme.button(I18n.t("privacy"), "purple", "eye", 76, 24)
	pv.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	op.add_child(pv)
	var ra := UiTheme.button(I18n.t("reset_ai"), "orange", "ai", 76, 24)
	ra.name = "ResetAi"
	ra.pressed.connect(_ask_reset_ai)
	op.add_child(ra)
	var rp := UiTheme.button(I18n.t("reset_progress"), "red", "retry", 76, 24)
	rp.pressed.connect(_ask_reset)
	op.add_child(rp)
	col.add_child(UiTheme.spacer(20))


func _section(parent: Control, title_text: String) -> VBoxContainer:
	var pc := glass_panel()
	var v := UiTheme.vbox(10)
	pc.add_child(v)
	v.add_child(UiTheme.label(title_text, 28, "text", HORIZONTAL_ALIGNMENT_LEFT))
	parent.add_child(pc)
	return v


func _toggle(text: String, key: String) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = text
	cb.name = "Toggle_" + key
	cb.button_pressed = Settings.flag(key)
	cb.custom_minimum_size = Vector2(0, 60)
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	return cb


func _set_lang(code: String) -> void:
	Settings.set_value("language", code)
	main.show_screen("settings", {}, true)


func _set_theme(mode: String) -> void:
	Settings.set_value("theme", mode)


func _ask_reset_ai() -> void:
	var yes := func() -> void:
		Save.reset_ai()
		Save.save_data()
		main.show_toast(I18n.t("done"))
	main.confirm(I18n.t("reset_ai_q"), I18n.t("ok"), "orange", yes)


func _ask_reset() -> void:
	var yes := func() -> void:
		Save.reset_all()
		main.show_toast(I18n.t("done"))
	main.confirm(I18n.t("reset_q"), I18n.t("ok"), "red", yes)


func on_back() -> bool:
	main.back_from_settings()
	return true
