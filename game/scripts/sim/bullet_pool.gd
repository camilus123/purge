class_name BulletPool
extends RefCounted
## Fixed-capacity bullet storage as parallel arrays. Live bullets are always
## packed in [0, count); removing one swaps the last bullet into its place.
## Packed arrays are shared by reference in Godot 4, so hot loops may alias them.
## The "extra" arrays (splash, homing and so on) are only used by the player's pool;
## `special` counts the live bullets that use any of them so plain shots skip that work.

var capacity: int
var count: int = 0
var x: PackedFloat32Array
var y: PackedFloat32Array
var vx: PackedFloat32Array
var vy: PackedFloat32Array
var radius: PackedFloat32Array
var damage: PackedFloat32Array
var life: PackedFloat32Array
var dtype: PackedInt32Array     # index into the damage type list
var kind: PackedInt32Array      # visual id, see GameSim.kind_of()
var pierce: PackedInt32Array    # how many more targets it may pass through (enemy pool: slot of the shooter)
var last_hit: PackedInt32Array  # enemy slot hit last, so piercing shots hit each target once
# Extras
var splash: PackedFloat32Array  # explosion radius on impact
var turn: PackedFloat32Array    # homing turn rate, radians/s
var wander: PackedFloat32Array  # random steering, radians/s
var fuse: PackedFloat32Array    # seconds until it bursts or explodes, < 0 = no fuse
var prox: PackedFloat32Array    # proximity trigger radius
var burst: PackedInt32Array     # burst table index used when it goes off, -1 = none
var target: PackedInt32Array    # enemy slot it homes on, -1 = none
var target_uid: PackedInt32Array
var has_extra: PackedByteArray


func _init(cap: int) -> void:
	capacity = cap
	for arr: String in ["x", "y", "vx", "vy", "radius", "damage", "life", "splash", "turn", "wander", "fuse", "prox"]:
		var a: PackedFloat32Array = get(arr)
		a.resize(cap)
		set(arr, a)
	for arr: String in ["dtype", "kind", "pierce", "last_hit", "burst", "target", "target_uid"]:
		var a: PackedInt32Array = get(arr)
		a.resize(cap)
		set(arr, a)
	has_extra.resize(cap)


func spawn(px: float, py: float, pvx: float, pvy: float, rad: float, dmg: float,
		dt_index: int, visual: int, lifetime: float, pierce_count: int) -> int:
	if count >= capacity:
		return -1
	var i := count
	x[i] = px
	y[i] = py
	vx[i] = pvx
	vy[i] = pvy
	radius[i] = rad
	damage[i] = dmg
	life[i] = lifetime
	dtype[i] = dt_index
	kind[i] = visual
	pierce[i] = pierce_count
	last_hit[i] = -1
	has_extra[i] = 0
	count += 1
	return i


## Gives bullet i its extra behaviour. Call right after spawn().
func set_extra(i: int, p_splash: float, p_turn: float, p_wander: float, p_fuse: float, p_prox: float,
		p_burst: int, p_target: int, p_target_uid: int) -> void:
	splash[i] = p_splash
	turn[i] = p_turn
	wander[i] = p_wander
	fuse[i] = p_fuse
	prox[i] = p_prox
	burst[i] = p_burst
	target[i] = p_target
	target_uid[i] = p_target_uid
	has_extra[i] = 1


func remove(i: int) -> void:
	var l := count - 1
	if i != l:
		x[i] = x[l]
		y[i] = y[l]
		vx[i] = vx[l]
		vy[i] = vy[l]
		radius[i] = radius[l]
		damage[i] = damage[l]
		life[i] = life[l]
		dtype[i] = dtype[l]
		kind[i] = kind[l]
		pierce[i] = pierce[l]
		last_hit[i] = last_hit[l]
		has_extra[i] = has_extra[l]
		if has_extra[l] != 0:
			splash[i] = splash[l]
			turn[i] = turn[l]
			wander[i] = wander[l]
			fuse[i] = fuse[l]
			prox[i] = prox[l]
			burst[i] = burst[l]
			target[i] = target[l]
			target_uid[i] = target_uid[l]
	count = l


func clear() -> void:
	count = 0
