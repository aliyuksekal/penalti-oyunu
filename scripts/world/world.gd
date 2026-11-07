extends Node3D
## Görsel dünya: stadyum, şutçu, kaleci, top, kamera ve efektler.
## Oyun mantığı scripts/game/match.gd içinde; burası yalnızca gösterir.

const Stadium = preload("res://scripts/world/stadium.gd")
const PlayerModel = preload("res://scripts/world/player_model.gd")
const Ball = preload("res://scripts/world/ball.gd")

const SPOT := Vector3(0, 0.11, 11.0)

var stadium: Stadium
var shooter: PlayerModel
var keeper: PlayerModel
var ball: Ball
var camera: Camera3D
var confetti: CPUParticles3D
var scan: MeshInstance3D
var cam_mode: String = "menu"
var _cam_tw: Tween
var _orbit: float = 0.0
var _shake: float = 0.0
var _shake_t: float = 0.0
var my_kit: String = "red_yellow"
var rival_kit: String = "yellow_navy"


func _ready() -> void:
	stadium = Stadium.new()
	add_child(stadium)
	shooter = PlayerModel.new(false, Color("c4875f"), Color("1e140c"))
	add_child(shooter)
	keeper = PlayerModel.new(true, Color("b27650"), Color("121010"))
	add_child(keeper)
	ball = Ball.new()
	add_child(ball)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	camera.current = true
	_build_confetti()
	_build_scan()
	setup_kits(my_kit, rival_kit)
	place_menu()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _fit_camera() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 58.0 if cam_mode != "keep" else 70.0
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 40.0 if cam_mode != "keep" else 52.0


func setup_kits(mine: String, rival: String) -> void:
	my_kit = mine
	rival_kit = rival
	var a: Dictionary = Kits.get_kit(mine)
	var b: Dictionary = Kits.get_kit(rival)
	stadium.set_crowd_colors(a["a"], a["b"], b["a"], b["b"])


func _process(delta: float) -> void:
	if cam_mode == "menu":
		_orbit += delta * 0.12
		var c := Vector3(0, 1.0, 5.0)
		camera.position = c + Vector3(sin(_orbit) * 10.0, 2.6 + sin(_orbit * 0.7) * 0.5, cos(_orbit) * 10.0)
		camera.look_at(c, Vector3.UP)
	if _shake_t > 0.0:
		_shake_t -= delta
		var k: float = _shake * clampf(_shake_t / 0.5, 0.0, 1.0)
		camera.h_offset = randf_range(-k, k)
		camera.v_offset = randf_range(-k, k)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func shake(amount: float = 0.12, dur: float = 0.5) -> void:
	_shake = amount
	_shake_t = dur


func _set_cam(pos: Vector3, look: Vector3, instant: bool, dur: float = 0.8) -> void:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	if instant:
		camera.position = pos
		camera.look_at(look, Vector3.UP)
		return
	var from_pos: Vector3 = camera.position
	var from_q: Quaternion = camera.quaternion
	var tmp := Node3D.new()
	add_child(tmp)
	tmp.position = pos
	tmp.look_at(look, Vector3.UP)
	var to_q: Quaternion = tmp.quaternion
	tmp.queue_free()
	var step := func(v: float) -> void:
		camera.position = from_pos.lerp(pos, v)
		camera.quaternion = from_q.slerp(to_q, v)
	_cam_tw = create_tween()
	_cam_tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------- yerleşimler ----------------
func _reset_ball() -> void:
	ball.position = SPOT
	ball.rotation = Vector3.ZERO
	ball.trail.emitting = false
	ball.visible = true


func place_menu() -> void:
	cam_mode = "menu"
	stadium.set_back_net_visible(true)
	_fit_camera()
	shooter.apply_kit(Kits.get_kit(my_kit))
	keeper.apply_kit({}, Kits.KEEPER[rival_kit])
	shooter.position = Vector3(-0.6, 0, 6.0)
	shooter.rotation = Vector3(0, 0.3, 0)
	shooter.set_state("idle")
	keeper.position = Vector3(0, 0, 0.3)
	keeper.rotation = Vector3.ZERO
	keeper.set_state("keeper_ready")
	ball.position = Vector3(-0.2, 0.11, 6.4)


func place_kits() -> void:
	cam_mode = "kits"
	stadium.set_back_net_visible(true)
	_fit_camera()
	shooter.apply_kit(Kits.get_kit(my_kit))
	keeper.apply_kit({}, Kits.KEEPER[rival_kit])
	shooter.position = Vector3(-0.75, 0, 5.4)
	shooter.rotation = Vector3(0, 0.25, 0)
	shooter.set_state("idle")
	keeper.position = Vector3(0.85, 0, 5.4)
	keeper.rotation = Vector3(0, -0.25, 0)
	keeper.set_state("keeper_ready")
	ball.position = Vector3(-0.35, 0.11, 6.0)
	_set_cam(Vector3(0, 1.35, 9.6), Vector3(0, 1.0, 5.4), false, 0.9)


## Oyuncu şut atar: şutçu = senin forman, kaleci = rakibin kaleci forması
func place_for_shoot(instant: bool = false) -> void:
	cam_mode = "shoot"
	_fit_camera()
	shooter.apply_kit(Kits.get_kit(my_kit))
	keeper.apply_kit({}, Kits.KEEPER[rival_kit])
	stadium.set_back_net_visible(true)
	_reset_players()
	_reset_ball()
	shooter.position = Vector3(-0.85, 0, 12.55)
	shooter.rotation = Vector3(0, PI + 0.45, 0)
	scan.visible = true
	var portrait: bool = get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y
	if portrait:
		_set_cam(Vector3(0.45, 1.6, 14.6), Vector3(-0.1, 1.05, 1.0), instant, 0.9)
	else:
		_set_cam(Vector3(0.55, 1.42, 15.35), Vector3(-0.1, 1.1, 0.0), instant, 0.9)


## Yapay zekâ şut atar: şutçu = rakip forma, kaleci = senin kaleci forman
func place_for_keep(instant: bool = false) -> void:
	cam_mode = "keep"
	_fit_camera()
	shooter.apply_kit(Kits.get_kit(rival_kit))
	keeper.apply_kit({}, Kits.KEEPER[my_kit])
	stadium.set_back_net_visible(false)
	_reset_players()
	_reset_ball()
	_set_cam(Vector3(0, 1.7, -2.9), Vector3(0, 0.85, 11.0), instant, 0.9)


func keeper_screen_pos() -> Vector2:
	return camera.unproject_position(keeper.global_position + Vector3(0, 1.9, 0))


func _reset_players() -> void:
	scan.visible = false
	shooter.position = Vector3(-0.9, 0, 13.6)
	shooter.rotation = Vector3(0, PI + 0.35, 0)
	shooter.set_state("idle")
	keeper.position = Vector3(0, 0, 0.25)
	keeper.rotation = Vector3.ZERO
	keeper.set_state("keeper_ready")


# ---------------- animasyonlar ----------------
## Koşu + vuruş. Bittiğinde (topa değdiği an) sinyal verir.
func run_up(duration: float = 0.6) -> void:
	shooter.set_state("run")
	var tw := create_tween()
	scan.visible = false
	tw.tween_property(shooter, "position", Vector3(-0.34, 0, 11.42), duration)
	tw.parallel().tween_property(shooter, "rotation:y", PI + 0.25, duration)
	await tw.finished
	shooter.set_state("kick")
	await get_tree().create_timer(0.2, false).timeout


## Kaleci dalışı: D = (x, y) kale düzleminde hedef, dur = süre
func dive(d: Vector2, dur: float) -> void:
	var feet_x: float = d.x * 0.32
	var v := Vector2(d.x - feet_x, maxf(d.y, 0.15))
	var ang: float = atan2(-v.x, v.y)
	ang = clampf(ang, -1.45, 1.45)
	var lift: float = clampf(v.length() - 1.95, 0.0, 0.9) * cos(ang)
	if absf(d.x) < 0.9 and d.y < 1.2:
		# ortaya gelen top: çömel / yerinde kal
		ang = 0.0
		lift = 0.0
	elif absf(d.x) < 0.9:
		lift = clampf(d.y - 1.6, 0.0, 0.6)
		ang = 0.0
	keeper.dive_dir = Vector2(signf(d.x) if absf(d.x) > 0.9 else 0.0, clampf((d.y - 0.6) / 1.4, 0.0, 1.0))
	keeper.set_state("dive")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(keeper, "position", Vector3(feet_x, lift, 0.35), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(keeper, "rotation", Vector3(0, 0, ang), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	if absf(ang) > 0.6:
		# yere düşüş
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(keeper, "position:y", 0.12, 0.25).set_ease(Tween.EASE_IN)
		t2.tween_property(keeper, "rotation:z", signf(ang) * 1.5, 0.25)


func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


## Top uçuşu: kale çizgisindeki geçiş noktası 'cross', sonra sonuca göre devam.
## kind: goal / saved / post / miss
func fly(cross: Vector2, flight: float, curl: float, kind: String) -> void:
	_reset_ball_trail(true)
	var start: Vector3 = ball.position
	var end := Vector3(cross.x, cross.y, 0.0)
	var mid: Vector3 = (start + end) * 0.5 + Vector3(curl * 1.6, 0.35 + absf(end.y - start.y) * 0.25, 0)
	ball.spin_axis = Vector3(1, curl * 2.0, 0)
	ball.spin_speed = 30.0
	var fstep := func(v: float) -> void:
		ball.position = _bezier(start, mid, end, v)
	var tw := create_tween()
	tw.tween_method(fstep, 0.0, 1.0, flight)
	await tw.finished
	match kind:
		"goal":
			var into := Vector3(cross.x * 0.9, maxf(0.25, cross.y * 0.85), -1.65)
			stadium.net_hit(Vector3(cross.x, cross.y, -1.7))
			var t2 := create_tween()
			t2.tween_property(ball, "position", into, 0.18)
			t2.tween_property(ball, "position", Vector3(into.x, 0.11, -1.4), 0.35).set_ease(Tween.EASE_IN)
			await t2.finished
		"saved":
			var out := Vector3(cross.x + signf(cross.x + 0.01) * 2.2, 0.11, 3.0)
			var s3 := func(v: float) -> void:
				var p: Vector3 = end.lerp(out, v)
				p.y = lerpf(end.y, 0.11, v) + sin(v * PI) * 1.2
				ball.position = p
			var t3 := create_tween()
			t3.tween_method(s3, 0.0, 1.0, 0.6)
			await t3.finished
		"post":
			var out2 := Vector3(cross.x - signf(cross.x) * 1.5, 0.11, 5.5)
			var s4 := func(v: float) -> void:
				var p: Vector3 = end.lerp(out2, v)
				p.y = lerpf(end.y, 0.11, v) + sin(v * PI) * 0.6
				ball.position = p
			var t4 := create_tween()
			t4.tween_method(s4, 0.0, 1.0, 0.55)
			await t4.finished
		_:
			var out3: Vector3 = end + (end - start).normalized() * 7.0
			out3.y = maxf(0.11, out3.y)
			var t5 := create_tween()
			t5.tween_property(ball, "position", out3, 0.45)
			await t5.finished
	_reset_ball_trail(false)


func _reset_ball_trail(on: bool) -> void:
	ball.trail.emitting = on


func celebrate_goal(scorer_is_player: bool) -> void:
	shooter.set_state("celebrate")
	keeper.set_state("sad")
	shake(0.09, 0.6)
	stadium.excite(1.0 if scorer_is_player else 0.55, 3.5)
	var kit: Dictionary = Kits.get_kit(my_kit if scorer_is_player else rival_kit)
	var g := Gradient.new()
	g.set_color(0, kit["a"])
	g.set_color(1, kit["b"])
	confetti.color_initial_ramp = g
	confetti.restart()
	confetti.emitting = true


func celebrate_save() -> void:
	keeper.set_state("keeper_celebrate")
	keeper.position.y = 0.0
	keeper.rotation = Vector3.ZERO
	shooter.set_state("sad")
	stadium.excite(0.6, 2.0)


func miss_reaction() -> void:
	shooter.set_state("sad")
	stadium.excite(0.35, 1.5)


const SCAN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
	float edge = max(smoothstep(0.42, 0.5, abs(UV.x - 0.5)), smoothstep(0.44, 0.5, abs(UV.y - 0.5)));
	float corner = step(0.38, abs(UV.x - 0.5)) * step(0.38, abs(UV.y - 0.5));
	float lines = smoothstep(0.85, 1.0, sin((UV.y * 60.0) - TIME * 6.0) * 0.5 + 0.5);
	float sweep = exp(-pow((fract(TIME * 0.6) - UV.y) * 9.0, 2.0));
	float grid = step(0.94, fract(UV.x * 18.0)) + step(0.94, fract(UV.y * 22.0));
	vec3 c = vec3(0.2, 0.85, 1.0);
	float a = edge * 0.25 + corner * edge * 0.9 + lines * 0.05 + sweep * 0.35 + grid * 0.04;
	ALBEDO = c * a * 2.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


func _build_scan() -> void:
	scan = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 2.15)
	scan.mesh = q
	var sh := Shader.new()
	sh.code = SCAN_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	scan.material_override = m
	scan.position = Vector3(0, 1.0, 0.6)
	scan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scan.visible = false
	add_child(scan)


func _build_confetti() -> void:
	confetti = CPUParticles3D.new()
	confetti.amount = 220
	confetti.lifetime = 3.0
	confetti.one_shot = true
	confetti.explosiveness = 0.9
	confetti.emitting = false
	confetti.position = Vector3(0, 3.2, -0.5)
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(4.5, 0.2, 0.6)
	confetti.direction = Vector3(0, 1, 0.6)
	confetti.spread = 50.0
	confetti.initial_velocity_min = 4.0
	confetti.initial_velocity_max = 8.0
	confetti.gravity = Vector3(0, -4.0, 0)
	confetti.damping_min = 1.0
	confetti.damping_max = 2.0
	confetti.angular_velocity_min = -400.0
	confetti.angular_velocity_max = 400.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.05)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.3, 0.3, 0.3)
	qm.material = m
	confetti.mesh = qm
	add_child(confetti)
