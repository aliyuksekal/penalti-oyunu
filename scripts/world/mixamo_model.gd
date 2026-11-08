extends Node3D
## Gerçek 3D futbolcu / kaleci: Mixamo "Remy" karakteri + Mixamo futbol animasyonları
## (CI'da tools/mixamo_to_glb.py ile tek .glb'ye çevrilir: assets/models/remy.glb).
## player_model.gd ile aynı arayüz: set_state, apply_kit, dive_dir, is_keeper.
## Forma: tişört ve şort ağlarının dokusu korunur (kırışıklık/gölge), rengi takım rengine boyanır.

const PATH := "res://assets/models/remy.glb"
const HEIGHT := 1.82

const KIT_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_nrm = false;
uniform vec3 col_a : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 col_b : source_color = vec3(1.0, 0.8, 0.1);
uniform int pattern = 2;
uniform float stripes = 7.0;
uniform float span = 40.0;
uniform float cx = 0.0;
varying vec3 mpos;
void vertex() {
	mpos = VERTEX;
}
void fragment() {
	vec3 t = texture(tex, UV).rgb;
	vec3 avg = textureLod(tex, vec2(0.5), 12.0).rgb;
	float l = dot(t, vec3(0.3, 0.59, 0.11));
	float la = max(dot(avg, vec3(0.3, 0.59, 0.11)), 0.03);
	float detail = clamp(l / la, 0.45, 1.45);
	vec3 c = col_a;
	if (pattern == 0) {
		c = mpos.x > cx ? col_a : col_b;
	} else if (pattern == 1) {
		c = fract((mpos.x - cx) / span * stripes + 0.25) < 0.5 ? col_a : col_b;
	}
	ALBEDO = c * detail;
	ROUGHNESS = 0.68;
	SPECULAR = 0.3;
	RIM = 0.25;
	RIM_TINT = 0.5;
	if (has_nrm) {
		NORMAL_MAP = texture(nrm, UV).rgb;
	}
}
"""

## oyundaki durum -> animasyon
const LOOPING := ["idle", "jog", "gk_idle", "gk_idle2", "gk_directing", "fallen"]

static var _info: Dictionary = {}       # anim adı -> {lat, t0, t1, contact}

var is_keeper: bool = false
var state: String = "idle"
var state_t: float = 0.0
var t: float = 0.0
var dive_dir: Vector2 = Vector2.ZERO

var skel: Skeleton3D
var ap: AnimationPlayer
var _root: Node3D
var _mats: Dictionary = {}   # "top" / "bottom" -> ShaderMaterial
var _hair_mat: StandardMaterial3D
var _bones: Dictionary = {}
var _gloves: Array[MeshInstance3D] = []
var _hop: float = 0.0
var _hips_rest_xz := Vector2.ZERO
var _dive_target := Vector3.ZERO
var _dive_dur: float = 0.5
var _dive_base := Vector3.ZERO
var _dive_off := Vector3.ZERO


func _init(keeper: bool = false, _skin: Color = Color.WHITE, _hair: Color = Color.BLACK) -> void:
	is_keeper = keeper
	_load()


static func available() -> bool:
	return ResourceLoader.exists(PATH)


func _load() -> void:
	var ps: PackedScene = load(PATH) as PackedScene
	if ps == null:
		push_error("Model yüklenemedi: " + PATH)
		return
	_root = ps.instantiate() as Node3D
	add_child(_root)
	skel = _find(_root, "Skeleton3D") as Skeleton3D
	ap = _find(_root, "AnimationPlayer") as AnimationPlayer
	if skel == null or ap == null:
		push_error("Remy: iskelet/animasyon yok")
		return
	for i in skel.get_bone_count():
		var bn: String = skel.get_bone_name(i)
		_bones[bn.replace("mixamorig:", "").replace("mixamorig_", "")] = i
	_normalize_height()
	_setup_materials()
	_prepare_animations()
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if is_keeper:
		_add_gloves()
	_play("gk_idle" if is_keeper else "idle", 0.0)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


## düğümün _root'a göre dönüşümü (ağaçta olmadan da çalışır)
func _rel(n: Node3D) -> Transform3D:
	var x := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != self:
		if c is Node3D:
			x = (c as Node3D).transform * x
		c = c.get_parent()
	return x


func bone(nm: String) -> int:
	return int(_bones.get(nm, -1))


func _normalize_height() -> void:
	var top: int = bone("HeadTop_End")
	if top < 0:
		top = bone("Head")
	if top < 0:
		return
	var h: float = (_rel(skel) * skel.get_bone_global_rest(top).origin).y
	if h > 0.01:
		_root.scale *= HEIGHT / h


func _setup_materials() -> void:
	var arr: Array = []
	_meshes(_root, arr)
	var sh := Shader.new()
	sh.code = KIT_SHADER
	for mi: MeshInstance3D in arr:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var nm: String = mi.name.to_lower()
		var key: String = ""
		if nm.contains("top"):
			key = "top"
		elif nm.contains("bottom"):
			key = "bottom"
		elif nm.contains("hair") and is_keeper:
			var src: Material = mi.get_active_material(0)
			if src is StandardMaterial3D:
				_hair_mat = (src as StandardMaterial3D).duplicate()
				_hair_mat.albedo_color = Color(0.55, 0.5, 0.48)
				mi.material_override = _hair_mat
		if key == "":
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		var src2: Material = mi.get_active_material(0)
		if src2 is StandardMaterial3D:
			var sm := src2 as StandardMaterial3D
			m.set_shader_parameter("tex", sm.albedo_texture)
			if sm.normal_enabled and sm.normal_texture != null:
				m.set_shader_parameter("nrm", sm.normal_texture)
				m.set_shader_parameter("has_nrm", true)
		# desen ölçüsü: ağın kendi biriminde gövde genişliği
		var bb: AABB = mi.get_aabb()
		m.set_shader_parameter("span", maxf(bb.size.x * 0.6, 0.0001))
		m.set_shader_parameter("cx", bb.get_center().x)
		mi.material_override = m
		_mats[key] = m


func _add_gloves() -> void:
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("f2f2f2")
	gm.roughness = 0.55
	for side in ["Left", "Right"]:
		var hb: int = bone(side + "Hand")
		var cb: int = bone(side + "HandMiddle1")
		if hb < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = skel.get_bone_name(hb)
		skel.add_child(att)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		mi.mesh = sm
		mi.material_override = gm
		var tip: Vector3 = skel.get_bone_rest(cb).origin if cb >= 0 else Vector3(0, 9, 0)
		var L: float = maxf(tip.length(), 0.001)
		# eldiven: avuç yönünde uzamış elips (kemik biriminde)
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, tip / L)).scaled(Vector3(L * 0.85, L * 1.3, L * 0.45)), tip * 0.6)
		att.add_child(mi)
		_gloves.append(mi)


## Animasyonlar: döngü ayarı. Ölçümler (dalış yönü, vuruş anı) _ready'de, iskelet
## gerçekten oynatılarak model uzayında yapılır; eksen varsayımı yok.
func _prepare_animations() -> void:
	for an in ap.get_animation_list():
		var a: Animation = ap.get_animation(an)
		if a != null and LOOPING.has(String(an).get_file()):
			a.loop_mode = Animation.LOOP_LINEAR
	var hb: int = bone("Hips")
	if hb >= 0:
		var r: Vector3 = _rel(skel) * skel.get_bone_global_rest(hb).origin
		_hips_rest_xz = Vector2(r.x, r.z)


func _ready() -> void:
	if ap != null and _info.is_empty():
		for nm in ["gk_dive", "gk_dive2", "penalty_kick", "gk_catch", "gk_block"]:
			_info[nm] = _sample(nm)
		_play("gk_idle" if is_keeper else "idle", 0.0)


## Animasyonu adım adım oynatıp kalçanın model uzayındaki yolunu ölç.
func _sample(base: String) -> Dictionary:
	var an: String = _anim_name(base)
	if an == "":
		return {}
	var a: Animation = ap.get_animation(an)
	var ln: float = a.length
	var hb: int = bone("Hips")
	var steps: int = 48
	var lat: PackedFloat32Array = []
	var fwd: PackedFloat32Array = []
	var times: PackedFloat32Array = []
	ap.play(an, 0.0)
	ap.speed_scale = 1.0
	var p0 := Vector3.ZERO
	for k in steps + 1:
		var tt: float = ln * k / steps
		ap.seek(tt, true)
		var p: Vector3 = _rel(skel) * skel.get_bone_global_pose(hb).origin
		if k == 0:
			p0 = p
		lat.append(p.x - p0.x)
		fwd.append(p.z - p0.z)
		times.append(tt)
	return _measure(lat, fwd, times)


func _measure(lat: PackedFloat32Array, fwd: PackedFloat32Array, times: PackedFloat32Array) -> Dictionary:
	var n: int = lat.size()
	var total: float = lat[n - 1]
	var t0: float = 0.0
	var t1: float = times[n - 1]
	var got0 := false
	for k in n:
		var f: float = lat[k] / total if absf(total) > 0.001 else 0.0
		if not got0 and f > 0.12:
			t0 = times[k]
			got0 = true
		if f > 0.85:
			t1 = times[k]
			break
	# vuruş anı: ileri hızın en yüksek olduğu andan sonra hızın yarıya düştüğü an
	var vmax: float = 0.0
	var kmax: int = 0
	for k in range(1, n):
		var v: float = (fwd[k] - fwd[k - 1]) / maxf(times[k] - times[k - 1], 0.001)
		if v > vmax:
			vmax = v
			kmax = k
	var contact: float = times[n - 1] * 0.55
	for k in range(kmax + 1, n):
		var v2: float = (fwd[k] - fwd[k - 1]) / maxf(times[k] - times[k - 1], 0.001)
		if v2 < vmax * 0.35:
			contact = times[k]
			break
	return {"lat": total, "t0": t0, "t1": t1, "contact": contact, "len": times[n - 1]}


func _anim_name(base: String) -> String:
	for an in ap.get_animation_list():
		if String(an).get_file() == base:
			return an
	return ""


func _play(base: String, blend: float = 0.15, speed: float = 1.0, from: float = 0.0) -> void:
	if ap == null:
		return
	var an: String = _anim_name(base)
	if an == "":
		return
	ap.play(an, blend)
	ap.speed_scale = speed
	if from > 0.0:
		ap.seek(from, true)


func apply_kit(kit: Dictionary, keeper_color: Color = Color.BLACK) -> void:
	var top: ShaderMaterial = _mats.get("top")
	var bot: ShaderMaterial = _mats.get("bottom")
	if is_keeper:
		if top:
			top.set_shader_parameter("col_a", keeper_color)
			top.set_shader_parameter("col_b", keeper_color)
			top.set_shader_parameter("pattern", 2)
		if bot:
			bot.set_shader_parameter("col_a", keeper_color.darkened(0.5))
			bot.set_shader_parameter("pattern", 2)
		var gc: Color = Color("f2f2f2") if keeper_color.get_luminance() < 0.55 else Color("262626")
		for g in _gloves:
			(g.material_override as StandardMaterial3D).albedo_color = gc
		return
	if kit.is_empty():
		return
	if top:
		top.set_shader_parameter("col_a", kit["a"])
		top.set_shader_parameter("col_b", kit["b"])
		top.set_shader_parameter("pattern", int(kit["pattern"]))
	if bot:
		bot.set_shader_parameter("col_a", kit["shorts"])
		bot.set_shader_parameter("pattern", 2)


## Koşu+vuruş toplam süresi: koşu (world.run_up süresi) + 0.2 sn sonra top
const RUN_TO_CONTACT := 0.8


func set_state(s: String) -> void:
	if s == "sad" and state == "dive":
		return   # yerdeki kaleci yerde kalsın
	var prev: String = state
	state = s
	state_t = 0.0
	_hop = 0.0
	match s:
		"idle":
			ap.stop()
			_play("idle", 0.0)
		"keeper_ready":
			# yeni atış: önceki dalıştan kalan her şeyi sıfırla
			ap.stop()
			ap.speed_scale = 1.0
			_dive_off = Vector3.ZERO
			_play("gk_idle", 0.0)
		"run":
			var inf: Dictionary = _info.get("penalty_kick", {})
			var c: float = float(inf.get("contact", 1.0))
			_play("penalty_kick", 0.12, 1.0, maxf(c - RUN_TO_CONTACT, 0.0))
		"kick":
			if prev != "run":
				var inf2: Dictionary = _info.get("penalty_kick", {})
				_play("penalty_kick", 0.05, 1.0, maxf(float(inf2.get("contact", 1.0)) - 0.2, 0.0))
		"celebrate":
			_play("idle", 0.25, 1.6)
		"keeper_celebrate":
			_play("gk_directing", 0.25)
		"sad":
			_play("idle", 0.3, 0.6)
		"dive":
			pass  # dive_to() oynatır


## Kaleci dalışı: d = kale düzleminde hedef (x: dünya x'i, y: yükseklik), dur = topun
## kaleye varış süresi. Eldivenlerin ortası tam bu noktaya, tam bu sürede ulaşır:
## görüntü ile kurtarış/gol kararı birebir aynı olur.
func dive_to(d: Vector2, dur: float) -> Tween:
	state = "dive"
	state_t = 0.0
	_dive_dur = maxf(dur, 0.2)
	_dive_base = Vector3(position.x, 0.0, position.z)
	_dive_off = Vector3.ZERO
	# dünya hedefini modelin yerel uzayına çevir (kaleci +Z'ye bakar)
	_dive_target = Vector3(d.x, clampf(d.y, 0.12, 2.5), 0.12)
	var local_x: float = (global_transform.affine_inverse() * _dive_target).x if is_inside_tree() else d.x
	var side: float = signf(local_x) if absf(d.x) > 0.9 else 0.0
	var pick: String = ""
	if side == 0.0:
		pick = "gk_catch" if d.y > 1.25 else "gk_block"
		var ln: float = float(_info.get(pick, {}).get("len", 2.0))
		_play(pick, 0.08, 1.6, ln * 0.18)
	else:
		# kalçası gerçekten o yana giden dalış animasyonu
		pick = "gk_dive"
		for cand in ["gk_dive", "gk_dive2"]:
			if signf(float(_info.get(cand, {}).get("lat", 0.0))) == side:
				pick = cand
		var inf: Dictionary = _info.get(pick, {})
		var t0: float = float(inf.get("t0", 0.6))
		var t1: float = float(inf.get("t1", 1.2))
		var start: float = maxf(t0 - 0.1, 0.0)
		_play(pick, 0.05, clampf((t1 - start) / _dive_dur, 0.8, 3.2), start)
	var tw := create_tween()
	tw.tween_interval(_dive_dur)
	tw.tween_callback(func() -> void: ap.speed_scale = 1.0)
	return tw


func hands_world() -> Vector3:
	var l: int = bone("LeftHand")
	var r: int = bone("RightHand")
	if l < 0 or r < 0:
		return global_position + Vector3(0, 1.0, 0)
	var g: Transform3D = skel.global_transform
	return (g * skel.get_bone_global_pose(l).origin + g * skel.get_bone_global_pose(r).origin) * 0.5


## Kalçayı yatayda yerinde tut (kök hareketini oyun kodu verir). Gerçek dönüşümlerle
## hesaplanır, iskeletin eksen düzenine bağlı değildir.
func _lock_root() -> void:
	var hb: int = bone("Hips")
	if hb < 0:
		return
	var hl: Vector3 = _rel(skel) * skel.get_bone_global_pose(hb).origin
	var want := Vector3(_hips_rest_xz.x, hl.y, _hips_rest_xz.y)
	var dm: Vector3 = want - hl
	if dm.length_squared() < 1e-8:
		return
	var ds: Vector3 = _rel(skel).basis.inverse() * dm
	var par: int = skel.get_bone_parent(hb)
	if par >= 0:
		ds = skel.get_bone_global_pose(par).basis.inverse() * ds
	skel.set_bone_pose_position(hb, skel.get_bone_pose_position(hb) + ds)


func _dive_follow(delta: float) -> void:
	if state_t > _dive_dur + 0.08:
		# top geçti: yerçekimi - havadaki kaleci yere iner
		_dive_off.y = move_toward(_dive_off.y, 0.0, delta * 4.5)
		position = _dive_base + _dive_off
		return
	_reach_arms(smoothstep(0.0, _dive_dur, state_t) * 0.9)
	var err: Vector3 = _dive_target - hands_world()
	var want: Vector3 = _dive_off + err
	want.y = clampf(want.y, 0.0, 1.6)
	want.z = clampf(want.z, -0.4, 0.4)
	var left: float = maxf(_dive_dur - state_t, 0.03)
	var k: float = clampf(delta / left * 1.6, 0.0, 1.0)
	_dive_off = _dive_off.lerp(want, k)
	position = _dive_base + _dive_off


## Kollar topa uzanır (dalış boyunca giderek artan ağırlıkla).
func _reach_arms(w: float) -> void:
	if w <= 0.0:
		return
	var g: Transform3D = skel.global_transform
	for side in ["Left", "Right"]:
		var ua: int = bone(side + "Arm")
		var fa: int = bone(side + "ForeArm")
		var hd: int = bone(side + "Hand")
		if ua < 0 or fa < 0 or hd < 0:
			continue
		var sh: Vector3 = g * skel.get_bone_global_pose(ua).origin
		var dir: Vector3 = _dive_target - sh
		_aim(ua, fa, dir, w)
		_aim(fa, hd, dir, w)


func _process(delta: float) -> void:
	t += delta
	state_t += delta
	if ap == null:
		return
	ap.advance(delta)
	_lock_root()
	match state:
		"dive":
			_dive_follow(delta)
		"celebrate":
			_hop = absf(sin(state_t * 7.0)) * 0.22 * clampf(3.0 - state_t, 0.0, 1.0)
			_root.position.y = _hop
			_raise_arms(1.0, 0.0)
		"sad":
			_root.position.y = 0.0
			_raise_arms(0.0, 1.0)
		_:
			_root.position.y = 0.0


## Kemik yönünü dünya uzayında hedefe çevir (animasyonun üstüne yazılır).
func _aim(b: int, child: int, target: Vector3, w: float) -> void:
	if b < 0 or child < 0 or w <= 0.0:
		return
	var sg: Transform3D = skel.global_transform
	var gb: Transform3D = skel.get_bone_global_pose(b)
	var gc: Transform3D = skel.get_bone_global_pose(child)
	var cur: Vector3 = (sg.basis * (gc.origin - gb.origin)).normalized()
	var want: Vector3 = cur.slerp(target.normalized(), w)
	if cur.cross(want).length() < 0.0001:
		return
	var qw := Quaternion(cur, want)
	var sb: Basis = sg.basis.orthonormalized()
	var qs: Quaternion = (sb.inverse() * Basis(qw) * sb).get_rotation_quaternion()
	var newg: Basis = Basis(qs) * gb.basis
	var par: int = skel.get_bone_parent(b)
	var pg: Basis = skel.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY
	var loc: Basis = pg.inverse() * newg
	skel.set_bone_pose_rotation(b, loc.get_rotation_quaternion())


func _raise_arms(up: float, head_hold: float) -> void:
	var fwd: Vector3 = global_basis.z
	var right: Vector3 = -global_basis.x
	if up > 0.0:
		var wave: float = sin(state_t * 9.0) * 0.15
		_aim(bone("LeftArm"), bone("LeftForeArm"), Vector3.UP * 1.0 - right * (0.35 + wave) + fwd * 0.1, up)
		_aim(bone("RightArm"), bone("RightForeArm"), Vector3.UP * 1.0 + right * (0.35 - wave) + fwd * 0.1, up)
		_aim(bone("LeftForeArm"), bone("LeftHand"), Vector3.UP - right * 0.15, up)
		_aim(bone("RightForeArm"), bone("RightHand"), Vector3.UP + right * 0.15, up)
	if head_hold > 0.0:
		# elleri başa, baş öne eğik
		_aim(bone("LeftArm"), bone("LeftForeArm"), Vector3.UP * 0.55 - right * 0.8 + fwd * 0.35, head_hold)
		_aim(bone("RightArm"), bone("RightForeArm"), Vector3.UP * 0.55 + right * 0.8 + fwd * 0.35, head_hold)
		_aim(bone("LeftForeArm"), bone("LeftHand"), Vector3.UP * 0.6 + right * 0.9 - fwd * 0.2, head_hold)
		_aim(bone("RightForeArm"), bone("RightHand"), Vector3.UP * 0.6 - right * 0.9 - fwd * 0.2, head_hold)
		_aim(bone("Neck"), bone("Head"), Vector3.UP * 0.75 + fwd * 0.65, head_hold)
