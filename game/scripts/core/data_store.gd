class_name DataStore
extends Node
## Loads gameplay data (JSON) loose from disk. Autoloaded as `Data`.
## In the editor the data folder is ../data beside the project; in a release
## build it is the data folder beside the executable.

var root_dir: String = ""
var items: Dictionary = {}  # id -> Dictionary, from every "items" list under tech/ and enemies/


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


func load_json(rel_path: String) -> Variant:
	return read_json(root_dir.path_join("data").path_join(rel_path))


func load_dict(rel_path: String) -> Dictionary:
	var v: Variant = load_json(rel_path)
	if v is Dictionary:
		return v
	return {}


func reload() -> void:
	items.clear()
	for folder: String in ["tech", "enemies"]:
		var dir_path := root_dir.path_join("data").path_join(folder)
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("Data folder missing: %s" % dir_path)
			continue
		for file_name in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var d: Variant = read_json(dir_path.path_join(file_name))
			if d is Dictionary and d.has("items"):
				for it: Dictionary in d["items"]:
					if items.has(it["id"]):
						push_warning("Duplicate data id %s in %s" % [it["id"], file_name])
					items[it["id"]] = it


func item(id: String) -> Dictionary:
	if not items.has(id):
		push_error("Unknown data id: %s" % id)
		return {}
	return items[id]
