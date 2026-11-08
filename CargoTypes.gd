extends RefCounted
## Yük çeşitleri: sandık, tomruk, varil, çuval, gaz tüpü, saman balyası, koli.
## Her birinin kendi ağırlığı, sürtünmesi, şekli (tomruk ve tüp yuvarlanır!) ve değeri var.
## İlerledikçe kasaya daha çok ve daha zor yük konur. Görseller kodla çizilir.

const TYPES := {
	"sandik": {"name": "Sandık", "size": Vector2(30, 26), "mass": 0.40, "friction": 0.80, "bounce": 0.05, "shape": "rect", "value": 20},
	"tomruk": {"name": "Tomruk", "size": Vector2(120, 18), "mass": 0.90, "friction": 0.90, "bounce": 0.02, "shape": "capsule", "value": 35},
	"varil": {"name": "Varil", "size": Vector2(24, 30), "mass": 0.60, "friction": 0.70, "bounce": 0.05, "shape": "rect", "value": 25},
	"cuval": {"name": "Çuval", "size": Vector2(34, 18), "mass": 0.45, "friction": 1.10, "bounce": 0.0, "shape": "capsule", "value": 15},
	"tup": {"name": "Gaz tüpü", "size": Vector2(40, 16), "mass": 0.35, "friction": 0.60, "bounce": 0.10, "shape": "capsule", "value": 40},
	"balya": {"name": "Saman balyası", "size": Vector2(40, 26), "mass": 0.25, "friction": 0.95, "bounce": 0.05, "shape": "rect", "value": 15},
	"koli": {"name": "Koli", "size": Vector2(26, 20), "mass": 0.15, "friction": 0.70, "bounce": 0.10, "shape": "rect", "value": 10},
}

## Kasanın içi (gövde yerel koordinatı)
const BED_X0 := -106.0
const BED_X1 := 22.0
const BED_FLOOR := -20.0


## k. teslimat için yük listesi: ilk yüklemeler kolay, sonra çoğalır ve zorlaşır
static func load_plan(leg: int, rng: RandomNumberGenerator) -> Array:
	var plan: Array = []
	match leg:
		1:
			plan = ["sandik", "sandik", "sandik", "cuval", "cuval"]
		2:
			plan = ["sandik", "sandik", "cuval", "cuval", "balya", "balya"]
		3:
			plan = ["tomruk", "tomruk", "varil", "varil", "sandik", "sandik"]
		4:
			plan = ["tomruk", "tomruk", "varil", "varil", "koli", "koli", "tup"]
		5:
			plan = ["tomruk", "tomruk", "tomruk", "varil", "varil", "balya", "tup"]
		_:
			plan = ["tomruk", "tomruk"]
			var pool: Array = ["sandik", "varil", "cuval", "tup", "balya", "koli", "tomruk"]
			var n: int = mini(8, 6 + (leg - 6) / 2)
			while plan.size() < n:
				plan.append(pool[rng.randi_range(0, pool.size() - 1)])
	# uzun tomruklar altta, gerisi karışık
	var logs: Array = plan.filter(func(k): return k == "tomruk")
	var rest: Array = plan.filter(func(k): return k != "tomruk")
	for i in range(rest.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	return logs + rest


## Yükleri kasaya raf raf diz: soldan sağa, sığmayınca bir üst sıra
static func pack(kinds: Array) -> Array:
	var out: Array = []
	var x: float = BED_X0
	var y: float = BED_FLOOR
	var row_h: float = 0.0
	for k in kinds:
		var sz: Vector2 = TYPES[k]["size"]
		if x + sz.x > BED_X1 + 0.5 and x > BED_X0:
			y -= row_h + 1.0
			x = BED_X0
			row_h = 0.0
		out.append(Vector2(x + sz.x * 0.5, y - sz.y * 0.5 - 0.5))
		x += sz.x + 2.0
		row_h = maxf(row_h, sz.y)
	return out


static func make(kind: String, rng: RandomNumberGenerator) -> RigidBody2D:
	var t: Dictionary = TYPES[kind]
	var sz: Vector2 = t["size"]
	var c := RigidBody2D.new()
	c.name = kind
	c.mass = float(t["mass"]) * rng.randf_range(0.9, 1.1)
	c.collision_layer = 4
	c.collision_mask = 1 | 2 | 4
	c.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	c.can_sleep = false
	c.z_index = 1
	c.set_meta("tur", kind)
	c.set_meta("deger", int(t["value"]))
	var m := PhysicsMaterial.new()
	m.friction = float(t["friction"])
	m.bounce = float(t["bounce"])
	c.physics_material_override = m
	var cs := CollisionShape2D.new()
	if t["shape"] == "capsule":
		var cap := CapsuleShape2D.new()
		cap.radius = sz.y * 0.5
		cap.height = sz.x
		cs.shape = cap
		cs.rotation = PI * 0.5   # yatay kapsül
	else:
		var rs := RectangleShape2D.new()
		rs.size = sz
		cs.shape = rs
	c.add_child(cs)
	_paint(c, kind, sz, rng)
	return c


# ---------------- görseller ----------------
static func _paint(c: Node2D, kind: String, sz: Vector2, rng: RandomNumberGenerator) -> void:
	var h: Vector2 = sz * 0.5
	match kind:
		"sandik":
			var col: Color = [Color(0.72, 0.5, 0.26), Color(0.62, 0.42, 0.22), Color(0.8, 0.58, 0.3)][rng.randi_range(0, 2)]
			_poly(c, _rect(h), col)
			_line(c, [Vector2(-h.x, -h.y + 9), Vector2(h.x, -h.y + 9)], 1.5, col.darkened(0.3))
			_line(c, [Vector2(-h.x, h.y - 9), Vector2(h.x, h.y - 9)], 1.5, col.darkened(0.3))
			_line(c, [Vector2(-h.x, -h.y), Vector2(h.x, h.y)], 2.5, col.darkened(0.35))
			_line(c, Array(_rect(h)) + [Vector2(-h.x, -h.y)], 3.0, col.darkened(0.45))
		"tomruk":
			var bark := Color(0.42, 0.28, 0.17).darkened(rng.randf_range(0.0, 0.15))
			_poly(c, _capsule(h), bark)
			for yy in [-5.0, 0.0, 5.0]:
				var pts: Array = []
				for k in range(9):
					var xx: float = -h.x + 6.0 + (sz.x - 12.0) * float(k) / 8.0
					pts.append(Vector2(xx, yy + rng.randf_range(-1.2, 1.2)))
				_line(c, pts, 1.5, bark.darkened(0.35))
			# kesik uç: yıllık halkalar
			_poly(c, _circle(Vector2(h.x - h.y * 0.4, 0), h.y * 0.92, 14), Color(0.86, 0.7, 0.46))
			for r in [h.y * 0.62, h.y * 0.32]:
				_line(c, Array(_circle(Vector2(h.x - h.y * 0.4, 0), r, 12)) + [_circle(Vector2(h.x - h.y * 0.4, 0), r, 12)[0]], 1.0, Color(0.6, 0.42, 0.24))
			_line(c, Array(_capsule(h)) + [_capsule(h)[0]], 2.0, bark.darkened(0.5))
		"varil":
			var vc: Color = [Color(0.75, 0.15, 0.12), Color(0.15, 0.35, 0.7), Color(0.2, 0.5, 0.25)][rng.randi_range(0, 2)]
			_poly(c, _rect(h), vc)
			_poly(c, PackedVector2Array([Vector2(-h.x, -h.y), Vector2(-h.x + 5, -h.y), Vector2(-h.x + 5, h.y), Vector2(-h.x, h.y)]), Color(1, 1, 1, 0.25))
			for yy in [-h.y + 8.0, h.y - 8.0]:
				_line(c, [Vector2(-h.x, yy), Vector2(h.x, yy)], 2.5, vc.darkened(0.45))
			_poly(c, _rect(Vector2(h.x, 2.5), Vector2(0, -h.y + 1.5)), vc.lightened(0.25))
			_line(c, Array(_rect(h)) + [Vector2(-h.x, -h.y)], 2.0, vc.darkened(0.55))
		"cuval":
			var sc := Color(0.86, 0.78, 0.6)
			_poly(c, _capsule(h), sc)
			_line(c, [Vector2(-h.x + 8, -h.y + 3), Vector2(h.x - 8, -h.y + 3)], 1.0, sc.darkened(0.25))
			_poly(c, PackedVector2Array([Vector2(h.x - 4, -4), Vector2(h.x + 3, -6), Vector2(h.x + 3, 6), Vector2(h.x - 4, 4)]), sc.darkened(0.15))
			_line(c, [Vector2(h.x - 5, -5), Vector2(h.x - 5, 5)], 2.0, Color(0.45, 0.32, 0.2))
			_line(c, Array(_capsule(h)) + [_capsule(h)[0]], 2.0, sc.darkened(0.45))
		"tup":
			var tc := Color(0.92, 0.42, 0.12)
			_poly(c, _capsule(h), tc)
			_poly(c, _rect(Vector2(3, h.y - 1), Vector2(-4, 0)), Color(0.95, 0.95, 0.95))
			_poly(c, _rect(Vector2(4, 3), Vector2(h.x + 3, 0)), Color(0.6, 0.62, 0.66))
			_line(c, [Vector2(-h.x + 6, -h.y + 3), Vector2(h.x - 8, -h.y + 3)], 2.0, Color(1, 1, 1, 0.35))
			_line(c, Array(_capsule(h)) + [_capsule(h)[0]], 2.0, tc.darkened(0.5))
		"balya":
			var bc := Color(0.9, 0.78, 0.35)
			_poly(c, _rect(h), bc)
			for k in range(7):
				var yy2: float = -h.y + 3.0 + float(k) * (sz.y - 6.0) / 6.0
				_line(c, [Vector2(-h.x + 1, yy2), Vector2(h.x - 1, yy2 + rng.randf_range(-1, 1))], 1.0, bc.darkened(0.2))
			for xx in [-h.x * 0.45, h.x * 0.45]:
				_line(c, [Vector2(xx, -h.y), Vector2(xx, h.y)], 2.0, Color(0.5, 0.3, 0.15))
			_line(c, Array(_rect(h)) + [Vector2(-h.x, -h.y)], 2.0, bc.darkened(0.4))
		"koli":
			var kc := Color(0.78, 0.6, 0.38)
			_poly(c, _rect(h), kc)
			_poly(c, _rect(Vector2(h.x, 2.5), Vector2(0, -h.y + 4)), kc.lightened(0.25))
			_line(c, [Vector2(-5, 2), Vector2(-5, -4), Vector2(-7, -2)], 1.2, kc.darkened(0.5))
			_line(c, [Vector2(3, 2), Vector2(3, -4), Vector2(1, -2)], 1.2, kc.darkened(0.5))
			_line(c, Array(_rect(h)) + [Vector2(-h.x, -h.y)], 2.0, kc.darkened(0.45))


static func _poly(parent: Node, pts: PackedVector2Array, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = col
	parent.add_child(p)


static func _line(parent: Node, pts: Array, w: float, col: Color) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array(pts)
	l.width = w
	l.default_color = col
	parent.add_child(l)


static func _rect(h: Vector2, c: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(-h.x, -h.y), c + Vector2(h.x, -h.y), c + Vector2(h.x, h.y), c + Vector2(-h.x, h.y)])


static func _capsule(h: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r: float = h.y
	for k in range(9):
		var a: float = -PI * 0.5 + PI * float(k) / 8.0
		pts.append(Vector2(h.x - r, 0) + Vector2(cos(a), sin(a)) * r)
	for k in range(9):
		var a2: float = PI * 0.5 + PI * float(k) / 8.0
		pts.append(Vector2(-h.x + r, 0) + Vector2(cos(a2), sin(a2)) * r)
	return pts


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(n):
		var a: float = TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
