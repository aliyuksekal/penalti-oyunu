extends Node2D
## Kamyon: RigidBody2D gövde + üstü açık U şeklinde yük kasası + 2 tekerlek.
## Süspansiyon: her tekerlekte GrooveJoint2D (dikey ray) + DampedSpringJoint2D (yay/amortisör).
## Kamera (Camera2D) kamyonu yumuşakça izler, hızlandıkça hafifçe uzaklaşır.
## Model (renk, kabin, teker boyu, güç çarpanları) TruckCatalog'dan gelir; çizim TruckArt'ta.

const TruckArt = preload("res://TruckArt.gd")
const TruckCatalog = preload("res://TruckCatalog.gd")

const PX_PER_M := 50.0
const WHEEL_X := 78.0          # tekerleklerin gövde merkezine yatay uzaklığı
const UP_TRAVEL := 24.0        # süspansiyonun yukarı (sıkışma) yolu
const DOWN_TRAVEL := 22.0      # aşağı (uzama) yolu
const SPRING_TOP := 70.0       # yayın gövdedeki bağlantı noktasının tekerlekten yüksekliği

## Kasanın iç ölçüleri (gövde yerel koordinatı, y aşağı +) - tüm kamyonlarda aynı
const BED_LEFT := -108.0
const BED_RIGHT := 24.0
const BED_FLOOR := -20.0
const BED_WALL_TOP := -64.0

## Garajdaki yükseltmelerin seviye başına etkisi
const UPGRADE_STEP := {"engine": 0.12, "stiffness": 0.10, "damping": 0.15, "grip": 0.10, "fuel": 0.20}

@export_group("Yükseltilebilir")
@export var engine_power: float = 62000.0        # tekerleklere verilen tork
@export var suspension_stiffness: float = 70.0   # yay sertliği
@export var suspension_damping: float = 3.0      # amortisör sönümlemesi (0.01 - 16)
@export var tire_friction: float = 1.2           # lastik tutuşu
@export var fuel_capacity: float = 100.0         # yakıt deposu (litre)

@export_group("Ayarlar")
@export var body_mass: float = 3.0
@export var wheel_mass: float = 0.6
@export var max_wheel_speed: float = 38.0        # rad/sn (≈ 72 km/s)
@export var reverse_ratio: float = 0.55
@export var brake_ratio: float = 1.6
@export var air_control: float = 3.2             # havada gövdeyi döndürme (rad/sn²)
@export var fuel_use_idle: float = 0.35          # litre/sn rölanti
@export var fuel_use_gas: float = 1.5            # litre/sn tam gaz (ek)
@export var heat_rise: float = 5.5               # tam gazda hararet artışı (%/sn)
@export var heat_fall: float = 11.0              # gaz bırakınca soğuma (%/sn)
@export var overheat_cooldown: float = 3.0       # aşırı ısınınca motorun kesik kaldığı süre (sn)
@export var base_zoom: float = 1.0

var body: RigidBody2D
var wheels: Array[RigidBody2D] = []
var camera: Camera2D
var smoke: CPUParticles2D
var model: Dictionary = {}
var wheel_r: float = 26.0
var wheel_y: float = 30.0

## Kontrol (CargoAndGameManager doldurur)
var gas_pressed: bool = false
var brake_pressed: bool = false
var engine_enabled: bool = true
var menu_view: bool = false       # menüde kamera kamyonu sola alır

var fuel: float = 100.0
var heat: float = 0.0
var overheated: bool = false
var built: bool = false
var _overheat_t: float = 0.0
var _base: Dictionary = {}
var _parts: Array[Node] = []


func _ready() -> void:
	# Main sahnesi kurmazsa (tek başına test) kendini kur
	call_deferred("_auto_build")


func _auto_build() -> void:
	if not built:
		build(global_position + Vector2(0, -60))


## Katalogdaki modeli ve o kamyonun yükseltme seviyelerini uygula (build'den önce çağrılır)
func apply_model(def: Dictionary, levels: Dictionary) -> void:
	if _base.is_empty():
		_base = {"engine_power": engine_power, "suspension_stiffness": suspension_stiffness,
			"suspension_damping": suspension_damping, "tire_friction": tire_friction,
			"fuel_capacity": fuel_capacity, "max_wheel_speed": max_wheel_speed, "body_mass": body_mass}
	model = def
	wheel_r = float(def["wheel_r"])
	wheel_y = 30.0 + (wheel_r - 26.0)
	var r_k: float = wheel_r / 26.0
	engine_power = _base["engine_power"] * float(def["power"]) * r_k * (1.0 + UPGRADE_STEP["engine"] * _lv(levels, "engine"))
	suspension_stiffness = _base["suspension_stiffness"] * float(def["stiff"]) * (1.0 + UPGRADE_STEP["stiffness"] * _lv(levels, "stiffness"))
	suspension_damping = _base["suspension_damping"] * float(def["damp"]) * (1.0 + UPGRADE_STEP["damping"] * _lv(levels, "damping"))
	tire_friction = _base["tire_friction"] * float(def["grip"]) * (1.0 + UPGRADE_STEP["grip"] * _lv(levels, "grip"))
	fuel_capacity = _base["fuel_capacity"] * float(def["fuel"]) * (1.0 + UPGRADE_STEP["fuel"] * _lv(levels, "fuel"))
	max_wheel_speed = _base["max_wheel_speed"] * float(def["speed"]) / r_k
	body_mass = _base["body_mass"] * float(def["mass"])


func _lv(levels: Dictionary, id: String) -> float:
	return float(levels.get(id, 0))


## spawn: gövdenin dünya konumu
func build(spawn: Vector2) -> void:
	if built:
		return
	built = true
	if model.is_empty():
		model = TruckCatalog.by_id("tosun")
	fuel = fuel_capacity
	heat = 0.0
	overheated = false
	var origin: Vector2 = to_local(spawn)

	# ---------------- gövde ----------------
	body = RigidBody2D.new()
	body.name = "Body"
	body.mass = body_mass
	body.position = origin
	body.collision_layer = 2
	body.collision_mask = 1 | 4
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.can_sleep = false
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2(-4, 6)   # alçak ağırlık merkezi = daha zor devrilir
	var bm := PhysicsMaterial.new()
	bm.friction = 0.6
	body.physics_material_override = bm
	add_child(body)
	_parts.append(body)

	var chassis := PackedVector2Array([Vector2(-118, -10), Vector2(112, -10), Vector2(118, 2), Vector2(112, 14), Vector2(-118, 14)])
	# Üstü açık U kasa (tek, içbükey poligon: Godot dışbükey parçalara ayırır)
	var bed := PackedVector2Array([
		Vector2(-118, BED_WALL_TOP), Vector2(BED_LEFT, BED_WALL_TOP), Vector2(BED_LEFT, BED_FLOOR),
		Vector2(BED_RIGHT, BED_FLOOR), Vector2(BED_RIGHT, BED_WALL_TOP), Vector2(BED_RIGHT + 10, BED_WALL_TOP),
		Vector2(BED_RIGHT + 10, -10), Vector2(-118, -10)])
	_add_collision(body, chassis)
	_add_collision(body, TruckArt.cab_polygon(String(model["cab"])))
	_add_collision(body, bed)
	TruckArt.paint_body(body, model, wheel_r, wheel_y)

	smoke = CPUParticles2D.new()
	smoke.position = Vector2(36, -100)
	smoke.amount = 14
	smoke.lifetime = 0.9
	smoke.direction = Vector2(-0.4, -1)
	smoke.spread = 18.0
	smoke.gravity = Vector2(0, -40)
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 4.0
	smoke.scale_amount_max = 9.0
	smoke.color = Color(0.35, 0.35, 0.38, 0.5)
	smoke.local_coords = false
	smoke.emitting = false
	body.add_child(smoke)

	# ---------------- tekerlekler + süspansiyon ----------------
	wheels.clear()
	var cargo_share: float = 5.0 * 0.4
	for side in [-1.0, 1.0]:
		var wpos: Vector2 = origin + Vector2(WHEEL_X * side, wheel_y)
		var w := _make_wheel(wpos)
		wheels.append(w)

		# dikey ray: tekerlek sadece gövdeye göre yukarı/aşağı hareket eder
		var groove := GrooveJoint2D.new()
		groove.position = wpos - Vector2(0, UP_TRAVEL)
		groove.length = UP_TRAVEL + DOWN_TRAVEL
		groove.initial_offset = UP_TRAVEL
		add_child(groove)
		_parts.append(groove)
		groove.node_a = groove.get_path_to(body)
		groove.node_b = groove.get_path_to(w)

		# yay + amortisör: gövdedeki üst noktadan tekerlek merkezine
		var spring := DampedSpringJoint2D.new()
		spring.position = wpos - Vector2(0, SPRING_TOP)
		spring.length = SPRING_TOP
		var load_n: float = (body_mass + cargo_share) * _gravity() * 0.5
		spring.rest_length = SPRING_TOP + clampf(load_n / maxf(suspension_stiffness, 1.0), 0.0, 60.0)
		spring.stiffness = suspension_stiffness
		spring.damping = clampf(suspension_damping, 0.01, 16.0)
		add_child(spring)
		_parts.append(spring)
		spring.node_a = spring.get_path_to(body)
		spring.node_b = spring.get_path_to(w)

	# ---------------- kamera ----------------
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.zoom = Vector2(base_zoom, base_zoom)
	camera.global_position = spawn
	add_child(camera)
	_parts.append(camera)
	camera.make_current()


## Kamyonu tamamen kaldır (garajda kamyon değiştirirken)
func teardown() -> void:
	for p in _parts:
		if is_instance_valid(p):
			p.queue_free()
	_parts.clear()
	wheels.clear()
	body = null
	camera = null
	smoke = null
	built = false


func _make_wheel(pos: Vector2) -> RigidBody2D:
	var w := RigidBody2D.new()
	w.mass = wheel_mass
	w.position = pos
	w.collision_layer = 2
	w.collision_mask = 1 | 4
	w.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	w.can_sleep = false
	w.contact_monitor = true
	w.max_contacts_reported = 2
	w.z_index = 2
	var m := PhysicsMaterial.new()
	m.friction = tire_friction
	m.bounce = 0.05
	w.physics_material_override = m
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = wheel_r
	cs.shape = c
	w.add_child(cs)
	TruckArt.paint_wheel(w, model, wheel_r)
	add_child(w)
	_parts.append(w)
	return w


func _physics_process(delta: float) -> void:
	if not built or body == null:
		return
	var grounded: bool = wheels_on_ground()
	var can_drive: bool = engine_enabled and not overheated and fuel > 0.0
	var throttle: float = 0.0
	if can_drive and gas_pressed:
		throttle = 1.0
	elif can_drive and brake_pressed:
		throttle = -1.0

	var fwd_speed: float = body.linear_velocity.dot(body.global_transform.x)
	for i in range(wheels.size()):
		var w: RigidBody2D = wheels[i]
		var share: float = 0.6 if i == 0 else 0.4   # arka ağırlıklı çekiş
		if gas_pressed and throttle > 0.0:
			if w.angular_velocity < max_wheel_speed:
				w.apply_torque(engine_power * share)
		elif brake_pressed:
			if fwd_speed > 40.0:
				# ileri giderken: fren (motor gerekmez)
				w.apply_torque(-engine_power * brake_ratio * share)
			elif throttle < 0.0 and w.angular_velocity > -max_wheel_speed * 0.5:
				# durunca: geri vites
				w.apply_torque(-engine_power * reverse_ratio * share)

	# havadayken gövde eğimini kontrol (gaz = arkaya, fren = öne yatır)
	if not grounded and engine_enabled:
		if gas_pressed:
			body.angular_velocity = maxf(body.angular_velocity - air_control * delta, -3.0)
		elif brake_pressed:
			body.angular_velocity = minf(body.angular_velocity + air_control * delta, 3.0)

	# yakıt bitince tekerlekler yuvarlanma direnciyle yavaşlar
	var damp: float = 2.5 if fuel <= 0.0 else 0.0
	for w2 in wheels:
		w2.angular_damp = damp
	_update_engine(delta, throttle)
	_update_camera(delta)


func _update_engine(delta: float, throttle: float) -> void:
	if engine_enabled and not menu_view:
		fuel = maxf(fuel - (fuel_use_idle + fuel_use_gas * absf(throttle)) * delta, 0.0)
	if overheated:
		_overheat_t -= delta
		heat = maxf(heat - heat_fall * 0.5 * delta, 70.0)
		if _overheat_t <= 0.0:
			overheated = false
			heat = 70.0
	elif throttle > 0.5:
		heat += heat_rise * delta
		if heat >= 100.0:
			heat = 100.0
			overheated = true
			_overheat_t = overheat_cooldown
	else:
		heat = maxf(heat - heat_fall * delta, 0.0)
	if smoke:
		smoke.emitting = throttle != 0.0 and not overheated


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var v: Vector2 = body.linear_velocity
	var look: Vector2 = Vector2(clampf(v.x * 0.35, -120.0, 260.0) + 120.0, -70.0)
	var z: float = base_zoom * lerpf(1.0, 0.72, clampf(v.length() / 1100.0, 0.0, 1.0))   # hızlanınca uzaklaş
	if menu_view:
		look = Vector2(330.0, -40.0)   # kamyon ekranın sol tarafında görünsün
		z = base_zoom * 1.3
	camera.global_position = body.global_position + look
	camera.zoom = camera.zoom.lerp(Vector2(z, z), clampf(delta * 1.5, 0.0, 1.0))


# ---------------- oyun yöneticisinin kullandığı bilgiler ----------------
func wheels_on_ground() -> bool:
	for w in wheels:
		if w.get_contact_count() > 0:
			return true
	return false


func is_flipped() -> bool:
	return cos(body.global_rotation) < -0.2


func speed_kmh() -> float:
	return body.linear_velocity.x / PX_PER_M * 3.6


func refuel() -> void:
	fuel = fuel_capacity


## Kasanın içindeki bir noktanın dünya konumu (yük yerleştirmek için)
func bed_to_global(local: Vector2) -> Vector2:
	return body.to_global(local)


## Bir nokta hâlâ kasanın içinde mi? (biraz pay bırakılmış)
func is_in_bed(world_pos: Vector2) -> bool:
	var p: Vector2 = body.to_local(world_pos)
	return p.x > BED_LEFT - 16.0 and p.x < BED_RIGHT + 16.0 and p.y < BED_FLOOR + 14.0 and p.y > BED_WALL_TOP - 90.0


# ---------------- yardımcılar ----------------
func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


func _add_collision(parent: Node, pts: PackedVector2Array) -> void:
	var c := CollisionPolygon2D.new()
	c.polygon = pts
	parent.add_child(c)
