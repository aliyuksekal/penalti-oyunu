extends Control
## Ekranı karartan, ortada panel gösteren açılır pencere.
## Android geri tuşu ve karartılmış alana dokunma ile kapanabilir (dismissible ise).

signal closed

var dismissible: bool = true
var content: VBoxContainer
var panel: PanelContainer
var _on_close: Callable = Callable()
var _closing: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(title_text: String = "", icon_name: String = "", max_width: float = 620.0) -> void:
	var dim := ColorRect.new()
	dim.color = UiTheme.c("overlay")
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = UiTheme.panel("panel", 32, 26)
	panel.custom_minimum_size = Vector2(minf(max_width, _avail_width()), 0)
	center.add_child(panel)
	content = UiTheme.vbox(16)
	panel.add_child(content)
	if icon_name != "":
		var ic := UiTheme.icon(icon_name, 110.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(ic)
	if title_text != "":
		var t := UiTheme.label(title_text, 38, "text", HORIZONTAL_ALIGNMENT_CENTER, true)
		content.add_child(t)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)


func _avail_width() -> float:
	var vs: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
	return vs.x - 40.0


func add(c: Control) -> Control:
	content.add_child(c)
	return c


func add_text(text: String, size: int = 26, color_key: String = "text_dim") -> Label:
	var l := UiTheme.label(text, size, color_key, HORIZONTAL_ALIGNMENT_CENTER, true)
	content.add_child(l)
	return l


func add_button(text: String, variant: String, cb: Callable, icon_name: String = "", close_after: bool = true) -> Button:
	var b := UiTheme.button(text, variant, icon_name)
	b.pressed.connect(_on_button.bind(cb, close_after))
	content.add_child(b)
	return b


func _on_button(cb: Callable, close_after: bool) -> void:
	if cb.is_valid():
		cb.call()
	if close_after:
		close()


func on_close(cb: Callable) -> void:
	_on_close = cb


func _on_dim_input(ev: InputEvent) -> void:
	if not dismissible:
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	if _on_close.is_valid():
		_on_close.call()
	closed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
