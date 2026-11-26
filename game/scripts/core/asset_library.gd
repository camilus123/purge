extends Node
## Resolves asset ids to models, sprite looks and sounds. Autoloaded as `Assets`.
## data/assets.json is the manifest; mods/assets.json overrides or adds entries by id.
## Files are loaded loose from disk at runtime (.glb, .ogg, .wav), relative to the game
## folder. A missing id or file logs a warning and gives a visible placeholder.

const FALLBACK_SPRITE := {"color": [1.0, 0.0, 1.0], "intensity": 3.0, "width": 2.0, "length": 2.0, "core": 0.3}

var manifest: Dictionary = {}
var _model_cache: Dictionary = {}   # id -> Mesh or PackedScene-like Node3D template
var _sound_cache: Dictionary = {}   # id -> AudioStream or String (synth name)
var _warned: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	manifest = {"models": {}, "sprites": {}, "sounds": {}, "shield_visuals": {}}
	_merge(DataStore.read_json(Data.root_dir.path_join("data/assets.json")))
	var mod_path := Data.root_dir.path_join("mods/assets.json")
	if FileAccess.file_exists(mod_path):
		_merge(DataStore.read_json(mod_path))
	for node: Variant in _model_cache.values():
		if node is Node:
			(node as Node).queue_free()
	_model_cache.clear()
	_sound_cache.clear()
	_warned.clear()


func _merge(d: Variant) -> void:
	if not (d is Dictionary):
		return
	for section: String in manifest:
		var entries: Variant = d.get(section, {})
		if entries is Dictionary:
			(manifest[section] as Dictionary).merge(entries, true)


func has(section: String, id: String) -> bool:
	return (manifest.get(section, {}) as Dictionary).has(id)


func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


## Absolute path for a manifest file entry; mods/ takes priority over the game folder.
func _file_path(rel: String) -> String:
	var modded := Data.root_dir.path_join("mods").path_join(rel)
	if FileAccess.file_exists(modded):
		return modded
	return Data.root_dir.path_join(rel)


# ---------------------------------------------------------------- models

## Returns a new node showing the model: a MeshInstance3D for placeholders, or an
## instance of the loaded glTF scene. The caller owns the node.
func instantiate_model(id: String) -> Node3D:
	if not _model_cache.has(id):
		_model_cache[id] = _load_model(id)
	var source: Variant = _model_cache[id]
	if source is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = source
		return mi
	return (source as Node3D).duplicate() as Node3D


func _load_model(id: String) -> Variant:
	var entry: Dictionary = (manifest["models"] as Dictionary).get(id, {})
	if entry.is_empty():
		_warn_once("model:" + id, "No model entry for asset id '%s', using placeholder" % id)
		return PlaceholderModels.get_mesh("")
	if entry.has("file"):
		var path := _file_path(entry["file"])
		if FileAccess.file_exists(path):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(path, state) == OK:
				var scene := doc.generate_scene(state)
				if scene is Node3D:
					var holder := Node3D.new()
					holder.add_child(scene)
					var sc: float = entry.get("scale", 1.0)
					(scene as Node3D).scale = Vector3(sc, sc, sc)
					return holder
		_warn_once("model:" + id, "Model file for '%s' could not be loaded (%s), using placeholder" % [id, path])
		return PlaceholderModels.get_mesh("")
	return PlaceholderModels.get_mesh(String(entry.get("placeholder", "")))


# ---------------------------------------------------------------- sprites and colours

func sprite(id: String) -> Dictionary:
	var sprites: Dictionary = manifest["sprites"]
	if sprites.has(id):
		return sprites[id]
	_warn_once("sprite:" + id, "No sprite entry for asset id '%s', using placeholder" % id)
	return FALLBACK_SPRITE


func shield_color(id: String) -> Color:
	var entry: Dictionary = (manifest["shield_visuals"] as Dictionary).get(id, {})
	var c: Array = entry.get("color", [0.25, 0.6, 1.0])
	return Color(c[0], c[1], c[2])


# ---------------------------------------------------------------- sounds

## Returns [stream_or_synth_name, volume]. The first element is null for an unknown id.
func sound(id: String) -> Array:
	var entry: Dictionary = (manifest["sounds"] as Dictionary).get(id, {})
	if entry.is_empty():
		_warn_once("sound:" + id, "No sound entry for asset id '%s'" % id)
		return [null, 1.0]
	if not _sound_cache.has(id):
		_sound_cache[id] = _load_sound(id, entry)
	return [_sound_cache[id], float(entry.get("volume", 1.0))]


func _load_sound(id: String, entry: Dictionary) -> Variant:
	if entry.has("file"):
		var path := _file_path(entry["file"])
		if FileAccess.file_exists(path):
			if path.ends_with(".ogg"):
				return AudioStreamOggVorbis.load_from_file(path)
			if path.ends_with(".wav"):
				return AudioStreamWAV.load_from_file(path)
		_warn_once("sound:" + id, "Sound file for '%s' could not be loaded (%s)" % [id, path])
	return String(entry.get("synth", "tick"))
