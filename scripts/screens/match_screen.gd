extends "res://scripts/screens/common.gd"
## Maç ekranı: skor tabelası, "seni okuyor" göstergesi, kaydırma girişi, ipucu,
## GOOOL efekti (yavaş çekim, flaş, dev yazı), maç sonu analizi.

const Match = preload("res://scripts/game/match.gd")
const Brain = preload("res://scripts/game/brain.gd")
const HINT_COST := 25

var game: Match
var _score_l: Label
var _my_dots: HBoxContainer
var _ai_dots: HBoxContainer
var _read_bar: ProgressBar
var _read_l: Label
var _bubble: PanelContainer
var _bubble_l: Label
var _prompt: Label
var _hint_btn: Button
var _big: Label
var _flash: ColorRect
var _swipe: Control
var _trail: Line2D
var _pts: PackedVector2Array = PackedVector2Array()
var _t0: float = 0.0
var _down: bool = false
var _bubble_tw: Tween
var _guess: Label
var _banner: PanelContainer


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.world.setup_kits(Save.my_kit, Save.rival_kit)
	main.world.place_for_shoot(true)
	main.world.ball.apply_style(Save.ball_equipped)
	# kaydırma alanı (tüm ekran)
	_swipe = Control.new()
	_swipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_swipe.gui_input.connect(_on_swipe_input)
	add_child(_swipe)
	_trail = Line2D.new()
	_trail.width = 14.0
	_trail.default_color = Color(1, 1, 1, 0.85)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.2))
	wc.add_point(Vector2(1, 1))
	_trail.width_curve = wc
	_swipe.add_child(_trail)
	# üst çubuk
	var top := UiTheme.hbox(10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var pause := UiTheme.button("", "gray", "pause", 72, 20)
	pause.name = "PauseButton"
	pause.custom_minimum_size.x = 72
	pause.pressed.connect(_open_pause)
	top.add_child(pause)
	top.add_child(UiTheme.hspacer())
	top.add_child(_score_panel())
	top.add_child(UiTheme.hspacer())
	top.add_child(_reading_panel())
	# baloncuk (yapay zekâ laf atar)
	_bubble = PanelContainer.new()
	var bc := Color("06223f")
	bc.a = 0.86
	_bubble.add_theme_stylebox_override("panel", UiTheme.box(bc, 22, Color("39d0ff"), 3, 10, 18))
	var bv := UiTheme.vbox(2)
	var bh := UiTheme.label("SENİ OKUYOR" if I18n.lang == "tr" else I18n.t("ai"), 22, "text")
	bh.add_theme_color_override("font_color", Color("39d0ff"))
	bv.add_child(bh)
	_bubble_l = UiTheme.label("", 26, "text")
	_bubble_l.add_theme_color_override("font_color", Color.WHITE)
	bv.add_child(_bubble_l)
	_bubble.add_child(bv)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	# alt yönerge + ipucu
	_prompt = UiTheme.title("", 30, Color.WHITE, Color("06142e"), 10)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 40
	add_child(_prompt)
	_guess = UiTheme.title("", 30, Color("ff4a4a"), Color("1a0000"), 8)
	_guess.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_guess)
	_banner = PanelContainer.new()
	var bnc := Color("06142e")
	bnc.a = 0.8
	_banner.add_theme_stylebox_override("panel", UiTheme.box(bnc, 10, Color(1, 1, 1, 0.15), 1, 0, 16))
	var bl := UiTheme.label(I18n.t("ai_analyzing"), 22, "text")
	bl.add_theme_color_override("font_color", Color.WHITE)
	_banner.add_child(bl)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_hint_btn = UiTheme.button(str(HINT_COST), "purple", "eye", 80, 24)
	_hint_btn.name = "HintButton"
	_hint_btn.custom_minimum_size = Vector2(160, 80)
	_hint_btn.pressed.connect(_buy_hint)
	add_child(_hint_btn)
	# büyük yazı + flaş
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_big = UiTheme.title("", 150, Color("ffd23f"), Color("7a2a00"), 26)
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.visible = false
	add_child(_big)
	resized.connect(_layout)
	_layout()
	# maç
	game = Match.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	game.setup(main.world, int(arg.get("level", -1)), int(arg.get("diff", Save.difficulty)), int(arg.get("mode", Save.play_mode)))
	game.phase_changed.connect(_on_phase)
	game.outcome.connect(_on_outcome)
	game.score_changed.connect(_refresh_score)
	game.taunt.connect(_show_bubble)
	game.reading_changed.connect(_on_reading)
	game.finished.connect(_on_finished)
	Sfx.play("whistle")
	game.start()


func on_leave() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if game != null:
		game.stop()


func on_back() -> bool:
	_open_pause()
	return true


func _layout() -> void:
	var vs: Vector2 = size
	_bubble.reset_size()
	var kp: Vector2 = main.world.keeper_screen_pos()
	if main.world.cam_mode == "shoot" and kp.x > 0.0:
		_bubble.position = Vector2(clampf(kp.x + 60.0, 10.0, vs.x - _bubble.size.x - 10.0), clampf(kp.y + 10.0, 120.0, vs.y - 200.0))
	else:
		_bubble.position = Vector2((vs.x - _bubble.size.x) / 2.0, vs.y * 0.22)
	_banner.reset_size()
	_banner.position = Vector2((vs.x - _banner.size.x) / 2.0, 118.0)
	_guess.reset_size()
	_guess.position = Vector2(vs.x - _guess.size.x - 24.0, vs.y - 300.0)
	_prompt.reset_size()
	_prompt.position = Vector2((vs.x - _prompt.size.x) / 2.0, vs.y - _prompt.size.y - 14)
	_hint_btn.position = Vector2(vs.x - 176, vs.y - 196)
	_big.pivot_offset = vs / 2.0


func _score_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var c: Color = Color("0a1630")
	c.a = 0.9
	pc.add_theme_stylebox_override("panel", UiTheme.box(c, 24, Color("ffffff30"), 2, 10, 18))
	var v := UiTheme.vbox(4)
	pc.add_child(v)
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_kit_chip(Save.my_kit))
	var you := UiTheme.label(I18n.t("you"), 24, "text")
	you.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(you)
	_score_l = UiTheme.title("0 - 0", 44, Color.WHITE, Color.BLACK, 6)
	row.add_child(_score_l)
	var ai := UiTheme.label(I18n.t("ai"), 24, "text")
	ai.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(ai)
	row.add_child(_kit_chip(Save.rival_kit))
	v.add_child(row)
	var dots := UiTheme.hbox(30)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_dots = UiTheme.hbox(5)
	_ai_dots = UiTheme.hbox(5)
	dots.add_child(_my_dots)
	dots.add_child(_ai_dots)
	v.add_child(dots)
	return pc


func _kit_chip(id: String) -> Control:
	var k: Dictionary = Kits.get_kit(id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for col in [k["a"], k["b"]]:
		var r := ColorRect.new()
		r.color = col
		r.custom_minimum_size = Vector2(14, 34)
		h.add_child(r)
	return h


func _reading_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var c: Color = Color("0a1630")
	c.a = 0.9
	pc.add_theme_stylebox_override("panel", UiTheme.box(c, 20, Color("39d0ff60"), 2, 8, 14))
	var v := UiTheme.vbox(4)
	pc.add_child(v)
	var h := UiTheme.hbox(6)
	h.add_child(UiTheme.icon("ai", 34))
	_read_l = UiTheme.label("", 22, "text")
	_read_l.add_theme_color_override("font_color", Color("bff2ff"))
	h.add_child(_read_l)
	v.add_child(h)
	_read_bar = UiTheme.bar("blue", 14)
	_read_bar.custom_minimum_size.x = 200
	UiTheme.set_bar_color(_read_bar, Color("39d0ff"))
	v.add_child(_read_bar)
	return pc


func _refresh_score() -> void:
	_score_l.text = "%d - %d" % [game.my_goals, game.ai_goals]
	_fill_dots(_my_dots, game.my_marks)
	_fill_dots(_ai_dots, game.ai_marks)


func _fill_dots(box: HBoxContainer, marks: Array[int]) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var from: int = maxi(0, marks.size() - 5)
	for i in range(from, marks.size()):
		var p := Panel.new()
		p.custom_minimum_size = Vector2(20, 20)
		var col: Color = Color(1, 1, 1, 0.25)
		if marks[i] == 1:
			col = Color("2fd36b")
		elif marks[i] == 0:
			col = Color("ff4a5a")
		p.add_theme_stylebox_override("panel", UiTheme.box(col, 10, Color(1, 1, 1, 0.5), 2, 0, 0))
		box.add_child(p)


func _on_reading(pct: int) -> void:
	_read_l.text = I18n.t("reading", {"v": pct})
	var tw := create_tween()
	tw.tween_property(_read_bar, "value", float(pct), 0.6)


func _on_phase(ph: String) -> void:
	match ph:
		"shoot":
			_prompt.text = I18n.t("your_turn_shoot")
			_hint_btn.visible = true
			_hint_btn.disabled = false
			_banner.visible = true
			var best: int = Brain.argmax(game._pred)
			var side_p: float = 0.0
			for zi in 9:
				if zi % 3 == best % 3:
					side_p += game._pred[zi]
			_guess.text = I18n.t("ai_guess", {"p": int(round(side_p * 100.0)), "z": I18n.t("zone_%d" % best)})
			_guess.visible = true
		"keep":
			_prompt.text = I18n.t("your_turn_keep")
			_hint_btn.visible = false
			_banner.visible = false
			_guess.visible = false
		_:
			_prompt.text = ""
			_hint_btn.visible = false
			_banner.visible = false
			_guess.visible = false
	_layout()


func _show_bubble(text: String) -> void:
	_bubble_l.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_layout()
	if _bubble_tw != null and _bubble_tw.is_valid():
		_bubble_tw.kill()
	_bubble_tw = create_tween()
	_bubble_tw.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	_bubble_tw.tween_interval(2.6)
	_bubble_tw.tween_property(_bubble, "modulate:a", 0.0, 0.3)


func _buy_hint() -> void:
	if game.phase != "aim":
		return
	if Save.spend(HINT_COST):
		_reveal_hint()
		return
	var reward := func() -> void:
		_reveal_hint()
	Ads.show_rewarded(reward)


func _reveal_hint() -> void:
	if game.phase != "aim":
		return
	var z: int = game.reveal_keeper()
	_show_bubble(I18n.t("hint_shown", {"v": I18n.t("zone_%d" % z)}))
	_hint_btn.disabled = true


# ---------------- kaydırma ----------------
func _on_swipe_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_down = true
			_pts = PackedVector2Array([mb.position])
			_t0 = Time.get_ticks_msec() / 1000.0
			_trail.clear_points()
			_trail.add_point(mb.position)
		elif _down:
			_down = false
			_finish_swipe()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _down:
		_pts.append(mm.position)
		_trail.add_point(mm.position)
		if _trail.get_point_count() > 24:
			_trail.remove_point(0)


func _finish_swipe() -> void:
	var tw := create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_reset_trail)
	if _pts.size() < 2:
		if game.phase == "keep":
			game.on_dive(Vector2(0, 1.0))
		return
	var dur: float = maxf(0.05, Time.get_ticks_msec() / 1000.0 - _t0)
	var vs: Vector2 = size
	var swipe: Dictionary = swipe_to_shot(_pts, dur, vs)
	if game.phase == "aim":
		if not bool(swipe["valid"]):
			return
		_prompt.text = ""
		_hint_btn.visible = false
		game.on_shot(swipe["target"], swipe["power"], swipe["curl"])
	elif game.phase == "keep":
		game.on_dive(swipe_to_dive(_pts, vs))


func _reset_trail() -> void:
	_trail.clear_points()
	_trail.modulate.a = 1.0


## Kaydırma -> şut (test edilebilir saf fonksiyon)
static func swipe_to_shot(pts: PackedVector2Array, dur: float, vs: Vector2) -> Dictionary:
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var d: Vector2 = b - a
	if d.y > -30.0 or d.length() < 50.0:
		return {"valid": false, "target": Vector2.ZERO, "power": 0.0, "curl": 0.0}
	var wide: float = vs.x * (0.30 if vs.x > vs.y else 0.42)
	var nx: float = d.x / wide
	var ny: float = -d.y / (vs.y * 0.5)
	var tx: float = clampf(nx, -1.4, 1.4) * 3.66
	var ty: float = clampf(0.12 + (ny - 0.2) * 2.6, 0.11, 3.2)
	var speed: float = d.length() / dur / vs.y
	var power: float = clampf((speed - 0.6) / 2.6, 0.15, 1.0)
	# falso: yolun düz çizgiden en büyük işaretli sapması
	var dev: float = 0.0
	var nrm: Vector2 = d.normalized().orthogonal()
	for p in pts:
		var off: float = (p - a).dot(nrm)
		if absf(off) > absf(dev):
			dev = off
	var curl: float = clampf(dev / maxf(1.0, d.length()) * 3.0, -1.0, 1.0)
	return {"valid": true, "target": Vector2(tx, ty), "power": power, "curl": curl}


static func swipe_to_dive(pts: PackedVector2Array, vs: Vector2) -> Vector2:
	var d: Vector2 = pts[pts.size() - 1] - pts[0]
	if d.length() < 30.0:
		return Vector2(0, 1.0)
	var x: float = clampf(d.x / (vs.x * 0.22), -1.0, 1.0) * 3.2
	var y: float = clampf(0.45 + (-d.y) / (vs.y * 0.35) * 1.8, 0.2, 2.4)
	return Vector2(x, y)


# ---------------- sonuç efektleri ----------------
func _on_outcome(kind: String, player_shooting: bool, zone: int) -> void:
	var text: String = ""
	var col := Color("ffd23f")
	match kind:
		"goal":
			var o: int = 4 + (3 if zone in [0, 2, 6, 8] else 0)
			text = I18n.t("goal")
			if I18n.lang == "tr" or I18n.lang == "uz":
				text = "G" + "O".repeat(o) + "L!"
			elif I18n.lang == "en":
				text = "GO" + "O".repeat(o) + "AL!"
			col = Color("ffd23f") if player_shooting else Color("ff6a6a")
			main.world.celebrate_goal(player_shooting)
			Sfx.play("net")
			Sfx.play("roar", 0.0 if player_shooting else -5.0)
			Sfx.vibrate(90)
			_slowmo(0.32, 0.9)
			_flash_screen(Color(1, 1, 1, 0.65))
		"saved":
			text = I18n.t("saved") if player_shooting else I18n.t("you_saved")
			col = Color("6fe3ff") if player_shooting else Color("49f08a")
			main.world.celebrate_save()
			Sfx.play("save")
			Sfx.play("ooh" if player_shooting else "roar", -3.0)
			Sfx.vibrate(45)
			_slowmo(0.5, 0.5)
		"post":
			text = I18n.t("post")
			col = Color("ffb04a")
			main.world.miss_reaction()
			Sfx.play("post")
			Sfx.play("ooh")
		_:
			text = I18n.t("miss")
			col = Color("ff8a8a")
			main.world.miss_reaction()
			Sfx.play("ooh")
	_show_big(text, col)


func _show_big(text: String, col: Color) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", col)
	_big.visible = true
	_big.modulate.a = 1.0
	_big.scale = Vector2(0.2, 0.2)
	_big.pivot_offset = size / 2.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_big, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(1.1)
	tw.tween_property(_big, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_hide_big)


func _hide_big() -> void:
	_big.visible = false


func _flash_screen(c: Color) -> void:
	_flash.color = c
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_flash, "color:a", 0.0, 0.45)


func _slowmo(scale_v: float, real_seconds: float) -> void:
	Engine.time_scale = scale_v
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	Engine.time_scale = 1.0


# ---------------- duraklat ----------------
func _open_pause() -> void:
	if main.has_modal():
		return
	get_tree().paused = true
	var m = main.new_modal(I18n.t("paused"), "pause")
	m.add_button(I18n.t("resume"), "primary", Callable(), "play")
	var quit := func() -> void:
		main.show_screen("menu")
	m.add_button(I18n.t("quit_match"), "red", quit, "home")
	var unpause := func() -> void:
		get_tree().paused = false
	m.closed.connect(unpause)


# ---------------- maç sonu ----------------
func _on_finished(win: bool, s: Dictionary) -> void:
	_prompt.text = ""
	Sfx.play("win" if win else "lose")
	await get_tree().create_timer(0.8).timeout
	var m = main.new_modal(I18n.t("win") if win else I18n.t("lose"), "trophy" if win else "", 720.0)
	m.dismissible = false
	if int(s["level"]) >= 0:
		var sr := UiTheme.hbox(6)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			sr.add_child(UiTheme.icon("star" if i < int(s["stars"]) else "star_empty", 64))
		m.add(sr)
	m.add(UiTheme.title("%d - %d" % [int(s["my_goals"]), int(s["ai_goals"])], 54, Color.WHITE, Color("0a1630"), 10))
	# analiz
	var ap := UiTheme.panel("panel2", 20, 14)
	var av := UiTheme.vbox(8)
	ap.add_child(av)
	var ah := UiTheme.hbox(8)
	ah.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_child(UiTheme.icon("ai", 40))
	ah.add_child(UiTheme.label(I18n.t("analysis"), 28, "text"))
	av.add_child(ah)
	var row := UiTheme.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_heatmap(s["zones"]))
	var tv := UiTheme.vbox(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiTheme.label(I18n.t("read_you", {"v": int(s["read_pct"])}), 24, "text", HORIZONTAL_ALIGNMENT_LEFT, true))
	tv.add_child(UiTheme.label(I18n.t("habit", {"v": I18n.t("zone_%d" % int(s["fav"]))}), 22, "text_dim", HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(tv)
	av.add_child(row)
	m.add(ap)
	var cr := UiTheme.hbox(8)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.add_child(UiTheme.icon("coin", 44))
	var cl := UiTheme.label(I18n.t("coins_earned", {"v": int(s["coins"])}), 30, "text")
	cr.add_child(cl)
	m.add(cr)
	var coins: int = int(s["coins"])
	var holder: Array = []
	var reward := func() -> void:
		Save.add_coins(coins)
		cl.text = I18n.t("coins_earned", {"v": coins * 2})
		Sfx.play("coin")
		if holder.size() > 0 and is_instance_valid(holder[0]):
			holder[0].disabled = true
	var dbl := func() -> void:
		if holder.size() > 0 and is_instance_valid(holder[0]):
			holder[0].disabled = true
		Ads.show_rewarded(reward)
	holder.append(m.add_button(I18n.t("double_coins"), "orange", dbl, "ad", false))
	var lvl: int = int(s["level"])
	if win and lvl >= 0 and lvl < Save.LEVELS - 1:
		var nxt := func() -> void:
			main.show_screen("match", {"level": lvl + 1, "diff": Save.difficulty, "mode": game.mode})
		m.add_button(I18n.t("next_level"), "primary", nxt, "skip")
	var again := func() -> void:
		main.show_screen("match", {"level": lvl, "diff": int(arg.get("diff", Save.difficulty)), "mode": game.mode})
	m.add_button(I18n.t("retry"), "blue", again, "retry")
	var menu := func() -> void:
		main.show_screen("levels" if lvl >= 0 else "menu")
	m.add_button(I18n.t("main_menu"), "gray", menu, "home")


func _heatmap(zones: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	var mx: int = 1
	for z in zones:
		mx = maxi(mx, int(z))
	for i in 9:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(58, 40)
		var v: float = float(zones[i]) / float(mx)
		var col: Color = Color("1d3a6e").lerp(Color("ff4a3a"), v)
		p.add_theme_stylebox_override("panel", UiTheme.box(col, 6, Color(1, 1, 1, 0.6), 2, 0, 0))
		var l := UiTheme.label(str(int(zones[i])) if int(zones[i]) > 0 else "", 20, "text")
		l.add_theme_color_override("font_color", Color.WHITE)
		p.add_child(l)
		g.add_child(p)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), 4, Color.WHITE, 5, 0, 6))
	frame.add_child(g)
	return frame
