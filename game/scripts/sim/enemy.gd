class_name Enemy
extends RefCounted
## One enemy slot. Slots are reused; `uid` changes every time a slot is respawned.

const MAX_ATTACKS := 4

var alive: bool = false
var slot: int = 0
var uid: int = 0
var type: EnemyType
var move: MovePattern        # the type's pattern, or a wave's override
var hp: float = 0.0
var max_hp: float = 0.0
var x: float = 0.0
var y: float = 0.0
var ox: float = 0.0   # position at the previous tick, for interpolation
var oy: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var radius: float = 1.0
var spawn_x: float = 0.0
var t: float = 0.0          # seconds alive
var phase: int = 0
var phase_t: float = 0.0
var path_i: int = 0
var hit_time: float = -10.0  # sim time of the last hit, drives the hit flash
# Per attack pattern state
var attack_cd: PackedFloat32Array
var attack_angle: PackedFloat32Array
var burst_left: PackedInt32Array


func _init() -> void:
	attack_cd.resize(MAX_ATTACKS)
	attack_angle.resize(MAX_ATTACKS)
	burst_left.resize(MAX_ATTACKS)
