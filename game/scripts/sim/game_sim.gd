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
const STATE_CLEAR := 2

# Events for the presentation layer: 4 floats each (type, x, y, value).
const EV_EXPLOSION := 1     # value = radius
const EV_HIT := 2           # value = damage type index
const EV_SHIELD_HIT := 3    # value = damage absorbed
const EV_HULL_HIT := 4      # value = damage taken
const EV_PLAYER_DEAD := 5
const EV_SHOT := 6          # value = weapon slot
const EV_POWER := 7         # value = shield share
const EV_RESTART := 8
const EV_SPECIAL := 9      # value = 1 fired, 0 out of ammo, -1 nothing fitted
const EV_STAGE_CLEAR := 10
const EV_SPLASH := 11       # value = radius of a weapon explosion
const EV_RAIL := 12         # x, y = muzzle, value = length of the shot
const EV_SHOCKWAVE := 13    # value = radius
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
var ship_model: String = ""
var background: Dictionary = {}   # the level's background block, read by the view
var score: int = 0
var credits: int = 0
var kills: int = 0
var escaped: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var loop_index: int = 0
var level_name: String = ""
var level_time: float = 0.0
var level_length: float = 0.0   # time of the last spawn; 0 for looping levels
var clear_time: float = 0.0     # seconds since the stage was cleared
# Stage statistics for the results screen.
var spawned_total: int = 0
var hull_damage_taken: float = 0.0
var boss_spawned: bool = false
var boss_killed: bool = false
var boss_kill_time: float = 0.0  # seconds from the boss appearing to its death
var boss_par_time: float = 0.0

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
var _spawns: Array = []                 # [time, EnemyType, x, MovePattern or null, is boss] sorted by time
var _move_patterns: Dictionary = {}     # id -> MovePattern
var _attack_patterns: Dictionary = {}   # id -> AttackPattern
var _loop: bool = false
var _base_scroll_speed: float = 12.0
var _scroll_target: float = 12.0
var _scroll_changes: Array = []         # [time, speed] sorted by time
var _scroll_ptr: int = 0
var _spawn_ptr: int = 0
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
var _bursts: Array = []                 # cluster burst definitions, see register_burst()
var _pending_bursts: PackedFloat32Array # x, y, burst index, struck enemy slot: spawned after the bullet loop
var _beam_hits: Array = []              # scratch: [along, slot] pairs for beam and rail hits
# Difficulty multipliers
var _d_hp: float = 1.0
var _d_damage: float = 1.0
var _d_bullet_speed: float = 1.0
var _d_fire_rate: float = 1.0


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


## Cluster bursts are kept in a table so bullets can refer to them by index.
func register_burst(d: Dictionary) -> int:
	_bursts.append({
		"count": int(d.get("count", 8)), "speed": float(d.get("speed", 35.0)), "damage": float(d.get("damage", 20.0)),
		"splash": float(d.get("splash", 3.0)), "lifetime": float(d.get("lifetime", 0.5)),
		"kind": kind_of(d.get("visual", "proj.bomblet")),
	})
	return _bursts.size() - 1


## Visual ids ("proj.laser.t1") are turned into small integers once; the view maps them to looks.
func kind_of(visual_id: String) -> int:
	if _kind_index.has(visual_id):
		return _kind_index[visual_id]
	var k := kind_names.size()
	kind_names.append(visual_id)
	_kind_index[visual_id] = k
	return k


## config keys: power, ship, reactor, shield, armor, weapon1, weapon2, special (Dictionaries from data,
## empty when the slot is empty), enemies, movement, attack (Arrays of definitions), level (Dictionary),
## difficulty (Dictionary of multipliers, optional), start_armor (float, optional: armor at the start
## of the stage), start_ammo (int, optional: special ammo at the start of the stage).
func setup(config: Dictionary) -> void:
	_power = config["power"]
	_ship_def = config["ship"]
	_loadout = config
	damage_types = _power.get("damage_types", damage_types)
	_recharge_scale = _power.get("shield_recharge_share_scale", 2.0)
	_ref_output = _power.get("reference_reactor_output", 100.0)
	_starved_mult = _power.get("starved_fire_rate_mult", 0.35)
	_power_step = _power.get("step", 0.1)
	var diff: Dictionary = config.get("difficulty", {})
	_d_hp = diff.get("enemy_hp", 1.0)
	_d_damage = diff.get("enemy_damage", 1.0)
	_d_bullet_speed = diff.get("bullet_speed", 1.0)
	_d_fire_rate = diff.get("fire_rate", 1.0)
	_bursts.clear()

	_move_patterns.clear()
	_attack_patterns.clear()
	for d: Dictionary in config.get("movement", []):
		_move_patterns[d["id"]] = MovePattern.from_def(d)
	for d: Dictionary in config.get("attack", []):
		_attack_patterns[d["id"]] = AttackPattern.from_def(d, damage_types, self)
	_enemy_types.clear()
	_enemy_type_list.clear()
	for d: Dictionary in config.get("enemies", []):
		var t := EnemyType.from_def(d, damage_types, _move_patterns, _attack_patterns)
		_enemy_types[t.id] = t
		_enemy_type_list.append(t)

	_load_level(config.get("level", {}))
	setup_player()
	restart()


func set_power_step(step: float) -> void:
	if step > 0.0:
		_power_step = step


func _load_level(level: Dictionary) -> void:
	level_name = level.get("name", "")
	boss_par_time = level.get("boss_par_time", 0.0)
	_base_scroll_speed = level.get("scroll_speed", 12.0)
	background = level.get("background", {})
	_loop = level.get("loop", false)
	_loop_length = level.get("loop_length", 30.0)
	_hp_scale_per_loop = level.get("hp_scale_per_loop", 1.0)
	_scroll_changes.clear()
	for c: Dictionary in level.get("scroll_changes", []):
		_scroll_changes.append([float(c["t"]), float(c["speed"])])
	_scroll_changes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_spawns.clear()
	for w: Dictionary in level.get("waves", []):
		var type_id: String = w["enemy"]
		if not _enemy_types.has(type_id):
			push_warning("Level refers to unknown enemy %s" % type_id)
			continue
		var override: MovePattern = null
		if w.has("movement"):
			if _move_patterns.has(w["movement"]):
				override = _move_patterns[w["movement"]]
			else:
				push_warning("Level refers to unknown movement pattern %s" % w["movement"])
		var boss: bool = w.get("boss", false)
		for k in int(w.get("count", 1)):
			_spawns.append([float(w["t"]) + k * float(w.get("dt", 0.0)), _enemy_types[type_id],
					float(w.get("x", 0.0)) + k * float(w.get("dx", 0.0)), override, boss])
	_spawns.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	level_length = 0.0
	if not _loop and not _spawns.is_empty():
		level_length = _spawns[_spawns.size() - 1][0]


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
	ship_model = ship.get("model", "")
	_respawn_invuln = ship.get("respawn_invulnerable_time", 2.0)

	p.armor_max = armor.get("hp", 100.0)
	p.armor_start = clampf(float(_loadout.get("start_armor", p.armor_max)), 1.0, p.armor_max)
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

	var muzzles: Array = ship.get("muzzles", [[-1.5, -3.0], [1.5, -3.0]])
	var keys := ["weapon1", "weapon2"]
	for slot in 2:
		p.weapons[slot] = null
		var def: Dictionary = _loadout.get(keys[slot], {})
		if not def.is_empty():
			var w := WeaponState.from_def(def, damage_types, self)
			w.muzzle_x = muzzles[slot][0]
			w.muzzle_y = muzzles[slot][1]
			p.weapons[slot] = w
	p.special = null
	var sdef: Dictionary = _loadout.get("special", {})
	if not sdef.is_empty():
		p.special = SpecialState.from_def(sdef, damage_types, self)
		p.special_ammo_start = clampi(int(_loadout.get("start_ammo", p.special.ammo_max)), 0, p.special.ammo_max)


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
	p.armor = p.armor_start
	p.shield = p.shield_max
	p.shield_timer = 0.0
	p.pool = p.pool_max
	p.invulnerable = _respawn_invuln
	for w in p.weapons:
		if w != null:
			w.reset()
	if p.special != null:
		p.special.ammo = p.special_ammo_start
		p.special.cooldown = 0.0
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
	level_time = 0.0
	clear_time = 0.0
	scroll_speed = _base_scroll_speed
	_scroll_target = _base_scroll_speed
	_scroll_ptr = 0
	_spawn_ptr = 0
	_hp_scale = 1.0
	spawned_total = 0
	hull_damage_taken = 0.0
	boss_spawned = false
	boss_killed = false
	boss_kill_time = 0.0
	_pending_bursts.clear()
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


## Middle mouse: fires the special weapon if it has ammo and is not cooling down.
func fire_special() -> void:
	var p := player
	var s := p.special
	if s == null or not p.alive or state != STATE_PLAYING:
		_emit(EV_SPECIAL, p.x, p.y, -1.0)
		return
	if s.cooldown > 0.0:
		return
	if s.ammo <= 0:
		_emit(EV_SPECIAL, p.x, p.y, 0.0)
		return
	s.ammo -= 1
	s.cooldown = s.cooldown_time
	_emit(EV_SPECIAL, p.x, p.y, 1.0)
	if s.shockwave:
		# Wipe every enemy bullet and hit every enemy on screen.
		ebul.clear()
		for e in enemies:
			if e.alive and e.y > -HALF_H - e.radius:
				_damage_enemy(e, s.shockwave_damage, s.dtype)
		_emit(EV_SHOCKWAVE, p.x, p.y, 70.0)
		return
	# Homing volleys spread over the nearest enemies, one target each where possible.
	var targets: Array = []
	if s.homing > 0.0:
		for e in enemies:
			if e.alive and e.y > -HALF_H:
				targets.append([(e.x - p.x) * (e.x - p.x) + (e.y - p.y) * (e.y - p.y), e.slot])
		targets.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n := s.volley
	for k in n:
		var sx := p.x
		var sy := p.y
		var vx := 0.0
		var vy := 0.0
		if s.behind:
			sx += (k - (n - 1) * 0.5) * s.spacing
			sy += 3.0
			vy = s.drift
		else:
			var ang := 0.0
			if n > 1:
				ang = s.spread * (float(k) / float(n - 1) - 0.5)
			sy -= 3.0
			vx = sin(ang) * s.speed
			vy = -cos(ang) * s.speed
		var i := pbul.spawn(sx, sy, vx, vy, s.radius, s.damage, s.dtype, s.kind, s.lifetime, 0)
		if i < 0:
			break
		var tslot := -1
		var tuid := 0
		if not targets.is_empty():
			tslot = targets[k % targets.size()][1]
			tuid = enemies[tslot].uid
		pbul.set_extra(i, s.splash, s.homing, s.wander, s.fuse if s.fuse > 0.0 else -1.0, s.proximity, s.burst, tslot, tuid)
		pbul.has_extra[i] = 2   # special: not counted for accuracy


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

	if p.weapons[0] != null:
		_step_weapon(p.weapons[0], in_fire_1 or stress, 0, weapon_share, dt)
	if p.weapons[1] != null:
		_step_weapon(p.weapons[1], in_fire_2 or stress, 1, weapon_share, dt)
	if p.special != null and p.special.cooldown > 0.0:
		p.special.cooldown -= dt


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
	if w.behaviour == WeaponState.BEAM:
		_step_beam(w, firing and not w.overheated, slot, weapon_share, dt)
		return
	if w.behaviour == WeaponState.RAIL:
		_step_rail(w, firing and not w.overheated, slot, weapon_share, dt)
		return
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
			var offset := 0.0
			if count > 1:
				var f := float(k) / float(count - 1) - 0.5
				angle = w.spread * f
				offset = w.spacing * f * float(count - 1)
			if w.random_spread > 0.0:
				angle += _rng.randf_range(-0.5, 0.5) * w.random_spread
			var i := pbul.spawn(p.x + w.muzzle_x + offset, p.y + w.muzzle_y, sin(angle) * w.speed, -cos(angle) * w.speed,
					w.radius, dmg, w.dtype, w.kind, w.lifetime, w.pierce)
			if i >= 0 and w.splash > 0.0:
				pbul.set_extra(i, w.splash, 0.0, 0.0, -1.0, 0.0, -1, -1, 0)
			shots_fired += 1
		_emit(EV_SHOT, p.x + w.muzzle_x, p.y + w.muzzle_y, slot)

		if w.heat_capacity > 0.0:
			w.heat += w.heat_per_shot
			if w.heat >= w.heat_capacity:
				w.heat = w.heat_capacity
				w.overheated = true
				break


## Applies damage to the player: shield first (with bleed-through and reflection), then armor.
## Continuous beam. Damage and energy are per second. A sweeping beam (phaser) swings
## from side to side; `pierce` is how many enemies it passes through before stopping.
func _step_beam(w: WeaponState, firing: bool, slot: int, weapon_share: float, dt: float) -> void:
	var p := player
	if not firing:
		w.beam_on = false
		return
	var mult := 1.0
	var need := w.energy_per_shot * dt
	if p.pool >= need:
		p.pool -= need
		w.starved = false
	else:
		p.pool = 0.0
		w.starved = true
		mult = _starved_mult
	w.sweep_t += dt * w.sweep_speed
	var ang := w.sweep * sin(w.sweep_t)
	var ox := p.x + w.muzzle_x
	var oy := p.y + w.muzzle_y
	var dx := sin(ang)
	var dy := -cos(ang)
	# The beam ends at the top of the playfield or at its range.
	var reach := minf(w.beam_range, (oy + HALF_H + 4.0) / maxf(-dy, 0.05))
	var hits := _line_hits(ox, oy, dx, dy, reach, w.beam_width * 0.5)
	var dmg := w.current_damage(weapon_share) * mult * dt
	var limit := mini(hits.size(), w.pierce + 1)
	for k in limit:
		_damage_enemy(enemies[hits[k][1]], dmg, w.dtype)
	w.beam_len = reach
	if hits.size() > w.pierce:
		w.beam_len = hits[w.pierce][0]
	w.beam_on = true
	w.beam_angle = ang
	w.hit_timer -= dt
	if limit > 0 and w.hit_timer <= 0.0:
		w.hit_timer = 0.05
		_emit(EV_HIT, ox + dx * w.beam_len, oy + dy * w.beam_len, w.dtype)
	w.sound_timer -= dt
	if w.sound_timer <= 0.0:
		w.sound_timer = 0.13
		_emit(EV_SHOT, ox, oy, slot)
	# Accuracy: every 0.1 s of beam counts as one shot, a hit if it touched anything.
	w.accuracy_hit = w.accuracy_hit or limit > 0
	w.accuracy_timer += dt
	if w.accuracy_timer >= 0.1:
		w.accuracy_timer -= 0.1
		shots_fired += 1
		if w.accuracy_hit:
			shots_hit += 1
		w.accuracy_hit = false


## Railgun: hold to charge, then an instant straight shot hits up to pierce + 1 enemies in a line.
func _step_rail(w: WeaponState, firing: bool, slot: int, weapon_share: float, dt: float) -> void:
	var p := player
	if not firing:
		w.charge = maxf(0.0, w.charge - dt * 2.0)
		return
	w.charge = minf(w.charge + dt, w.charge_time)
	if w.charge < w.charge_time or w.cooldown > 0.0:
		return
	var rate := w.current_rate(weapon_share)
	if p.pool >= w.energy_per_shot:
		p.pool -= w.energy_per_shot
		w.starved = false
	else:
		rate *= _starved_mult
		w.starved = true
	w.cooldown = 1.0 / maxf(rate, 0.01)
	w.charge = 0.0
	var ox := p.x + w.muzzle_x
	var oy := p.y + w.muzzle_y
	var reach := oy + HALF_H + 4.0
	var hits := _line_hits(ox, oy, 0.0, -1.0, reach, w.beam_width * 0.5)
	var limit := mini(hits.size(), w.pierce + 1)
	var dmg := w.current_damage(weapon_share)
	for k in limit:
		var e := enemies[hits[k][1]]
		_emit(EV_HIT, e.x, e.y + e.radius * 0.5, w.dtype)
		_damage_enemy(e, dmg, w.dtype)
	var length := reach
	if hits.size() > w.pierce:
		length = hits[w.pierce][0]
	shots_fired += 1
	if limit > 0:
		shots_hit += 1
	_emit(EV_RAIL, ox, oy, length)
	_emit(EV_SHOT, ox, oy, slot)


## Enemies touched by a line from (ox, oy) along the unit direction (dx, dy), nearest first,
## as [distance along the line, slot] pairs. half_width widens the line.
func _line_hits(ox: float, oy: float, dx: float, dy: float, reach: float, half_width: float) -> Array:
	_beam_hits.clear()
	for e in enemies:
		if not e.alive:
			continue
		var rx := e.x - ox
		var ry := e.y - oy
		var along := rx * dx + ry * dy
		if along < -e.radius or along > reach + e.radius:
			continue
		var side := absf(rx * dy - ry * dx)
		if side <= e.radius + half_width:
			_beam_hits.append([maxf(along - e.radius * 0.5, 0.0), e.slot])
	if _beam_hits.size() > 1:
		_beam_hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return _beam_hits


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
		var dealt := minf(to_hull * (1.0 - p.resist[dtype]), p.armor)
		p.armor -= dealt
		hull_damage_taken += dealt
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

func spawn_enemy(type: EnemyType, sx: float, move_override: MovePattern = null) -> Enemy:
	if _free_count <= 0:
		return null
	_free_count -= 1
	var e := enemies[_free[_free_count]]
	_uid += 1
	e.uid = _uid
	e.alive = true
	e.type = type
	e.move = move_override if move_override != null else type.move
	e.max_hp = type.hp * _hp_scale * _d_hp
	e.hp = e.max_hp
	e.radius = type.radius
	e.spawn_x = sx
	e.x = sx
	e.y = -HALF_H - type.radius - 2.0
	e.ox = e.x
	e.oy = e.y
	e.vx = 0.0
	e.vy = 0.0
	e.t = 0.0
	e.phase = 0
	e.phase_t = 0.0
	e.path_i = 0
	e.hit_time = -10.0
	e.is_boss = false
	e.spawn_time = level_time
	for k in type.attacks.size():
		e.attack_cd[k] = type.attacks[k].first_delay
		e.attack_angle[k] = PI * 0.5
		e.burst_left[k] = 0
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
			for k in t.attacks.size():
				e.attack_cd[k] = _rng.randf_range(0.2, 1.4)
		return
	level_time += dt
	# Scroll speed changes ease in over about a second.
	while _scroll_ptr < _scroll_changes.size() and _scroll_changes[_scroll_ptr][0] <= level_time:
		_scroll_target = _scroll_changes[_scroll_ptr][1]
		_scroll_ptr += 1
	if scroll_speed != _scroll_target:
		scroll_speed = move_toward(scroll_speed, _scroll_target, maxf(absf(_scroll_target - scroll_speed), 2.0) * dt)
	while _spawn_ptr < _spawns.size() and _spawns[_spawn_ptr][0] <= level_time:
		var s: Array = _spawns[_spawn_ptr]
		var e := spawn_enemy(s[1], s[2], s[3])
		if e != null:
			spawned_total += 1
			if s[4]:
				e.is_boss = true
				boss_spawned = true
		_spawn_ptr += 1
	if _loop:
		if level_time >= _loop_length:
			level_time -= _loop_length
			_spawn_ptr = 0
			_scroll_ptr = 0
			loop_index += 1
			_hp_scale *= _hp_scale_per_loop
	elif state == STATE_PLAYING and _spawn_ptr >= _spawns.size() and enemy_count == 0 and not _spawns.is_empty():
		# Every wave has been destroyed or has left: the stage is over.
		state = STATE_CLEAR
		clear_time = 0.0
		_emit(EV_STAGE_CLEAR, player.x, player.y, 0.0)
	elif state == STATE_CLEAR:
		clear_time += dt


func _step_enemies(dt: float) -> void:
	var p := player
	for c in NCOL:
		_col_count[c] = 0
	for e in enemies:
		if not e.alive:
			continue
		var t := e.type
		var m := e.move
		e.ox = e.x
		e.oy = e.y
		e.t += dt

		match m.type:
			MovePattern.SINE:
				e.y += t.speed * dt
				e.x = e.spawn_x + m.amplitude * sin(e.t * m.frequency * TAU)
			MovePattern.ZIGZAG:
				e.y += t.speed * dt
				# Triangle wave between -width and +width.
				var ph := fposmod(e.t / m.period, 1.0)
				e.x = e.spawn_x + m.width * (4.0 * absf(ph - 0.5) - 1.0)
			MovePattern.SWOOP_HOLD:
				if e.phase == 0:
					# Arrive fast, ease into the hold line.
					var remaining := m.hold_y - e.y
					e.y += t.speed * clampf(remaining * 0.12, 0.15, 1.6) * dt
					if remaining <= 0.3:
						e.phase = 1
						e.phase_t = 0.0
				elif e.phase == 1:
					e.phase_t += dt
					e.x = e.spawn_x + m.drift * sin(e.phase_t * 0.7)
					if e.phase_t >= m.hold_time and not stress:
						e.phase = 2
				else:
					e.y += t.speed * 1.5 * dt
			MovePattern.DIVE:
				if e.phase == 0:
					e.y += t.speed * dt
					if e.t >= m.delay:
						# Commit to a straight run at where the player is right now.
						var ddx := p.x - e.x
						var ddy := maxf(p.y - e.y, 10.0)
						var dl := sqrt(ddx * ddx + ddy * ddy)
						e.vx = ddx / dl * m.dive_speed
						e.vy = ddy / dl * m.dive_speed
						e.phase = 1
				else:
					e.x += e.vx * dt
					e.y += e.vy * dt
			MovePattern.CIRCLE:
				if e.phase == 0:
					e.y += t.speed * dt
					if e.y >= m.center_y:
						e.phase = 1
						e.phase_t = 0.0
				elif e.phase == 1:
					e.phase_t += dt
					var ang := e.phase_t * m.angular_speed
					e.x = e.spawn_x + m.radius * sin(ang)
					e.y = m.center_y + m.radius * (1.0 - cos(ang))
					if e.phase_t >= m.time and not stress:
						e.phase = 2
				else:
					e.y += t.speed * 1.5 * dt
			MovePattern.PATH:
				if e.path_i < m.points.size():
					var target := m.points[e.path_i]
					var tx := e.spawn_x + target.x - e.x
					var ty := target.y - e.y
					var dist := sqrt(tx * tx + ty * ty)
					var step_len := t.speed * dt
					if dist <= step_len:
						e.x += tx
						e.y += ty
						e.path_i += 1
					else:
						e.x += tx / dist * step_len
						e.y += ty / dist * step_len
				else:
					e.y += t.speed * dt
			_:
				e.y += t.speed * dt

		if e.y > HALF_H + e.radius + 4.0 or absf(e.x) > HALF_W + 30.0:
			escaped += 1
			_free_enemy(e)
			continue

		# Attacks
		if p.alive and e.y > -HALF_H:
			for k in t.attacks.size():
				var cd := e.attack_cd[k] - dt
				if cd <= 0.0:
					var a := t.attacks[k]
					_enemy_fire(e, a, k)
					if a.burst > 1:
						if e.burst_left[k] <= 0:
							e.burst_left[k] = a.burst
						e.burst_left[k] -= 1
						cd += a.burst_interval if e.burst_left[k] > 0 else a.interval / _d_fire_rate
					else:
						cd += a.interval / _d_fire_rate
				e.attack_cd[k] = cd

		# Body collision with the player
		if p.alive:
			var dx := e.x - p.x
			var dy := e.y - p.y
			var rr := e.radius + p.radius
			if dx * dx + dy * dy <= rr * rr:
				damage_player(t.collision_damage * _d_damage, 1, e.slot)
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


func _enemy_fire(e: Enemy, a: AttackPattern, k: int) -> void:
	var count := a.count
	var base := 0.0
	var step := 0.0
	match a.type:
		AttackPattern.RING:
			base = e.attack_angle[k]
			e.attack_angle[k] = base + a.rotate
			step = TAU / float(count)
		AttackPattern.FAN_DOWN:
			base = PI * 0.5
		_:
			base = atan2(player.y - e.y, player.x - e.x)
	if a.type != AttackPattern.RING and count > 1:
		step = a.spread / float(count - 1)
		base -= a.spread * 0.5
	if stress:
		# Stress test: every shot becomes a full ring.
		count = 10
		step = TAU / 10.0
	var spd := a.bullet_speed * _d_bullet_speed
	var dmg := a.damage * _d_damage
	for i in count:
		var ang := base + step * i
		ebul.spawn(e.x, e.y, cos(ang) * spd, sin(ang) * spd, a.bullet_radius, dmg, a.dtype, a.bullet_kind, 8.0, e.slot)


## A weapon explosion: damages every enemy within radius of (x, y).
func _explode(x: float, y: float, radius: float, dmg: float, dtype: int) -> void:
	for e in enemies:
		if not e.alive:
			continue
		var dx := e.x - x
		var dy := e.y - y
		var rr := radius + e.radius
		if dx * dx + dy * dy <= rr * rr:
			_damage_enemy(e, dmg, dtype)
	_emit(EV_SPLASH, x, y, radius)


## A bullet with extras goes off: a cluster burst (spawned after the bullet loop) or an explosion.
## `struck` is the enemy it hit, if any; bomblets do not hit that one again straight away.
func _detonate(i: int, struck: int = -1) -> void:
	var b := pbul
	if b.burst[i] >= 0:
		_pending_bursts.append(b.x[i])
		_pending_bursts.append(b.y[i])
		_pending_bursts.append(b.burst[i])
		_pending_bursts.append(struck)
	# The shell itself explodes too (a cluster bomb's casing as well as its bomblets).
	if b.splash[i] > 0.0:
		_explode(b.x[i], b.y[i], b.splash[i], b.damage[i], b.dtype[i])


func _spawn_pending_bursts() -> void:
	var n := _pending_bursts.size() / 4
	for k in n:
		var bx := _pending_bursts[k * 4]
		var by := _pending_bursts[k * 4 + 1]
		var d: Dictionary = _bursts[int(_pending_bursts[k * 4 + 2])]
		var struck := int(_pending_bursts[k * 4 + 3])
		var count: int = d["count"]
		for j in count:
			var ang := TAU * (float(j) + _rng.randf()) / float(count)
			var sp: float = d["speed"] * _rng.randf_range(0.6, 1.0)
			var i := pbul.spawn(bx, by, cos(ang) * sp, sin(ang) * sp, 1.0, d["damage"], 2, d["kind"], d["lifetime"] + 0.5, 0)
			if i < 0:
				break
			pbul.set_extra(i, d["splash"], 0.0, 0.0, d["lifetime"] * _rng.randf_range(0.8, 1.0), 0.0, -1, -1, 0)
			pbul.has_extra[i] = 2
			pbul.last_hit[i] = struck
	_pending_bursts.clear()


## Steering, fuses and proximity triggers for bullets with extras. Returns true if it went off.
func _step_extra(i: int, dt: float) -> bool:
	var b := pbul
	if b.turn[i] > 0.0:
		var slot := b.target[i]
		if slot < 0 or not enemies[slot].alive or enemies[slot].uid != b.target_uid[i]:
			slot = -1
			var best := INF
			for e in enemies:
				if e.alive and e.y > -HALF_H:
					var d := (e.x - b.x[i]) * (e.x - b.x[i]) + (e.y - b.y[i]) * (e.y - b.y[i])
					if d < best:
						best = d
						slot = e.slot
			b.target[i] = slot
			if slot >= 0:
				b.target_uid[i] = enemies[slot].uid
		if slot >= 0:
			var e := enemies[slot]
			var cur := atan2(b.vy[i], b.vx[i])
			var want := atan2(e.y - b.y[i], e.x - b.x[i])
			var diff := wrapf(want - cur, -PI, PI)
			var turn := clampf(diff, -b.turn[i] * dt, b.turn[i] * dt)
			var sp := sqrt(b.vx[i] * b.vx[i] + b.vy[i] * b.vy[i])
			b.vx[i] = cos(cur + turn) * sp
			b.vy[i] = sin(cur + turn) * sp
	if b.wander[i] > 0.0:
		var a := atan2(b.vy[i], b.vx[i]) + _rng.randf_range(-1.0, 1.0) * b.wander[i] * dt
		var sp2 := sqrt(b.vx[i] * b.vx[i] + b.vy[i] * b.vy[i])
		b.vx[i] = cos(a) * sp2
		b.vy[i] = sin(a) * sp2
	if b.fuse[i] >= 0.0:
		b.fuse[i] -= dt
		if b.fuse[i] <= 0.0:
			_detonate(i)
			return true
	if b.prox[i] > 0.0:
		var r := b.prox[i]
		for e in enemies:
			if e.alive:
				var dx := e.x - b.x[i]
				var dy := e.y - b.y[i]
				var rr := r + e.radius
				if dx * dx + dy * dy <= rr * rr:
					_detonate(i)
					return true
	return false


func _damage_enemy(e: Enemy, amount: float, dtype: int) -> void:
	e.hp -= amount * (1.0 - e.type.resist[dtype])
	e.hit_time = time
	if e.hp <= 0.0 and e.alive:
		if e.is_boss:
			boss_killed = true
			boss_kill_time = level_time - e.spawn_time
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
	var bextra := b.has_extra
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
		if not dead and bextra[i] != 0:
			dead = _step_extra(i, dt)
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
							if bextra[i] != 2 and blast[i] == -1:
								shots_hit += 1
							_emit(EV_HIT, nx, ny, bdtype[i])
							if bextra[i] != 0 and (b.splash[i] > 0.0 or b.burst[i] >= 0):
								_detonate(i, slot)
								dead = true
								break
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
	if not _pending_bursts.is_empty():
		_spawn_pending_bursts()


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
