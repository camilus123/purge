class_name PlaceholderModels
extends RefCounted
## Clean placeholder models built from primitives, keyed by the placeholder name in data/assets.json.
## Conventions (see docs/MODDING.md): player faces -Z, enemies face +Z, Y is up, 1 unit = 1 m.
## Real .glb models will replace these through the asset manifest.

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


static func get_mesh(id: String) -> Mesh:
	if _cache.has(id):
		return _cache[id]
	var parts: Array = []
	match id:
		"player":
			parts = _player()
		"drone":
			parts = _drone()
		"gunship":
			parts = _gunship()
		"dart":
			parts = _dart()
		"sentry":
			parts = _sentry()
		_:
			# The visible "missing model" stand-in.
			parts = [[_box(Vector3(4, 2, 4)), Transform3D.IDENTITY, _mat(Color(1, 0, 1), 0.0, 0.6, Color(1, 0, 1), 1.5)]]
	var mesh := _build(parts)
	_cache[id] = mesh
	return mesh


static func _mat(color: Color, metallic: float = 0.4, roughness: float = 0.45,
		emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color, metallic, roughness, emission, energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func _xf(pos: Vector3, scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos)


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	return m


## Merges [mesh, transform, material] parts into one ArrayMesh with a surface per material.
static func _build(parts: Array) -> ArrayMesh:
	var tools: Dictionary = {}
	var order: Array = []
	for p: Array in parts:
		var mat: Material = p[2]
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
			order.append(mat)
		(tools[mat] as SurfaceTool).append_from(p[0], 0, p[1])
	var mesh := ArrayMesh.new()
	for mat: Material in order:
		(tools[mat] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


static func _player() -> Array:
	var hull := _mat(Color(0.78, 0.82, 0.9), 0.5, 0.35)
	var dark := _mat(Color(0.16, 0.2, 0.3), 0.6, 0.4)
	var accent := _mat(Color(0.1, 0.5, 0.9), 0.3, 0.4, Color(0.2, 0.7, 1.0), 2.5)
	var glass := _mat(Color(0.05, 0.2, 0.3), 0.8, 0.1, Color(0.2, 0.9, 1.0), 1.2)
	var engine := _mat(Color(1, 0.6, 0.2), 0.0, 0.5, Color(1.0, 0.55, 0.15), 6.0)
	var back := PI * 0.5   # rotate a Y-up cylinder to lie along Z
	return [
		[_sphere(), _xf(Vector3(0, 0, -0.3), Vector3(1.05, 0.7, 3.5)), hull],
		[_box(Vector3(3.6, 0.22, 1.5)), _xf(Vector3(-2.2, 0, 1.0), Vector3.ONE, Vector3(0, 0.38, 0)), hull],
		[_box(Vector3(3.6, 0.22, 1.5)), _xf(Vector3(2.2, 0, 1.0), Vector3.ONE, Vector3(0, -0.38, 0)), hull],
		[_box(Vector3(0.3, 0.3, 1.9)), _xf(Vector3(-3.85, 0, 1.75)), accent],
		[_box(Vector3(0.3, 0.3, 1.9)), _xf(Vector3(3.85, 0, 1.75)), accent],
		[_sphere(), _xf(Vector3(0, 0.45, -1.3), Vector3(0.5, 0.4, 1.0)), glass],
		[_cyl(0.5, 0.42, 2.2), _xf(Vector3(-0.95, 0, 2.5), Vector3.ONE, Vector3(back, 0, 0)), dark],
		[_cyl(0.5, 0.42, 2.2), _xf(Vector3(0.95, 0, 2.5), Vector3.ONE, Vector3(back, 0, 0)), dark],
		[_sphere(), _xf(Vector3(-0.95, 0, 3.6), Vector3(0.36, 0.36, 0.3)), engine],
		[_sphere(), _xf(Vector3(0.95, 0, 3.6), Vector3(0.36, 0.36, 0.3)), engine],
		[_box(Vector3(0.16, 0.9, 1.5)), _xf(Vector3(0, 0.6, 2.1)), dark],
		[_cyl(0.12, 0.12, 1.6), _xf(Vector3(-1.6, 0, -2.2), Vector3.ONE, Vector3(back, 0, 0)), dark],
		[_cyl(0.12, 0.12, 1.6), _xf(Vector3(1.6, 0, -2.2), Vector3.ONE, Vector3(back, 0, 0)), dark],
	]


static func _drone() -> Array:
	var body := _mat(Color(0.3, 0.3, 0.34), 0.6, 0.4)
	var plate := _mat(Color(0.55, 0.12, 0.1), 0.4, 0.5)
	var eye := _mat(Color(1, 0.2, 0.1), 0.0, 0.4, Color(1.0, 0.15, 0.05), 5.0)
	return [
		[_sphere(), _xf(Vector3.ZERO, Vector3(1.7, 0.9, 1.9)), body],
		[_sphere(), _xf(Vector3(0, 0.55, 1.0), Vector3(0.55, 0.4, 0.55)), eye],
		[_box(Vector3(1.3, 0.25, 4.2)), _xf(Vector3(-2.5, 0, -0.2), Vector3.ONE, Vector3(0, -0.25, 0)), plate],
		[_box(Vector3(1.3, 0.25, 4.2)), _xf(Vector3(2.5, 0, -0.2), Vector3.ONE, Vector3(0, 0.25, 0)), plate],
		[_box(Vector3(3.4, 0.3, 0.5)), _xf(Vector3(0, 0, -0.3)), body],
	]


static func _gunship() -> Array:
	var steel := _mat(Color(0.26, 0.28, 0.33), 0.65, 0.4)
	var plate := _mat(Color(0.5, 0.13, 0.1), 0.4, 0.5)
	var glow := _mat(Color(1, 0.25, 0.1), 0.0, 0.4, Color(1.0, 0.2, 0.05), 5.0)
	var engine := _mat(Color(1, 0.5, 0.2), 0.0, 0.5, Color(1.0, 0.45, 0.1), 5.0)
	var back := PI * 0.5
	return [
		[_box(Vector3(5.0, 1.5, 8.0)), _xf(Vector3.ZERO), steel],
		[_box(Vector3(3.4, 0.6, 5.0)), _xf(Vector3(0, 0.95, 0.4)), plate],
		[_box(Vector3(1.8, 1.0, 2.2)), _xf(Vector3(0, 1.5, -1.6)), steel],
		[_cyl(0.95, 0.95, 6.5), _xf(Vector3(-3.6, 0, 0.6), Vector3.ONE, Vector3(back, 0, 0)), steel],
		[_cyl(0.95, 0.95, 6.5), _xf(Vector3(3.6, 0, 0.6), Vector3.ONE, Vector3(back, 0, 0)), steel],
		[_sphere(), _xf(Vector3(-3.6, 0, 3.9), Vector3(0.7, 0.7, 0.5)), glow],
		[_sphere(), _xf(Vector3(3.6, 0, 3.9), Vector3(0.7, 0.7, 0.5)), glow],
		[_sphere(), _xf(Vector3(0, 0.3, 4.0), Vector3(0.9, 0.5, 0.4)), glow],
		[_box(Vector3(3.6, 0.8, 0.4)), _xf(Vector3(0, 0, -4.1)), engine],
	]


static func _dart() -> Array:
	var body := _mat(Color(0.32, 0.3, 0.3), 0.6, 0.4)
	var plate := _mat(Color(0.6, 0.2, 0.08), 0.4, 0.5)
	var eye := _mat(Color(1, 0.5, 0.1), 0.0, 0.4, Color(1.0, 0.45, 0.05), 5.0)
	return [
		[_cyl(0.0, 0.9, 4.6), _xf(Vector3(0, 0, 0.4), Vector3.ONE, Vector3(PI * 0.5, 0, 0)), body],
		[_box(Vector3(4.4, 0.2, 1.3)), _xf(Vector3(0, 0, -1.2)), plate],
		[_sphere(), _xf(Vector3(0, 0.35, 0.6), Vector3(0.4, 0.3, 0.6)), eye],
	]


static func _sentry() -> Array:
	var steel := _mat(Color(0.25, 0.27, 0.32), 0.65, 0.4)
	var plate := _mat(Color(0.5, 0.13, 0.1), 0.4, 0.5)
	var glow := _mat(Color(1, 0.2, 0.5), 0.0, 0.4, Color(1.0, 0.1, 0.5), 5.0)
	var parts: Array = [
		[_cyl(4.6, 5.2, 1.4), _xf(Vector3.ZERO), steel],
		[_cyl(2.6, 3.2, 1.2), _xf(Vector3(0, 1.1, 0)), plate],
		[_sphere(), _xf(Vector3(0, 1.8, 0), Vector3(1.3, 0.8, 1.3)), glow],
	]
	for i in 6:
		var a := TAU * i / 6.0
		parts.append([_box(Vector3(1.0, 0.8, 2.2)), _xf(Vector3(sin(a) * 5.2, 0, cos(a) * 5.2), Vector3.ONE, Vector3(0, a, 0)), steel])
		parts.append([_sphere(), _xf(Vector3(sin(a) * 6.3, 0, cos(a) * 6.3), Vector3(0.4, 0.4, 0.4)), glow])
	return parts
