extends Node3D
## Gece maçı stadyumu: çizgili çim ve saha çizgileri (shader), kale + titreşen ağ,
## seyirci dolu tribünler (shader), LED reklam panoları (yazısız), ışık kuleleri, gökyüzü.

const GOAL_HALF := 3.66
const GOAL_H := 2.44
const NET_DEPTH := 1.9

var net_mat: ShaderMaterial
var crowd_mat: ShaderMaterial
var crowd_mats: Array[ShaderMaterial] = []
var board_mat: ShaderMaterial
var _excite: float = 0.0
var _excite_target: float = 0.15
var _net_t: float = 10.0
var _inner_nets: Array[Node3D] = []


const GRASS_SHADER := """
shader_type spatial;
uniform vec3 g1 : source_color = vec3(0.12, 0.40, 0.14);
uniform vec3 g2 : source_color = vec3(0.09, 0.33, 0.11);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float line_seg(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.02, abs(d)); }
void fragment() {
	float stripe = step(0.5, fract(wp.z / 6.0));
	vec3 col = mix(g1, g2, stripe);
	float n = noise(wp.xz * 3.0) * 0.6 + noise(wp.xz * 17.0) * 0.4;
	col *= 0.86 + 0.22 * n;
	float w = 0.12;
	float L = 0.0;
	// kale çizgisi
	L = max(L, line_seg(wp.z, w));
	// ceza sahası
	L = max(L, line_seg(wp.z - 16.5, w) * step(abs(wp.x), 20.16));
	L = max(L, line_seg(abs(wp.x) - 20.16, w) * step(wp.z, 16.5) * step(0.0, wp.z));
	// altı pas
	L = max(L, line_seg(wp.z - 5.5, w) * step(abs(wp.x), 9.16));
	L = max(L, line_seg(abs(wp.x) - 9.16, w) * step(wp.z, 5.5) * step(0.0, wp.z));
	// penaltı noktası
	L = max(L, 1.0 - smoothstep(0.13, 0.15, length(wp.xz - vec2(0.0, 11.0))));
	// ceza yayı
	float r = length(wp.xz - vec2(0.0, 11.0));
	L = max(L, line_seg(r - 9.15, w) * step(16.5, wp.z));
	col = mix(col, vec3(0.93, 0.95, 0.93), L);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
"""

const NET_SHADER := """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
uniform vec3 impact = vec3(0.0, 1.0, 0.0);
uniform float t_since = 10.0;
uniform float cell = 0.14;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wpos, impact);
	float wave = sin(d * 7.0 - t_since * 18.0) * exp(-t_since * 2.6) * exp(-d * 0.9);
	VERTEX += NORMAL * wave * 0.35;
}
void fragment() {
	vec2 g = abs(fract(UV * vec2(%s) / cell) - 0.5);
	float wire = 1.0 - smoothstep(0.38, 0.47, max(g.x, g.y));
	if (wire < 0.05) { discard; }
	ALBEDO = vec3(0.96);
	ALPHA = wire * 0.92;
	ROUGHNESS = 0.6;
}
"""

const CROWD_SHADER := """
shader_type spatial;
uniform vec3 c1 : source_color = vec3(0.8, 0.1, 0.15);
uniform vec3 c2 : source_color = vec3(1.0, 0.75, 0.1);
uniform vec3 c3 : source_color = vec3(0.1, 0.2, 0.5);
uniform vec3 c4 : source_color = vec3(1.0, 0.9, 0.2);
uniform float excite = 0.15;
uniform vec2 seats = vec2(180.0, 40.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 s = UV * seats;
	vec2 id = floor(s);
	vec2 f = fract(s);
	float h = hash(id);
	float h2 = hash(id + 7.3);
	float bob = sin(TIME * (6.0 + h * 6.0) + h * 30.0) * 0.18 * (0.3 + excite * 1.8) * step(0.25, h2 + excite);
	vec2 c = f - vec2(0.5, 0.42 + bob);
	float head = 1.0 - smoothstep(0.17, 0.21, length(c - vec2(0.0, 0.22)));
	float body = 1.0 - smoothstep(0.24, 0.28, length(vec2(c.x * 0.9, max(0.0, -c.y - 0.02) * 0.6 + max(0.0, c.y) * 3.0)));
	vec3 shirt = h < 0.3 ? c1 : (h < 0.55 ? c2 : (h < 0.78 ? c3 : c4));
	shirt *= 0.75 + h2 * 0.35;
	vec3 skin = mix(vec3(0.96, 0.78, 0.62), vec3(0.45, 0.30, 0.2), h2);
	vec3 seat = vec3(0.08, 0.09, 0.13);
	vec3 col = seat;
	col = mix(col, shirt, body);
	col = mix(col, skin, head);
	// telefon flaşları
	float flash = step(0.997 - excite * 0.004, hash(id + floor(TIME * 3.0)));
	col += vec3(1.0) * flash * 1.6;
	// derinlik: üst sıralar biraz karanlık
	col *= mix(1.0, 0.65, UV.y);
	ALBEDO = col;
	EMISSION = col * 0.25 + vec3(1.0) * flash * 2.0;
	ROUGHNESS = 1.0;
}
"""

const BOARD_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 a : source_color = vec3(0.1, 0.5, 1.0);
uniform vec3 b : source_color = vec3(0.0, 0.9, 0.6);
uniform float excite = 0.0;
void fragment() {
	float x = UV.x * 40.0 - TIME * (1.5 + excite * 8.0);
	float band = smoothstep(0.35, 0.65, abs(fract(x * 0.25) - 0.5) * 2.0);
	float chevron = step(0.5, fract(x + abs(UV.y - 0.5) * 2.0));
	vec3 col = mix(a, b, band) * (0.65 + 0.35 * chevron);
	vec2 px = fract(UV * vec2(400.0, 12.0));
	col *= 0.75 + 0.25 * step(0.2, px.x) * step(0.2, px.y);
	ALBEDO = col * (1.2 + excite);
}
"""


const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = exp(-d * d * 18.0);
	float halo = exp(-d * 3.2) * 0.35;
	float rays = pow(max(0.0, 1.0 - abs(UV.y - 0.5) * 18.0), 3.0) * exp(-abs(UV.x - 0.5) * 3.0) * 0.5;
	ALBEDO = vec3(1.0, 0.97, 0.88) * (core * 3.0 + halo + rays);
	ALPHA = clamp(core + halo + rays, 0.0, 1.0);
}
"""

const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 a : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 b : source_color = vec3(1.0, 0.8, 0.1);
uniform float phase = 0.0;
void vertex() {
	float w = UV.x;
	VERTEX.z += sin(UV.x * 6.0 - TIME * 5.0 + phase) * 0.18 * w;
	VERTEX.y += sin(UV.x * 4.0 - TIME * 4.0 + phase) * 0.06 * w;
}
void fragment() {
	vec3 c = UV.y < 0.5 ? a : b;
	float shade = 0.75 + 0.25 * sin(UV.x * 6.0 - TIME * 5.0 + phase);
	ALBEDO = c * shade;
	ROUGHNESS = 0.8;
	EMISSION = c * 0.15;
}
"""

var flag_mats: Array[ShaderMaterial] = []


func _ready() -> void:
	_build_environment()
	_build_pitch()
	_build_goal()
	_build_stands()
	_build_boards()
	_build_lights()
	_build_flags()


func _process(delta: float) -> void:
	_excite = lerpf(_excite, _excite_target, clampf(delta * 3.0, 0.0, 1.0))
	for cm in crowd_mats:
		cm.set_shader_parameter("excite", _excite)
	if board_mat:
		board_mat.set_shader_parameter("excite", _excite)
	_net_t += delta
	if net_mat:
		net_mat.set_shader_parameter("t_since", _net_t)


func _build_flags() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(3.2, 2.0)
		pm.subdivide_width = 12
		pm.subdivide_depth = 2
		pm.orientation = PlaneMesh.FACE_Z
		mi.mesh = pm
		var m := _shader_mat(FLAG_SHADER)
		m.set_shader_parameter("phase", rng.randf() * 6.28)
		mi.material_override = m
		flag_mats.append(m)
		var x: float = -40.0 + i * 6.0 + rng.randf_range(-1.5, 1.5)
		var row: float = rng.randf_range(0.15, 0.7)
		mi.position = Vector3(x, 3.5 + row * 12.0, -16.5 - row * 9.0)
		mi.rotation = Vector3(0, 0, rng.randf_range(-0.25, 0.25))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func set_crowd_colors(a1: Color, a2: Color, b1: Color, b2: Color) -> void:
	for i in flag_mats.size():
		var fm: ShaderMaterial = flag_mats[i]
		fm.set_shader_parameter("a", a1 if i % 3 != 2 else b1)
		fm.set_shader_parameter("b", a2 if i % 3 != 2 else b2)
	for cm in crowd_mats:
		cm.set_shader_parameter("c1", a1)
		cm.set_shader_parameter("c2", a2)
		cm.set_shader_parameter("c3", b1)
		cm.set_shader_parameter("c4", b2)
	if board_mat:
		board_mat.set_shader_parameter("a", a1)
		board_mat.set_shader_parameter("b", b1)


func excite(level: float, seconds: float = 3.0) -> void:
	_excite_target = level
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: _excite_target = 0.15)


func set_back_net_visible(v: bool) -> void:
	for n in _inner_nets:
		n.visible = v


func net_hit(p: Vector3) -> void:
	_net_t = 0.0
	if net_mat:
		net_mat.set_shader_parameter("impact", p)


func _mat(color: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var psky := ProceduralSkyMaterial.new()
	psky.sky_top_color = Color(0.02, 0.04, 0.10)
	psky.sky_horizon_color = Color(0.10, 0.16, 0.30)
	psky.ground_bottom_color = Color(0.02, 0.03, 0.06)
	psky.ground_horizon_color = Color(0.10, 0.16, 0.30)
	psky.sun_angle_max = 0.0
	sky.sky_material = psky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.16, 0.28)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_pitch() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(110, 90)
	mi.mesh = pm
	mi.position = Vector3(0, 0, 12)
	mi.material_override = _shader_mat(GRASS_SHADER)
	add_child(mi)
	# sahanın dışı (koşu pisti)
	var track := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(240, 200)
	track.mesh = tm
	track.position = Vector3(0, -0.02, 10)
	track.material_override = _mat(Color(0.12, 0.2, 0.13), 1.0)
	add_child(track)


func _cyl(r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	return mi


func _build_goal() -> void:
	var white := _mat(Color(0.97, 0.97, 0.97), 0.3)
	var r := 0.06
	for sx in [-1.0, 1.0]:
		var post := _cyl(r, GOAL_H + r, white)
		post.position = Vector3(sx * GOAL_HALF, (GOAL_H + r) / 2.0, 0)
		add_child(post)
		# arka destekler
		var back := _cyl(0.025, GOAL_H * 0.6, _mat(Color(0.8, 0.8, 0.85), 0.4, 0.5))
		back.position = Vector3(sx * GOAL_HALF, GOAL_H * 0.3, -NET_DEPTH)
		add_child(back)
		var diag := _cyl(0.02, 2.3, _mat(Color(0.8, 0.8, 0.85), 0.4, 0.5))
		diag.position = Vector3(sx * GOAL_HALF, GOAL_H * 0.8, -NET_DEPTH * 0.5)
		diag.rotation = Vector3(deg_to_rad(-38), 0, 0)
		add_child(diag)
	var bar := _cyl(r, GOAL_HALF * 2 + r * 2, white)
	bar.rotation = Vector3(0, 0, PI / 2)
	bar.position = Vector3(0, GOAL_H + r * 0.5, 0)
	add_child(bar)
	# ağ: arka (titreşen), yanlar ve üst
	net_mat = _shader_mat(NET_SHADER % "1.0, 1.0")
	var back_net := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(GOAL_HALF * 2, GOAL_H * 1.05)
	bp.subdivide_width = 40
	bp.subdivide_depth = 16
	bp.orientation = PlaneMesh.FACE_Z
	back_net.mesh = bp
	back_net.position = Vector3(0, GOAL_H * 0.5, -NET_DEPTH + 0.1)
	back_net.rotation = Vector3(deg_to_rad(-8), 0, 0)
	var m_back: ShaderMaterial = net_mat
	m_back.set_shader_parameter("cell", 0.14)
	back_net.material_override = m_back
	_set_net_scale(m_back, bp.size)
	add_child(back_net)
	_inner_nets.append(back_net)
	for sx in [-1.0, 1.0]:
		var side := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(NET_DEPTH, GOAL_H)
		sp.orientation = PlaneMesh.FACE_X
		side.mesh = sp
		side.position = Vector3(sx * GOAL_HALF, GOAL_H * 0.5, -NET_DEPTH * 0.5)
		var ms := _shader_mat(NET_SHADER % ("%f, %f" % [NET_DEPTH / 0.14 * 0.14, GOAL_H]))
		side.material_override = ms
		add_child(side)
	var top := MeshInstance3D.new()
	var tp := PlaneMesh.new()
	tp.size = Vector2(GOAL_HALF * 2, NET_DEPTH * 0.7)
	top.mesh = tp
	top.position = Vector3(0, GOAL_H, -NET_DEPTH * 0.35)
	top.material_override = _shader_mat(NET_SHADER % ("%f, %f" % [GOAL_HALF * 2, NET_DEPTH * 0.7]))
	add_child(top)
	_inner_nets.append(top)


func _set_net_scale(m: ShaderMaterial, size: Vector2) -> void:
	# NET_SHADER içindeki UV ölçeği derleme anında sabit; arka ağ için ayrı shader kur
	var sh := Shader.new()
	sh.code = NET_SHADER % ("%f, %f" % [size.x, size.y])
	m.shader = sh


func _build_stands() -> void:
	crowd_mat = _shader_mat(CROWD_SHADER)
	# kale arkası (ana tribün) ve yan tribünler: eğimli düzlemler
	var specs: Array = [
		[Vector3(0, 9.5, -24), Vector3(deg_to_rad(55), 0, 0), Vector2(110, 26), Vector2(220, 44)],
		[Vector3(-46, 9.5, 14), Vector3(deg_to_rad(55), deg_to_rad(90), 0), Vector2(110, 26), Vector2(220, 44)],
		[Vector3(46, 9.5, 14), Vector3(deg_to_rad(55), deg_to_rad(-90), 0), Vector2(110, 26), Vector2(220, 44)],
	]
	for s in specs:
		var mi := MeshInstance3D.new()
		var qm := PlaneMesh.new()
		qm.size = s[2]
		qm.orientation = PlaneMesh.FACE_Y
		mi.mesh = qm
		mi.position = s[0]
		mi.rotation = s[1]
		var m: ShaderMaterial = crowd_mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("seats", s[3])
		mi.material_override = m
		crowd_mats.append(m)
		add_child(mi)
	# çatı saçakları
	var roof_mat := _mat(Color(0.06, 0.07, 0.1), 0.8)
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(120, 0.6, 10)
	roof.mesh = rb
	roof.material_override = roof_mat
	roof.position = Vector3(0, 21.5, -31)
	add_child(roof)
	# tribün önü duvar
	var wall := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(120, 1.6, 0.5)
	wall.mesh = wb
	wall.material_override = _mat(Color(0.1, 0.12, 0.18), 0.9)
	wall.position = Vector3(0, 0.8, -13.2)
	add_child(wall)


func _build_boards() -> void:
	board_mat = _shader_mat(BOARD_SHADER)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(60, 0.95, 0.15)
	mi.mesh = bm
	mi.material_override = board_mat
	mi.position = Vector3(0, 0.48, -6.5)
	add_child(mi)
	for sx in [-1.0, 1.0]:
		var side := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.15, 0.95, 40)
		side.mesh = sb
		side.material_override = board_mat
		side.position = Vector3(sx * 30.0, 0.48, 13)
		add_child(side)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-150), 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)
	# ışık kuleleri (parlayan paneller)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.98, 0.9)
	glow.emission_energy_multiplier = 6.0
	var pole_mat := _mat(Color(0.2, 0.22, 0.28), 0.6, 0.6)
	for p in [Vector3(-34, 0, -20), Vector3(34, 0, -20), Vector3(-44, 0, 38), Vector3(44, 0, 38)]:
		var pole := _cyl(0.4, 30, pole_mat)
		pole.position = p + Vector3(0, 15, 0)
		add_child(pole)
		var panel := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(7, 4, 0.5)
		panel.mesh = pb
		panel.material_override = glow
		add_child(panel)
		panel.look_at_from_position(p + Vector3(0, 31, 0), Vector3(0, 0, 8), Vector3.UP)
		var flare := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(16, 16)
		flare.mesh = fq
		flare.material_override = _shader_mat(FLARE_SHADER)
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flare.position = p + Vector3(0, 31, 1.0)
		add_child(flare)
