extends Control
## Ekranlar için ortak yardımcılar: üst başlık çubuğu ve jeton göstergesi.

var main
var arg: Dictionary = {}
var _coin_label: Label


func make_header(title_text: String, back_target: String = "menu") -> HBoxContainer:
	var h := UiTheme.hbox(12)
	var back := UiTheme.button("", "gray", "home", 76, 22)
	back.name = "BackButton"
	back.custom_minimum_size.x = 76
	back.pressed.connect(func() -> void: main.show_screen(back_target))
	h.add_child(back)
	var t := UiTheme.title(title_text, 44, Color.WHITE, Color("0b1d4a"), 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(coin_chip())
	return h


func coin_chip() -> PanelContainer:
	var pc := UiTheme.panel("panel", 30, 12)
	var row := UiTheme.hbox(6)
	row.add_child(UiTheme.icon("coin", 40))
	_coin_label = UiTheme.label(str(Save.coins), 28, "text")
	_coin_label.custom_minimum_size.x = 70
	row.add_child(_coin_label)
	pc.add_child(row)
	if not Save.changed.is_connected(_refresh_coins):
		Save.changed.connect(_refresh_coins)
	return pc


func _refresh_coins() -> void:
	if _coin_label != null and is_instance_valid(_coin_label):
		_coin_label.text = str(Save.coins)


func glass_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var c: Color = UiTheme.c("panel")
	c.a = 0.88
	pc.add_theme_stylebox_override("panel", UiTheme.box(c, 28, UiTheme.c("border"), 2, 12, 20))
	return pc


## Rol seçimi: şutçu / kaleci / klasik seri. Son seçilen en üstte, vurgulu.
func add_role_buttons(m, level_idx: int) -> void:
	var modes: Array = [[0, "mode_shoot", "ball"], [1, "mode_keep", "glove"], [2, "mode_both", "play"]]
	m.add_text(I18n.t("choose_role_hint"), 22)
	for row in modes:
		var md: int = int(row[0])
		var go := func() -> void:
			Save.play_mode = md
			Save.save_data()
			main.show_screen("match", {"level": level_idx, "diff": Save.difficulty, "mode": md})
		m.add_button(I18n.t(str(row[1])), "primary" if md == Save.play_mode else "blue", go, str(row[2]))
