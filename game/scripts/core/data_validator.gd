class_name DataValidator
extends RefCounted
## Checks every data file against its JSON Schema (data/schemas/) and checks that all
## cross-references resolve: tech prerequisites, patterns, enemies, damage types and asset ids.
## Supported schema keywords: type, properties, required, additionalProperties, items, enum,
## minimum, maximum, minItems, maxItems, and the custom "x-ref" (the string must be a known id
## of that kind: tech, enemy, movement, attack, damage_type, model, sprite, sound, shield_visual).

const TECH_SCHEMAS := {
	"tech/weapons.json": "weapons", "tech/shields.json": "shields", "tech/reactors.json": "reactors",
	"tech/armor.json": "armor", "tech/ship.json": "ship", "tech/power_model.json": "power_model",
}

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var files_checked: int = 0

var _ds: DataStore
var _refs: Dictionary = {}      # kind -> Dictionary used as a set of ids
var _schemas: Dictionary = {}
var _file: String = ""


## Runs every check. Returns true when there are no errors.
func run(ds: DataStore) -> bool:
	_ds = ds
	errors.clear()
	warnings.clear()
	files_checked = 0
	_build_registries()

	for rel: String in TECH_SCHEMAS:
		_check_file(rel, TECH_SCHEMAS[rel])
	for file_name in ds.list("tech"):
		var rel := "tech".path_join(file_name)
		if file_name.ends_with(".json") and not TECH_SCHEMAS.has(rel):
			warnings.append("data/%s: no schema for this file yet, only references were indexed" % rel)
	for file_name in ds.list("enemies"):
		if file_name.ends_with(".json"):
			_check_file("enemies".path_join(file_name), "patterns" if file_name == "patterns.json" else "enemies")
	_check_file("economy.json", "economy")
	_check_assets()
	for set_def: Dictionary in ds.sets:
		var folder: String = "levels".path_join(set_def["folder"])
		_check_file(folder.path_join("set.json"), "set")
		for level_file: Variant in set_def.get("levels", []):
			var rel := folder.path_join(String(level_file))
			if FileAccess.file_exists(ds.resolve(rel)):
				_check_file(rel, "level")
			else:
				errors.append("data/%s/set.json: levels: file '%s' does not exist" % [folder, level_file])
	_check_duplicate_ids()
	_check_tech_tree()
	return errors.is_empty()


func summary() -> String:
	return "%d files checked, %d errors, %d warnings" % [files_checked, errors.size(), warnings.size()]


# ---------------------------------------------------------------- registries

func _build_registries() -> void:
	for kind: String in ["tech", "enemy", "movement", "attack", "damage_type", "model", "sprite", "sound", "shield_visual"]:
		_refs[kind] = {}
	for id: String in _ds.items:
		var src: String = _ds.item_source.get(id, "")
		_refs["enemy" if src.begins_with("enemies/") else "tech"][id] = true
	for d: Variant in _ds.movement:
		if d is Dictionary and d.has("id"):
			_refs["movement"][d["id"]] = true
	for d: Variant in _ds.attack:
		if d is Dictionary and d.has("id"):
			_refs["attack"][d["id"]] = true
	for t: Variant in _ds.load_dict("tech/power_model.json").get("damage_types", []):
		_refs["damage_type"][t] = true
	var manifest := _load_manifest()
	for pair: Array in [["models", "model"], ["sprites", "sprite"], ["sounds", "sound"], ["shield_visuals", "shield_visual"]]:
		var section: Variant = manifest.get(pair[0], {})
		if section is Dictionary:
			for id: String in section:
				_refs[pair[1]][id] = true


func _load_manifest() -> Dictionary:
	var merged: Dictionary = {}
	for rel: String in ["data/assets.json", "mods/assets.json"]:
		var path := _ds.root_dir.path_join(rel)
		if not FileAccess.file_exists(path):
			continue
		var d: Variant = DataStore.read_json(path)
		if d is Dictionary:
			for section: String in d:
				if d[section] is Dictionary:
					if not merged.has(section):
						merged[section] = {}
					(merged[section] as Dictionary).merge(d[section], true)
	return merged


# ---------------------------------------------------------------- files

func _schema(name: String) -> Dictionary:
	if not _schemas.has(name):
		var d: Variant = DataStore.read_json(_ds.root_dir.path_join("data/schemas/%s.schema.json" % name))
		if not (d is Dictionary):
			errors.append("data/schemas/%s.schema.json: schema missing or not valid JSON" % name)
			d = {}
		_schemas[name] = d
	return _schemas[name]


func _check_file(rel: String, schema_name: String) -> void:
	var path := _ds.resolve(rel)
	_file = ("mods/data/" if path.contains("/mods/data/") else "data/") + rel
	if not FileAccess.file_exists(path):
		errors.append("%s: file is missing" % _file)
		return
	var d: Variant = DataStore.read_json(path)
	if d == null:
		errors.append("%s: not valid JSON" % _file)
		return
	files_checked += 1
	_check(d, _schema(schema_name), "")


func _check_assets() -> void:
	_check_file("assets.json", "assets")
	var manifest := _load_manifest()
	for section: String in ["models", "sounds"]:
		var entries: Variant = manifest.get(section, {})
		if not (entries is Dictionary):
			continue
		for id: String in entries:
			var entry: Variant = entries[id]
			if entry is Dictionary and entry.has("file"):
				var rel: String = entry["file"]
				if not FileAccess.file_exists(_ds.root_dir.path_join(rel)) and not FileAccess.file_exists(_ds.root_dir.path_join("mods").path_join(rel)):
					warnings.append("assets: %s '%s': file '%s' not found, the placeholder will be used" % [section, id, rel])


# ---------------------------------------------------------------- schema checking

func _err(path: String, message: String) -> void:
	errors.append("%s: %s: %s" % [_file, path if path != "" else "(root)", message])


func _type_ok(v: Variant, type_name: String) -> bool:
	match type_name:
		"object":
			return v is Dictionary
		"array":
			return v is Array
		"string":
			return v is String
		"boolean":
			return v is bool
		"number":
			return v is float or v is int
		"integer":
			return v is int or (v is float and v == floorf(v))
		"null":
			return v == null
	return true


func _check(v: Variant, schema: Dictionary, path: String) -> void:
	if schema.has("type"):
		var types: Variant = schema["type"]
		var ok := false
		if types is Array:
			for t: String in types:
				ok = ok or _type_ok(v, t)
		else:
			ok = _type_ok(v, types)
		if not ok:
			_err(path, "expected %s, got %s" % [types, JSON.stringify(v).left(40)])
			return
	if schema.has("enum") and not (schema["enum"] as Array).has(v):
		_err(path, "'%s' is not one of %s" % [v, schema["enum"]])
	if v is float or v is int:
		if schema.has("minimum") and v < schema["minimum"]:
			_err(path, "%s is below the minimum %s" % [v, schema["minimum"]])
		if schema.has("maximum") and v > schema["maximum"]:
			_err(path, "%s is above the maximum %s" % [v, schema["maximum"]])
	elif v is String:
		if schema.has("x-ref"):
			var kind: String = schema["x-ref"]
			if not (_refs.get(kind, {}) as Dictionary).has(v):
				_err(path, "unknown %s id '%s'" % [kind.replace("_", " "), v])
	elif v is Array:
		if schema.has("minItems") and v.size() < schema["minItems"]:
			_err(path, "needs at least %d entries" % schema["minItems"])
		if schema.has("maxItems") and v.size() > schema["maxItems"]:
			_err(path, "allows at most %d entries" % schema["maxItems"])
		if schema.has("items"):
			for i in v.size():
				var label := "[%d]" % i
				if v[i] is Dictionary and v[i].has("id"):
					label = "[%s]" % v[i]["id"]
				_check(v[i], schema["items"], path + label)
	elif v is Dictionary:
		var props: Dictionary = schema.get("properties", {})
		for key: String in schema.get("required", []):
			if not v.has(key):
				_err(path, "missing required field '%s'" % key)
		var extra: Variant = schema.get("additionalProperties", true)
		for key: String in v:
			var sub := key if path == "" else path + "." + key
			if props.has(key):
				_check(v[key], props[key], sub)
			elif extra is Dictionary:
				_check(v[key], extra, sub)
			elif extra is bool and extra == false:
				_err(path, "unknown field '%s'" % key)


# ---------------------------------------------------------------- cross-file checks

func _check_duplicate_ids() -> void:
	var seen: Dictionary = {}
	for folder: String in ["tech", "enemies"]:
		for file_name in _ds.list(folder):
			if not file_name.ends_with(".json"):
				continue
			var rel := folder.path_join(file_name)
			var d: Variant = _ds.load_json(rel)
			if not (d is Dictionary):
				continue
			for list_key: String in ["items", "movement", "attack"]:
				if not (d.get(list_key) is Array):
					continue
				for it: Variant in d[list_key]:
					if it is Dictionary and it.has("id"):
						var key: String = list_key + ":" + String(it["id"])
						if seen.has(key):
							errors.append("data/%s: id '%s' is already defined in data/%s" % [rel, it["id"], seen[key]])
						seen[key] = rel


## Prerequisites must not form a cycle, and every node must be reachable (buyable).
func _check_tech_tree() -> void:
	var tech: Dictionary = _refs["tech"]
	var state: Dictionary = {}   # id -> 1 while visiting, 2 when proven reachable, 3 when in or behind a cycle
	for id: String in tech:
		_visit_tech(id, state, [])
	for id: String in tech:
		var item: Dictionary = _ds.items[id]
		for other: Variant in item.get("excludes", []):
			if tech.has(other) and (item.get("requires", []) as Array).has(other):
				errors.append("data/%s: [%s]: both requires and excludes '%s'" % [_ds.item_source[id], id, other])


func _visit_tech(id: String, state: Dictionary, stack: Array) -> bool:
	if state.get(id, 0) == 2:
		return true
	if state.get(id, 0) == 3:
		return false
	if state.get(id, 0) == 1:
		var loop: Array = stack.slice(stack.find(id))
		loop.append(id)
		errors.append("data/%s: [%s]: prerequisite cycle: %s" % [_ds.item_source[id], id, " -> ".join(loop)])
		return false
	state[id] = 1
	stack.append(id)
	var ok := true
	for req: Variant in (_ds.items[id] as Dictionary).get("requires", []):
		if not _ds.items.has(req):
			ok = false   # already reported as an unknown reference
		elif not _visit_tech(req, state, stack):
			ok = false
	stack.pop_back()
	if not ok and state[id] != 3:
		errors.append("data/%s: [%s]: can never be bought because a prerequisite is unreachable" % [_ds.item_source[id], id])
	state[id] = 2 if ok else 3
	return ok
