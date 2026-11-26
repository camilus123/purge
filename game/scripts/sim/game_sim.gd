class_name GameSim
extends RefCounted
## The whole gameplay simulation. Advances in fixed steps, knows nothing about
## nodes or rendering, and takes all of its numbers from data dictionaries.
## Coordinates: x right, y down the screen, playfield is [-HALF_W, HALF_W] x [-HALF_H, HALF_H].

const HALF_W := 45.0
const HALF_H := 60.0
const MAX_ENEMIES := 256
const PLAYER_BULLETS := 1024
const ENEMY_BULLETS := 3072

# Broadphase: the playfield is cut into vertical columns; each lists the enemies overlapping it.
const NCOL := 16
const COL_X0 := -52.0
const COL_W := 6.5
const MAX_PER_COL := 64

const STATE_PLAYING := 0
const STATE_DEAD := 1

# Events for the presentation layer: 4 floats each (type, x, y, value).
const EV_EXPLOSION := 1     # value = radius
const EV_HIT := 2           # value = damage type index
const EV_SHIELD_HIT := 3    # value = damage absorbed
const EV_HULL_HIT := 4      # value = damage taken
const EV_PLAYER_DEAD := 5
const EV_SHOT := 6          # value = weapon slot
const EV_POWER := 7         # value = shield share
const EV_RESTART := 8
const EV_SPECIAL := 9
const MAX_EVENTS := 512

var player := PlayerShip.new()
var pbul := BulletPool.new(PLAYER_BULLETS)
var ebul := BulletPool.new(ENEMY_BULLETS)
var enemies: Array[Enemy] = []
var enemy_count: int = 0
var events: PackedFloat32Array
var event_count: int = 0

var state: int = STATE_PLAYING
var time: float = 0.0
var scroll: float = 0.0
var scroll_speed: float = 12.0
var score: int = 0
var credits: int = 0
var kills: int = 0
var escaped: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var loop_index: int = 0

# Input, written by the game loop before each step.
var in_move: Vector2 = Vector2.ZERO     # relative aim movement in playfield units, consumed each step
var in_absolute: bool = false
var in_target: Vector2 = Vector2.ZERO   # aim point for absolute mode
var in_fire_1: bool = false
var in_fire_2: bool = false

# Debug switches
var invincible: bool = false
var stress: bool = false
var stress_target: int = 60

var damage_types: Array = ["energy", "kinetic", "explosive"]
var kind_names: Array[String] = []

var _kind_index: Dictionary = {}
var _power: Dictionary = {}
var _ship_def: Dictionary = {}
var _loadout: Dictionary = {}
var _enemy_types: Dictionary = {}       # id -> EnemyType
var _enemy_type_list: Array[EnemyType] = []
var _spawns: Array = []                 # [time, EnemyType, x] sorted by time
var _spawn_ptr: int = 0
var _level_time: float = 0.0
var _loop_length: float = 30.0
var _hp_scale: float = 1.0
var _hp_scale_per_loop: float = 1.0
var _free: PackedInt32Array
var _free_count: int = 0
var _uid: int = 0
var _dead_timer: float = 0.0
var _col_count: PackedInt32Array
var _col_items: PackedInt32Array
var _rng := RandomNumberGenerator.new()
var _recharge_scale: float = 2.0
var _ref_output: float = 100.0
var _starved_mult: float = 0.35
var _power_step: float = 0.1
var _respawn_invuln: float = 2.0


func _init() -> void:
	events.resize(MAX_EVENTS * 4)
	_col_count.resize(NCOL)
	_col_items.resize(NCOL * MAX_PER_COL)
	_free.resize(MAX_ENEMIES)
	enemies.resize(MAX_ENEMIES)
	for i in MAX_ENEMIES:
		var e := Enemy.new()
		e.slot = i
		enemies[i] = e
	_rng.seed = 12345


## Visual ids ("proj.laser.t1") are turned into small integers once; the view maps them to looks.
func kind_of(visual_id: String) -> int:
	if _kind_index.has(visual_id):
		return _kind_index[visual_id]
	var k := kind_names.size()
	kind_names.append(visual_id)
	_kind_index[visual_id] = k
	return k


## config keys: power, ship, reactor, shield, armor, weapon1, weapon2 (Dictionaries from data),
## enemies (Array of enemy definitions), level (Dictionary).
func setup(config: Dictionary) -> void:
	_power = config["power"]
	_ship_def = config["ship"]
	_loadout = config
	damage_types = _power.get("damage_types", damage_types)
	_recharge_scale = _power.get("shield_recharge_share_scale", 2.0)
	_ref_output = _power.get("reference_reactor_output", 100.0)
	_starved_mult = _power.get("starved_fire_rate_mult", 0.35)
	_power_step = _power.get("step", 0.1)

	_enemy_types.clear()
	_enemy_type_list.clear()
	for d: Dictionary in config.get("enemies", []):
		var t := EnemyType.from_def(d, damage_types, self)
		_enemy_types[t.id] = t
		_enemy_type_list.append(t)

	_load_level(config.get("level", {}))
	setup_player()
	restart()


func set_power_step(step: float) -> void:
	if step > 0.0:
		_power_step = step


func _load_level(level: Dictionary) -> void:
	scroll_speed = level.get("scroll_speed", 12.0)
	_loop_length = level.get("loop_length", 30.0)
	_hp_scale_per_loop = level.get("hp_scale_per_loop", 1.0)
	_spawns.clear()
	for w: Dictionary in level.get("waves", []):
		var type_id: String = w["enemy"]
		if not _enemy_types.has(type_id):
			push_warning("Level refers to unknown enemy %s" % type_id)
			continue
		for k in int(w.get("count", 1)):
			_spawns.append([float(w["t"]) + k * float(w.get("dt", 0.0)), _enemy_types[type_id],
					float(w.get("x", 0.0)) + k * float(w.get("dx", 0.0))])
	_spawns.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func setup_player() -> void:
	var p := player
	var ship := _ship_def
	var armor: Dictionary = _loadout["armor"]
	var shield: Dictionary = _loadout["shield"]
	var reactor: Dictionary = _loadout["reactor"]
	p.max_speed = float(ship.get("max_speed", 240.0)) * float(armor.get("speed_mult", 1.0))
	p.accel = ship.get("acceleration", 12000.0)
	p.follow_gain = ship.get("follow_gain", 40.0)
	p.radius = ship.get("hitbox_radius", 1.5)
	p.ram_damage = ship.get("ram_damage", 60.0)
	_respawn_invuln = ship.get("respawn_invulnerable_time", 2.0)

	p.armor_max = armor.get("hp", 100.0)
	p.resist.resize(damage_types.size())
	var res: Dictionary = armor.get("resist", {})
	for i in damage_types.size():
		p.resist[i] = res.get(damage_types[i], 0.0)

	p.shield_name = shield.get("name", "")
	p.shield_visual = shield.get("visual", "")
	p.shield_max = shield.get("capacity", 0.0)
	p.shield_recharge = shield.get("recharge", 0.0)
	p.shield_delay = shield.get("delay", 1.0)
	p.shield_reflect = shield.get("reflect", 0.0)
	p.shield_bleed = shield.get("bleed", 0.0)

	p.reactor_output = reactor.get("output", 100.0)
	p.pool_max = reactor.get("capacitor", 100.0)
	p.shield_share = _power.get("default_shield_share", 0.5)

	p.weapons.clear()
	var muzzles: Array = ship.get("muzzles", [[-1.5, -3.0], [1.5, -3.0]])
	var slot := 0
	for key: String in ["weapon1", "weapon2"]:
		if _loadout.has(key) and not (_loadout[key] as Dictionary).is_empty():
			var w := WeaponState.from_def(_loadout[key], damage_types, self)
			w.muzzle_x = muzzles[slot][0]
			w.muzzle_y = muzzles[slot][1]
			p.weapons.append(w)
		slot += 1


## Restart the stage: the player gets back the armor and shields they entered with.
func restart() -> void:
	var p := player
	p.alive = true
	p.x = 0.0
	p.y = HALF_H * 0.6
	p.ox = p.x
	p.oy = p.y
	p.tx = p.x
	p.ty = p.y
	p.vx = 0.0
	p.vy = 0.0
	p.armor = p.armor_max
	p.shield = p.shield_max
	p.shield_timer = 0.0
	p.pool = p.pool_max
	p.invulnerable = _respawn_invuln
	for w in p.weapons:
		w.reset()
	pbul.clear()
	ebul.clear()
	_free_count = 0
	for i in range(MAX_ENEMIES - 1, -1, -1):
		enemies[i].alive = false
		_free[_free_count] = i
		_free_count += 1
	enemy_count = 0
	state = STATE_PLAYING
	score = 0
	credits = 0
	kills = 0
	escaped = 0
	shots_fired = 0
	shots_hit = 0
	loop_index = 0
	_level_time = 0.0
	_spawn_ptr = 0
	_hp_scale = 1.0
	in_move = Vector2.ZERO
	_emit(EV_RESTART, p.x, p.y, 0.0)


func _emit(type: int, ex: float, ey: float, value: float) -> void:
	if event_count >= MAX_EVENTS:
		return
	var o := event_count * 4
	events[o] = type
	events[o + 1] = ex
	events[o + 2] = ey
	events[o + 3] = value
	event_count += 1


## Wheel input: dir = +1 shifts one step toward weapons, -1 toward shields.
func shift_power(dir: int) -> void:
	var p := player
	var s := clampf(p.shield_share - dir * _power_step, 0.0, 1.0)
	s = snappedf(s, 0.001)
	if not is_equal_approx(s, p.shield_share):
		p.shield_share = s
	_emit(EV_POWER, p.x, p.y, p.shield_share)


func fire_special() -> void:
	# Special weapons arrive with the tech tree (Milestone 4).
	_emit(EV_SPECIAL, player.x, player.y, 0.0)


func step(dt: float) -> void:
	time += dt
	scroll += scroll_speed * dt
	if state == STATE_DEAD:
		_dead_timer -= dt
		if _dead_timer <= 0.0:
			restart()
			return
	_step_player(dt)
	_step_spawner(dt)
	_step_enemies(dt)
	_step_player_bullets(dt)
	_step_enemy_bullets(dt)


# ---------------------------------------------------------------- player

func _step_player(dt: float) -> void:
	var p := player
	p.ox = p.x
	p.oy = p.y
	if not p.alive:
		return
	if p.invulnerable > 0.0:
		p.invulnerable -= dt

	# The aim point moves with the mouse; the ship chases it within its speed and acceleration.
	if in_absolute:
		p.tx = in_target.x
		p.ty = in_target.y
	else:
		p.tx += in_move.x
		p.ty += in_move.y
	in_move = Vector2.ZERO
	var margin := 2.0
	p.tx = clampf(p.tx, -HALF_W + margin, HALF_W - margin)
	p.ty = clampf(p.ty, -HALF_H + margin, HALF_H - margin)

	var to_x := p.tx - p.x
	var to_y := p.ty - p.y
	var want_x := to_x * p.follow_gain
	var want_y := to_y * p.follow_gain
	var want_len := sqrt(want_x * want_x + want_y * want_y)
	if want_len > p.max_speed:
		var k := p.max_speed / want_len
		want_x *= k
		want_y *= k
	var dvx := want_x - p.vx
	var dvy := want_y - p.vy
	var dv := sqrt(dvx * dvx + dvy * dvy)
	var max_dv := p.accel * dt
	if dv > max_dv:
		var k2 := max_dv / dv
		dvx *= k2
		dvy *= k2
	p.vx += dvx
	p.vy += dvy
	p.x = clampf(p.x + p.vx * dt, -HALF_W + margin, HALF_W - margin)
	p.y = clampf(p.y + p.vy * dt, -HALF_H + margin, HALF_H - margin)

	# Reactor: the shield share recharges shields, the weapon share fills the weapon pool.
	var weapon_share := 1.0 - p.shield_share
	if p.shield_timer > 0.0:
		p.shield_timer -= dt
	elif p.shield < p.shield_max:
		p.shield = minf(p.shield_max, p.shield + shield_recharge_rate() * dt)
	p.pool = minf(p.pool_max, p.pool + p.reactor_output * weapon_share * dt)

	var n := p.weapons.size()
	if n > 0:
		_step_weapon(p.weapons[0], in_fire_1 or stress, 0, weapon_share, dt)
	if n > 1:
		_step_weapon(p.weapons[1], in_fire_2 or stress, 1, weapon_share, dt)


## Shield points per second at the current split.
func shield_recharge_rate() -> float:
	var p := player
	return p.shield_recharge * p.shield_share * _recharge_scale * (p.reactor_output / _ref_output)


func _step_weapon(w: WeaponState, firing: bool, slot: int, weapon_share: float, dt: float) -> void:
	var p := player
	if w.spin_up > 0.0:
		w.spin = move_toward(w.spin, 1.0 if (firing and not w.overheated) else 0.0, dt / w.spin_up)
	if w.heat > 0.0:
		w.heat = maxf(0.0, w.heat - w.heat_dissipation * dt)
	if w.overheated and w.heat <= w.heat_capacity * w.overheat_recover:
		w.overheated = false
	if w.cooldown > 0.0:
		w.cooldown -= dt
	if not firing or w.overheated:
		if w.cooldown < 0.0:
			w.cooldown = 0.0
		return

	while w.cooldown <= 0.0:
		var rate := w.current_rate(weapon_share)
		if p.pool >= w.energy_per_shot:
			p.pool -= w.energy_per_shot
			w.starved = false
		else:
			# Out of energy: keep firing, but slowly.
			rate *= _starved_mult
			w.starved = true
		w.cooldown += 1.0 / maxf(rate, 0.01)

		var dmg := w.current_damage(weapon_share)
		var count := w.projectiles
		for k in count:
			var angle := 0.0
			if count > 1:
				angle = w.spread * (float(k) / float(count - 1) - 0.5)
			if w.random_spread > 0.0:
				angle += _rng.randf_range(-0.5, 0.5) * w.random_spread
			pbul.spawn(p.x + w.muzzle_x, p.y + w.muzzle_y, sin(angle) * w.speed, -cos(angle) * w.speed,
					w.radius, dmg, w.dtype, w.kind, w.lifetime, w.pierce)
			shots_fired += 1
		_emit(EV_SHOT, p.x + w.muzzle_x, p.y + w.muzzle_y, slot)

		if w.heat_capacity > 0.0:
			w.heat += w.heat_per_shot
			if w.heat >= w.heat_capacity:
				w.heat = w.heat_capacity
				w.overheated = true
				break


## Applies damage to the player: shield first (with bleed-through and reflection), then armor.
func damage_player(amount: float, dtype: int, from_slot: int = -1) -> void:
	var p := player
	if not p.alive or invincible or stress or p.invulnerable > 0.0:
		return
	var to_hull := amount
	if p.shield > 0.0:
		var bleed := amount * p.shield_bleed
		var to_shield := amount - bleed
		var absorbed := minf(p.shield, to_shield)
		p.shield -= absorbed
		to_hull = bleed + (to_shield - absorbed)
		_emit(EV_SHIELD_HIT, p.x, p.y, absorbed)
		if p.shield_reflect > 0.0 and absorbed > 0.0:
			_reflect(absorbed * p.shield_reflect, dtype, from_slot)
	p.shield_timer = p.shield_delay
	if to_hull > 0.0:
		var dealt := to_hull * (1.0 - p.resist[dtype])
		p.armor -= dealt
		_emit(EV_HULL_HIT, p.x, p.y, dealt)
		if p.armor <= 0.0:
			p.armor = 0.0
			p.alive = false
			state = STATE_DEAD
			_dead_timer = 2.5
			_emit(EV_PLAYER_DEAD, p.x, p.y, 0.0)
			_emit(EV_EXPLOSION, p.x, p.y, 7.0)


func _reflect(amount: float, dtype: int, from_slot: int) -> void:
	var target: Enemy = null
	if from_slot >= 0 and enemies[from_slot].alive:
		target = enemies[from_slot]
	else:
		var best := INF
		for e in enemies:
			if e.alive:
				var d := (e.x - player.x) * (e.x - player.x) + (e.y - player.y) * (e.y - player.y)
				if d < best:
					best = d
					target = e
	if target != null:
		_damage_enemy(target, amount, dtype)


# ---------------------------------------------------------------- enemies

func spawn_enemy(type: EnemyType, sx: float) -> Enemy:
	if _free_count <= 0:
		return null
	_free_count -= 1
	var e := enemies[_free[_free_count]]
	_uid += 1
	e.uid = _uid
	e.alive = true
	e.type = type
	e.max_hp = type.hp * _hp_scale
	e.hp = e.max_hp
	e.radius = type.radius
	e.spawn_x = sx
	e.x = sx
	e.y = -HALF_H - type.radius - 2.0
	e.ox = e.x
	e.oy = e.y
	e.t = 0.0
	e.phase = 0
	e.phase_t = 0.0
	e.attack_cd = type.atk_first_delay
	e.hit_time = -10.0
	enemy_count += 1
	return e


func _free_enemy(e: Enemy) -> void:
	e.alive = false
	_free[_free_count] = e.slot
	_free_count += 1
	enemy_count -= 1


func _step_spawner(dt: float) -> void:
	if stress:
		while enemy_count < stress_target and not _enemy_type_list.is_empty():
			var t := _enemy_type_list[_rng.randi() % _enemy_type_list.size()]
			var e := spawn_enemy(t, _rng.randf_range(-HALF_W + 5.0, HALF_W - 5.0))
			if e == null:
				break
			e.attack_cd = _rng.randf_range(0.2, 1.4)
		return
	_level_time += dt
	while _spawn_ptr < _spawns.size() and _spawns[_spawn_ptr][0] <= _level_time:
		var s: Array = _spawns[_spawn_ptr]
		spawn_enemy(s[1], s[2])
		_spawn_ptr += 1
	if _level_time >= _loop_length:
		_level_time -= _loop_length
		_spawn_ptr = 0
		loop_index += 1
		_hp_scale *= _hp_scale_per_loop


func _step_enemies(dt: float) -> void:
	var p := player
	for c in NCOL:
		_col_count[c] = 0
	for e in enemies:
		if not e.alive:
			continue
		var t := e.type
		e.ox = e.x
		e.oy = e.y
		e.t += dt

		match t.move:
			EnemyType.MOVE_SINE:
				e.y += t.speed * dt
				e.x = e.spawn_x + t.amplitude * sin(e.t * t.frequency * TAU)
			EnemyType.MOVE_SWOOP_HOLD:
				if e.phase == 0:
					# Arrive fast, ease into the hold line.
					var remaining := t.hold_y - e.y
					e.y += t.speed * clampf(remaining * 0.12, 0.15, 1.6) * dt
					if remaining <= 0.3:
						e.phase = 1
						e.phase_t = 0.0
				elif e.phase == 1:
					e.phase_t += dt
					e.x = e.spawn_x + t.drift * sin(e.phase_t * 0.7)
					if e.phase_t >= t.hold_time and not stress:
						e.phase = 2
				else:
					e.y += t.speed * 1.5 * dt
			_:
				e.y += t.speed * dt

		if e.y > HALF_H + e.radius + 4.0:
			escaped += 1
			_free_enemy(e)
			continue

		# Attack
		if t.has_attack and p.alive and e.y > -HALF_H:
			e.attack_cd -= dt
			if e.attack_cd <= 0.0:
				e.attack_cd += t.atk_interval
				_enemy_fire(e, t)

		# Body collision with the player
		if p.alive:
			var dx := e.x - p.x
			var dy := e.y - p.y
			var rr := e.radius + p.radius
			if dx * dx + dy * dy <= rr * rr:
				damage_player(t.collision_damage, 1, e.slot)
				_damage_enemy(e, p.ram_damage, 1)
				if not e.alive:
					continue

		# Broadphase registration
		var c0 := int((e.x - e.radius - 2.0 - COL_X0) / COL_W)
		var c1 := int((e.x + e.radius + 2.0 - COL_X0) / COL_W)
		if c0 < 0:
			c0 = 0
		if c1 >= NCOL:
			c1 = NCOL - 1
		for c in range(c0, c1 + 1):
			var cn := _col_count[c]
			if cn < MAX_PER_COL:
				_col_items[c * MAX_PER_COL + cn] = e.slot
				_col_count[c] = cn + 1


func _enemy_fire(e: Enemy, t: EnemyType) -> void:
	var base := atan2(player.y - e.y, player.x - e.x)
	var count := t.atk_count
	var spread := t.atk_spread
	if stress:
		# Stress test: every enemy fires full rings.
		count = 10
		spread = TAU * 0.9
	for k in count:
		var a := base
		if count > 1:
			a += spread * (float(k) / float(count - 1) - 0.5)
		ebul.spawn(e.x, e.y, cos(a) * t.bullet_speed, sin(a) * t.bullet_speed,
				t.bullet_radius, t.bullet_damage, 0, t.bullet_kind, 8.0, e.slot)


func _damage_enemy(e: Enemy, amount: float, dtype: int) -> void:
	e.hp -= amount * (1.0 - e.type.resist[dtype])
	e.hit_time = time
	if e.hp <= 0.0:
		kills += 1
		score += e.type.credits * 10
		credits += e.type.credits
		_emit(EV_EXPLOSION, e.x, e.y, e.radius)
		_free_enemy(e)


# ---------------------------------------------------------------- bullets

func _step_player_bullets(dt: float) -> void:
	var b := pbul
	var bx := b.x
	var by := b.y
	var bvx := b.vx
	var bvy := b.vy
	var blife := b.life
	var brad := b.radius
	var bdmg := b.damage
	var bdtype := b.dtype
	var bpierce := b.pierce
	var blast := b.last_hit
	var cols := _col_count
	var items := _col_items
	var inv_col := 1.0 / COL_W
	var y_min := -HALF_H - 4.0
	var y_max := HALF_H + 4.0
	var x_max := HALF_W + 8.0
	var i := 0
	var n := b.count
	while i < n:
		var nx := bx[i] + bvx[i] * dt
		var ny := by[i] + bvy[i] * dt
		bx[i] = nx
		by[i] = ny
		var l := blife[i] - dt
		blife[i] = l
		var dead := l <= 0.0 or ny < y_min or ny > y_max or nx < -x_max or nx > x_max
		if not dead:
			var c := int((nx - COL_X0) * inv_col)
			if c >= 0 and c < NCOL:
				var cn := cols[c]
				if cn > 0:
					var base := c * MAX_PER_COL
					var r := brad[i]
					for j in cn:
						var slot := items[base + j]
						if slot == blast[i]:
							continue
						var e := enemies[slot]
						if not e.alive:
							continue
						var ddx := e.x - nx
						var ddy := e.y - ny
						var rr := e.radius + r
						if ddx * ddx + ddy * ddy <= rr * rr:
							shots_hit += 1
							_emit(EV_HIT, nx, ny, bdtype[i])
							_damage_enemy(e, bdmg[i], bdtype[i])
							if bpierce[i] > 0:
								bpierce[i] -= 1
								blast[i] = slot
							else:
								dead = true
								break
		if dead:
			b.remove(i)
			n -= 1
		else:
			i += 1


func _step_enemy_bullets(dt: float) -> void:
	var b := ebul
	var bx := b.x
	var by := b.y
	var bvx := b.vx
	var bvy := b.vy
	var blife := b.life
	var brad := b.radius
	var p := player
	var px := p.x
	var py := p.y
	var pr := p.radius
	var can_hit := p.alive
	var y_max := HALF_H + 4.0
	var x_max := HALF_W + 8.0
	var i := 0
	var n := b.count
	while i < n:
		var nx := bx[i] + bvx[i] * dt
		var ny := by[i] + bvy[i] * dt
		bx[i] = nx
		by[i] = ny
		var l := blife[i] - dt
		blife[i] = l
		var dead := l <= 0.0 or ny < -y_max or ny > y_max or nx < -x_max or nx > x_max
		if not dead and can_hit:
			var ddx := nx - px
			var ddy := ny - py
			var rr := brad[i] + pr
			if ddx * ddx + ddy * ddy <= rr * rr:
				# For enemy bullets the pierce field carries the slot of the enemy that fired.
				damage_player(b.damage[i], b.dtype[i], b.pierce[i])
				can_hit = p.alive
				dead = true
		if dead:
			b.remove(i)
			n -= 1
		else:
			i += 1
