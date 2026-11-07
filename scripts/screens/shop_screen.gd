extends "res://scripts/screens/common.gd"
## Mağaza: top stilleri (jetonla), reklam izleyip jeton kazanma.

const Ball = preload("res://scripts/world/ball.gd")

var _rows: VBoxContainer


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.world.place_menu()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(make_header(I18n.t("shop")))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	_rows = UiTheme.vbox(10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_rows)
	_fill()


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var free := glass_panel()
	var fr := UiTheme.hbox(12)
	free.add_child(fr)
	fr.add_child(UiTheme.icon("ad", 64))
	var fl := UiTheme.label("+50", 32, "text", HORIZONTAL_ALIGNMENT_LEFT)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(fl)
	var reward := func() -> void:
		Save.add_coins(50)
		Sfx.play("coin")
	var watch := func() -> void:
		Ads.show_rewarded(reward)
	var fb := UiTheme.button("", "orange", "coin", 76, 24)
	fb.custom_minimum_size.x = 110
	fb.pressed.connect(watch)
	fr.add_child(fb)
	_rows.add_child(free)
	for i in Save.BALL_PRICES.size():
		var pc := glass_panel()
		var r := UiTheme.hbox(12)
		pc.add_child(r)
		var ic := UiTheme.icon("ball", 70)
		var st: Array = Ball.STYLES[i]
		ic.modulate = (st[0] as Color).lerp(Color.WHITE, 0.25)
		r.add_child(ic)
		var nm := UiTheme.label(I18n.t("ball_%d" % i), 28, "text", HORIZONTAL_ALIGNMENT_LEFT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		var b: Button
		if i in Save.balls_owned:
			if Save.ball_equipped == i:
				b = UiTheme.button(I18n.t("equipped"), "gray", "", 72, 24)
				b.disabled = true
			else:
				b = UiTheme.button(I18n.t("equip"), "blue", "", 72, 24)
				b.pressed.connect(_equip.bind(i))
		else:
			b = UiTheme.button(str(Save.BALL_PRICES[i]), "primary", "coin", 72, 24)
			b.pressed.connect(_buy.bind(i))
		b.name = "Ball_%d" % i
		b.custom_minimum_size.x = 200
		r.add_child(b)
		_rows.add_child(pc)


func _buy(i: int) -> void:
	if Save.spend(Save.BALL_PRICES[i]):
		Save.balls_owned.append(i)
		Save.ball_equipped = i
		Save.save_data()
		Sfx.play("coin")
		_fill()
	else:
		main.show_toast(I18n.t("not_enough_coins"))


func _equip(i: int) -> void:
	Save.ball_equipped = i
	Save.save_data()
	main.world.ball.apply_style(i)
	_fill()
