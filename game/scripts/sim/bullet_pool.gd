class_name BulletPool
extends RefCounted
## Fixed-capacity bullet storage as parallel arrays. Live bullets are always
## packed in [0, count); removing one swaps the last bullet into its place.
## Packed arrays are shared by reference in Godot 4, so hot loops may alias them.

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
var pierce: PackedInt32Array    # how many more targets it may pass through
var last_hit: PackedInt32Array  # enemy slot hit last, so piercing shots hit each target once


func _init(cap: int) -> void:
	capacity = cap
	x.resize(cap)
	y.resize(cap)
	vx.resize(cap)
	vy.resize(cap)
	radius.resize(cap)
	damage.resize(cap)
	life.resize(cap)
	dtype.resize(cap)
	kind.resize(cap)
	pierce.resize(cap)
	last_hit.resize(cap)


func spawn(px: float, py: float, pvx: float, pvy: float, rad: float, dmg: float,
		dt_index: int, visual: int, lifetime: float, pierce_count: int) -> bool:
	if count >= capacity:
		return false
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
	count += 1
	return true


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
	count = l


func clear() -> void:
	count = 0
