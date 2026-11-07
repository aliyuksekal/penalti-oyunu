extends Node3D
## İskeletli 3D futbolcu / kaleci (tools/make_characters.py ile üretilen .glb).
## Forma rengi/deseni shader ile boyanır (arma ve yazı yok). Animasyon kodla: görünmez
## "vekil" eklemlere açı verilir, her karede iskelet kemiklerine aktarılır.

const BODY_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 shirt_a : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 shirt_b : source_color = vec3(1.0, 0.8, 0.1);
uniform vec3 trim : source_color = vec3(1.0);
uniform vec3 shorts : source_color = vec3(1.0);
uniform vec3 socks : source_color = vec3(1.0);
uniform vec3 boots : source_color = vec3(0.06, 0.07, 0.09);
uniform vec3 skin : source_color = vec3(0.86, 0.64, 0.5);
uniform vec3 hair : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 gloves : source_color = vec3(0.95);
uniform int pattern = 0;
uniform float stripes = 9.0;
uniform float sleeve_pattern = 1.0;
varying flat float region;
varying float occ;
varying vec2 rest;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	region = floor(UV2.x * 10.0 + 0.5);
	occ = UV2.y;
	rest = UV;
}
vec3 kit_color(vec2 r) {
	bool arm = abs(r.x) > 0.205;
	if (pattern == 0) {
		return r.x > 0.0 ? shirt_a : shirt_b;
	} else if (pattern == 1) {
		if (arm && sleeve_pattern < 0.5) { return shirt_a; }
		return fract((r.x + 1.0) * stripes) < 0.5 ? shirt_a : shirt_b;
	}
	return shirt_a;
}
void fragment() {
	vec3 col = skin;
	float rough = 0.55;
	float spec = 0.35;
	float sheen = 0.0;
	if (region < 0.5) {
		col = skin;
		rough = 0.5;
		spec = 0.4;
	} else if (region < 1.5) {
		col = kit_color(rest);
		// kumaş: ince örgü + büyük kırışıklık
		float weave = 0.93 + 0.07 * sin(rest.x * 900.0) * sin(rest.y * 900.0);
		float wr = noise(rest * vec2(18.0, 9.0));
		col *= weave * (0.9 + 0.2 * wr);
		rough = 0.62;
		spec = 0.3;
		sheen = 0.25;
	} else if (region < 2.5) {
		col = shorts * (0.92 + 0.12 * noise(rest * 20.0));
		rough = 0.6;
		sheen = 0.2;
	} else if (region < 3.5) {
		float rib = 0.9 + 0.1 * sin(rest.x * 700.0);
		col = socks * rib;
		rough = 0.8;
	} else if (region < 4.5) {
		col = boots;
		rough = 0.25;
		spec = 0.7;
	} else if (region < 5.5) {
		float strand = noise(vec2(rest.x * 160.0, rest.y * 25.0));
		col = hair * (0.7 + 0.5 * strand);
		rough = 0.45;
		spec = 0.5;
	} else if (region < 6.5) {
		col = gloves;
		rough = 0.5;
	} else {
		col = trim;
		rough = 0.5;
	}
	ALBEDO = col * mix(0.55, 1.0, occ);
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = 0.3 + sheen;
	RIM_TINT = 0.5;
	AO = occ;
	AO_LIGHT_AFFECT = 0.4;
}
"""

const MODELS := {
	false: "res://assets/models/player.glb",
	true: "res://assets/models/keeper.glb",
}
## vekil -> kemik eşlemesi (vekil x<0 tarafı = kemik ".R")
const MAP := {
	"arm_l": "UpperArm.R", "fore_l": "ForeArm.R", "arm_r": "UpperArm.L", "fore_r": "ForeArm.L",
	"leg_l": "UpLeg.R", "shin_l": "Leg.R", "leg_r": "UpLeg.L", "shin_r": "Leg.L",
}

var is_keeper: bool = false
var state: String = "idle"
var t: float = 0.0
var state_t: float = 0.0
var dive_dir: Vector2 = Vector2.ZERO

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D

var skel: Skeleton3D
var mat: ShaderMaterial
var _bones: Dictionary = {}
var _hips_rest: Vector3 = Vector3.ZERO
var _proxies: Dictionary = {}


func _init(keeper: bool = false, skin_color: Color = Color("e0ac83"), hair_color: Color = Color("2b1d14")) -> void:
	is_keeper = keeper
	for n in ["hips", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "leg_l", "leg_r", "shin_l", "shin_r"]:
		var p := Node3D.new()
		_proxies[n] = p
	hips = _proxies["hips"]
	torso = _proxies["torso"]
	head = _proxies["head"]
	arm_l = _proxies["arm_l"]
	arm_r = _proxies["arm_r"]
	fore_l = _proxies["fore_l"]
	fore_r = _proxies["fore_r"]
	leg_l = _proxies["leg_l"]
	leg_r = _proxies["leg_r"]
	shin_l = _proxies["shin_l"]
	shin_r = _proxies["shin_r"]
	hips.position = Vector3(0, 0.93, 0)
	var sh := Shader.new()
	sh.code = BODY_SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("skin", skin_color)
	mat.set_shader_parameter("hair", hair_color)
	_load_model()


func _load_model() -> void:
	var path: String = MODELS[is_keeper]
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_error("Model yüklenemedi: " + path)
		return
	var inst: Node = ps.instantiate()
	add_child(inst)
	skel = _find_skeleton(inst)
	for mi in _find_meshes(inst):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if skel == null:
		push_error("İskelet bulunamadı: " + path)
		return
	for i in skel.get_bone_count():
		_bones[skel.get_bone_name(i)] = i
	if _bones.has("Hips"):
		_hips_rest = skel.get_bone_rest(int(_bones["Hips"])).origin
	_add_face()


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


func _find_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_meshes(c))
	return out


func _sphere(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	return mi


func _std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _add_face() -> void:
	if not _bones.has("Head"):
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skel.add_child(att)
	var s: float = 1.04 if is_keeper else 1.0
	var white := _std(Color(0.96, 0.96, 0.95), 0.2)
	var iris := _std(Color(0.28, 0.18, 0.1), 0.15)
	var dark := _std(Color(0.05, 0.04, 0.04), 0.1)
	var brow := _std(Color(0.1, 0.07, 0.05), 0.8)
	var lip := _std(Color(0.62, 0.36, 0.32), 0.5)
	for sx in [-1.0, 1.0]:
		var eye := _sphere(0.0115 * s, white)
		eye.position = Vector3(sx * 0.033 * s, 0.103 * s, 0.081 * s)
		eye.scale = Vector3(1.0, 0.75, 0.6)
		att.add_child(eye)
		var ir := _sphere(0.0075 * s, iris)
		ir.position = Vector3(sx * 0.033 * s, 0.103 * s, 0.0885 * s)
		ir.scale = Vector3(1, 1, 0.5)
		att.add_child(ir)
		var pu := _sphere(0.0038 * s, dark)
		pu.position = Vector3(sx * 0.033 * s, 0.103 * s, 0.0925 * s)
		att.add_child(pu)
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03 * s, 0.0045 * s, 0.008 * s)
		b.mesh = bm
		b.material_override = brow
		b.position = Vector3(sx * 0.034 * s, 0.124 * s, 0.093 * s)
		b.rotation = Vector3(0.2, 0, sx * -0.12)
		att.add_child(b)
	var mouth := MeshInstance3D.new()
	var mm := CapsuleMesh.new()
	mm.radius = 0.005 * s
	mm.height = 0.04 * s
	mouth.mesh = mm
	mouth.material_override = lip
	mouth.rotation = Vector3(0, 0, PI / 2)
	mouth.position = Vector3(0, 0.05 * s, 0.093 * s)
	att.add_child(mouth)


func apply_kit(kit: Dictionary, keeper_color: Color = Color.BLACK) -> void:
	if is_keeper:
		mat.set_shader_parameter("shirt_a", keeper_color)
		mat.set_shader_parameter("shirt_b", keeper_color)
		mat.set_shader_parameter("pattern", 2)
		mat.set_shader_parameter("trim", keeper_color.lightened(0.45))
		mat.set_shader_parameter("shorts", keeper_color.darkened(0.45))
		mat.set_shader_parameter("socks", keeper_color.darkened(0.1))
		mat.set_shader_parameter("gloves", Color("f2f2f2") if keeper_color.get_luminance() < 0.55 else Color("202020"))
		return
	mat.set_shader_parameter("shirt_a", kit["a"])
	mat.set_shader_parameter("shirt_b", kit["b"])
	mat.set_shader_parameter("pattern", int(kit["pattern"]))
	mat.set_shader_parameter("trim", kit["trim"])
	mat.set_shader_parameter("shorts", kit["shorts"])
	mat.set_shader_parameter("socks", kit["socks"])


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _process(delta: float) -> void:
	t += delta
	state_t += delta
	match state:
		"idle":
			_pose_idle()
		"run":
			_pose_run(state_t * 9.0)
		"kick":
			_pose_kick(state_t)
		"celebrate", "keeper_celebrate":
			_pose_celebrate(state_t)
		"sad":
			_pose_sad()
		"keeper_ready":
			_pose_keeper_ready()
		"dive":
			_pose_dive()
	_apply_to_skeleton()


func _q(r: Vector3) -> Quaternion:
	return Quaternion.from_euler(r)


func _apply_to_skeleton() -> void:
	if skel == null:
		return
	for key in MAP.keys():
		var bn: String = MAP[key]
		if _bones.has(bn):
			skel.set_bone_pose_rotation(int(_bones[bn]), _q((_proxies[key] as Node3D).rotation))
	if _bones.has("Spine"):
		skel.set_bone_pose_rotation(int(_bones["Spine"]), _q(torso.rotation * 0.5))
	if _bones.has("Chest"):
		skel.set_bone_pose_rotation(int(_bones["Chest"]), _q(torso.rotation * 0.5))
	if _bones.has("Neck"):
		skel.set_bone_pose_rotation(int(_bones["Neck"]), _q(head.rotation * 0.4))
	if _bones.has("Head"):
		skel.set_bone_pose_rotation(int(_bones["Head"]), _q(head.rotation * 0.6))
	if _bones.has("Hips"):
		var hi: int = int(_bones["Hips"])
		skel.set_bone_pose_position(hi, _hips_rest + Vector3(hips.position.x, hips.position.y - 0.93, 0))
		skel.set_bone_pose_rotation(hi, _q(hips.rotation))
	# ayak bilekleri: diz büküldükçe ayak yere paralel kalsın
	for side in ["L", "R"]:
		var fb: String = "Foot." + side
		if _bones.has(fb):
			var up: Node3D = leg_r if side == "L" else leg_l
			var dn: Node3D = shin_r if side == "L" else shin_l
			skel.set_bone_pose_rotation(int(_bones[fb]), _q(Vector3(-(up.rotation.x + dn.rotation.x) * 0.6, 0, 0)))


func _reset_pose() -> void:
	for n in _proxies.values():
		(n as Node3D).rotation = Vector3.ZERO
	hips.position = Vector3(0, 0.93, 0)


func _pose_idle() -> void:
	_reset_pose()
	var b: float = sin(t * 2.2)
	torso.rotation.x = 0.02 * b
	hips.position.y = 0.93 + 0.006 * b
	arm_l.rotation.z = -0.1
	arm_r.rotation.z = 0.1
	fore_l.rotation.x = -0.25
	fore_r.rotation.x = -0.25
	leg_l.rotation.z = -0.04
	leg_r.rotation.z = 0.04
	head.rotation.y = 0.15 * sin(t * 0.6)


func _pose_run(p: float) -> void:
	_reset_pose()
	var s: float = sin(p)
	leg_l.rotation.x = -0.75 * s
	leg_r.rotation.x = 0.75 * s
	shin_l.rotation.x = 1.0 * maxf(0.0, s)
	shin_r.rotation.x = 1.0 * maxf(0.0, -s)
	arm_l.rotation.x = 0.65 * s
	arm_r.rotation.x = -0.65 * s
	arm_l.rotation.z = -0.12
	arm_r.rotation.z = 0.12
	fore_l.rotation.x = -1.1
	fore_r.rotation.x = -1.1
	torso.rotation.x = -0.2
	hips.position.y = 0.93 + 0.035 * absf(cos(p))


func _pose_kick(k: float) -> void:
	_reset_pose()
	var back: float = clampf(k / 0.18, 0.0, 1.0)
	var fwd: float = clampf((k - 0.18) / 0.14, 0.0, 1.0)
	# sağ ayakla vuruş (vekil leg_r = sağ bacak, x>0)
	leg_r.rotation.x = lerpf(0.0, 0.95, back) - fwd * 2.2
	shin_r.rotation.x = lerpf(0.2, 1.6, back) * (1.0 - fwd * 0.9)
	leg_l.rotation.x = -0.2
	shin_l.rotation.x = 0.35
	hips.position.y = 0.9
	arm_l.rotation.z = -1.0
	arm_l.rotation.x = -0.3
	arm_r.rotation.z = 0.55
	arm_r.rotation.x = 0.5
	fore_l.rotation.x = -0.4
	torso.rotation.x = -0.15 + fwd * 0.2
	torso.rotation.y = -0.25 * fwd
	head.rotation.x = 0.3


func _pose_celebrate(k: float) -> void:
	_reset_pose()
	var j: float = absf(sin(k * 6.0))
	hips.position.y = 0.93 + 0.2 * j
	arm_l.rotation.z = -2.7 + 0.15 * sin(k * 12.0)
	arm_r.rotation.z = 2.7 - 0.15 * sin(k * 12.0)
	fore_l.rotation.x = -0.35
	fore_r.rotation.x = -0.35
	leg_l.rotation.x = -0.35 * j
	shin_l.rotation.x = 0.9 * j
	shin_r.rotation.x = 0.4 * j
	head.rotation.x = -0.3


func _pose_sad() -> void:
	_reset_pose()
	head.rotation.x = 0.55
	torso.rotation.x = 0.25
	arm_l.rotation.x = -0.6
	arm_r.rotation.x = -0.6
	arm_l.rotation.z = 0.35
	arm_r.rotation.z = -0.35
	fore_l.rotation.x = -1.8
	fore_r.rotation.x = -1.8
	hips.position.y = 0.91


func _pose_keeper_ready() -> void:
	_reset_pose()
	var b: float = sin(t * 7.0)
	hips.position.y = 0.82 + 0.02 * absf(b)
	leg_l.rotation.z = -0.25
	leg_r.rotation.z = 0.25
	leg_l.rotation.x = -0.45
	leg_r.rotation.x = -0.45
	shin_l.rotation.x = 0.85
	shin_r.rotation.x = 0.85
	torso.rotation.x = 0.3
	head.rotation.x = -0.3
	arm_l.rotation.z = -0.75
	arm_r.rotation.z = 0.75
	arm_l.rotation.x = -0.55
	arm_r.rotation.x = -0.55
	fore_l.rotation.x = -0.6
	fore_r.rotation.x = -0.6


func _pose_dive() -> void:
	_reset_pose()
	var side: float = signf(dive_dir.x) if absf(dive_dir.x) > 0.3 else 0.0
	var up: float = clampf(dive_dir.y, 0.0, 1.0)
	arm_l.rotation.z = -2.75 if side <= 0.0 else -1.7
	arm_r.rotation.z = 2.75 if side >= 0.0 else 1.7
	arm_l.rotation.x = -0.35 - up * 0.3
	arm_r.rotation.x = -0.35 - up * 0.3
	leg_l.rotation.z = -0.1
	leg_r.rotation.z = 0.1
	leg_l.rotation.x = 0.15
	shin_l.rotation.x = 0.4
	shin_r.rotation.x = 0.3
	head.rotation.z = -0.3 * side
	torso.rotation.z = 0.15 * side
