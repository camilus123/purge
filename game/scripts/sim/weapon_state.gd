class_name WeaponState
extends RefCounted
## A mounted primary weapon: its data unpacked into typed fields plus its runtime state.
## Behaviour is built from components: projectile count, spread, spacing, pierce, splash
## (projectiles), a continuous beam that may sweep (beam), or a charged instant line (rail).

const PROJECTILE := 0
const BEAM := 1
const RAIL := 2

var id: String
var name: String
var sound: String
var behaviour: int = PROJECTILE
var is_energy: bool
var damage: float          # per shot, or per second for beams
var fire_rate: float
var speed: float
var radius: float
var lifetime: float
var projectiles: int
var spread: float          # radians, total fan width for multi-projectile shots
var random_spread: float   # radians, random scatter per projectile
var spacing: float         # sideways distance between parallel projectiles
var pierce: int
var splash: float          # explosion radius on impact, 0 = none
var dtype: int
var kind: int
var energy_per_shot: float # per shot, or per second for beams
var heat_per_shot: float
var heat_capacity: float
var heat_dissipation: float
var overheat_recover: float
var spin_up: float
var spin_min_rate: float
var beam_range: float = 130.0
var beam_width: float = 1.0
var beam_kind: int = 0
var sweep: float = 0.0          # radians, half of the total sweep
var sweep_speed: float = 0.0    # radians of phase per second
var charge_time: float = 0.0
var dmg_scale_0: float = 1.0   # multiplier at 0% weapon power
var dmg_scale_1: float = 1.0   # multiplier at 100% weapon power
var rate_scale_0: float = 1.0
var rate_scale_1: float = 1.0
var muzzle_x: float = 0.0
var muzzle_y: float = 0.0

# Runtime state
var cooldown: float = 0.0
var spin: float = 0.0
var heat: float = 0.0
var overheated: bool = false
var starved: bool = false
var charge: float = 0.0
var sweep_t: float = 0.0
var sound_timer: float = 0.0
var hit_timer: float = 0.0
var accuracy_timer: float = 0.0
var accuracy_hit: bool = false
# Beam geometry for the view, valid while beam_on: start, direction and length.
var beam_on: bool = false
var beam_angle: float = 0.0
var beam_len: float = 0.0


static func from_def(d: Dictionary, damage_types: Array, sim: GameSim) -> WeaponState:
	var w := WeaponState.new()
	w.id = d["id"]
	w.name = d.get("name", w.id)
	w.sound = d.get("sound", "")
	match String(d.get("behaviour", "projectile")):
		"beam":
			w.behaviour = BEAM
		"rail":
			w.behaviour = RAIL
		_:
			w.behaviour = PROJECTILE
	w.is_energy = String(d.get("class", "energy")) == "energy"
	w.damage = d["damage"]
	w.fire_rate = d["fire_rate"]
	w.speed = d.get("projectile_speed", 250.0)
	w.radius = d.get("radius", 1.0)
	w.lifetime = d.get("lifetime", 1.0)
	w.projectiles = int(d.get("projectiles", 1))
	w.spread = deg_to_rad(d.get("spread_deg", 0.0))
	w.random_spread = deg_to_rad(d.get("random_spread_deg", 0.0))
	w.spacing = d.get("spacing", 0.0)
	w.pierce = int(d.get("pierce", 0))
	w.splash = d.get("splash", 0.0)
	w.dtype = maxi(damage_types.find(d.get("damage_type", "energy")), 0)
	w.kind = sim.kind_of(d.get("projectile_visual", ""))
	w.energy_per_shot = d.get("energy_per_shot", 0.0)
	w.heat_per_shot = d.get("heat_per_shot", 0.0)
	w.heat_capacity = d.get("heat_capacity", 0.0)
	w.heat_dissipation = d.get("heat_dissipation", 0.0)
	w.overheat_recover = d.get("overheat_recover", 0.4)
	w.spin_up = d.get("spin_up", 0.0)
	w.spin_min_rate = d.get("spin_min_rate", 1.0)
	w.beam_range = d.get("range", 130.0)
	w.beam_width = d.get("beam_width", 1.0)
	w.beam_kind = sim.kind_of(d.get("beam_visual", d.get("projectile_visual", "")))
	w.sweep = deg_to_rad(d.get("sweep_deg", 0.0)) * 0.5
	w.sweep_speed = d.get("sweep_speed", 0.0)
	w.charge_time = d.get("charge_time", 0.0)
	var ps: Dictionary = d.get("power_scaling", {})
	if ps.has("damage"):
		w.dmg_scale_0 = ps["damage"][0]
		w.dmg_scale_1 = ps["damage"][1]
	if ps.has("fire_rate"):
		w.rate_scale_0 = ps["fire_rate"][0]
		w.rate_scale_1 = ps["fire_rate"][1]
	return w


func reset() -> void:
	cooldown = 0.0
	spin = 0.0
	heat = 0.0
	overheated = false
	starved = false
	charge = 0.0
	sweep_t = 0.0
	beam_on = false


## Shots per second right now, given the weapon power share (0..1).
func current_rate(weapon_share: float) -> float:
	var r := fire_rate * lerpf(rate_scale_0, rate_scale_1, weapon_share)
	if spin_up > 0.0:
		r *= lerpf(spin_min_rate, 1.0, spin)
	return r


func current_damage(weapon_share: float) -> float:
	return damage * lerpf(dmg_scale_0, dmg_scale_1, weapon_share)
