extends "res://scripts/screens/common.gd"
## Kariyer: 5 lig x 4 bölüm, zorluk seçimi, yıldızlar, kilitler, reklamla bölüm geçme.

var _diff_btns: Array[Button] = []


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.world.place_menu()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(make_header(I18n.t("campaign")))
	var dp := glass_panel()
	var dr := UiTheme.hbox(10)
	dp.add_child(dr)
	dr.add_child(UiTheme.label(I18n.t("difficulty"), 26, "text"))
	for i in 4:
		var b := UiTheme.button(I18n.t("diff_%d" % i), "gray", "", 70, 24)
		b.name = "Diff_%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_diff.bind(i))
		dr.add_child(b)
		_diff_btns.append(b)
	root.add_child(dp)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var col := UiTheme.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	for lg in 5:
		var pc := glass_panel()
		var v := UiTheme.vbox(8)
		pc.add_child(v)
		var hr := UiTheme.hbox(8)
		hr.add_child(UiTheme.icon("trophy", 36))
		hr.add_child(UiTheme.label(I18n.t("league_%d" % lg), 28, "text", HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(hr)
		var row := UiTheme.hbox(10)
		for k in 4:
			row.add_child(_level_button(lg * 4 + k))
		v.add_child(row)
		col.add_child(pc)
	_refresh_diff()


func _level_button(idx: int) -> Button:
	var open: bool = idx <= Save.unlocked
	var b := Button.new()
	b.name = "Level_%d" % idx
	b.custom_minimum_size = Vector2(120, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = UiTheme.c("blue") if open else UiTheme.c("gray")
	if open and Save.stars[idx] > 0:
		col = UiTheme.c("primary")
	b.add_theme_stylebox_override("normal", UiTheme.box(col, 20, col.darkened(0.3), 3, 4, 6))
	b.add_theme_stylebox_override("hover", UiTheme.box(col.lightened(0.08), 20, col.darkened(0.3), 3, 4, 6))
	b.add_theme_stylebox_override("pressed", UiTheme.box(col.darkened(0.15), 20, col.darkened(0.3), 3, 0, 6))
	var v := UiTheme.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if open:
		var n := UiTheme.title(str(idx + 1), 40, Color.WHITE, col.darkened(0.45), 8)
		v.add_child(n)
		var sr := UiTheme.hbox(2)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		for s in 3:
			sr.add_child(UiTheme.icon("star" if s < Save.stars[idx] else "star_empty", 28))
		v.add_child(sr)
	else:
		var ic := UiTheme.icon("lock", 54)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
	b.pressed.connect(_open_level.bind(idx))
	return b


func _set_diff(i: int) -> void:
	Save.difficulty = i
	Save.save_data()
	_refresh_diff()


func _refresh_diff() -> void:
	for i in _diff_btns.size():
		UiTheme.color_button(_diff_btns[i], "orange" if i == Save.difficulty else "gray")


func _open_level(idx: int) -> void:
	if idx > Save.unlocked:
		main.show_toast(I18n.t("locked"))
		return
	var m = main.new_modal(I18n.t("level_n", {"v": idx + 1}), "ball")
	m.add_text(I18n.t("league_%d" % int(idx / 4)), 26, "text")
	m.add_text(I18n.t("keeper_style", {"v": I18n.t("style_%d" % (idx % 4))}) + " · " + I18n.t("diff_%d" % Save.difficulty), 24)
	add_role_buttons(m, idx)
	if Save.stars[idx] == 0 and idx < Save.LEVELS - 1:
		var reward := func() -> void:
			Save.complete_level(idx, 1)
			main.show_screen("levels")
		var skip := func() -> void:
			Ads.show_rewarded(reward)
		m.add_button(I18n.t("skip_level"), "orange", skip, "ad")
	m.add_button(I18n.t("close"), "gray", Callable())
