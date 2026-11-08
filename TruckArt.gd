extends RefCounted
## Kamyonları kodla çizen ressam: oyundaki kamyon da, garajdaki ön izleme de bunu kullanır.
## Gölgeli boya (vertex renkleri), cam yansıması, krom tampon, far ışığı, çamurluk,
## alaşım jant... Hiç görsel dosya yok.

const WHEEL_X := 78.0


## Kabin şekli (çarpışma şekli olarak da kullanılır)
static func cab_polygon(kind: String) -> PackedVector2Array:
	match kind:
		"rounded":
			return PackedVector2Array([Vector2(40, -10), Vector2(40, -76), Vector2(50, -85), Vector2(80, -85), Vector2(98, -62), Vector2(114, -52), Vector2(118, -38), Vector2(118, -10)])
		"cabover":
			return PackedVector2Array([Vector2(40, -10), Vector2(40, -90), Vector2(108, -90), Vector2(117, -80), Vector2(118, -10)])
		"hood":
			return PackedVector2Array([Vector2(40, -10), Vector2(40, -92), Vector2(72, -92), Vector2(76, -58), Vector2(112, -55), Vector2(118, -46), Vector2(118, -10)])
		"offroad":
			return PackedVector2Array([Vector2(40, -10), Vector2(40, -84), Vector2(86, -84), Vector2(104, -58), Vector2(118, -54), Vector2(118, -10)])
		_:
			return PackedVector2Array([Vector2(40, -10), Vector2(40, -82), Vector2(84, -82), Vector2(100, -52), Vector2(116, -47), Vector2(118, -10)])


static func _window(kind: String) -> PackedVector2Array:
	match kind:
		"rounded":
			return PackedVector2Array([Vector2(48, -73), Vector2(56, -79), Vector2(78, -79), Vector2(93, -60), Vector2(48, -57)])
		"cabover":
			return PackedVector2Array([Vector2(50, -82), Vector2(106, -82), Vector2(110, -58), Vector2(50, -58)])
		"hood":
			return PackedVector2Array([Vector2(46, -85), Vector2(67, -85), Vector2(70, -62), Vector2(46, -62)])
		"offroad":
			return PackedVector2Array([Vector2(48, -77), Vector2(83, -77), Vector2(98, -58), Vector2(48, -58)])
		_:
			return PackedVector2Array([Vector2(48, -75), Vector2(81, -75), Vector2(95, -52), Vector2(48, -52)])


static func _roof_y(kind: String) -> float:
	var y: float = 0.0
	for p in cab_polygon(kind):
		y = minf(y, p.y)
	return y


## Gövde boyası. parent: gövde düğümü (RigidBody2D ya da ön izleme Node2D'si)
static func paint_body(parent: Node2D, d: Dictionary, wheel_r: float, wheel_y: float) -> void:
	var body_c: Color = d["body"]
	var acc: Color = d["accent"]
	var bed_c: Color = d["bed"]
	var kind: String = d["cab"]
	var extras: Array = d["extras"]
	var chrome_top := Color(0.97, 0.98, 1.0)
	var chrome_bot := Color(0.55, 0.58, 0.64)
	var dark := Color(0.12, 0.13, 0.15)
	var roof: float = _roof_y(kind)
	var fx: float = 118.0

	# egzoz bacaları (kabinin arkasında)
	if extras.has("stack") or extras.has("stacks2"):
		_grad_x(parent, _rect(33, roof - 20, 39, -10), chrome_bot, chrome_top)
		_poly(parent, _rect(32, roof - 24, 40, roof - 20), dark)
	if extras.has("stacks2"):
		_grad_x(parent, _rect(26, roof - 14, 31, -64), chrome_bot, chrome_top)
		_poly(parent, _rect(25, roof - 18, 32, roof - 14), dark)

	# şasi + yakıt deposu
	_grad(parent, _rect(-116, -10, 114, 9), Color(0.25, 0.27, 0.31), Color(0.1, 0.11, 0.13))
	_grad(parent, _round_rect(-34, -2, 22, 15, 6), chrome_top, chrome_bot)
	_line(parent, [Vector2(-30, 6), Vector2(18, 6)], 1.5, Color(0.5, 0.52, 0.58, 0.8))
	# basamak
	_poly(parent, _rect(44, 4, 66, 9), Color(0.6, 0.62, 0.66))

	# kasa (üstü açık U) - üstte açık, altta koyu gölgeli boya
	var bed := PackedVector2Array([Vector2(-118, -64), Vector2(-108, -64), Vector2(-108, -20), Vector2(24, -20), Vector2(24, -64), Vector2(34, -64), Vector2(34, -10), Vector2(-118, -10)])
	_grad(parent, bed, bed_c.lightened(0.18), bed_c.darkened(0.25))
	_line(parent, Array(bed) + [bed[0]], 2.0, bed_c.darkened(0.55))
	for yy in [-52.0, -40.0, -28.0]:
		_line(parent, [Vector2(-116, yy), Vector2(-110, yy)], 2.0, bed_c.darkened(0.35))
		_line(parent, [Vector2(26, yy), Vector2(32, yy)], 2.0, bed_c.darkened(0.35))
	_line(parent, [Vector2(-118, -65), Vector2(-108, -65)], 3.0, Color(0.85, 0.87, 0.9))
	_line(parent, [Vector2(24, -65), Vector2(34, -65)], 3.0, Color(0.85, 0.87, 0.9))
	_line(parent, [Vector2(-106, -17), Vector2(22, -17)], 2.0, bed_c.darkened(0.4))
	# kasa yan bandı (reflektör)
	_poly(parent, _rect(-104, -15, -70, -12), Color(0.95, 0.75, 0.15))
	_poly(parent, _rect(-62, -15, -28, -12), Color(0.95, 0.95, 0.95))

	# kabin
	var cab: PackedVector2Array = cab_polygon(kind)
	_grad(parent, cab, body_c.lightened(0.28), body_c.darkened(0.3))
	if extras.has("stripe"):
		_poly(parent, _rect(41, -36, 116, -29), acc)
		_poly(parent, _rect(41, -27, 116, -25), acc.lightened(0.2))
	if kind == "hood":
		# uzun motor kaputu çizgisi + krom ızgara
		_line(parent, [Vector2(78, -56), Vector2(114, -53)], 2.0, body_c.lightened(0.45))
		_grad(parent, _rect(112, -52, 119, -12), chrome_top, chrome_bot)
		for gy in range(6):
			_line(parent, [Vector2(113, -48.0 + gy * 6.0), Vector2(118, -48.0 + gy * 6.0)], 1.5, Color(0.3, 0.32, 0.36))
	_line(parent, Array(cab) + [cab[0]], 2.5, body_c.darkened(0.6))

	# cam + yansıma + çerçeve
	var win: PackedVector2Array = _window(kind)
	_grad(parent, win, Color(0.78, 0.92, 1.0), Color(0.3, 0.5, 0.68))
	var wmin := Vector2(9999, 9999)
	var wmax := Vector2(-9999, -9999)
	for p in win:
		wmin = wmin.min(p)
		wmax = wmax.max(p)
	_poly(parent, PackedVector2Array([Vector2(wmin.x + 8, wmax.y), Vector2(wmin.x + 18, wmax.y), Vector2(wmin.x + 30, wmin.y), Vector2(wmin.x + 20, wmin.y)]), Color(1, 1, 1, 0.32))
	_poly(parent, PackedVector2Array([Vector2(wmin.x + 23, wmax.y), Vector2(wmin.x + 27, wmax.y), Vector2(wmin.x + 39, wmin.y), Vector2(wmin.x + 35, wmin.y)]), Color(1, 1, 1, 0.22))
	_line(parent, Array(win) + [win[0]], 3.0, body_c.darkened(0.65))
	# sürücü silueti
	_poly(parent, _circle_at(Vector2(wmin.x + 14, wmax.y - 9), 6.0, 12), Color(0.12, 0.14, 0.2, 0.55))
	if extras.has("visor"):
		_poly(parent, PackedVector2Array([Vector2(wmin.x - 2, wmin.y - 5), Vector2(wmax.x + 6, wmin.y - 5), Vector2(wmax.x + 2, wmin.y + 2), Vector2(wmin.x - 2, wmin.y + 2)]), acc)

	# kapı çizgisi, kolu, ayna
	_line(parent, [Vector2(44, wmin.y - 2), Vector2(44, -12)], 2.0, body_c.darkened(0.5))
	_line(parent, [Vector2(wmax.x - 6, wmax.y + 2), Vector2(wmax.x - 6, -12)], 2.0, body_c.darkened(0.5))
	_grad(parent, _round_rect(50, -47, 60, -43, 2), chrome_top, chrome_bot)
	var mx: float = wmax.x + 2.0
	_line(parent, [Vector2(mx - 4, wmax.y - 4), Vector2(mx + 6, wmax.y - 14)], 2.0, dark)
	_poly(parent, _round_rect(mx + 3, wmax.y - 26, mx + 9, wmax.y - 12, 2), dark)

	# far + far ışığı + ızgara + tampon
	var beam := _poly(parent, PackedVector2Array([Vector2(fx, -34), Vector2(fx + 90, -54), Vector2(fx + 90, -2), Vector2(fx, -24)]), Color.WHITE)
	beam.name = "Far"
	beam.vertex_colors = PackedColorArray([Color(1, 0.96, 0.75, 0.42), Color(1, 0.96, 0.75, 0.0), Color(1, 0.96, 0.75, 0.0), Color(1, 0.96, 0.75, 0.42)])
	_poly(parent, _round_rect(fx - 7, -35, fx + 1, -24, 2), Color(1.0, 0.97, 0.78))
	_poly(parent, _round_rect(fx - 6, -21, fx + 1, -17, 1), Color(1.0, 0.65, 0.1))   # sinyal
	if kind != "hood":
		_poly(parent, _rect(fx - 9, -16, fx, -10), dark)
		_line(parent, [Vector2(fx - 8, -13), Vector2(fx - 1, -13)], 1.5, chrome_bot)
	_grad(parent, _round_rect(fx - 6, -11, fx + 6, -1, 3), chrome_top, chrome_bot)
	# arka: stop lambası + tampon
	_poly(parent, _round_rect(-122, -30, -116, -16, 2), Color(0.9, 0.08, 0.08))
	_poly(parent, _circle_at(Vector2(-123, -23), 9.0, 12), Color(1, 0.1, 0.1, 0.18))
	_grad(parent, _round_rect(-124, -10, -112, 0, 2), Color(0.3, 0.32, 0.36), Color(0.08, 0.09, 0.1))

	# tavan aksesuarları
	if kind == "classic" or kind == "cabover":
		for i in range(3):
			_poly(parent, _round_rect(52.0 + i * 12.0, roof - 4, 58.0 + i * 12.0, roof, 1), Color(1.0, 0.68, 0.12))
	if extras.has("spoiler"):
		_grad(parent, PackedVector2Array([Vector2(40, roof), Vector2(40, roof - 16), Vector2(66, roof - 10), Vector2(80, roof)]), body_c.lightened(0.2), body_c.darkened(0.2))
	if extras.has("lightbar"):
		_poly(parent, _rect(46, roof - 9, 84, roof - 4), dark)
		for i in range(4):
			_poly(parent, _round_rect(48.0 + i * 9.0, roof - 9, 55.0 + i * 9.0, roof - 4, 1), Color(1.0, 0.92, 0.45))
		_line(parent, [Vector2(48, roof - 4), Vector2(48, roof)], 2.0, dark)
		_line(parent, [Vector2(82, roof - 4), Vector2(82, roof)], 2.0, dark)
	if extras.has("bullbar"):
		_line(parent, [Vector2(fx - 2, -56), Vector2(fx + 10, -46), Vector2(fx + 10, -6), Vector2(fx + 2, 0)], 4.0, Color(0.22, 0.23, 0.26))
		_line(parent, [Vector2(fx + 1, -40), Vector2(fx + 10, -40)], 3.0, Color(0.22, 0.23, 0.26))
		_line(parent, [Vector2(fx + 1, -24), Vector2(fx + 10, -24)], 3.0, Color(0.22, 0.23, 0.26))
	if extras.has("snorkel"):
		_line(parent, [Vector2(fx - 12, -30), Vector2(fx - 16, roof + 4), Vector2(fx - 18, roof - 10), Vector2(fx - 8, roof - 12)], 5.0, Color(0.15, 0.16, 0.14))

	# çamurlukla birlikte tekerlek kemeri (lastiğin üstünü örter)
	for side in [-1.0, 1.0]:
		var c := Vector2(WHEEL_X * side, wheel_y)
		var arch := PackedVector2Array()
		var n: int = 14
		for i in range(n + 1):
			var a: float = PI + PI * float(i) / float(n)
			arch.append(c + Vector2(cos(a), sin(a)) * (wheel_r + 9.0))
		for i in range(n, -1, -1):
			var a2: float = PI + PI * float(i) / float(n)
			arch.append(c + Vector2(cos(a2), sin(a2)) * (wheel_r + 3.0))
		var fender := _poly(parent, arch, (body_c if side > 0.0 else bed_c).darkened(0.35))
		fender.z_index = 3
	# çamurluk lastiği (arka)
	var flap := _poly(parent, _round_rect(-WHEEL_X - wheel_r - 12.0, wheel_y - 6.0, -WHEEL_X - wheel_r - 3.0, wheel_y + wheel_r * 0.45, 2.0), Color(0.08, 0.08, 0.09))
	flap.z_index = 3


## Tekerlek boyası: dişli lastik, yanak, alaşım jant (delikler dönüşü gösterir), krom göbek
static func paint_wheel(parent: Node2D, d: Dictionary, r: float) -> void:
	var off: bool = d["tread"] == "offroad"
	var rim_c: Color = d["rim"]
	var n: int = 22 if off else 34
	var depth: float = 5.0 if off else 2.2
	var tire := PackedVector2Array()
	for i in range(n * 2):
		var a: float = TAU * float(i) / float(n * 2)
		var rr: float = r if (i % 4) < 2 else r - depth
		tire.append(Vector2(cos(a), sin(a)) * rr)
	_poly(parent, tire, Color(0.1, 0.1, 0.11))
	_poly(parent, _circle_at(Vector2.ZERO, r - depth - 1.5, 30), Color(0.17, 0.17, 0.19))
	_poly(parent, _circle_at(Vector2.ZERO, r * 0.64, 28), rim_c.darkened(0.35))
	var disc := _poly(parent, _circle_at(Vector2.ZERO, r * 0.58, 28), rim_c)
	# üst-sol aydınlık, alt-sağ gölge
	var vc := PackedColorArray()
	for p in disc.polygon:
		var k: float = clampf(0.5 - (p.x + p.y) / (r * 1.6), 0.0, 1.0)
		vc.append(Color(1, 1, 1).lerp(Color(0.62, 0.62, 0.66), 1.0 - k))
	disc.vertex_colors = vc
	for i in range(6):
		var a2: float = TAU * float(i) / 6.0
		_poly(parent, _circle_at(Vector2(cos(a2), sin(a2)) * r * 0.36, r * 0.11, 10), rim_c.darkened(0.6))
	_poly(parent, _circle_at(Vector2.ZERO, r * 0.2, 16), Color(0.92, 0.93, 0.96))
	for i in range(5):
		var a3: float = TAU * float(i) / 5.0 + 0.3
		_poly(parent, _circle_at(Vector2(cos(a3), sin(a3)) * r * 0.12, 1.6, 6), Color(0.35, 0.36, 0.4))
	_poly(parent, PackedVector2Array([Vector2(-r * 0.5, -r * 0.18), Vector2(-r * 0.18, -r * 0.5), Vector2(-r * 0.1, -r * 0.42), Vector2(-r * 0.42, -r * 0.1)]), Color(1, 1, 1, 0.25))


## Garaj ön izlemesi: fiziksiz, sadece görüntü
static func build_preview(parent: Node2D, d: Dictionary) -> void:
	var r: float = d["wheel_r"]
	var wy: float = 30.0 + (r - 26.0)
	var b := Node2D.new()
	parent.add_child(b)
	paint_body(b, d, r, wy)
	# vitrindeki kamyon dolu görünsün: kasaya sandıklar
	var slots: Array = [Vector2(-86, -34), Vector2(-42, -34), Vector2(2, -34), Vector2(-64, -62), Vector2(-20, -62)]
	var cols: Array = [Color(0.72, 0.5, 0.26), Color(0.62, 0.42, 0.22), Color(0.8, 0.58, 0.3), Color(0.55, 0.62, 0.3), Color(0.35, 0.5, 0.72)]
	for i in range(slots.size()):
		var c: Vector2 = slots[i]
		var col: Color = cols[i]
		var box := _poly(parent, _rect(c.x - 15, c.y - 13, c.x + 15, c.y + 13), col)
		box.z_index = 1
		var fr := Line2D.new()
		fr.points = PackedVector2Array([Vector2(c.x - 15, c.y - 13), Vector2(c.x + 15, c.y - 13), Vector2(c.x + 15, c.y + 13), Vector2(c.x - 15, c.y + 13), Vector2(c.x - 15, c.y - 13), Vector2(c.x + 15, c.y + 13)])
		fr.width = 2.5
		fr.default_color = col.darkened(0.45)
		fr.z_index = 1
		parent.add_child(fr)
	for side in [-1.0, 1.0]:
		var w := Node2D.new()
		w.position = Vector2(WHEEL_X * side, wy)
		w.z_index = 2
		w.rotation = 0.4 * side
		parent.add_child(w)
		paint_wheel(w, d, r)


# ---------------- yardımcılar ----------------
static func _poly(parent: Node, pts: PackedVector2Array, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	parent.add_child(p)
	return p


## Dikey degrade (üst -> alt)
static func _grad(parent: Node, pts: PackedVector2Array, top: Color, bottom: Color) -> Polygon2D:
	var p := _poly(parent, pts, Color.WHITE)
	var y0: float = 1e9
	var y1: float = -1e9
	for v in pts:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var vc := PackedColorArray()
	for v in pts:
		vc.append(top.lerp(bottom, (v.y - y0) / maxf(y1 - y0, 0.001)))
	p.vertex_colors = vc
	return p


## Yatay degrade (sol -> sağ), krom borular için
static func _grad_x(parent: Node, pts: PackedVector2Array, left: Color, right: Color) -> Polygon2D:
	var p := _poly(parent, pts, Color.WHITE)
	var x0: float = 1e9
	var x1: float = -1e9
	for v in pts:
		x0 = minf(x0, v.x)
		x1 = maxf(x1, v.x)
	var vc := PackedColorArray()
	for v in pts:
		var t: float = (v.x - x0) / maxf(x1 - x0, 0.001)
		vc.append(left.lerp(right, 1.0 - absf(t - 0.4) * 1.6))
	p.vertex_colors = vc
	return p


static func _line(parent: Node, pts: Array, width: float, col: Color) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array(pts)
	l.width = width
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(l)


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _round_rect(x0: float, y0: float, x1: float, y1: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners: Array = [Vector2(x1 - r, y0 + r), Vector2(x1 - r, y1 - r), Vector2(x0 + r, y1 - r), Vector2(x0 + r, y0 + r)]
	var start: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for i in range(4):
		for k in range(4):
			var a: float = start[i] + PI * 0.5 * float(k) / 3.0
			var c: Vector2 = corners[i]
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _circle_at(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
