class_name EnemyType
extends RefCounted
## An enemy definition from data, unpacked into typed fields once so the
## simulation loop does no dictionary lookups.

const MOVE_STRAIGHT := 0
const MOVE_SINE := 1
const MOVE_SWOOP_HOLD := 2

var id: String
var model: String
var hp: float
var resist: PackedFloat32Array   # per damage type index
var collision_damage: float
var speed: float
var radius: float
var credits: int

var move: int = MOVE_STRAIGHT
var amplitude: float = 0.0
var frequency: float = 0.0
var hold_y: float = 0.0
var hold_time: float = 0.0
var drift: float = 0.0

var has_attack: bool = false
var atk_interval: float = 1.0
var atk_first_delay: float = 1.0
var atk_count: int = 1
var atk_spread: float = 0.0      # radians, total fan width
var bullet_speed: float = 50.0
var bullet_damage: float = 10.0
var bullet_radius: float = 1.0
var bullet_kind: int = 0


static func from_def(d: Dictionary, damage_types: Array, sim: GameSim) -> EnemyType:
	var t := EnemyType.new()
	t.id = d["id"]
	t.model = d.get("model", "")
	t.hp = d["hp"]
	t.collision_damage = d.get("collision_damage", 20.0)
	t.speed = d.get("speed", 30.0)
	t.radius = d.get("radius", 3.0)
	t.credits = int(d.get("credits", 0))
	t.resist.resize(damage_types.size())
	var res: Dictionary = d.get("resist", {})
	for i in damage_types.size():
		t.resist[i] = res.get(damage_types[i], 0.0)

	var mv: Dictionary = d.get("movement", {})
	match String(mv.get("type", "straight")):
		"sine":
			t.move = MOVE_SINE
			t.amplitude = mv.get("amplitude", 10.0)
			t.frequency = mv.get("frequency", 0.5)
		"swoop_hold":
			t.move = MOVE_SWOOP_HOLD
			t.hold_y = mv.get("hold_y", -30.0)
			t.hold_time = mv.get("hold_time", 8.0)
			t.drift = mv.get("drift", 0.0)
		_:
			t.move = MOVE_STRAIGHT

	if d.has("attack"):
		var a: Dictionary = d["attack"]
		t.has_attack = true
		t.atk_interval = a.get("interval", 2.0)
		t.atk_first_delay = a.get("first_delay", 1.0)
		t.atk_count = int(a.get("count", 1))
		t.atk_spread = deg_to_rad(a.get("spread_deg", 0.0))
		t.bullet_speed = a.get("bullet_speed", 50.0)
		t.bullet_damage = a.get("damage", 10.0)
		t.bullet_radius = a.get("bullet_radius", 1.0)
		t.bullet_kind = sim.kind_of(a.get("bullet_visual", "proj.enemy.orb"))
	return t
