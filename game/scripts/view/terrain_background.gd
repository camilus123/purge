class_name TerrainBackground
extends Node3D
## Low-altitude background: a procedural ground plane with real 3D buildings on the city
## blocks, so they shift in perspective as the ship flies over. Buildings are streamed
## row by row as the ground scrolls; only the row entering the screen is rewritten.

const GROUND_Y := -34.0
const CELL := 8.0
const COLS := 20          # cells across, centred on x = 0
const ROWS := 32          # cells along the flight direction
const TOP_Z := -128.0     # world z where new rows appear

var ground_speed_scale: float = 1.0

var _ground_mat: ShaderMaterial
var _mm: MultiMesh
var _mm_node: MultiMeshInstance3D
var _first_row: int = 2147483647
var _palette: Array[Color] = [
	Color(0.55, 0.56, 0.6), Color(0.62, 0.58, 0.5), Color(0.4, 0.47, 0.56),
	Color(0.5, 0.5, 0.5), Color(0.66, 0.64, 0.6), Color(0.45, 0.36, 0.3),
]


## Must match urban() in terrain.gdshader.
static func urban(x: float, z: float) -> float:
	return sin(x * 0.021 + 1.7) * 0.6 + sin(z * 0.011 + 0.4) * 0.8 + sin((x + z) * 0.007) * 0.5


static func _cell_random(i: int, j: int, salt: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


func setup(config: Dictionary) -> void:
	ground_speed_scale = config.get("ground_speed_scale", 2.5)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(360, 420)
	ground.mesh = plane
	ground.position = Vector3(0, GROUND_Y, -10)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/terrain.gdshader")
	_ground_mat.set_shader_parameter("corruption_amount", float(config.get("corruption", 0.0)))
	ground.material_override = _ground_mat
	add_child(ground)

	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	box.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = box
	_mm.instance_count = COLS * ROWS
	_mm.custom_aabb = AABB(Vector3(-1e6, -100, -1e6), Vector3(2e6, 200, 2e6))
	_mm_node = MultiMeshInstance3D.new()
	_mm_node.multimesh = _mm
	_mm_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm_node)
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for i in COLS * ROWS:
		_mm.set_instance_transform(i, hidden)


## scroll: the simulation's scroll distance.
func update(scroll: float) -> void:
	var ground_scroll := scroll * ground_speed_scale
	_ground_mat.set_shader_parameter("scroll", ground_scroll)
	_mm_node.position.z = ground_scroll
	# Rows are indexed in ground space; as the ground slides down the screen, lower indices appear at the top.
	var first := floori((TOP_Z - ground_scroll) / CELL)
	if _first_row == 2147483647 or absi(first - _first_row) >= ROWS:
		for j in range(first, first + ROWS):
			_build_row(j)
	else:
		for j in range(first, _first_row):
			_build_row(j)
	_first_row = first


func _build_row(j: int) -> void:
	var slot := posmod(j, ROWS) * COLS
	var gz := (j + 0.5) * CELL
	for c in COLS:
		var i := c - COLS / 2
		var gx := (i + 0.5) * CELL
		var u := urban(gx, gz)
		var t := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if u > 0.78 and _cell_random(i, j, 1) > 0.18:
			# Taller towards the centre of a city.
			var height := 2.5 + _cell_random(i, j, 2) * 5.0 + maxf(0.0, u - 0.95) * 22.0 * _cell_random(i, j, 3)
			var w := 4.2 + _cell_random(i, j, 4) * 1.4
			var d := 4.2 + _cell_random(i, j, 5) * 1.4
			t = Transform3D(Basis.from_scale(Vector3(w, height, d)), Vector3(gx, GROUND_Y + height * 0.5, gz))
			var col := _palette[int(_cell_random(i, j, 6) * (_palette.size() - 0.01))]
			_mm.set_instance_color(slot + c, col * (0.34 + 0.14 * _cell_random(i, j, 7)))
		_mm.set_instance_transform(slot + c, t)
