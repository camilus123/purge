class_name Enemy
extends RefCounted
## One enemy slot. Slots are reused; `uid` changes every time a slot is respawned.

var alive: bool = false
var slot: int = 0
var uid: int = 0
var type: EnemyType
var hp: float = 0.0
var max_hp: float = 0.0
var x: float = 0.0
var y: float = 0.0
var ox: float = 0.0   # position at the previous tick, for interpolation
var oy: float = 0.0
var radius: float = 1.0
var spawn_x: float = 0.0
var t: float = 0.0          # seconds alive
var phase: int = 0
var phase_t: float = 0.0
var attack_cd: float = 0.0
var hit_time: float = -10.0  # sim time of the last hit, drives the hit flash
