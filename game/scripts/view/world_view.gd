class_name WorldView
extends Node3D
## Draws the simulation in 3D. Lives inside the playfield SubViewport.
## Gameplay (x, y) maps to world (X, Z); Y is up toward the camera.

const FOV := 30.0          # vertical field of view, degrees
const TILT := 10.0         # camera tilt away from straight down, degrees
const BULLET_HEIGHT := 0.6
const FX_MAX := 1536
const STRIDE := 16         # MultiMesh floats per instance: 12 transform + 4 custom

# Looks for projectile and effect ids: [colour, intensity, width, length, core radius].
const SPRITES := {
	"proj.laser.t1": [Color(0.15, 0.85, 1.0), 3.0, 1.7, 6.5, 0.32],
	"proj.chaingun.t1": [Color(1.0, 0.8, 0.35), 2.6, 1.0, 3.8, 0.28],
	"proj.enemy.orb": [Color(1.0, 0.28, 0.08), 2.6, 2.9, 2.9, 0.42],
	"proj.enemy.shard": [Color(1.0, 0.1, 0.65), 2.6, 2.2, 3.8, 0.4],
	"fx.spark": [Color(1.0, 0.55, 0.15), 3.0, 0.55, 2.6, 0.25],
	"fx.spark.hit": [Color(0.5, 0.85, 1.0), 2.5, 0.45, 1.8, 0.25],
	"fx.flash": [Color(1.0, 0.7, 0.35), 2.2, 2.0, 2.0, 0.35],
	"fx.trail": [Color(0.25, 0.55, 1.0), 2.0, 0.9, 2.6, 0.2],
	"fx.muzzle": [Color(0.8, 0.9, 1.0), 2.0, 1.6, 1.6, 0.3],
}
const SPRITE_FALLBACK := [Color(1, 0, 1), 3.0, 2.0, 2.0, 0.3]

var sim: GameSim
var camera: Camera3D
var environment: Environment

var _ship_root: Node3D
var _ship: MeshInstance3D
var _shield: MeshInstance3D
var _shield_mat: ShaderMaterial
var _shield_flash: float = 0.0

var _pb_mm: MultiMesh
var _eb_mm: MultiMesh
var _fx_mm: MultiMesh
var _pb_buf: PackedFloat32Array
var _eb_buf: PackedFloat32Array
var _fx_buf: PackedFloat32Array
var _add_mat: ShaderMaterial
var _solid_mat: ShaderMaterial
var _fx_mat: ShaderMaterial

var _stars_mat: ShaderMaterial
var _planet: MeshInstance3D
var _planet_mat: ShaderMaterial

var _enemy_nodes: Array[MeshInstance3D] = []
var _enemy_uid: PackedInt32Array
var _enemy_flash: PackedByteArray
var _node_pool: Dictionary = {}   # model id -> Array of free MeshInstance3D
var _flash_mat: StandardMaterial3D

# Effects are purely visual, so they run on frame time, not simulation time.
var _fx_count: int = 0
var _fx_x: PackedFloat32Array
var _fx_y: PackedFloat32Array
var _fx_vx: PackedFloat32Array
var _fx_vy: PackedFloat32Array
var _fx_life: PackedFloat32Array
var _fx_inv_life: PackedFloat32Array
var _fx_scale: PackedFloat32Array
var _fx_kind: PackedInt32Array
var _k_spark: int
var _k_hit: int
var _k_flash: int
var _k_trail: int
var _k_muzzle: int
var _trail_acc: float = 0.0
var _shake: float = 0.0
var _cam_base: Vector3
var _rng := RandomNumberGenerator.new()


## Width / height of the playfield viewport such that the bottom edge of the
## playfield exactly spans the viewport width.
static func playfield_aspect() -> float:
	var a := deg_to_rad(FOV * 0.5)
	var th := deg_to_rad(TILT)
	var h := 2.0 * GameSim.HALF_H / (tan(th + a) - tan(th - a))
	var half_w_at_aspect_1 := h * sin(a) / cos(th - a)
	return GameSim.HALF_W / half_w_at_aspect_1


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	_build_camera()
	_build_background()
	_build_ship()
	_build_sprites()
	_enemy_nodes.resize(GameSim.MAX_ENEMIES)
	_enemy_uid.resize(GameSim.MAX_ENEMIES)
	_enemy_flash.resize(GameSim.MAX_ENEMIES)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.6, 1.6, 1.6)


func _build_camera() -> void:
	var a := deg_to_rad(FOV * 0.5)
	var th := deg_to_rad(TILT)
	var h := 2.0 * GameSim.HALF_H / (tan(th + a) - tan(th - a))
	var cz := GameSim.HALF_H + h * tan(th - a)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 20.0
	camera.far = 1200.0
	_cam_base = Vector3(0.0, h, cz)
	camera.position = _cam_base
	camera.rotation_degrees = Vector3(-(90.0 - TILT), 0.0, 0.0)
	add_child(camera)
	camera.make_current()

	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.01)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.52, 0.7)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = bool(Settings.values["glow"])
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	camera.environment = environment

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = false
	add_child(sun)


func _build_background() -> void:
	var stars := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 1000)
	stars.mesh = plane
	_stars_mat = ShaderMaterial.new()
	_stars_mat.shader = load("res://shaders/starfield.gdshader")
	stars.material_override = _stars_mat
	stars.position = Vector3(0, -300, -60)
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

	_planet = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 110.0
	sphere.height = 220.0
	sphere.radial_segments = 96
	sphere.rings = 48
	_planet.mesh = sphere
	_planet_mat = ShaderMaterial.new()
	_planet_mat.shader = load("res://shaders/planet.gdshader")
	_planet.material_override = _planet_mat
	_planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_planet.rotation_degrees = Vector3(20, 0, 15)
	add_child(_planet)


func _build_ship() -> void:
	_ship_root = Node3D.new()
	add_child(_ship_root)
	_ship = MeshInstance3D.new()
	_ship.mesh = PlaceholderModels.get_mesh("ship.player.default")
	_ship_root.add_child(_ship)

	_shield = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	_shield.mesh = s
	_shield.scale = Vector3(4.6, 3.0, 5.0)
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = load("res://shaders/shield.gdshader")
	_shield.material_override = _shield_mat
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ship_root.add_child(_shield)
	refresh_loadout()


## Call after the player's equipment changes.
func refresh_loadout() -> void:
	var tint := Color(0.25, 0.6, 1.0)
	match sim.player.shield_visual:
		"fx.shield.flicker":
			tint = Color(1.0, 0.9, 0.4)
		"fx.shield.mirror":
			tint = Color(0.75, 0.45, 1.0)
	_shield_mat.set_shader_parameter("tint", tint)


func _build_sprites() -> void:
	_k_spark = sim.kind_of("fx.spark")
	_k_hit = sim.kind_of("fx.spark.hit")
	_k_flash = sim.kind_of("fx.flash")
	_k_trail = sim.kind_of("fx.trail")
	_k_muzzle = sim.kind_of("fx.muzzle")

	_add_mat = ShaderMaterial.new()
	_add_mat.shader = load("res://shaders/sprite_add.gdshader")
	_add_mat.render_priority = 2
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://shaders/sprite_add.gdshader")
	_fx_mat.render_priority = 1
	_solid_mat = ShaderMaterial.new()
	_solid_mat.shader = load("res://shaders/sprite_solid.gdshader")
	_solid_mat.render_priority = 3
	refresh_sprite_table()

	_fx_buf = _make_buffer(FX_MAX)
	_pb_buf = _make_buffer(GameSim.PLAYER_BULLETS)
	_eb_buf = _make_buffer(GameSim.ENEMY_BULLETS)
	_fx_mm = _make_multimesh(FX_MAX, _fx_mat)
	_pb_mm = _make_multimesh(GameSim.PLAYER_BULLETS, _add_mat)
	_eb_mm = _make_multimesh(GameSim.ENEMY_BULLETS, _solid_mat)

	_fx_x.resize(FX_MAX)
	_fx_y.resize(FX_MAX)
	_fx_vx.resize(FX_MAX)
	_fx_vy.resize(FX_MAX)
	_fx_life.resize(FX_MAX)
	_fx_inv_life.resize(FX_MAX)
	_fx_scale.resize(FX_MAX)
	_fx_kind.resize(FX_MAX)


## Rebuilds the shader lookup tables from the visual ids the simulation has registered.
func refresh_sprite_table() -> void:
	var colors := PackedVector4Array()
	var shapes := PackedVector4Array()
	colors.resize(32)
	shapes.resize(32)
	for k in mini(sim.kind_names.size(), 32):
		var id := sim.kind_names[k]
		var s: Array = SPRITES.get(id, SPRITE_FALLBACK)
		if not SPRITES.has(id):
			push_warning("No sprite look for '%s', using placeholder" % id)
		var c: Color = s[0]
		var i: float = s[1]
		colors[k] = Vector4(c.r * i, c.g * i, c.b * i, 1.0)
		shapes[k] = Vector4(s[2], s[3], s[4], 0.0)
	for m: ShaderMaterial in [_add_mat, _fx_mat, _solid_mat]:
		m.set_shader_parameter("colors", colors)
		m.set_shader_parameter("shapes", shapes)


func _make_buffer(capacity: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(capacity * STRIDE)
	for i in capacity:
		var o := i * STRIDE
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
		buf[o + 7] = BULLET_HEIGHT
		buf[o + 13] = 1.0
	return buf


func _make_multimesh(capacity: int, mat: ShaderMaterial) -> MultiMesh:
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-80, -5, -90), Vector3(160, 10, 180))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return mm


# ---------------------------------------------------------------- events

func handle_event(type: int, ex: float, ey: float, value: float) -> void:
	match type:
		GameSim.EV_EXPLOSION:
			_explode(ex, ey, value)
		GameSim.EV_HIT:
			for i in 2:
				_spawn_fx(_k_hit, ex, ey, _rng.randf_range(-30, 30), _rng.randf_range(10, 60), 0.12, 1.0)
		GameSim.EV_SHIELD_HIT:
			_shield_flash = 1.0
		GameSim.EV_HULL_HIT:
			_shake = minf(1.0, _shake + 0.25 + value * 0.02)
			for i in 6:
				var a := _rng.randf() * TAU
				var sp := _rng.randf_range(20, 60)
				_spawn_fx(_k_spark, ex, ey, cos(a) * sp, sin(a) * sp, 0.3, 1.0)
		GameSim.EV_SHOT:
			_spawn_fx(_k_muzzle, ex, ey - 0.5, 0.0, 0.0, 0.04, 1.0)
		GameSim.EV_RESTART:
			_fx_count = 0
			_shake = 0.0


func _explode(ex: float, ey: float, radius: float) -> void:
	_spawn_fx(_k_flash, ex, ey, 0.0, 0.0, 0.16, radius * 2.4)
	var n := int(8 + radius * 3.0)
	for i in n:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(15.0, 55.0 + radius * 6.0)
		_spawn_fx(_k_spark, ex, ey, cos(a) * sp, sin(a) * sp + sim.scroll_speed, _rng.randf_range(0.25, 0.6), 1.0)
	_shake = minf(1.0, _shake + radius * 0.035)


func _spawn_fx(kind: int, fx: float, fy: float, fvx: float, fvy: float, life: float, scale: float) -> void:
	if _fx_count >= FX_MAX:
		return
	var i := _fx_count
	_fx_x[i] = fx
	_fx_y[i] = fy
	_fx_vx[i] = fvx
	_fx_vy[i] = fvy
	_fx_life[i] = life
	_fx_inv_life[i] = 1.0 / life
	_fx_scale[i] = scale
	_fx_kind[i] = kind
	_fx_count += 1


# ---------------------------------------------------------------- per-frame draw

## alpha: how far between the previous and the current simulation tick this frame is (0..1).
func render(alpha: float, frame_dt: float, tick_dt: float, running: bool) -> void:
	var p := sim.player

	# Player ship
	var px := lerpf(p.ox, p.x, alpha)
	var py := lerpf(p.oy, p.y, alpha)
	_ship_root.position = Vector3(px, 0.0, py)
	var blink := p.invulnerable > 0.0 and fmod(p.invulnerable, 0.2) > 0.1
	_ship_root.visible = p.alive
	_ship.visible = not blink
	_ship.rotation.z = lerpf(_ship.rotation.z, -clampf(p.vx / maxf(p.max_speed, 1.0), -1.0, 1.0) * 0.55,
			minf(1.0, frame_dt * 14.0))
	_shield_flash = maxf(0.0, _shield_flash - frame_dt * 5.0)
	var charge := 0.0
	if p.shield_max > 0.0:
		charge = p.shield / p.shield_max
	_shield.visible = charge > 0.0 or _shield_flash > 0.0
	_shield_mat.set_shader_parameter("strength", charge)
	_shield_mat.set_shader_parameter("flash", _shield_flash)

	# Engine trail
	if running and p.alive:
		_trail_acc += frame_dt * 90.0
		while _trail_acc >= 1.0:
			_trail_acc -= 1.0
			var side := -0.95 if (_fx_count & 1) == 0 else 0.95
			_spawn_fx(_k_trail, px + side, py + 4.2, p.vx * 0.2, 55.0, 0.16, 1.0)

	_render_enemies(alpha)

	var lag := (1.0 - alpha) * tick_dt if running else 0.0
	_add_mat.set_shader_parameter("lag", lag)
	_solid_mat.set_shader_parameter("lag", lag)
	_fill_bullets(sim.pbul, _pb_mm, _pb_buf)
	_fill_bullets(sim.ebul, _eb_mm, _eb_buf)
	_update_fx(frame_dt if running else 0.0)

	# Background
	_stars_mat.set_shader_parameter("scroll", sim.scroll)
	var cycle := 700.0
	var pz := fposmod(sim.scroll * 0.35 + 250.0, cycle) - cycle * 0.5
	_planet.position = Vector3(-70.0, -190.0, pz - 30.0)
	_planet_mat.set_shader_parameter("spin", sim.time * 0.006)
	_planet_mat.set_shader_parameter("cloud_shift", sim.time * 0.004)

	# Screen shake
	var shake_amount: float = _shake * _shake * 1.6 * float(Settings.values["screen_shake"])
	_shake = maxf(0.0, _shake - frame_dt * 2.5)
	if shake_amount > 0.001:
		camera.position = _cam_base + Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * shake_amount
	else:
		camera.position = _cam_base


func _render_enemies(alpha: float) -> void:
	var now := sim.time
	var enemies := sim.enemies
	for i in GameSim.MAX_ENEMIES:
		var e := enemies[i]
		var node := _enemy_nodes[i]
		if not e.alive:
			if node != null:
				_release_node(i)
			continue
		if node != null and _enemy_uid[i] != e.uid:
			_release_node(i)
			node = null
		if node == null:
			node = _acquire_node(e.type.model)
			_enemy_nodes[i] = node
			_enemy_uid[i] = e.uid
			_enemy_flash[i] = 0
		var ex := lerpf(e.ox, e.x, alpha)
		node.position = Vector3(ex, 0.0, lerpf(e.oy, e.y, alpha))
		node.rotation.z = clampf((e.x - e.ox) * 3.0, -0.6, 0.6)
		var flashing := 1 if now - e.hit_time < 0.05 else 0
		if flashing != _enemy_flash[i]:
			_enemy_flash[i] = flashing
			node.material_overlay = _flash_mat if flashing == 1 else null


func _acquire_node(model: String) -> MeshInstance3D:
	var free: Array = _node_pool.get(model, [])
	var node: MeshInstance3D
	if free.is_empty():
		node = MeshInstance3D.new()
		node.mesh = PlaceholderModels.get_mesh(model)
		node.set_meta("model", model)
		add_child(node)
	else:
		node = free.pop_back()
	node.visible = true
	return node


func _release_node(slot: int) -> void:
	var node := _enemy_nodes[slot]
	node.visible = false
	node.material_overlay = null
	var model: String = node.get_meta("model")
	if not _node_pool.has(model):
		_node_pool[model] = []
	(_node_pool[model] as Array).append(node)
	_enemy_nodes[slot] = null


func _fill_bullets(pool: BulletPool, mm: MultiMesh, buf: PackedFloat32Array) -> void:
	var n := pool.count
	var bx := pool.x
	var by := pool.y
	var bvx := pool.vx
	var bvy := pool.vy
	var bkind := pool.kind
	var o := 0
	for i in n:
		buf[o + 3] = bx[i]
		buf[o + 11] = by[i]
		buf[o + 12] = bkind[i]
		buf[o + 14] = bvx[i]
		buf[o + 15] = bvy[i]
		o += STRIDE
	mm.buffer = buf
	mm.visible_instance_count = n


func _update_fx(dt: float) -> void:
	var buf := _fx_buf
	var drag := maxf(0.0, 1.0 - dt * 2.5)
	var i := 0
	var o := 0
	while i < _fx_count:
		var l := _fx_life[i] - dt
		if l <= 0.0:
			var last := _fx_count - 1
			_fx_x[i] = _fx_x[last]
			_fx_y[i] = _fx_y[last]
			_fx_vx[i] = _fx_vx[last]
			_fx_vy[i] = _fx_vy[last]
			_fx_life[i] = _fx_life[last]
			_fx_inv_life[i] = _fx_inv_life[last]
			_fx_scale[i] = _fx_scale[last]
			_fx_kind[i] = _fx_kind[last]
			_fx_count = last
			continue
		_fx_life[i] = l
		var vx := _fx_vx[i] * drag
		var vy := _fx_vy[i] * drag
		_fx_vx[i] = vx
		_fx_vy[i] = vy
		var x := _fx_x[i] + vx * dt
		var y := _fx_y[i] + vy * dt
		_fx_x[i] = x
		_fx_y[i] = y
		var s := _fx_scale[i]
		buf[o] = s
		buf[o + 10] = s
		buf[o + 3] = x
		buf[o + 11] = y
		buf[o + 12] = _fx_kind[i]
		buf[o + 13] = l * _fx_inv_life[i]
		buf[o + 14] = vx
		buf[o + 15] = vy
		i += 1
		o += STRIDE
	_fx_mm.buffer = buf
	_fx_mm.visible_instance_count = _fx_count
