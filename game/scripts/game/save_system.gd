class_name SaveSystem
extends RefCounted
## Save slots as human-readable JSON files in the user folder (on Windows:
## %APPDATA%\Godot\app_userdata\purge\saves\slot_<n>.json), plus a small profile file
## that remembers which level sets have been completed (for single-set unlocks).

const SLOT_COUNT := 3
const DIR := "user://saves"
const PROFILE := "user://profile.json"

static var base_dir: String = DIR   # tests point this somewhere else


static func slot_path(slot: int) -> String:
	return base_dir.path_join("slot_%d.json" % slot)


static func save(run: RunState) -> bool:
	if run.slot < 0:
		return false
	DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(slot_path(run.slot), FileAccess.WRITE)
	if f == null:
		push_error("Could not write save slot %d: %s" % [run.slot, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(run.to_dict(), "\t"))
	return true


static func load_slot(slot: int) -> RunState:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("Save slot %d is damaged" % slot)
		return null
	var run := RunState.from_dict(d)
	if run != null:
		run.slot = slot
	return run


static func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(slot_path(slot))


## Short descriptions for the load menu: [{slot, empty, text, saved_at}].
static func list_slots() -> Array:
	var out: Array = []
	for i in SLOT_COUNT:
		var entry := {"slot": i, "empty": true, "text": "Empty", "saved_at": ""}
		var path := slot_path(i)
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				entry["empty"] = false
				entry["saved_at"] = String(d.get("saved_at", "")).replace("T", " ")
				entry["data"] = d
			else:
				entry["empty"] = false
				entry["text"] = "Damaged save"
		out.append(entry)
	return out


static func load_profile() -> Dictionary:
	var profile := {"version": 1, "completed_sets": []}
	if FileAccess.file_exists(PROFILE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		if d is Dictionary:
			profile.merge(d, true)
	return profile


static func mark_set_completed(set_id: String) -> void:
	var profile := load_profile()
	var done: Array = profile["completed_sets"]
	if not set_id in done:
		done.append(set_id)
	var f := FileAccess.open(PROFILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))
