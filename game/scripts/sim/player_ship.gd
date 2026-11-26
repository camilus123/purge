class_name PlayerShip
extends RefCounted
## Player ship state. All numbers come from data via GameSim.setup_player().

var alive: bool = true
var x: float = 0.0
var y: float = 40.0
var ox: float = 0.0   # position at the previous tick, for interpolation
var oy: float = 40.0
var vx: float = 0.0
var vy: float = 0.0
var tx: float = 0.0   # aim point the ship chases
var ty: float = 40.0

var max_speed: float = 240.0
var accel: float = 12000.0
var follow_gain: float = 40.0
var radius: float = 1.5
var ram_damage: float = 60.0
var invulnerable: float = 0.0   # seconds of spawn protection left

var armor: float = 100.0
var armor_max: float = 100.0
var resist: PackedFloat32Array

var shield_name: String = ""
var shield_visual: String = ""
var shield: float = 0.0
var shield_max: float = 0.0
var shield_recharge: float = 0.0
var shield_delay: float = 0.0
var shield_reflect: float = 0.0
var shield_bleed: float = 0.0
var shield_timer: float = 0.0   # time until recharge resumes

var reactor_output: float = 100.0
var pool: float = 0.0           # weapon energy pool
var pool_max: float = 150.0
var shield_share: float = 0.5   # 0..1, the rest goes to weapons

var weapons: Array[WeaponState] = []
