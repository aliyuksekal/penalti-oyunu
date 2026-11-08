extends Control
## Ana menü: BAŞLA, kamyonlar (jetonla satın al / seç), geliştirme (altınla),
## mağaza (altın -> jeton, reklam izle -> jeton, jeton paketleri).
## Ekonomi işlemlerini CargoAndGameManager yapar; burası sadece arayüz.

const TruckCatalog = preload("res://TruckCatalog.gd")
const TruckArt = preload("res://TruckArt.gd")

var manager: Node            # CargoAndGameManager
var tab: String = "trucks"
var _gold_lbl: Label
var _token_lbl: Label
var _best_lbl: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab_btns: Dictionary = {}

const C_PANEL := Color(0.07, 0.09, 0.13, 0.92)
const C_CARD := Color(0.13, 0.16, 0.22, 1.0)
const C_GOLD := Color(1.0, 0.8, 0.25)
const C_TOKEN := Color(0.35, 0.85, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- sol üst: başlık ---
	var title := _lbl(self, "AĞIR YÜK", 66, Color(1.0, 0.62, 0.15))
	title.position = Vector2(34, 18)
	var sub := _lbl(self, "Kargo Taşıma", 28, Color.WHITE)
	sub.position = Vector2(38, 100)

	# --- sol alt: başla ---
	var start := Button.new()
	start.text = "BAŞLA  ▶"
	start.add_theme_font_size_override("font_size", 44)
	start.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	start.offset_left = 34
	start.offset_right = 384
	start.offset_top = -136
	start.offset_bottom = -30
	manager._style_btn(start, Color(0.15, 0.68, 0.3))
	start.pressed.connect(func() -> void: manager.start_game())
	add_child(start)
	_best_lbl = _lbl(self, "", 22, Color.WHITE)
	_best_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_best_lbl.offset_left = 38
	_best_lbl.offset_top = -178
	_best_lbl.offset_bottom = -140
	var toggles := HBoxContainer.new()
	toggles.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toggles.offset_left = 34
	toggles.offset_right = 420
	toggles.offset_top = -236
	toggles.offset_bottom = -184
	toggles.add_theme_constant_override("separation", 6)
	add_child(toggles)
	manager.add_settings_toggles(toggles)

	# --- sağ panel ---
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -680
	panel.offset_right = -14
	panel.offset_top = 14
	panel.offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 14)
	v.add_child(money)
	_gold_lbl = _chip(money, C_GOLD)
	_token_lbl = _chip(money, C_TOKEN)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in [["trucks", "KAMYONLAR"], ["upgrades", "GELİŞTİRME"], ["shop", "MAĞAZA"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		var id: String = t[0]
		var go := func() -> void:
			tab = id
			refresh()
		b.pressed.connect(go)
		tabs.add_child(b)
		_tab_btns[id] = b

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12
	v.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)


func refresh() -> void:
	if _content == null:
		return
	_gold_lbl.text = "ALTIN  %d" % manager.total_gold
	_token_lbl.text = "JETON  %d" % manager.tokens
	_best_lbl.text = "Rekor: %d m" % int(manager.best_m)
	for id in _tab_btns:
		var b: Button = _tab_btns[id]
		manager._style_btn(b, Color(0.95, 0.55, 0.12) if id == tab else Color(0.2, 0.23, 0.3))
	for c in _content.get_children():
		c.queue_free()
	match tab:
		"trucks":
			_build_trucks()
		"upgrades":
			_build_upgrades()
		"shop":
			_build_shop()


# ---------------- KAMYONLAR ----------------
func _build_trucks() -> void:
	for d in TruckCatalog.all():
		var id: String = d["id"]
		var own: bool = manager.owned.has(id)
		var sel: bool = manager.selected == id
		var card := _card(Color(0.95, 0.55, 0.12) if sel else Color(0, 0, 0, 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)

		var pv := Control.new()
		pv.custom_minimum_size = Vector2(200, 124)
		pv.clip_contents = true
		pv.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(pv)
		var holder := Node2D.new()
		holder.position = Vector2(102, 72)
		holder.scale = Vector2(0.66, 0.66)
		pv.add_child(holder)
		TruckArt.build_preview(holder, d)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_theme_constant_override("separation", 2)
		h.add_child(info)
		_lbl(info, String(d["name"]), 26, Color.WHITE)
		var ds := _lbl(info, String(d["desc"]), 15, Color(0.75, 0.8, 0.88))
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.custom_minimum_size = Vector2(200, 0)
		_stat(info, "Güç", float(d["power"]) / 2.1)
		_stat(info, "Tutuş", float(d["grip"]) / 1.55)
		_stat(info, "Süspansiyon", (float(d["stiff"]) + float(d["damp"])) / 2.0 / 1.4)
		_stat(info, "Yakıt", float(d["fuel"]) / 1.9)

		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 20)
		if sel:
			b.text = "SEÇİLİ"
			b.disabled = true
			manager._style_btn(b, Color(0.95, 0.55, 0.12))
		elif own:
			b.text = "SEÇ"
			manager._style_btn(b, Color(0.2, 0.45, 0.8))
			b.pressed.connect(func() -> void: manager.select_truck(id))
		else:
			b.text = "SATIN AL\n%d jeton" % int(d["price"])
			manager._style_btn(b, Color(0.1, 0.55, 0.7) if manager.tokens >= int(d["price"]) else Color(0.3, 0.32, 0.38))
			b.pressed.connect(func() -> void: manager.buy_truck(id))
		h.add_child(b)


func _stat(parent: Control, title: String, v: float) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(h)
	var l := _lbl(h, title, 14, Color(0.8, 0.84, 0.9))
	l.custom_minimum_size = Vector2(92, 0)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(120, 10)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.show_percentage = false
	pb.max_value = 1.0
	pb.step = 0.0
	pb.value = clampf(v, 0.05, 1.0)
	pb.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.22, 0.25, 0.32)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.82, 0.45)
	fill.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	h.add_child(pb)


# ---------------- GELİŞTİRME ----------------
func _build_upgrades() -> void:
	var d: Dictionary = TruckCatalog.by_id(manager.selected)
	_lbl(_content, "Kamyon: %s" % d["name"], 26, Color.WHITE)
	var lv: Dictionary = manager.levels_of(manager.selected)
	for up in manager.UPGRADES:
		var uid: String = up["id"]
		var lvl: int = int(lv.get(uid, 0))
		var card := _card(Color(0, 0, 0, 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(info)
		_lbl(info, String(up["name"]), 24, Color.WHITE)
		var dots := ""
		for i in range(manager.MAX_LEVEL):
			dots += "●" if i < lvl else "○"
		_lbl(info, "%s   +%d%%" % [dots, int(round(float(up["step"]) * lvl * 100.0))], 18, Color(0.55, 0.9, 0.6))
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 62)
		b.add_theme_font_size_override("font_size", 20)
		if lvl >= manager.MAX_LEVEL:
			b.text = "EN ÜST"
			b.disabled = true
			manager._style_btn(b, Color(0.3, 0.32, 0.38))
		else:
			var cost: int = manager.upgrade_cost(manager.selected, uid)
			b.text = "YÜKSELT\n%d altın" % cost
			manager._style_btn(b, Color(0.8, 0.55, 0.1) if manager.total_gold >= cost else Color(0.3, 0.32, 0.38))
			b.pressed.connect(func() -> void: manager.buy_upgrade(uid))
		h.add_child(b)
	_note("Yükseltmeler altınla alınır ve sadece bu kamyona işler. Her işlemden önce kısa bir reklam gösterilir.")


# ---------------- MAĞAZA ----------------
func _build_shop() -> void:
	if manager.ads.test_mode:
		_note("TEST MODU: reklamlar ve ödemeler deneme amaçlıdır, gerçek ödeme alınmaz.")
	_lbl(_content, "Altını jetona çevir  (100 altın = 10 jeton)", 22, C_GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	for opt in [[1, "100 → 10"], [10, "1.000 → 100"], [-1, "TÜMÜ"]]:
		var b := Button.new()
		b.text = opt[1]
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		var n: int = opt[0]
		var need: int = manager.GOLD_PER_TOKEN_STEP * (1 if n < 0 else n)
		manager._style_btn(b, Color(0.8, 0.55, 0.1) if manager.total_gold >= need else Color(0.3, 0.32, 0.38))
		b.pressed.connect(func() -> void: manager.convert_gold(n))
		row.add_child(b)

	_lbl(_content, "Ücretsiz jeton", 22, C_TOKEN)
	var ad := Button.new()
	ad.text = "▶  Reklam izle:  +%d jeton" % manager.REWARDED_TOKENS
	ad.custom_minimum_size = Vector2(0, 66)
	ad.add_theme_font_size_override("font_size", 26)
	manager._style_btn(ad, Color(0.1, 0.55, 0.7))
	ad.pressed.connect(func() -> void: manager.watch_ad_for_tokens())
	_content.add_child(ad)

	_lbl(_content, "Jeton paketleri", 22, C_TOKEN)
	for p in manager.ads.PACKS:
		var pack: Dictionary = p
		var card := _card(Color(0, 0, 0, 0))
		var h := HBoxContainer.new()
		card.add_child(h)
		var l := _lbl(h, "%s\n%d jeton" % [pack["name"], int(pack["tokens"])], 22, Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := Button.new()
		b.text = "TEST AL" if manager.ads.test_mode else String(pack["price"])
		b.custom_minimum_size = Vector2(170, 58)
		b.add_theme_font_size_override("font_size", 22)
		manager._style_btn(b, Color(0.15, 0.6, 0.3))
		b.pressed.connect(func() -> void: manager.buy_pack(pack))
		h.add_child(b)


# ---------------- yardımcılar ----------------
func _card(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_corner_radius_all(14)
	sb.border_color = border
	sb.set_border_width_all(3 if border.a > 0.0 else 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	_content.add_child(p)
	return p


func _chip(parent: Control, col: Color) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.16, 0.22)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return _lbl(p, "", 26, col)


func _note(text: String) -> void:
	var l := _lbl(_content, text, 16, Color(0.7, 0.74, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)


func _lbl(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l
