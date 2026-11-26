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
	test_beam_and_phaser()
	test_railgun()
	test_splash_weapon()
	test_specials()
	test_stage_start_values()
	test_difficulty()
	test_shop_rules()
	test_repair_and_restock()
	test_economy()
	test_save_round_trip()
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


func _make_sim(shield_id: String = "shield.bulwark.t1", level: Dictionary = {"name": "test", "waves": []},
		extra: Dictionary = {}) -> GameSim:
	var sim := GameSim.new()
	var cfg := {
		"power": _json("tech/power_model.json"),
		"ship": _json("tech/ship.json"),
		"reactor": _item("tech/reactors.json", "reactor.core.t1"),
		"shield": _item("tech/shields.json", shield_id),
		"armor": _item("tech/armor.json", "armor.standard.t1"),
		"weapon1": _item("tech/weapons.json", "weapon.laser.t1"),
		"weapon2": _item("tech/weapons.json", "weapon.chaingun.t1"),
		"enemies": _json("enemies/frontier.json")["items"],
		"movement": _json("enemies/patterns.json")["movement"],
		"attack": _json("enemies/patterns.json")["attack"],
		"level": level,
	}
	cfg.merge(extra, true)
	sim.setup(cfg)
	sim.player.invulnerable = 0.0
	return sim


func _steps(sim: GameSim, seconds: float) -> void:
	for i in roundi(seconds * 240.0):
		sim.step(1.0 / 240.0)


## A sentry parked at (x, y) that does not move or shoot, with plenty of health.
func _dummy(sim: GameSim, x: float, y: float, hp: float = 100000.0) -> Enemy:
	var e := sim.spawn_enemy(sim._enemy_types["enemy.frontier.drone"], x, sim._move_patterns["move.straight"])
	e.x = x
	e.y = y
	e.max_hp = hp
	e.hp = hp
	return e


func _freeze(sim: GameSim) -> void:
	# Stops every enemy moving and shooting by giving them a zero-speed straight pattern and no attacks.
	for e in sim.enemies:
		if e.alive:
			var t := EnemyType.new()
			t.id = e.type.id
			t.hp = e.type.hp
			t.resist = e.type.resist
			t.radius = e.type.radius
			t.speed = 0.0
			t.move = MovePattern.new()
			e.type = t
			e.move = t.move


func _items() -> Dictionary:
	var ds := DataStore.new()
	ds.root_dir = _root_dir
	ds.reload()
	var out := ds.items.duplicate()
	ds.free()
	return out


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


func test_beam_and_phaser() -> void:
	print("beam and phaser")
	var sim := _make_sim("", {"name": "t", "waves": []}, {"weapon1": _item("tech/weapons.json", "weapon.laser.t4"), "weapon2": {}})
	sim.invincible = true
	sim.player.shield_share = 0.0
	var front := _dummy(sim, sim.player.x - 1.6, 0.0)
	var behind := _dummy(sim, sim.player.x - 1.6, -30.0)
	_freeze(sim)
	sim.in_fire_1 = true
	_steps(sim, 1.0)
	var dealt_front := front.max_hp - front.hp
	check("lance beam deals about its damage per second (x1.6 at full weapon power)", dealt_front, 130.0 * 1.6, 25.0)
	check("non-piercing beam stops at the first enemy", behind.max_hp - behind.hp, 0.0)
	var w := sim.player.weapons[0]
	check("beam length ends at the enemy", 1.0 if w.beam_len < 40.0 else 0.0, 1.0)

	var sim2 := _make_sim("", {"name": "t", "waves": []}, {"weapon1": _item("tech/weapons.json", "weapon.phaser.t1"), "weapon2": {}})
	sim2.invincible = true
	var a := _dummy(sim2, sim2.player.x - 1.6, 20.0)
	var b := _dummy(sim2, sim2.player.x - 1.6, 5.0)
	var c := _dummy(sim2, sim2.player.x - 1.6, -10.0)
	var d := _dummy(sim2, sim2.player.x - 1.6, -20.0)
	_freeze(sim2)
	sim2.in_fire_1 = true
	_steps(sim2, 2.0)
	var touched := 0
	for e: Enemy in [a, b, c]:
		if e.hp < e.max_hp:
			touched += 1
	check("phaser pierces through 2 enemies to hit a third", float(touched), 3.0)
	check("phaser stops after pierce + 1 enemies", d.max_hp - d.hp, 0.0)


func test_railgun() -> void:
	print("railgun")
	var sim := _make_sim("", {"name": "t", "waves": []}, {"weapon1": {}, "weapon2": _item("tech/weapons.json", "weapon.railgun.t1")})
	sim.invincible = true
	var targets: Array = []
	for k in 5:
		targets.append(_dummy(sim, sim.player.x + 1.6, 10.0 - k * 12.0))
	_freeze(sim)
	sim.in_fire_2 = true
	_steps(sim, 0.4)
	check("no shot before the charge time", targets[0].max_hp - targets[0].hp, 0.0)
	_steps(sim, 0.1)
	var hit := 0
	for e: Enemy in targets:
		if e.hp < e.max_hp:
			hit += 1
	check("one rail shot hits pierce + 1 = 4 enemies in a line", float(hit), 4.0)
	check("rail damage per target", targets[0].max_hp - targets[0].hp, 110.0, 15.0)


func test_splash_weapon() -> void:
	print("splash")
	var sim := _make_sim("", {"name": "t", "waves": []}, {"weapon1": _item("tech/weapons.json", "weapon.autocannon.t1"), "weapon2": {}})
	sim.invincible = true
	var x := sim.player.x - 1.6
	var a := _dummy(sim, x, 0.0)
	var b := _dummy(sim, x + 5.5, 0.0)
	var far := _dummy(sim, x + 20.0, 0.0)
	_freeze(sim)
	sim.in_fire_1 = true
	_steps(sim, 0.5)
	check("shell damages the enemy it hits", 1.0 if a.hp < a.max_hp else 0.0, 1.0)
	check("splash damages a neighbour", 1.0 if b.hp < b.max_hp else 0.0, 1.0)
	check("splash does not reach far enemies", far.max_hp - far.hp, 0.0)


func _special_sim(id: String) -> GameSim:
	var sim := _make_sim("", {"name": "t", "waves": []}, {"weapon1": {}, "weapon2": {}, "special": _item("tech/specials.json", id)})
	sim.invincible = true
	return sim


func test_specials() -> void:
	print("special weapons")
	var sim := _special_sim("special.seeker.t1")
	var left := _dummy(sim, -30.0, -20.0, 30.0)
	var right := _dummy(sim, 30.0, -20.0, 30.0)
	_freeze(sim)
	var ammo := sim.player.special.ammo
	sim.fire_special()
	check("firing uses one ammo", float(sim.player.special.ammo), float(ammo - 1))
	_steps(sim, 2.0)
	check("seekers home in on targets left and right", float(int(not left.alive) + int(not right.alive)), 2.0)

	var sim2 := _special_sim("special.shockwave.t1")
	var e := _dummy(sim2, 0.0, -30.0)
	_freeze(sim2)
	for k in 50:
		sim2.ebul.spawn(0.0, 0.0, 0.0, 10.0, 1.0, 10.0, 0, 0, 5.0, -1)
	sim2.fire_special()
	check("shockwave clears enemy bullets", float(sim2.ebul.count), 0.0)
	check("shockwave damages enemies", e.max_hp - e.hp, 120.0, 0.5)

	var sim3 := _special_sim("special.cluster.t1")
	var targets: Array = []
	for k in 5:
		targets.append(_dummy(sim3, -14.0 + k * 7.0, -10.0))
	_freeze(sim3)
	sim3.fire_special()
	_steps(sim3, 1.6)
	var hit := 0
	for t: Enemy in targets:
		if t.hp < t.max_hp:
			hit += 1
	# Only the middle target is in the bomb's path; the others can only be reached by bomblets.
	check("cluster bomb bursts and its bomblets reach other enemies", 1.0 if hit >= 3 else 0.0, 1.0)

	var sim4 := _special_sim("special.mines.t1")
	sim4.fire_special()
	check("mine layer drops two mines", float(sim4.pbul.count), 2.0)
	var m := _dummy(sim4, sim4.player.x, sim4.player.y + 14.0)
	_freeze(sim4)
	_steps(sim4, 1.0)
	check("a mine goes off when an enemy comes close", 1.0 if m.hp < m.max_hp else 0.0, 1.0)

	var sim5 := _special_sim("special.torpedo.t1")
	sim5.player.special.ammo = 0
	sim5.fire_special()
	check("no ammo, no torpedo", float(sim5.pbul.count), 0.0)


func test_stage_start_values() -> void:
	print("stage start values")
	var sim := _make_sim("shield.bulwark.t1", {"name": "t", "waves": []},
			{"special": _item("tech/specials.json", "special.torpedo.t1"), "start_armor": 40.0, "start_ammo": 2})
	check("stage starts with damaged armor", sim.player.armor, 40.0)
	check("stage starts with the ammo carried in", float(sim.player.special.ammo), 2.0)
	sim.fire_special()
	sim.damage_player(10000.0, 0)
	_steps(sim, 3.0)
	check("restart gives back the stage-start armor", sim.player.armor, 40.0)
	check("restart gives back the stage-start ammo", float(sim.player.special.ammo), 2.0)


func test_difficulty() -> void:
	print("difficulty")
	var hard := {"enemy_hp": 1.35, "enemy_damage": 1.3, "bullet_speed": 1.15, "fire_rate": 1.2}
	var sim := _make_sim("", {"name": "t", "waves": []}, {"difficulty": hard})
	var e := sim.spawn_enemy(sim._enemy_types["enemy.frontier.drone"], 0.0)
	check("hard: enemy health x1.35", e.max_hp, 30.0 * 1.35)
	sim._enemy_fire(e, sim._attack_patterns["atk.aimed.single"], 0)
	check("hard: bullet damage x1.3", sim.ebul.damage[0], 13.0)
	var spd := Vector2(sim.ebul.vx[0], sim.ebul.vy[0]).length()
	check("hard: bullet speed x1.15", spd, 52.0 * 1.15, 0.05)


func test_shop_rules() -> void:
	print("shop rules")
	var items := _items()
	var econ := _json("economy.json")
	var run := RunState.create("campaign", ["frontier"], "normal", econ, {})
	check("starting credits", float(run.credits), 3000.0)
	check("starting weapon is equipped", 1.0 if run.equipped["weapon1"] == "weapon.laser.t1" else 0.0, 1.0)
	check("tier 2 needs tier 1 of its branch", 1.0 if ShopRules.state(run, items, "weapon.railgun.t2") == ShopRules.LOCKED else 0.0, 1.0)
	check("buy a shield", 1.0 if ShopRules.buy(run, items, "shield.flicker.t1") else 0.0, 1.0)
	check("credits deducted", float(run.credits), 2400.0)
	check("bought shield fills the empty slot", 1.0 if run.equipped["shield"] == "shield.flicker.t1" else 0.0, 1.0)
	check("same-visit sale refunds in full", float(ShopRules.sell_value(run, items, econ, "shield.flicker.t1")), 600.0)
	run.shop_visit += 1
	check("later sale refunds 75%", float(ShopRules.sell_value(run, items, econ, "shield.flicker.t1")), 450.0)
	ShopRules.buy(run, items, "weapon.chaingun.t1")
	check("second weapon goes to the empty RMB slot", 1.0 if run.equipped["weapon2"] == "weapon.chaingun.t1" else 0.0, 1.0)
	ShopRules.equip(run, items, "weapon.chaingun.t1", "weapon1")
	check("equipping into the other slot swaps the weapons",
			1.0 if run.equipped["weapon1"] == "weapon.chaingun.t1" and run.equipped["weapon2"] == "weapon.laser.t1" else 0.0, 1.0)
	run.credits = 100000
	ShopRules.buy(run, items, "reactor.core.t2")
	ShopRules.buy(run, items, "reactor.steady.t3")
	check("upgrade in the same branch replaces the equipped tier", 1.0 if run.equipped["reactor"] == "reactor.steady.t3" else 0.0, 1.0)
	check("the other branch is excluded", 1.0 if ShopRules.state(run, items, "reactor.surge.t3") == ShopRules.EXCLUDED else 0.0, 1.0)
	check("cannot sell a prerequisite of something owned", 0.0 if ShopRules.can_sell(run, items, "reactor.core.t2")[0] else 1.0, 1.0)
	check("cannot sell the equipped reactor", 0.0 if ShopRules.can_sell(run, items, "reactor.steady.t3")[0] else 1.0, 1.0)
	check("cannot unequip the armor", 0.0 if ShopRules.unequip(run, "armor") else 1.0, 1.0)
	check("can unequip a weapon", 1.0 if ShopRules.unequip(run, "weapon2") else 0.0, 1.0)
	ShopRules.buy(run, items, "special.seeker.t1")
	check("buying a special fills its ammo", float(run.ammo["special.seeker.t1"]), 6.0)


func test_repair_and_restock() -> void:
	print("repair and restock")
	var items := _items()
	var econ := _json("economy.json")
	var run := RunState.create("campaign", ["frontier"], "normal", econ, {})
	run.hull_damage = 40.0
	check("repair cost is 3 per point", float(ShopRules.repair_cost(run, items, econ)), 120.0)
	run.credits = 60
	ShopRules.repair(run, items, econ)
	check("partial repair with the credits available", run.hull_damage, 20.0)
	check("credits spent on repair", float(run.credits), 0.0)
	run.credits = 1000
	ShopRules.buy(run, items, "special.torpedo.t1")
	run.ammo["special.torpedo.t1"] = 1
	check("restock cost", float(ShopRules.restock_cost(run, items, "special.torpedo.t1")), 240.0)
	ShopRules.restock(run, items, "special.torpedo.t1")
	check("restocked to capacity", float(run.ammo["special.torpedo.t1"]), 4.0)


func test_economy() -> void:
	print("stage credits")
	var econ := _json("economy.json")
	var stats := {"kills": 45, "spawned": 50, "kill_credits": 900, "shots_fired": 200, "shots_hit": 120,
		"hull_damage": 0.0, "armor_start": 100.0, "boss_spawned": true, "boss_killed": true,
		"boss_kill_time": 20.0, "boss_par_time": 40.0}
	var r := Economy.stage_results(stats, econ, {"name": "Normal", "credit_mult": 1.0})
	# 900 kills + 500 (90%) + accuracy 0.6 -> 500 * 0.5 = 250 + 500 no damage + 1500 boss + 20 s * 25 = 500
	check("normal total", float(r["total"]), 900.0 + 500.0 + 250.0 + 500.0 + 1500.0 + 500.0)
	var r2 := Economy.stage_results(stats, econ, {"name": "Hard", "credit_mult": 1.3})
	check("hard multiplies the total", float(r2["total"]), roundf(4150.0 * 1.3))
	stats["hull_damage"] = 50.0
	var r3 := Economy.stage_results(stats, econ, {"name": "Normal", "credit_mult": 1.0})
	check("half the hull lost gives half the hull bonus", float(r3["total"]), 4150.0 - 500.0 + 200.0)


func test_save_round_trip() -> void:
	print("save and load")
	SaveSystem.base_dir = "user://test_saves"
	var items := _items()
	var econ := _json("economy.json")
	var run := RunState.create("single", ["frontier"], "hard", econ, {"starting_credits_mult": 0.85})
	run.slot = 2
	ShopRules.buy(run, items, "special.mines.t1")
	run.hull_damage = 12.5
	run.level_index = 3
	run.stats["kills"] = 77
	check("save writes a file", 1.0 if SaveSystem.save(run) else 0.0, 1.0)
	var back := SaveSystem.load_slot(2)
	check("load returns a run", 0.0 if back == null else 1.0, 1.0)
	if back != null:
		check("credits survive", float(back.credits), float(run.credits))
		check("equipment survives", 1.0 if back.equipped == run.equipped else 0.0, 1.0)
		check("ammo survives", float(back.ammo.get("special.mines.t1", -1)), 10.0)
		check("hull damage survives", back.hull_damage, 12.5)
		check("progress survives", float(back.level_index), 3.0)
		check("stats survive", float(back.stats["kills"]), 77.0)
		check("a reload starts a new shop visit", float(back.shop_visit), float(run.shop_visit + 1))
	check("unknown future version is refused", 1.0 if RunState.from_dict({"version": 999, "set_ids": []}) == null else 0.0, 1.0)
	SaveSystem.delete_slot(2)
	check("slot deleted", 1.0 if SaveSystem.load_slot(2) == null else 0.0, 1.0)
	SaveSystem.base_dir = SaveSystem.DIR
