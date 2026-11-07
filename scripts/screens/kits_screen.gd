extends "res://scripts/screens/common.gd"
## Forma seçimi: kendi formanı ve yapay zekânın formasını seç (yalnızca renkler).

const KitSwatch = preload("res://scripts/ui/kit_swatch.gd")

var _mine: Array = []
var _rival: Array = []
var _mine_label: Label
var _rival_label: Label


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.world.setup_kits(Save.my_kit, Save.rival_kit)
	main.world.place_kits()
	var root := UiTheme.vbox(10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(make_header(I18n.t("kits")))
	root.add_child(UiTheme.spacer(4, true))
	var portrait: bool = main.is_portrait()
	var box: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	box.add_child(_section(true))
	if not portrait:
		var mid := Control.new()
		mid.custom_minimum_size = Vector2(240, 0)
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mid)
	box.add_child(_section(false))
	_refresh()


func _section(mine: bool) -> PanelContainer:
	var pc := glass_panel()
	var v := UiTheme.vbox(10)
	pc.add_child(v)
	v.add_child(UiTheme.label(I18n.t("your_kit") if mine else I18n.t("rival_kit"), 28, "text"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for id in Kits.ORDER:
		var s = KitSwatch.new(id)
		s.custom_minimum_size = Vector2(124, 124)
		s.name = ("Mine_" if mine else "Rival_") + id
		s.pressed.connect(_pick.bind(mine, id))
		g.add_child(s)
		if mine:
			_mine.append(s)
		else:
			_rival.append(s)
	v.add_child(g)
	var l := UiTheme.label("", 26, "text")
	v.add_child(l)
	if mine:
		_mine_label = l
	else:
		_rival_label = l
	return pc


func _pick(mine: bool, id: String) -> void:
	Sfx.play("tap")
	if mine:
		Save.my_kit = id
		if Save.rival_kit == id:
			for k in Kits.ORDER:
				if k != id:
					Save.rival_kit = k
					break
	else:
		if id == Save.my_kit:
			main.show_toast(I18n.t("same_kit"))
			return
		Save.rival_kit = id
	Save.save_data()
	main.world.setup_kits(Save.my_kit, Save.rival_kit)
	main.world.place_kits()
	_refresh()


func _refresh() -> void:
	for s in _mine:
		s.selected = s.kit_id == Save.my_kit
		s.queue_redraw()
	for s in _rival:
		s.selected = s.kit_id == Save.rival_kit
		s.disabled = s.kit_id == Save.my_kit
		s.modulate = Color(1, 1, 1, 0.35) if s.disabled else Color.WHITE
		s.queue_redraw()
	_mine_label.text = I18n.t(Kits.name_key(Save.my_kit))
	_rival_label.text = I18n.t(Kits.name_key(Save.rival_kit))
