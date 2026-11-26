class_name DataStore
extends Node
## Loads gameplay data (JSON) loose from disk. Autoloaded as `Data`.
## In the editor the data folder is ../data beside the project; in a release
## build it is the data folder beside the executable.
## Any file under mods/data/ replaces the built-in file with the same relative
## path, and extra files there are loaded too.

var root_dir: String = ""
var items: Dictionary = {}       # id -> Dictionary, from every "items" list under tech/ and enemies/
var item_source: Dictionary = {} # id -> relative file it came from
var movement: Array = []         # movement pattern definitions
var attack: Array = []           # attack pattern definitions
var sets: Array = []             # level set dictionaries (each with "folder"), sorted by "order"


func _ready() -> void:
	root_dir = find_root()
	reload()


static func find_root() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	return OS.get_executable_path().get_base_dir()


static func read_json(abs_path: String) -> Variant:
	if not FileAccess.file_exists(abs_path):
		push_warning("Data file missing: %s" % abs_path)
		return null
	var text := FileAccess.get_file_as_string(abs_path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON error in %s line %d: %s" % [abs_path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Absolute path of a data file, preferring the mods override.
func resolve(rel_path: String) -> String:
	var modded := root_dir.path_join("mods/data").path_join(rel_path)
	if FileAccess.file_exists(modded):
		return modded
	return root_dir.path_join("data").path_join(rel_path)


func load_json(rel_path: String) -> Variant:
	return read_json(resolve(rel_path))


func load_dict(rel_path: String) -> Dictionary:
	var v: Variant = load_json(rel_path)
	if v is Dictionary:
		return v
	return {}


## Names of the entries in a data folder, merged from data/ and mods/data/.
func list(rel_folder: String, directories: bool = false) -> PackedStringArray:
	var names: Dictionary = {}
	for base: String in ["data", "mods/data"]:
		var dir := DirAccess.open(root_dir.path_join(base).path_join(rel_folder))
		if dir == null:
			continue
		for n in (dir.get_directories() if directories else dir.get_files()):
			names[n] = true
	var out := PackedStringArray(names.keys())
	out.sort()
	return out


func reload() -> void:
	items.clear()
	item_source.clear()
	movement = []
	attack = []
	for folder: String in ["tech", "enemies"]:
		for file_name in list(folder):
			if not file_name.ends_with(".json"):
				continue
			var rel := folder.path_join(file_name)
			var d: Variant = load_json(rel)
			if not (d is Dictionary):
				continue
			if d.has("movement") and d["movement"] is Array:
				movement.append_array(d["movement"])
			if d.has("attack") and d["attack"] is Array:
				attack.append_array(d["attack"])
			if d.has("items") and d["items"] is Array:
				for it: Variant in d["items"]:
					if it is Dictionary and it.has("id"):
						items[it["id"]] = it
						item_source[it["id"]] = rel
	sets = []
	for folder in list("levels", true):
		var set_def := load_dict("levels".path_join(folder).path_join("set.json"))
		if set_def.is_empty():
			continue
		set_def["folder"] = folder
		sets.append(set_def)
	sets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("order", 0)) < float(b.get("order", 0)))


func item(id: String) -> Dictionary:
	if not items.has(id):
		push_error("Unknown data id: %s" % id)
		return {}
	return items[id]


func items_with_prefix(prefix: String) -> Array:
	var out: Array = []
	for id: String in items:
		if id.begins_with(prefix):
			out.append(items[id])
	return out


func find_set(set_id: String) -> Dictionary:
	for s: Dictionary in sets:
		if s.get("id", "") == set_id:
			return s
	return {}


func load_level(set_def: Dictionary, index: int) -> Dictionary:
	var levels: Array = set_def.get("levels", [])
	if index < 0 or index >= levels.size():
		return {}
	return load_dict("levels".path_join(set_def["folder"]).path_join(levels[index]))
