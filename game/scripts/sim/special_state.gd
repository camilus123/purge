class_name SpecialState
extends RefCounted
## The mounted special weapon (middle mouse): its data unpacked and its ammo and cooldown.

var id: String = ""
var name: String = ""
var ammo: int = 0
var ammo_max: int = 0
var cooldown: float = 0.0
var cooldown_time: float = 0.6
var volley: int = 1
var spread: float = 0.0      # radians, total fan width of a volley
var spacing: float = 0.0     # sideways distance between items launched behind the ship
var behind: bool = false
var shockwave: bool = false
var shockwave_damage: float = 0.0
var sound: String = "sfx.special.launch"
# Projectile
var speed: float = 80.0
var damage: float = 30.0
var dtype: int = 2
var radius: float = 1.2
var lifetime: float = 3.0
var splash: float = 0.0
var homing: float = 0.0
var wander: float = 0.0
var fuse: float = 0.0
var proximity: float = 0.0
var drift: float = 0.0
var kind: int = 0
var burst: int = -1          # index into GameSim's burst table, -1 = none


static func from_def(d: Dictionary, damage_types: Array, sim: GameSim) -> SpecialState:
	var s := SpecialState.new()
	s.id = d["id"]
	s.name = d.get("name", s.id)
	s.ammo_max = int(d.get("ammo", 1))
	s.ammo = s.ammo_max
	s.cooldown_time = d.get("cooldown", 0.6)
	s.volley = int(d.get("volley", 1))
	s.spread = deg_to_rad(d.get("spread_deg", 0.0))
	s.spacing = d.get("spacing", 0.0)
	s.behind = String(d.get("launch", "forward")) == "behind"
	s.shockwave = String(d.get("effect", "")) == "shockwave"
	s.shockwave_damage = d.get("shockwave_damage", 0.0)
	s.sound = d.get("sound", "sfx.special.shockwave" if s.shockwave else "sfx.special.launch")
	var p: Dictionary = d.get("projectile", {})
	s.speed = p.get("speed", s.speed)
	s.damage = p.get("damage", s.damage)
	s.dtype = maxi(damage_types.find(p.get("damage_type", "explosive")), 0)
	s.radius = p.get("radius", s.radius)
	s.lifetime = p.get("lifetime", s.lifetime)
	s.splash = p.get("splash", 0.0)
	s.homing = p.get("homing", 0.0)
	s.wander = p.get("wander", 0.0)
	s.fuse = p.get("fuse", 0.0)
	s.proximity = p.get("proximity", 0.0)
	s.drift = p.get("drift", 0.0)
	s.kind = sim.kind_of(p.get("visual", "proj.missile"))
	if p.has("burst"):
		s.burst = sim.register_burst(p["burst"])
	return s
