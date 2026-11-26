class_name AttackPattern
extends RefCounted
## A reusable attack pattern from data/enemies/patterns.json, unpacked into typed fields.

const AIMED := 0      # fan of `count` bullets centred on the player
const RING := 1       # `count` bullets evenly around the enemy; rotate_deg turns it into a spiral
const FAN_DOWN := 2   # fan of `count` bullets centred straight down

const TYPES := {"aimed": AIMED, "ring": RING, "fan_down": FAN_DOWN}

var id: String = ""
var type: int = AIMED
var interval: float = 2.0
var first_delay: float = 1.0
var count: int = 1
var spread: float = 0.0          # radians, total fan width
var rotate: float = 0.0          # radians added to the ring's start angle after every shot
var burst: int = 1               # shots per volley
var burst_interval: float = 0.15
var bullet_speed: float = 50.0
var damage: float = 10.0
var dtype: int = 0
var bullet_radius: float = 1.0
var bullet_kind: int = 0


static func from_def(d: Dictionary, damage_types: Array, sim: GameSim) -> AttackPattern:
	var a := AttackPattern.new()
	a.id = d.get("id", "")
	a.type = TYPES.get(String(d.get("type", "aimed")), AIMED)
	a.interval = d.get("interval", a.interval)
	a.first_delay = d.get("first_delay", a.first_delay)
	a.count = int(d.get("count", 1))
	a.spread = deg_to_rad(d.get("spread_deg", 0.0))
	a.rotate = deg_to_rad(d.get("rotate_deg", 0.0))
	a.burst = int(d.get("burst", 1))
	a.burst_interval = d.get("burst_interval", a.burst_interval)
	a.bullet_speed = d.get("bullet_speed", a.bullet_speed)
	a.damage = d.get("damage", a.damage)
	a.dtype = maxi(damage_types.find(d.get("damage_type", "energy")), 0)
	a.bullet_radius = d.get("bullet_radius", a.bullet_radius)
	a.bullet_kind = sim.kind_of(d.get("bullet_visual", "proj.enemy.orb"))
	return a
