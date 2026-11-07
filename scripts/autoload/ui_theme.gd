extends Node
## Açık/koyu tema. Tüm arayüz Godot Theme ile çizilir; metinler görsellere gömülmez.

signal theme_changed

var dark: bool = false
var theme: Theme
var p: Dictionary = {}  # aktif palet

const LIGHT := {
	"bg": Color("eef3fb"), "panel": Color("ffffff"), "panel2": Color("e3ecfa"), "border": Color("c7d6ef"),
	"text": Color("0f1b33"), "text_dim": Color("51617f"), "overlay": Color(0.02, 0.05, 0.12, 0.6),
	"primary": Color("1fb55a"), "primary_dark": Color("148a42"),
	"blue": Color("2a7cf0"), "blue_dark": Color("1a56b0"),
	"orange": Color("ff9a1f"), "orange_dark": Color("c96a00"),
	"purple": Color("7a4dff"), "purple_dark": Color("5530c4"),
	"red": Color("e8364a"), "red_dark": Color("a81e2f"),
	"gray": Color("8f9bb3"), "gray_dark": Color("66718a"),
	"gold": Color("ffc21a"), "gold_dark": Color("c98f00"),
	"good": Color("1fb55a"), "bad": Color("e8364a"),
	"bar_bg": Color("dbe4f3"),
}
const DARK := {
	"bg": Color("070d1c"), "panel": Color("111b33"), "panel2": Color("1a2747"), "border": Color("2b3b63"),
	"text": Color("eef3ff"), "text_dim": Color("9fb0d6"), "overlay": Color(0, 0, 0, 0.66),
	"primary": Color("19a14f"), "primary_dark": Color("0f7336"),
	"blue": Color("2468d4"), "blue_dark": Color("164594"),
	"orange": Color("e3861a"), "orange_dark": Color("a35c00"),
	"purple": Color("6b40e6"), "purple_dark": Color("4a26ab"),
	"red": Color("d22f42"), "red_dark": Color("8f1824"),
	"gray": Color("4a5878"), "gray_dark": Color("343f59"),
	"gold": Color("f2b20f"), "gold_dark": Color("b07f00"),
	"good": Color("35d070"), "bad": Color("ff5566"),
	"bar_bg": Color("24304f"),
}


func _ready() -> void:
	Settings.changed.connect(_on_setting)
	refresh()


func _on_setting(key: String) -> void:
	if key == "theme" or key == "all":
		refresh()


func resolve_dark() -> bool:
	var mode: String = str(Settings.get_value("theme"))
	if mode == "dark":
		return true
	if mode == "light":
		return false
	if DisplayServer.is_dark_mode_supported():
		return DisplayServer.is_dark_mode()
	return false


func refresh() -> void:
	dark = resolve_dark()
	p = DARK if dark else LIGHT
	theme = _build()
	RenderingServer.set_default_clear_color(p["bg"])
	theme_changed.emit()


func c(key: String) -> Color:
	return p.get(key, Color.MAGENTA)


func box(bg: Color, radius: int = 22, border: Color = Color(0, 0, 0, 0), bw: int = 0, shadow: int = 0, margin: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = border
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.28 if dark else 0.16)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	sb.anti_aliasing = true
	return sb


func _build() -> Theme:
	var t := Theme.new()
	t.default_font = Assets.font
	t.default_font_size = 26
	t.set_color("font_color", "Label", c("text"))
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	# Varsayılan düğme (mavi)
	_style_button(t, "Button", c("blue"), c("blue_dark"))
	t.set_font_size("font_size", "Button", 28)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 44)
	# Paneller
	t.set_stylebox("panel", "PanelContainer", box(c("panel"), 26, c("border"), 2, 10, 18))
	t.set_stylebox("panel", "Panel", box(c("panel"), 26, c("border"), 2, 10, 18))
	# İlerleme çubuğu
	var bg := box(c("bar_bg"), 14, Color(0, 0, 0, 0), 0, 0, 0)
	var fill := box(c("good"), 14, Color(0, 0, 0, 0), 0, 0, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", 18)
	# CheckButton
	t.set_color("font_color", "CheckButton", c("text"))
	t.set_color("font_hover_color", "CheckButton", c("text"))
	t.set_color("font_pressed_color", "CheckButton", c("text"))
	t.set_color("font_focus_color", "CheckButton", c("text"))
	t.set_color("font_hover_pressed_color", "CheckButton", c("text"))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", empty)
	t.set_font_size("font_size", "CheckButton", 26)
	# Kaydırma
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


func _style_button(t: Theme, type: String, base: Color, darker: Color) -> void:
	t.set_stylebox("normal", type, _btn_box(base, darker))
	t.set_stylebox("hover", type, _btn_box(base.lightened(0.06), darker))
	t.set_stylebox("pressed", type, _btn_box(darker, darker.darkened(0.2), true))
	t.set_stylebox("disabled", type, _btn_box(c("gray"), c("gray_dark")))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(st, type, Color.WHITE)
	t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.75))
	t.set_color("font_outline_color", type, darker.darkened(0.35))
	t.set_constant("outline_size", type, 4)


func _btn_box(base: Color, darker: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(22)
	sb.border_width_bottom = 2 if pressed else 7
	sb.border_color = darker
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 0 if pressed else 4
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14 if not pressed else 19
	sb.content_margin_bottom = 14
	sb.anti_aliasing = true
	return sb


func color_button(b: Button, variant: String) -> void:
	## variant: primary, blue, orange, purple, red, gray
	var base: Color = c(variant)
	var darker: Color = c(variant + "_dark")
	b.add_theme_stylebox_override("normal", _btn_box(base, darker))
	b.add_theme_stylebox_override("hover", _btn_box(base.lightened(0.06), darker))
	b.add_theme_stylebox_override("pressed", _btn_box(darker, darker.darkened(0.2), true))
	b.add_theme_color_override("font_outline_color", darker.darkened(0.25))


# ---------------- widget yardımcıları ----------------
func label(text: String, size: int = 26, color_key: String = "text", align: int = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c(color_key))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func title(text: String, size: int = 64, color: Color = Color.WHITE, outline: Color = Color("7a1d4f"), outline_size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func button(text: String, variant: String = "blue", icon_name: String = "", min_h: int = 92, font_size: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	if variant != "blue":
		color_button(b, variant)
	if icon_name != "" and Assets.ui.has(icon_name):
		b.icon = Assets.ui[icon_name]
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(min_h * 0.55))
	b.pressed.connect(_btn_feedback)
	return b


func _btn_feedback() -> void:
	Sfx.play("button")
	Sfx.vibrate(12)


func icon(name: String, size: float = 48.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Assets.ui.get(name, null)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func panel(bg_key: String = "panel", radius: int = 26, margin: int = 18) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(c(bg_key), radius, c("border"), 2, 10, margin))
	return pc


func vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep: int = 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func spacer(h: float = 10.0, expand: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	if expand:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func hspacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func bar(color_key: String = "good", height: float = 26.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0
	pb.max_value = 100
	pb.custom_minimum_size = Vector2(80, height)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("fill", box(c(color_key), int(height / 2), Color(0, 0, 0, 0), 0, 0, 0))
	pb.add_theme_stylebox_override("background", box(c("bar_bg"), int(height / 2), Color(0, 0, 0, 0), 0, 0, 0))
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


func set_bar_color(pb: ProgressBar, col: Color) -> void:
	var sb: StyleBoxFlat = pb.get_theme_stylebox("fill") as StyleBoxFlat
	if sb != null:
		sb.bg_color = col
