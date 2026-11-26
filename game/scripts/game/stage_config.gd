class_name StageConfig
extends RefCounted
## Builds the simulation's config for one stage from the data files and the run's loadout.


static func build(run: RunState, ds: DataStore, level: Dictionary) -> Dictionary:
	var items := ds.items
	var cfg := {
		"power": ds.load_dict("tech/power_model.json"),
		"ship": ds.load_dict("tech/ship.json"),
		"enemies": ds.items_with_prefix("enemy."),
		"movement": ds.movement,
		"attack": ds.attack,
		"level": level,
		"difficulty": difficulty_def(ds, run.difficulty),
	}
	for s: String in RunState.SLOTS:
		var id: String = run.equipped.get(s, "")
		if id != "" and not items.has(id):
			push_warning("Equipped item '%s' no longer exists in the data; slot %s left empty" % [id, s])
			id = ""
		cfg[s] = items.get(id, {}) if id != "" else {}
	if (cfg["reactor"] as Dictionary).is_empty():
		cfg["reactor"] = {"output": 100, "capacitor": 150}
	if (cfg["armor"] as Dictionary).is_empty():
		cfg["armor"] = {"hp": 100}
	cfg["start_armor"] = ShopRules.armor_now(run, items) if items.has(run.equipped["armor"]) else 100.0
	var special: String = run.equipped["special"]
	if special != "":
		cfg["start_ammo"] = int(run.ammo.get(special, 0))
	return cfg


static func difficulty_def(ds: DataStore, id: String) -> Dictionary:
	var d := ds.load_dict("difficulty.json")
	for lvl: Dictionary in d.get("levels", []):
		if lvl.get("id", "") == id:
			return lvl
	return {"id": id, "name": id.capitalize()}


## Stage statistics from a finished simulation, in the shape Economy.stage_results() expects.
static func stage_stats(sim: GameSim) -> Dictionary:
	return {
		"kills": sim.kills, "spawned": sim.spawned_total, "kill_credits": sim.credits,
		"shots_fired": sim.shots_fired, "shots_hit": sim.shots_hit,
		"hull_damage": sim.hull_damage_taken, "armor_start": sim.player.armor_start,
		"boss_spawned": sim.boss_spawned, "boss_killed": sim.boss_killed,
		"boss_kill_time": sim.boss_kill_time, "boss_par_time": sim.boss_par_time,
	}
