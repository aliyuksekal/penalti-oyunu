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
@export var reverse_ratio: float = 0.8
@export var brake_decel: float = 110.0            # fren: tekerlek yavaşlaması (rad/sn²)
@export var reverse_hold_time: float = 0.35      # bu kadar basılı tutunca fren -> geri vites
@export_group("Turbo")
@export var turbo_power: float = 1.8             # turbo sırasında güç çarpanı
@export var turbo_speed: float = 1.3             # turbo sırasında azami hız çarpanı
@export var turbo_duration: float = 2.5          # sn
@export var turbo_kick: float = 330.0            # anlık itiş: kazandırdığı ani hız (px/sn)
@export var turbo_push: float = 650.0            # turbo süresince ek itme ivmesi (px/sn²)
@export var turbo_recharge: float = 12.0         # turbonun yeniden dolma süresi (sn)
@export_group("")
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
var brake_hold: float = 0.0       # fren düğmesine ne kadardır basılı (sn)
var reversing: bool = false
var turbo_active: bool = false
var turbo_charge: float = 1.0     # 0..1, 1 = kullanıma hazır
var _turbo_t: float = 0.0
var flame: CPUParticles2D
var engine_enabled: bool = true
var menu_view: bool = false       # menüde kamera
var menu_panel_open: bool = false # menüde sağ panel açıksa kamyon sola kayar

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
	var ex: Array = model["extras"]
	if ex.has("stack") or ex.has("stacks2"):
		smoke.position = Vector2(36, TruckArt._roof_y(String(model["cab"])) - 24.0)   # dikey egzoz bacası
		smoke.direction = Vector2(-0.4, -1)
	else:
		smoke.position = Vector2(-122, 6)   # arkadaki egzoz borusu
		smoke.direction = Vector2(-1, -0.35)
	smoke.amount = 26
	smoke.lifetime = 1.3
	smoke.spread = 18.0
	smoke.gravity = Vector2(0, -40)
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 0.35
	smoke.scale_amount_max = 0.6
	smoke.color = Color(0.35, 0.35, 0.38, 0.5)
	# yumuşak yuvarlak duman topu (kodla üretilen doku), zamanla büyür ve solar
	var puff_g := Gradient.new()
	puff_g.set_color(0, Color(1, 1, 1, 1))
	puff_g.set_color(1, Color(1, 1, 1, 0))
	var puff := GradientTexture2D.new()
	puff.gradient = puff_g
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 32
	puff.height = 32
	smoke.texture = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.8))
	smoke.scale_amount_curve = grow
	smoke.local_coords = false
	smoke.emitting = false
	body.add_child(smoke)

	# turbo alevi: egzozdan turuncu-mavi alev
	flame = CPUParticles2D.new()
	flame.position = smoke.position
	flame.amount = 30
	flame.lifetime = 0.28
	flame.direction = smoke.direction
	flame.spread = 10.0
	flame.gravity = Vector2.ZERO
	flame.initial_velocity_min = 160.0
	flame.initial_velocity_max = 240.0
	flame.texture = smoke.texture
	flame.scale_amount_min = 0.35
	flame.scale_amount_max = 0.6
	var fg := Gradient.new()
	fg.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	fg.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.4, 0.5, 1.0, 0.0)])
	flame.color_ramp = fg
	flame.local_coords = false
	flame.emitting = false
	body.add_child(flame)

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
	flame = null
	turbo_active = false
	turbo_charge = 1.0
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
	elif can_drive and brake_pressed and brake_hold >= reverse_hold_time:
		throttle = -0.8

	var fwd_speed: float = body.linear_velocity.dot(body.global_transform.x)
	var power: float = engine_power * (turbo_power if turbo_active else 1.0)
	var vmax: float = max_wheel_speed * (turbo_speed if turbo_active else 1.0)
	# kısa basış = fren; basılı tutunca (ve kamyon neredeyse durmuşsa) = geri vites
	reversing = brake_pressed and can_drive and brake_hold >= reverse_hold_time and fwd_speed < 60.0
	for i in range(wheels.size()):
		var w: RigidBody2D = wheels[i]
		var share: float = _drive_share(i)
		if gas_pressed and throttle > 0.0:
			if w.angular_velocity < vmax:
				w.apply_torque(power * share)
		elif reversing:
			if w.angular_velocity > -max_wheel_speed * 0.55:
				w.apply_torque(-engine_power * reverse_ratio * share)
		elif brake_pressed:
			# fren motor gerektirmez: tekerlekleri yavaşlat
			w.angular_velocity = move_toward(w.angular_velocity, 0.0, brake_decel * delta)

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
	_update_turbo(delta)
	_update_smoke(throttle)


## Çekiş: wheels[0] arka teker, wheels[1] ön teker.
## Arkadan itiş = bütün güç arka tekere; 4x4 = güç iki tekere bölünür.
func _drive_share(i: int) -> float:
	if String(model.get("drive", "rwd")) == "awd":
		return 0.55 if i == 0 else 0.45
	return 1.0 if i == 0 else 0.0


## Turbo: anlık itiş (ani hız kazanımı) + birkaç saniye ek güç; motoru ısıtır
func use_turbo() -> bool:
	if turbo_active or turbo_charge < 1.0 or not engine_enabled or overheated or fuel <= 0.0:
		return false
	# anlık itiş: kamyonu bulunduğu yönde ileri fırlat
	body.apply_central_impulse(body.global_transform.x * body.mass * turbo_kick)
	turbo_active = true
	turbo_charge = 0.0
	_turbo_t = turbo_duration
	return true


func _update_turbo(delta: float) -> void:
	if turbo_active:
		_turbo_t -= delta
		body.apply_central_force(body.global_transform.x * body.mass * turbo_push)
		heat = minf(heat + heat_rise * 0.9 * delta, 99.0)
		fuel = maxf(fuel - fuel_use_gas * 0.6 * delta, 0.0)
		if _turbo_t <= 0.0 or overheated or fuel <= 0.0:
			turbo_active = false
	elif not menu_view:
		turbo_charge = minf(turbo_charge + delta / turbo_recharge, 1.0)
	if flame:
		flame.emitting = turbo_active


## Egzoz dumanı: rölantide ince ve açık; yokuşta gaza basınca koyu ve yoğun
func _update_smoke(throttle: float) -> void:
	if smoke == null:
		return
	var running: bool = engine_enabled and fuel > 0.0
	smoke.emitting = running
	if not running:
		return
	var climb: float = clampf(-sin(body.global_rotation) * 2.5, 0.0, 1.0)   # burun yukarı = yokuş
	var load_k: float = clampf(maxf(throttle, 0.0) * (0.35 + 0.65 * climb) + (0.25 if overheated else 0.0), 0.0, 1.0)
	var light := Color(0.82, 0.83, 0.86, 0.28)
	var dark := Color(0.1, 0.1, 0.11, 0.8)
	smoke.color = light.lerp(dark, load_k)
	smoke.speed_scale = 0.6 + absf(throttle) * 0.6 + load_k * 0.6
	smoke.scale_amount_min = 0.35 + load_k * 0.45
	smoke.scale_amount_max = 0.6 + load_k * 0.8
	smoke.initial_velocity_min = 25.0 + load_k * 40.0
	smoke.initial_velocity_max = 50.0 + load_k * 70.0


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var v: Vector2 = body.linear_velocity
	var look: Vector2 = Vector2(clampf(v.x * 0.35, -120.0, 260.0) + 120.0, -70.0)
	var z: float = base_zoom * lerpf(1.0, 0.72, clampf(v.length() / 1100.0, 0.0, 1.0))   # hızlanınca uzaklaş
	if menu_view:
		look = Vector2(330.0 if menu_panel_open else 40.0, -40.0)   # panel açıksa kamyon sola
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


## Reklamla kurtarma: kamyonu verilen noktada dik ve durmuş halde yeniden yerleştir
func upright_at(p: Vector2) -> void:
	body.global_transform = Transform2D(0.0, p)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	for i in range(wheels.size()):
		var side: float = -1.0 if i == 0 else 1.0
		var w: RigidBody2D = wheels[i]
		w.global_transform = Transform2D(0.0, p + Vector2(WHEEL_X * side, wheel_y))
		w.linear_velocity = Vector2.ZERO
		w.angular_velocity = 0.0


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
