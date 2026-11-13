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
	if String(d.get("kind", "truck")) == "bus":
		paint_bus(parent, d, wheel_r, wheel_y)
		return
	var tir: bool = String(d.get("kind", "truck")) == "tir"
	var ext: float = 0.0 if tir else float(d.get("ext", 0.0))
	var rx: float = -118.0 - ext            # arka uç
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
	if tir:
		rx = -96.0
	_grad(parent, _rect(rx + 2.0, -10, 114, 9), Color(0.25, 0.27, 0.31), Color(0.1, 0.11, 0.13))
	_grad(parent, _round_rect(-34, -2, 22, 15, 6), chrome_top, chrome_bot)
	_line(parent, [Vector2(-30, 6), Vector2(18, 6)], 1.5, Color(0.5, 0.52, 0.58, 0.8))
	# basamak
	_poly(parent, _rect(44, 4, 66, 9), Color(0.6, 0.62, 0.66))

	if tir:
		# beşinci teker (dorse bağlantı tablası)
		_grad(parent, _round_rect(-54, -18, 6, -10, 3), Color(0.35, 0.36, 0.4), Color(0.12, 0.12, 0.14))
		_poly(parent, _circle_at(Vector2(-24, -16), 5.0, 10), Color(0.75, 0.76, 0.8))
	else:
		# kasa (üstü açık U) - üstte açık, altta koyu gölgeli boya
		var bl: float = -108.0 - ext
		var bed := PackedVector2Array([Vector2(rx, -64), Vector2(bl, -64), Vector2(bl, -20), Vector2(24, -20), Vector2(24, -64), Vector2(34, -64), Vector2(34, -10), Vector2(rx, -10)])
		_grad(parent, bed, bed_c.lightened(0.18), bed_c.darkened(0.25))
		_line(parent, Array(bed) + [bed[0]], 2.0, bed_c.darkened(0.55))
		for yy in [-52.0, -40.0, -28.0]:
			_line(parent, [Vector2(rx + 2.0, yy), Vector2(rx + 8.0, yy)], 2.0, bed_c.darkened(0.35))
			_line(parent, [Vector2(26, yy), Vector2(32, yy)], 2.0, bed_c.darkened(0.35))
		_line(parent, [Vector2(rx, -65), Vector2(bl, -65)], 3.0, Color(0.85, 0.87, 0.9))
		_line(parent, [Vector2(24, -65), Vector2(34, -65)], 3.0, Color(0.85, 0.87, 0.9))
		_line(parent, [Vector2(bl + 2.0, -17), Vector2(22, -17)], 2.0, bed_c.darkened(0.4))
		# kasa yan bandı (reflektör): uzun kasada daha çok
		var rxs: float = bl + 4.0
		var k: int = 0
		while rxs + 34.0 < 16.0:
			_poly(parent, _rect(rxs, -15, rxs + 34.0, -12), Color(0.95, 0.75, 0.15) if k % 2 == 0 else Color(0.95, 0.95, 0.95))
			rxs += 42.0
			k += 1

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
	_poly(parent, _round_rect(rx - 4.0, -30, rx + 2.0, -16, 2), Color(0.9, 0.08, 0.08))
	_poly(parent, _circle_at(Vector2(rx - 5.0, -23), 9.0, 12), Color(1, 0.1, 0.1, 0.18))
	_grad(parent, _round_rect(rx - 6.0, -10, rx + 6.0, 0, 2), Color(0.3, 0.32, 0.36), Color(0.08, 0.09, 0.1))

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
	var axles: Array = _axles(d)
	for i in range(axles.size()):
		_fender(parent, Vector2(float(axles[i]), wheel_y), wheel_r, (body_c if i == axles.size() - 1 else bed_c).darkened(0.35))
	# çamurluk lastiği (en arka teker)
	var ra: float = float(axles[0])
	var flap := _poly(parent, _round_rect(ra - wheel_r - 12.0, wheel_y - 6.0, ra - wheel_r - 3.0, wheel_y + wheel_r * 0.45, 2.0), Color(0.08, 0.08, 0.09))
	flap.z_index = 3


static func _axles(d: Dictionary) -> Array:
	var a: Array = (d.get("axles", [-WHEEL_X, WHEEL_X]) as Array).duplicate()
	a.sort()
	return a


static func _fender(parent: Node2D, c: Vector2, wheel_r: float, col: Color) -> void:
	var arch := PackedVector2Array()
	var n: int = 14
	for i in range(n + 1):
		var a: float = PI + PI * float(i) / float(n)
		arch.append(c + Vector2(cos(a), sin(a)) * (wheel_r + 9.0))
	for i in range(n, -1, -1):
		var a2: float = PI + PI * float(i) / float(n)
		arch.append(c + Vector2(cos(a2), sin(a2)) * (wheel_r + 3.0))
	var fender := _poly(parent, arch, col)
	fender.z_index = 3


## Tır dorsesi (dorse yerel koordinatı: 0,0 = beşinci teker pimi)
static func paint_trailer(parent: Node2D, d: Dictionary, L: float, wheel_r: float, wy: float) -> void:
	var bed_c: Color = d["bed"]
	var acc: Color = d["accent"]
	var dark := Color(0.12, 0.13, 0.15)
	# şasi kirişi + döşeme
	_grad(parent, _rect(-L, -14, 28, 6), bed_c.lightened(0.15), bed_c.darkened(0.35))
	_line(parent, [Vector2(-L, -14), Vector2(28, -14)], 2.0, bed_c.lightened(0.4))
	_grad(parent, _rect(-L + 20.0, 6, 0, 12), Color(0.22, 0.23, 0.26), Color(0.08, 0.09, 0.1))
	# önde yüksek alın (headboard) + arkada kapak
	_grad(parent, _rect(16, -96, 28, -14), acc.lightened(0.15), acc.darkened(0.3))
	for yy in [-80.0, -62.0, -44.0, -28.0]:
		_line(parent, [Vector2(17, yy), Vector2(27, yy)], 2.0, acc.darkened(0.5))
	_grad(parent, _rect(-L, -44, -L + 10.0, -14), bed_c.lightened(0.1), bed_c.darkened(0.3))
	# yan dikmeler (yük bağlama direkleri)
	var x: float = -L + 52.0
	while x < 0.0:
		_line(parent, [Vector2(x, -14), Vector2(x, -40)], 3.0, bed_c.darkened(0.45))
		x += 64.0
	# reflektör bandı
	var rx: float = -L + 14.0
	var k: int = 0
	while rx + 30.0 < 10.0:
		_poly(parent, _rect(rx, -4, rx + 30.0, -1), Color(0.95, 0.75, 0.15) if k % 2 == 0 else Color(0.95, 0.95, 0.95))
		rx += 40.0
		k += 1
	# park ayakları
	_poly(parent, _rect(-70, 6, -64, wy - 6.0), Color(0.3, 0.31, 0.35))
	_poly(parent, _rect(-74, wy - 8.0, -60, wy - 4.0), dark)
	# stop lambası + tampon
	_poly(parent, _round_rect(-L - 4.0, -12, -L + 2.0, 2, 2), Color(0.9, 0.08, 0.08))
	_grad(parent, _round_rect(-L + 4.0, 12, -L + 26.0, 18, 2), Color(0.3, 0.32, 0.36), Color(0.08, 0.09, 0.1))
	# dorse çamurlukları
	var ta: Array = [-L + 66.0, -L + 128.0]
	for tx in ta:
		_fender(parent, Vector2(float(tx), wy), wheel_r, bed_c.darkened(0.4))


## Üstü açık turizm otobüsü: alt kat kapalı gövde, üst kat açık güverte (yolcular ayakta)
const BUS_DECK := -96.0      # üst kat zemini (gövdeye göre y)
const BUS_RAIL := -128.0     # ön/arka korkuluk üstü


static func bus_rear(ext: float) -> float:
	return -150.0 - ext


## Alt kat gövdesi çarpışma şekli (üst kat zemini dahil)
static func bus_polygon(ext: float) -> PackedVector2Array:
	var r: float = bus_rear(ext)
	return PackedVector2Array([Vector2(r, BUS_DECK), Vector2(108, BUS_DECK), Vector2(122, -70), Vector2(124, 14), Vector2(r, 14)])


## Ön ve arka korkuluk (yolcuyu tutan duvarlar)
static func bus_rails(ext: float) -> Array:
	var r: float = bus_rear(ext)
	return [
		PackedVector2Array([Vector2(r, BUS_RAIL + 6.0), Vector2(r + 8.0, BUS_RAIL + 6.0), Vector2(r + 8.0, BUS_DECK), Vector2(r, BUS_DECK)]),
		PackedVector2Array([Vector2(96, BUS_RAIL - 4.0), Vector2(110, BUS_RAIL), Vector2(110, BUS_DECK), Vector2(96, BUS_DECK)]),
	]


## Koltuk (ayakta yolcu) sayısı: güverte uzunluğuna göre
static func bus_seats(d: Dictionary) -> int:
	var w: float = 96.0 - (bus_rear(float(d.get("ext", 0.0))) + 8.0)
	return clampi(int(floor(w / 22.0)), 4, 20)


static func paint_bus(parent: Node2D, d: Dictionary, wheel_r: float, wheel_y: float) -> void:
	var body_c: Color = d["body"]
	var acc: Color = d["accent"]
	var ext: float = float(d.get("ext", 0.0))
	var r: float = bus_rear(ext)
	var chrome_top := Color(0.97, 0.98, 1.0)
	var chrome_bot := Color(0.55, 0.58, 0.64)
	var poly: PackedVector2Array = bus_polygon(ext)
	_grad(parent, poly, body_c.lightened(0.3), body_c.darkened(0.25))
	_line(parent, Array(poly) + [poly[0]], 2.5, body_c.darkened(0.6))
	# alt etek + renkli şerit
	_grad(parent, _rect(r, -20, 124, 14), acc.lightened(0.1), acc.darkened(0.35))
	_poly(parent, _rect(r, -36, 118, -30), acc)
	# alt kat camları (koyu)
	var wx: float = r + 12.0
	while wx + 38.0 < 56.0:
		_grad(parent, _round_rect(wx, -86, wx + 38.0, -44, 4), Color(0.45, 0.6, 0.72), Color(0.15, 0.22, 0.3))
		_poly(parent, PackedVector2Array([Vector2(wx + 5, -44), Vector2(wx + 12, -44), Vector2(wx + 24, -86), Vector2(wx + 17, -86)]), Color(1, 1, 1, 0.18))
		wx += 46.0
	# üst kat: zemin kenarı, yan korkuluk (ince), ön ve arka korkuluk
	_line(parent, [Vector2(r, BUS_DECK), Vector2(108, BUS_DECK)], 4.0, body_c.darkened(0.45))
	var rail := Line2D.new()
	rail.points = PackedVector2Array([Vector2(r + 4.0, BUS_RAIL + 10.0), Vector2(100, BUS_RAIL + 10.0)])
	rail.width = 3.0
	rail.default_color = Color(0.85, 0.87, 0.9, 0.9)
	rail.z_index = 2      # yolcuların önünde: korkuluğa tutunuyormuş gibi
	parent.add_child(rail)
	var px: float = r + 4.0
	while px < 100.0:
		var post := Line2D.new()
		post.points = PackedVector2Array([Vector2(px, BUS_DECK), Vector2(px, BUS_RAIL + 10.0)])
		post.width = 2.5
		post.default_color = Color(0.8, 0.82, 0.86, 0.9)
		post.z_index = 2
		parent.add_child(post)
		px += 44.0
	for rp in bus_rails(ext):
		_grad(parent, rp, acc.lightened(0.15), acc.darkened(0.3))
	# ön cam (alt kat) + sürücü
	_grad(parent, PackedVector2Array([Vector2(90, -90), Vector2(106, -90), Vector2(120, -62), Vector2(90, -62)]), Color(0.8, 0.93, 1.0), Color(0.3, 0.5, 0.68))
	_poly(parent, _circle_at(Vector2(100, -74), 6.5, 12), Color(0.12, 0.14, 0.2, 0.55))
	# kapı
	_grad(parent, _round_rect(60, -90, 84, -2, 3), Color(0.55, 0.75, 0.9), Color(0.22, 0.35, 0.5))
	_line(parent, [Vector2(72, -90), Vector2(72, -2)], 2.0, body_c.darkened(0.5))
	# yan yazı
	var lab := Label.new()
	lab.text = "CITY TOUR" if ext < 0.0 else "TURİZM"
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", acc.darkened(0.2))
	lab.position = Vector2(r + 14.0, -30)
	parent.add_child(lab)
	# far + stop + tampon
	_poly(parent, _round_rect(116, -40, 125, -28, 2), Color(1.0, 0.97, 0.78))
	var beam := _poly(parent, PackedVector2Array([Vector2(124, -38), Vector2(214, -58), Vector2(214, -6), Vector2(124, -28)]), Color.WHITE)
	beam.name = "Far"
	beam.vertex_colors = PackedColorArray([Color(1, 0.96, 0.75, 0.42), Color(1, 0.96, 0.75, 0.0), Color(1, 0.96, 0.75, 0.0), Color(1, 0.96, 0.75, 0.42)])
	_poly(parent, _round_rect(r - 4.0, -40, r + 2.0, -24, 2), Color(0.9, 0.08, 0.08))
	_grad(parent, _round_rect(110, 4, 128, 14, 3), chrome_top, chrome_bot)
	_grad(parent, _round_rect(r - 6.0, 4, r + 10.0, 14, 3), Color(0.3, 0.32, 0.36), Color(0.08, 0.09, 0.1))
	var axles: Array = _axles(d)
	for i in range(axles.size()):
		_fender(parent, Vector2(float(axles[i]), wheel_y), wheel_r, body_c.darkened(0.45))


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


## Garaj ön izlemesi: fiziksiz, sadece görüntü. Uzun araçlar kutuya sığsın diye küçültülür.
static func build_preview(parent: Node2D, d: Dictionary) -> void:
	var r: float = d["wheel_r"]
	var wy: float = 30.0 + (r - 26.0)
	var kind: String = String(d.get("kind", "truck"))
	var root := Node2D.new()
	parent.add_child(root)
	var front: float = 130.0
	var back: float = 130.0 + float(d.get("ext", 0.0))
	if kind == "tir":
		back = 24.0 + float(d.get("trailer_len", 420.0))
	elif kind == "bus":
		back = 160.0 + float(d.get("ext", 0.0))
	var k: float = minf(1.0, 260.0 / (front + back))
	root.scale = Vector2(k, k)
	root.position = Vector2((back - front) * 0.5 * k, 0)
	if kind == "tir":
		var tr := Node2D.new()
		tr.position = Vector2(-24, -16)
		root.add_child(tr)
		var L: float = float(d.get("trailer_len", 420.0))
		paint_trailer(tr, d, L, r, wy + 16.0)
		for tx in [-L + 66.0, -L + 128.0]:
			var tw := Node2D.new()
			tw.position = Vector2(float(tx), wy + 16.0)
			tw.z_index = 2
			tr.add_child(tw)
			paint_wheel(tw, d, r)
		_preview_boxes(tr, -L + 30.0, 0.0, -28.0)
	var b := Node2D.new()
	root.add_child(b)
	paint_body(b, d, r, wy)
	if kind == "truck":
		_preview_boxes(root, -100.0 - float(d.get("ext", 0.0)), 16.0, -34.0)
	for ax in _axles(d):
		var w := Node2D.new()
		w.position = Vector2(float(ax), wy)
		w.z_index = 2
		w.rotation = 0.4
		root.add_child(w)
		paint_wheel(w, d, r)


## Vitrindeki araç dolu görünsün: kasaya sandıklar
static func _preview_boxes(parent: Node2D, x0: float, x1: float, y: float) -> void:
	var cols: Array = [Color(0.72, 0.5, 0.26), Color(0.62, 0.42, 0.22), Color(0.8, 0.58, 0.3), Color(0.55, 0.62, 0.3), Color(0.35, 0.5, 0.72)]
	var i: int = 0
	var x: float = x0 + 15.0
	while x + 15.0 <= x1:
		for row in range(2 if i % 3 != 2 else 1):
			var c := Vector2(x, y - 28.0 * row)
			var col: Color = cols[(i + row) % cols.size()]
			var box := _poly(parent, _rect(c.x - 15, c.y - 13, c.x + 15, c.y + 13), col)
			box.z_index = 1
			var fr := Line2D.new()
			fr.points = PackedVector2Array([Vector2(c.x - 15, c.y - 13), Vector2(c.x + 15, c.y - 13), Vector2(c.x + 15, c.y + 13), Vector2(c.x - 15, c.y + 13), Vector2(c.x - 15, c.y - 13), Vector2(c.x + 15, c.y + 13)])
			fr.width = 2.5
			fr.default_color = col.darkened(0.45)
			fr.z_index = 1
			parent.add_child(fr)
		x += 32.0
		i += 1


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
