class_name RunState
extends RefCounted
## Everything about one playthrough that outlives a stage: where the player is in the
## campaign or set, credits, owned and equipped tech, hull damage, special ammo and totals.
## Saved as JSON (see SaveSystem); `VERSION` goes up whenever the layout changes, and
## from_dict() migrates older saves.

const VERSION := 1
const SLOTS := ["reactor", "shield", "armor", "weapon1", "weapon2", "special"]

var mode: String = "campaign"        # "campaign" or "single"
var set_ids: Array = []              # level sets to play, in order
var set_pos: int = 0                 # index into set_ids
var level_index: int = 0             # level within the current set
var difficulty: String = "normal"
var credits: int = 0
var owned: Dictionary = {}           # item id -> shop visit number it was bought in (0 = start)
var equipped: Dictionary = {}        # slot -> item id ("" = empty)
var ammo: Dictionary = {}            # special item id -> uses left
var hull_damage: float = 0.0         # armor points missing; repaired in the shop
var shop_visit: int = 1
var finished: bool = false
var slot: int = -1                   # save slot, -1 = not saved (quick play)
var stats: Dictionary = {
	"stages_cleared": 0, "kills": 0, "credits_earned": 0, "deaths": 0, "play_time": 0.0,
	"shots_fired": 0, "shots_hit": 0,
}


func _init() -> void:
	for s: String in SLOTS:
		equipped[s] = ""


## A fresh run. `items` maps ids to item definitions, `economy` and `difficulty_def` are the data files.
static func create(p_mode: String, p_set_ids: Array, p_difficulty: String, economy: Dictionary,
		difficulty_def: Dictionary, starting_credits: float = -1.0, loadout: Dictionary = {}) -> RunState:
	var r := RunState.new()
	r.mode = p_mode
	r.set_ids = p_set_ids.duplicate()
	r.difficulty = p_difficulty
	var base := starting_credits if starting_credits >= 0.0 else float(economy.get("starting_credits", 3000))
	r.credits = roundi(base * float(difficulty_def.get("starting_credits_mult", 1.0)))
	var start: Dictionary = loadout if not loadout.is_empty() else economy.get("starting_loadout", {})
	for slot_name: String in start:
		var id: String = start[slot_name]
		if id == "":
			continue
		r.owned[id] = 0
		r.equipped[slot_name] = id
	return r


func current_set_id() -> String:
	if set_pos < set_ids.size():
		return set_ids[set_pos]
	return ""


## Moves to the next stage. Returns false when the run is over.
func advance(levels_in_set: int) -> bool:
	level_index += 1
	if level_index >= levels_in_set:
		level_index = 0
		set_pos += 1
	finished = set_pos >= set_ids.size()
	return not finished


func is_equipped(id: String) -> bool:
	for s: String in SLOTS:
		if equipped[s] == id:
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "mode": mode, "set_ids": set_ids, "set_pos": set_pos, "level_index": level_index,
		"difficulty": difficulty, "credits": credits, "owned": owned, "equipped": equipped, "ammo": ammo,
		"hull_damage": hull_damage, "shop_visit": shop_visit, "finished": finished, "stats": stats,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}


## Builds a run from saved data, migrating older versions. Returns null if the data is unusable.
static func from_dict(d: Dictionary) -> RunState:
	var version := int(d.get("version", 0))
	if version > VERSION or not d.has("set_ids"):
		return null
	# Future migrations go here: if version < 2: ... rename fields, convert values ...
	var r := RunState.new()
	r.mode = d.get("mode", "campaign")
	r.set_ids = d.get("set_ids", [])
	r.set_pos = int(d.get("set_pos", 0))
	r.level_index = int(d.get("level_index", 0))
	r.difficulty = d.get("difficulty", "normal")
	r.credits = int(d.get("credits", 0))
	for id: String in d.get("owned", {}):
		r.owned[id] = int(d["owned"][id])
	var eq: Dictionary = d.get("equipped", {})
	for s: String in SLOTS:
		r.equipped[s] = String(eq.get(s, ""))
	for id: String in d.get("ammo", {}):
		r.ammo[id] = int(d["ammo"][id])
	r.hull_damage = float(d.get("hull_damage", 0.0))
	# Each load is a new shop visit, so same-visit full refunds do not survive a reload.
	r.shop_visit = int(d.get("shop_visit", 1)) + 1
	r.finished = d.get("finished", false)
	var st: Dictionary = d.get("stats", {})
	for k: String in r.stats:
		if st.has(k):
			r.stats[k] = st[k]
	return r
