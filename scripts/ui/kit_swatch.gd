extends Button
## Forma rengi/desen örneği (tişört silueti, yazısız).

var kit_id: String = "red_yellow"
var selected: bool = false


func _init(id: String = "red_yellow") -> void:
	kit_id = id
	custom_minimum_size = Vector2(150, 150)
	focus_mode = Control.FOCUS_NONE
	flat = true


func _draw() -> void:
	var k: Dictionary = Kits.get_kit(kit_id)
	var r := Rect2(Vector2.ZERO, size)
	var bg: Color = UiTheme.c("panel2") if not selected else UiTheme.c("primary")
	draw_style_box(UiTheme.box(bg, 22, UiTheme.c("gold") if selected else UiTheme.c("border"), 5 if selected else 2, 0, 0), r)
	var w: float = minf(size.x, size.y) * 0.72
	var o := Vector2((size.x - w) / 2.0, (size.y - w) / 2.0 + w * 0.04)
	var pts := PackedVector2Array([
		o + Vector2(0.30, 0.0) * w, o + Vector2(0.70, 0.0) * w, o + Vector2(1.0, 0.2) * w, o + Vector2(0.88, 0.42) * w,
		o + Vector2(0.78, 0.36) * w, o + Vector2(0.78, 1.0) * w, o + Vector2(0.22, 1.0) * w, o + Vector2(0.22, 0.36) * w,
		o + Vector2(0.12, 0.42) * w, o + Vector2(0.0, 0.2) * w])
	var ca: Color = k["a"]
	var cb: Color = k["b"]
	draw_colored_polygon(pts, ca)
	if int(k["pattern"]) == 0:
		var half := PackedVector2Array([o + Vector2(0.5, 0.0) * w, o + Vector2(0.70, 0.0) * w, o + Vector2(1.0, 0.2) * w, o + Vector2(0.88, 0.42) * w,
			o + Vector2(0.78, 0.36) * w, o + Vector2(0.78, 1.0) * w, o + Vector2(0.5, 1.0) * w])
		draw_colored_polygon(half, cb)
	else:
		var n: int = 5
		for i in n:
			if i % 2 == 1:
				var x0: float = 0.22 + (0.56 / n) * i
				var x1: float = x0 + 0.56 / n
				draw_rect(Rect2(o + Vector2(x0, 0.06) * w, Vector2((x1 - x0) * w, 0.94 * w)), cb)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.35), 3.0, true)
	draw_arc(o + Vector2(0.5, 0.0) * w, w * 0.11, 0.0, PI, 12, k["trim"], 4.0, true)
