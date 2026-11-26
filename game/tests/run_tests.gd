extends SceneTree
## Headless rule tests. Run with:
##   godot --headless --path game -s res://tests/run_tests.gd
## Uses the real data files, but overrides the numbers a test depends on.

var _failed := 0
var _passed := 0
var _root_dir := ""


func _init() -> void:
	_root_dir = DataStore.find_root()
	test_power_split()
	test_shield_recharge()
	test_bulwark_damage()
	test_mirror_bleed_and_reflect()
	test_enemy_resistance()
	test_starved_weapon_fires_slowly()
	test_death_restarts_with_full_ship()
	test_patterns()
	test_level_timeline()
	test_validator()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(name: String, got: float, want: float, eps: float = 0.01) -> void:
	if absf(got - want) <= eps:
		_passed += 1
		print("  ok    ", name)
	else:
		_failed += 1
		print("  FAIL  ", name, "  got ", got, " want ", want)


func _json(rel: String) -> Dictionary:
	return DataStore.read_json(_root_dir.path_join("data").path_join(rel))


func _item(file: String, id: String) -> Dictionary:
	for it: Dictionary in _json(file)["items"]:
		if it["id"] == id:
			return it.duplicate(true)
	return {}


func _make_sim(shield_id: String = "shield.bulwark.t1", level: Dictionary = {"name": "test", "waves": []}) -> GameSim:
	var sim := GameSim.new()
	sim.setup({
		"power": _json("tech/power_model.json"),
		"ship": _json("tech/ship.json"),
		"reactor": _item("tech/reactors.json", "reactor.basic.t1"),
		"shield": _item("tech/shields.json", shield_id),
		"armor": _item("tech/armor.json", "armor.standard.t1"),
		"weapon1": _item("tech/weapons.json", "weapon.laser.t1"),
		"weapon2": _item("tech/weapons.json", "weapon.chaingun.t1"),
		"enemies": _json("enemies/frontier.json")["items"],
		"movement": _json("enemies/patterns.json")["movement"],
		"attack": _json("enemies/patterns.json")["attack"],
		"level": level,
	})
	sim.player.invulnerable = 0.0
	return sim


func test_power_split() -> void:
	print("power split")
	var sim := _make_sim()
	check("starts at 50/50", sim.player.shield_share, 0.5)
	sim.shift_power(1)
	check("wheel up gives weapons 10%", sim.player.shield_share, 0.4)
	for i in 20:
		sim.shift_power(1)
	check("clamps at 0% shields", sim.player.shield_share, 0.0)
	for i in 30:
		sim.shift_power(-1)
	check("clamps at 100% shields", sim.player.shield_share, 1.0)


func test_shield_recharge() -> void:
	print("shield recharge")
	var sim := _make_sim()
	check("table value at 50/50", sim.shield_recharge_rate(), sim.player.shield_recharge)
	sim.player.shield_share = 1.0
	check("doubles at 100% shields", sim.shield_recharge_rate(), sim.player.shield_recharge * 2.0)
	sim.player.shield_share = 0.0
	check("stops at 0% shields", sim.shield_recharge_rate(), 0.0)


func test_bulwark_damage() -> void:
	print("bulwark shield")
	var sim := _make_sim()
	var p := sim.player
	sim.damage_player(50.0, 0)
	check("shield absorbs all", p.shield, p.shield_max - 50.0)
	check("armor untouched", p.armor, p.armor_max)
	sim.damage_player(p.shield + 30.0, 0)
	check("shield empty", p.shield, 0.0)
	check("overflow hits armor", p.armor, p.armor_max - 30.0)


func test_mirror_bleed_and_reflect() -> void:
	print("mirror shield")
	var sim := _make_sim("shield.mirror.t1")
	var p := sim.player
	var e := sim.spawn_enemy(sim._enemy_types["enemy.frontier.gunship"], 0.0)
	var hp := e.hp
	sim.damage_player(50.0, 0, e.slot)
	check("20% bleeds to armor", p.armor, p.armor_max - 10.0)
	check("80% hits shield", p.shield, p.shield_max - 40.0)
	check("25% of absorbed is reflected", e.hp, hp - 10.0)


func test_enemy_resistance() -> void:
	print("enemy resistance")
	var sim := _make_sim()
	var e := sim.spawn_enemy(sim._enemy_types["enemy.frontier.gunship"], 0.0)
	var hp := e.hp
	sim._damage_enemy(e, 10.0, 0)
	check("energy full damage", e.hp, hp - 10.0)
	sim._damage_enemy(e, 10.0, 1)
	check("kinetic reduced by 20%", e.hp, hp - 18.0)


func test_starved_weapon_fires_slowly() -> void:
	print("weapon energy")
	var full := _make_sim()
	full.in_fire_1 = true
	for i in 240:
		full.step(1.0 / 240.0)
	var starved := _make_sim()
	starved.player.pool = 0.0
	starved.player.shield_share = 1.0   # nothing refills the pool
	starved.in_fire_1 = true
	for i in 240:
		starved.step(1.0 / 240.0)
	check("laser at 50/50 fires about 9.2 shots/s", full.shots_fired, 9.0 * 1.025, 1.5)
	check("starved laser still fires, slowly", starved.shots_fired, 9.0 * 0.8 * 0.35, 1.5)


func test_death_restarts_with_full_ship() -> void:
	print("death and restart")
	var sim := _make_sim()
	sim.credits = 500
	sim.damage_player(10000.0, 0)
	check("ship destroyed", float(sim.state), float(GameSim.STATE_DEAD))
	for i in 240 * 3:
		sim.step(1.0 / 240.0)
	check("stage restarted", float(sim.state), float(GameSim.STATE_PLAYING))
	check("armor restored", sim.player.armor, sim.player.armor_max)
	check("shield restored", sim.player.shield, sim.player.shield_max)
	check("credits from failed attempt dropped", float(sim.credits), 0.0)


func test_patterns() -> void:
	print("movement and attack patterns")
	var sim := _make_sim()
	var dart := sim.spawn_enemy(sim._enemy_types["enemy.frontier.dart"], -30.0)
	sim.player.x = 20.0
	sim.player.tx = 20.0
	for i in 240 * 3:
		sim.step(1.0 / 240.0)
	check("dive commits toward the player", 1.0 if (not dart.alive or dart.x > -20.0) else 0.0, 1.0)
	var sim2 := _make_sim()
	sim2.invincible = true
	sim2.spawn_enemy(sim2._enemy_types["enemy.frontier.sentry"], 0.0)
	for i in 240 * 6:
		sim2.step(1.0 / 240.0)
	check("ring and spiral attacks fire bullets", 1.0 if sim2.ebul.count > 20 else 0.0, 1.0)
	var sim3 := _make_sim()
	var zig := sim3.spawn_enemy(sim3._enemy_types["enemy.frontier.drone"], 0.0, sim3._move_patterns["move.zigzag"])
	var max_x := 0.0
	for i in 240 * 2:
		sim3.step(1.0 / 240.0)
		max_x = maxf(max_x, absf(zig.x))
	check("wave movement override is used (zigzag width 14)", max_x, 14.0, 0.5)


func test_level_timeline() -> void:
	print("level timeline")
	var level := {"name": "t", "scroll_speed": 10, "scroll_changes": [{"t": 1.0, "speed": 20}],
		"waves": [{"t": 0.5, "enemy": "enemy.frontier.drone", "count": 3, "x": -10, "dx": 10, "dt": 0.25}]}
	var sim := _make_sim("shield.bulwark.t1", level)
	sim.invincible = true
	for i in 125:
		sim.step(1.0 / 240.0)
	check("first of the wave spawned at 0.5s", float(sim.enemy_count), 1.0)
	for i in 240:
		sim.step(1.0 / 240.0)
	check("whole wave spawned", float(sim.enemy_count), 3.0)
	for i in 240 * 2:
		sim.step(1.0 / 240.0)
	check("scroll speed change applied", sim.scroll_speed, 20.0, 0.5)
	for e in sim.enemies:
		if e.alive:
			sim._damage_enemy(e, 9999.0, 0)
	sim.step(1.0 / 240.0)
	check("stage clear when the last wave is gone", float(sim.state), float(GameSim.STATE_CLEAR))


func test_validator() -> void:
	print("data validator")
	var ds := DataStore.new()
	ds.root_dir = _root_dir
	ds.reload()
	var v := DataValidator.new()
	v.run(ds)
	for e in v.errors:
		print("      ", e)
	check("shipped data has no errors", float(v.errors.size()), 0.0)
	check("finds the level sets", 1.0 if ds.sets.size() >= 2 else 0.0, 1.0)

	# Break things in memory and make sure each problem is reported.
	v._file = "test"
	v.errors.clear()
	v._check({"id": "x", "type": "sine", "amplitude": "wide"}, v._schema("patterns")["properties"]["movement"]["items"], "movement[x]")
	check("wrong type is reported", float(v.errors.size()), 1.0)
	v.errors.clear()
	v._check({"t": 1, "enemy": "enemy.does.not.exist"}, v._schema("level")["properties"]["waves"]["items"], "waves[0]")
	check("unknown enemy reference is reported", float(v.errors.size()), 1.0)
	v.errors.clear()
	v._check({"t": 1, "enemy": "enemy.frontier.drone", "bogus": 1}, v._schema("level")["properties"]["waves"]["items"], "waves[0]")
	check("unknown field is reported", float(v.errors.size()), 1.0)
	v.errors.clear()
	ds.items["tech.a"] = {"id": "tech.a", "requires": ["tech.b"]}
	ds.items["tech.b"] = {"id": "tech.b", "requires": ["tech.a"]}
	ds.item_source["tech.a"] = "tech/test.json"
	ds.item_source["tech.b"] = "tech/test.json"
	v._refs["tech"]["tech.a"] = true
	v._refs["tech"]["tech.b"] = true
	v._check_tech_tree()
	check("prerequisite cycle is reported", 1.0 if v.errors.size() >= 1 else 0.0, 1.0)
	ds.free()
