extends Node2D
## Sonsuz, aşamalı zorlaşan 2D arazi (chunk sistemi).
## - Her parça: StaticBody2D + CollisionPolygon2D + Polygon2D (toprak) + Line2D (çim çizgisi)
## - Önde yeni parçalar üretilir, geride kalanlar bellekten silinir.
## - Her 500 metrede düz bir "Teslimat Noktası" alanı oluşur.
## Hiç görsel dosya kullanılmaz; her şey kodla çizilir.

const PX_PER_M := 50.0          # 1 metre = 50 piksel

@export var chunk_width: float = 1024.0
@export var point_spacing: float = 32.0
@export var chunks_ahead: int = 3
@export var chunks_behind: int = 2
@export var base_y: float = 560.0
@export var checkpoint_interval_m: float = 500.0
@export var flat_half_width: float = 380.0     # teslimat alanının yarı genişliği (px)
@export var flat_blend: float = 320.0          # düzlükten tepeye yumuşak geçiş (px)
@export var max_difficulty_at_m: float = 3000.0 # bu mesafede zorluk tavan yapar
@export var noise_seed: int = 0                 # 0 = her oyunda farklı arazi

@export_group("Renkler")
@export var ground_color: Color = Color(0.45, 0.31, 0.19)
@export var deep_color: Color = Color(0.33, 0.22, 0.14)
@export var grass_color: Color = Color(0.40, 0.74, 0.27)
@export var grass_dark: Color = Color(0.22, 0.47, 0.16)

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _chunks: Dictionary = {}   # int -> Node2D
var _ground_mat := PhysicsMaterial.new()


func _ready() -> void:
	var s: int = noise_seed if noise_seed != 0 else randi()
	_noise.seed = s
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0011
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_detail.seed = s + 17
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.011
	_detail.fractal_octaves = 1
	_ground_mat.friction = 1.0
	_ground_mat.bounce = 0.0
	_build_start_wall()
	update_around(0.0)


## 0 (başlangıç) .. 1 (en zor)
func difficulty_at(x: float) -> float:
	return clampf(maxf(x, 0.0) / PX_PER_M / max_difficulty_at_m, 0.0, 1.0)


func _raw_height(x: float) -> float:
	var d: float = difficulty_at(x)
	var amp: float = lerpf(70.0, 320.0, d)        # tepe yüksekliği artar
	var stretch: float = lerpf(1.0, 1.6, d)       # tepeler sıklaşır = daha dik
	var big: float = _noise.get_noise_1d(x * stretch)
	var bumps: float = _detail.get_noise_1d(x) * lerpf(3.0, 28.0, d)  # engebe artar
	return base_y - big * amp + bumps


func checkpoint_px() -> float:
	return checkpoint_interval_m * PX_PER_M


## k. teslimat noktasının x konumu (k = 1 -> 500 m)
func checkpoint_x(k: int) -> float:
	return float(k) * checkpoint_px()


## Arazinin x noktasındaki yüzey yüksekliği (y aşağı doğru artar)
func height_at(x: float) -> float:
	var cp: float = checkpoint_px()
	var k: int = maxi(roundi(x / cp), 0)
	var cx: float = float(k) * cp
	var raw: float = _raw_height(x)
	var dist: float = absf(x - cx)
	if dist < flat_half_width + flat_blend:
		var flat_h: float = _raw_height(cx)
		var w: float = 1.0
		if dist > flat_half_width:
			w = 1.0 - smoothstep(0.0, 1.0, (dist - flat_half_width) / flat_blend)
		return lerpf(raw, flat_h, w)
	return raw


## Araç nereye giderse etrafındaki parçaları hazırla, uzaktakileri sil
func update_around(x: float) -> void:
	var ci: int = floori(x / chunk_width)
	for i in range(ci - chunks_behind, ci + chunks_ahead + 1):
		if not _chunks.has(i):
			var c: Node2D = _build_chunk(i)
			add_child(c)
			_chunks[i] = c
	for key in _chunks.keys():
		var k: int = key
		if k < ci - chunks_behind or k > ci + chunks_ahead + 1:
			var old: Node2D = _chunks[k]
			old.queue_free()
			_chunks.erase(k)


func _build_chunk(i: int) -> Node2D:
	var x0: float = float(i) * chunk_width
	var root := Node2D.new()
	root.name = "Chunk_%d" % i

	var top := PackedVector2Array()
	var n: int = int(chunk_width / point_spacing)
	for j in range(n + 1):
		var x: float = x0 + float(j) * point_spacing
		top.append(Vector2(x, height_at(x)))
	var bottom_y: float = base_y + 1600.0

	var poly := PackedVector2Array(top)
	poly.append(Vector2(x0 + chunk_width, bottom_y))
	poly.append(Vector2(x0, bottom_y))

	# --- fizik ---
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = _ground_mat
	var col := CollisionPolygon2D.new()
	col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS   # düz alanlarda da sorunsuz
	col.polygon = poly
	body.add_child(col)
	root.add_child(body)

	# --- görsel: toprak + derin katman + çim ---
	var dirt := Polygon2D.new()
	dirt.polygon = poly
	dirt.color = ground_color
	root.add_child(dirt)

	var deep_pts := PackedVector2Array()
	for p in top:
		deep_pts.append(p + Vector2(0, 70))
	deep_pts.append(Vector2(x0 + chunk_width, bottom_y))
	deep_pts.append(Vector2(x0, bottom_y))
	var deep := Polygon2D.new()
	deep.polygon = deep_pts
	deep.color = deep_color
	root.add_child(deep)

	var edge := Line2D.new()
	edge.points = top
	edge.width = 22.0
	edge.default_color = grass_dark
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	edge.position = Vector2(0, 6)
	root.add_child(edge)

	var grass := Line2D.new()
	grass.points = top
	grass.width = 12.0
	grass.default_color = grass_color
	grass.joint_mode = Line2D.LINE_JOINT_ROUND
	root.add_child(grass)

	# --- bu parçada teslimat noktası var mı? ---
	var cp: float = checkpoint_px()
	var k0: int = maxi(ceili(x0 / cp), 0)
	var cx: float = float(k0) * cp
	if cx >= x0 and cx < x0 + chunk_width:
		_build_station(root, k0, cx)
	return root


func _build_station(root: Node2D, k: int, cx: float) -> void:
	var y: float = height_at(cx)
	var st := Node2D.new()
	st.name = "Station_%d" % k
	st.position = Vector2(cx, y)
	st.z_index = -1
	root.add_child(st)

	# beton zemin
	var pad := Polygon2D.new()
	var hw: float = flat_half_width - 60.0
	pad.polygon = PackedVector2Array([Vector2(-hw, -3), Vector2(hw, -3), Vector2(hw, 16), Vector2(-hw, 16)])
	pad.color = Color(0.62, 0.62, 0.6)
	st.add_child(pad)
	var stripe := Line2D.new()
	stripe.points = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)])
	stripe.width = 4.0
	stripe.default_color = Color(0.95, 0.8, 0.15)
	st.add_child(stripe)

	if k == 0:
		_add_label(st, "BAŞLANGIÇ", Vector2(-120, -230), 30)
		return

	# depo binası
	var bx: float = 150.0
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([Vector2(bx, -3), Vector2(bx, -150), Vector2(bx + 230, -150), Vector2(bx + 230, -3)])
	wall.color = Color(0.78, 0.36, 0.22)
	st.add_child(wall)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(bx - 16, -150), Vector2(bx + 115, -215), Vector2(bx + 246, -150)])
	roof.color = Color(0.32, 0.33, 0.38)
	st.add_child(roof)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([Vector2(bx + 70, -3), Vector2(bx + 70, -100), Vector2(bx + 160, -100), Vector2(bx + 160, -3)])
	door.color = Color(0.25, 0.25, 0.28)
	st.add_child(door)
	for r in range(5):
		var ln := Line2D.new()
		var yy: float = -90.0 + float(r) * 18.0
		ln.points = PackedVector2Array([Vector2(bx + 72, yy), Vector2(bx + 158, yy)])
		ln.width = 3.0
		ln.default_color = Color(0.4, 0.4, 0.44)
		st.add_child(ln)

	# bayrak direği
	var pole := Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -260)])
	pole.width = 7.0
	pole.default_color = Color(0.85, 0.85, 0.88)
	st.add_child(pole)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(3, -258), Vector2(95, -232), Vector2(3, -206)])
	flag.color = Color(0.1, 0.75, 0.35)
	st.add_child(flag)
	_add_label(st, "TESLİMAT\n%d m" % int(k * checkpoint_interval_m), Vector2(-110, -380), 30)


func _add_label(parent: Node, text: String, pos: Vector2, size: int) -> void:
	var lb := Label.new()
	lb.text = text
	lb.position = pos
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.custom_minimum_size = Vector2(220, 0)
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.add_theme_constant_override("outline_size", 8)
	parent.add_child(lb)


## Başlangıcın gerisine kalın bir kaya duvarı: geri giderken boşluğa düşülmesin
func _build_start_wall() -> void:
	var wx: float = -flat_half_width - flat_blend - 120.0
	var y: float = height_at(wx)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.physics_material_override = _ground_mat
	var pts := PackedVector2Array([Vector2(wx - 80, y - 700), Vector2(wx + 40, y - 700), Vector2(wx + 40, y + 300), Vector2(wx - 80, y + 300)])
	var col := CollisionPolygon2D.new()
	col.polygon = pts
	wall.add_child(col)
	var vis := Polygon2D.new()
	vis.polygon = pts
	vis.color = Color(0.4, 0.38, 0.36)
	wall.add_child(vis)
	add_child(wall)
