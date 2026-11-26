class_name EnemyType
extends RefCounted
## An enemy definition from data, unpacked into typed fields once so the
## simulation loop does no dictionary lookups.

var id: String
var model: String
var hp: float
var resist: PackedFloat32Array   # per damage type index
var collision_damage: float
var speed: float
var radius: float
var credits: int
var move: MovePattern
var attacks: Array[AttackPattern] = []


## movement and attack are dictionaries of pattern id -> MovePattern / AttackPattern.
static func from_def(d: Dictionary, damage_types: Array, movement: Dictionary, attack: Dictionary) -> EnemyType:
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

	var move_id: String = d.get("movement", "")
	if movement.has(move_id):
		t.move = movement[move_id]
	else:
		push_warning("Enemy %s: unknown movement pattern '%s', flying straight" % [t.id, move_id])
		t.move = MovePattern.new()
	for attack_id: String in d.get("attacks", []):
		if attack.has(attack_id) and t.attacks.size() < Enemy.MAX_ATTACKS:
			t.attacks.append(attack[attack_id])
		else:
			push_warning("Enemy %s: attack pattern '%s' unknown or over the limit of %d" % [t.id, attack_id, Enemy.MAX_ATTACKS])
	return t
