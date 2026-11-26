class_name MovePattern
extends RefCounted
## A reusable movement pattern from data/enemies/patterns.json, unpacked into typed fields.

const STRAIGHT := 0
const SINE := 1
const SWOOP_HOLD := 2
const DIVE := 3
const CIRCLE := 4
const PATH := 5
const ZIGZAG := 6

const TYPES := {
	"straight": STRAIGHT, "sine": SINE, "swoop_hold": SWOOP_HOLD, "dive": DIVE,
	"circle": CIRCLE, "path": PATH, "zigzag": ZIGZAG,
}

var id: String = ""
var type: int = STRAIGHT
var amplitude: float = 10.0      # sine: sideways swing
var frequency: float = 0.5       # sine: swings per second
var width: float = 12.0          # zigzag: sideways reach
var period: float = 1.5          # zigzag: seconds per full zig and zag
var hold_y: float = -30.0        # swoop_hold: where it stops
var hold_time: float = 8.0       # swoop_hold: how long it stays
var drift: float = 0.0           # swoop_hold: sideways sway while holding
var delay: float = 1.0           # dive: seconds before it commits to the dive
var dive_speed: float = 70.0     # dive: speed toward where the player was
var center_y: float = -20.0      # circle: top of the circle
var radius: float = 12.0         # circle
var angular_speed: float = 1.5   # circle: radians per second
var time: float = 6.0            # circle: how long it circles
var points: PackedVector2Array   # path: [x offset from spawn x, y]


static func from_def(d: Dictionary) -> MovePattern:
	var m := MovePattern.new()
	m.id = d.get("id", "")
	m.type = TYPES.get(String(d.get("type", "straight")), STRAIGHT)
	m.amplitude = d.get("amplitude", m.amplitude)
	m.frequency = d.get("frequency", m.frequency)
	m.width = d.get("width", m.width)
	m.period = d.get("period", m.period)
	m.hold_y = d.get("hold_y", m.hold_y)
	m.hold_time = d.get("hold_time", m.hold_time)
	m.drift = d.get("drift", m.drift)
	m.delay = d.get("delay", m.delay)
	m.dive_speed = d.get("dive_speed", m.dive_speed)
	m.center_y = d.get("center_y", m.center_y)
	m.radius = d.get("radius", m.radius)
	m.angular_speed = d.get("angular_speed", m.angular_speed)
	m.time = d.get("time", m.time)
	for p: Array in d.get("points", []):
		m.points.append(Vector2(p[0], p[1]))
	return m
