extends "res://scripts/screens/common.gd"
## Nasıl oynanır (ilk açılışta da gösterilir): 3 sayfa.

const PAGES := [["ball", "howto_1"], ["glove", "howto_2"], ["ai", "howto_3"]]
var page: int = 0
var _card: VBoxContainer
var _next: Button


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	main.world.place_menu()
	var root := UiTheme.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UiTheme.spacer(4, true))
	var pc := glass_panel()
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.custom_minimum_size = Vector2(minf(760.0, get_viewport_rect().size.x - 40.0), 0)
	_card = UiTheme.vbox(16)
	pc.add_child(_card)
	root.add_child(pc)
	var row := UiTheme.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var skip := UiTheme.button(I18n.t("close"), "gray", "", 84, 26)
	skip.name = "SkipButton"
	skip.pressed.connect(_finish)
	row.add_child(skip)
	_next = UiTheme.button("", "primary", "play", 84, 30)
	_next.name = "NextButton"
	_next.custom_minimum_size.x = 300
	_next.pressed.connect(_advance)
	row.add_child(_next)
	root.add_child(row)
	root.add_child(UiTheme.spacer(4, true))
	_show()


func _show() -> void:
	for c in _card.get_children():
		c.queue_free()
	var p: Array = PAGES[page]
	var ic := UiTheme.icon(str(p[0]), 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.add_child(ic)
	_card.add_child(UiTheme.title(I18n.t("how_to_play"), 40, Color.WHITE, Color("0a2a6b"), 10))
	_card.add_child(UiTheme.label(I18n.t(str(p[1])), 28, "text", HORIZONTAL_ALIGNMENT_CENTER, true))
	_card.add_child(UiTheme.label("%d / %d" % [page + 1, PAGES.size()], 22, "text_dim"))
	_next.text = I18n.t("play") if page == PAGES.size() - 1 else "›"


func _advance() -> void:
	if page >= PAGES.size() - 1:
		_finish()
		return
	page += 1
	_show()


func _finish() -> void:
	Settings.set_value("intro_seen", true)
	main.show_screen("menu")


func on_back() -> bool:
	if page > 0:
		page -= 1
		_show()
		return true
	return false
