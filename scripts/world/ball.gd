extends Node3D
## Top: ikosahedron köşelerine göre siyah yamalı shader, iz parçacıkları ve stil seçenekleri.

const RADIUS := 0.11
const BALL_SHADER := """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.97);
uniform vec3 patch : source_color = vec3(0.07, 0.08, 0.12);
uniform float emit = 0.0;
varying vec3 n;
void vertex() { n = normalize(VERTEX); }
void fragment() {
	float phi = 1.618034;
	vec3 v[12] = vec3[](
		vec3(-1.0, phi, 0.0), vec3(1.0, phi, 0.0), vec3(-1.0, -phi, 0.0), vec3(1.0, -phi, 0.0),
		vec3(0.0, -1.0, phi), vec3(0.0, 1.0, phi), vec3(0.0, -1.0, -phi), vec3(0.0, 1.0, -phi),
		vec3(phi, 0.0, -1.0), vec3(phi, 0.0, 1.0), vec3(-phi, 0.0, -1.0), vec3(-phi, 0.0, 1.0));
	float m = 0.0;
	for (int i = 0; i < 12; i++) { m = max(m, dot(n, normalize(v[i]))); }
	float p = smoothstep(0.90, 0.915, m);
	vec3 col = mix(base, patch, p);
	ALBEDO = col;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	EMISSION = base * emit;
}
"""
## stil: [taban rengi, yama rengi, iz rengi, ışıma]
const STYLES: Array = [
	[Color(0.97, 0.97, 0.97), Color(0.07, 0.08, 0.12), Color(1, 1, 1, 0.8), 0.0],
	[Color(1.0, 0.82, 0.25), Color(0.55, 0.35, 0.0), Color(1.0, 0.85, 0.3, 0.9), 0.15],
	[Color(0.15, 1.0, 0.85), Color(0.6, 0.1, 0.9), Color(0.2, 1.0, 0.9, 0.95), 0.6],
	[Color(1.0, 0.45, 0.1), Color(0.6, 0.05, 0.0), Color(1.0, 0.4, 0.05, 1.0), 0.5],
	[Color(0.75, 0.92, 1.0), Color(0.2, 0.45, 0.8), Color(0.6, 0.9, 1.0, 0.9), 0.3],
]

var mat: ShaderMaterial
var mesh_i: MeshInstance3D
var trail: CPUParticles3D
var spin_axis: Vector3 = Vector3.RIGHT
var spin_speed: float = 0.0


func _ready() -> void:
	mesh_i = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 28
	sm.rings = 14
	mesh_i.mesh = sm
	var sh := Shader.new()
	sh.code = BALL_SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	mesh_i.material_override = mat
	add_child(mesh_i)
	trail = CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.emitting = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.05
	trail.scale_amount_min = 0.9
	trail.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var qm := SphereMesh.new()
	qm.radius = 0.085
	qm.height = 0.17
	qm.radial_segments = 8
	qm.rings = 4
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.vertex_color_use_as_albedo = true
	qm.material = tm
	trail.mesh = qm
	add_child(trail)
	apply_style(0)


func apply_style(i: int) -> void:
	var s: Array = STYLES[clampi(i, 0, STYLES.size() - 1)]
	mat.set_shader_parameter("base", s[0])
	mat.set_shader_parameter("patch", s[1])
	mat.set_shader_parameter("emit", s[3])
	var g := Gradient.new()
	var c: Color = s[2]
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	trail.color_ramp = g


func _process(delta: float) -> void:
	if spin_speed > 0.01:
		mesh_i.rotate(spin_axis.normalized(), spin_speed * delta)
		spin_speed = maxf(0.0, spin_speed - delta * 4.0)
