class_name Economy
extends RefCounted
## Credits earned for a stage, as a list of lines the results screen shows one by one.
## All weights come from data/economy.json ("results") and data/difficulty.json.


## stats: kills, spawned, kill_credits, shots_fired, shots_hit, hull_damage, armor_start,
## boss_spawned, boss_killed, boss_kill_time, boss_par_time, pickup_credits, secrets.
## Returns {"lines": [[label, detail, amount], ...], "total": int}.
static func stage_results(stats: Dictionary, economy: Dictionary, difficulty: Dictionary) -> Dictionary:
	var w: Dictionary = economy.get("results", {})
	var lines: Array = []

	var kills := int(stats.get("kills", 0))
	var spawned := int(stats.get("spawned", 0))
	lines.append(["Enemies destroyed", "%d" % kills, int(stats.get("kill_credits", 0))])

	var pct := 0.0
	if spawned > 0:
		pct = 100.0 * kills / spawned
	var kill_bonus := 0
	for tier: Array in w.get("kill_percent_bonus", []):
		if pct >= float(tier[0]) - 0.001:
			kill_bonus = int(tier[1])
	lines.append(["Destroyed %d%% of the enemies" % floori(pct), "", kill_bonus])

	var fired := int(stats.get("shots_fired", 0))
	var acc := 0.0
	if fired > 0:
		acc = clampf(float(stats.get("shots_hit", 0)) / fired, 0.0, 1.0)
	var acc_min := float(w.get("accuracy_bonus_min_accuracy", 0.2))
	var acc_bonus := roundi(float(w.get("accuracy_bonus_max", 0)) * clampf((acc - acc_min) / maxf(1.0 - acc_min, 0.001), 0.0, 1.0))
	lines.append(["Accuracy", "%d%%" % roundi(acc * 100.0), acc_bonus])

	var hull := float(stats.get("hull_damage", 0.0))
	var start := maxf(float(stats.get("armor_start", 100.0)), 1.0)
	if hull <= 0.0:
		lines.append(["No hull damage", "", int(w.get("no_hull_damage_bonus", 0))])
	else:
		var kept := clampf(1.0 - hull / start, 0.0, 1.0)
		lines.append(["Hull damage taken", "%d" % roundi(hull), roundi(float(w.get("hull_bonus_max", 0)) * kept)])

	if stats.get("boss_spawned", false):
		if stats.get("boss_killed", false):
			lines.append(["Boss destroyed", "", int(w.get("boss_kill_bonus", 0))])
			var par := float(stats.get("boss_par_time", 0.0))
			var t := float(stats.get("boss_kill_time", 0.0))
			if par > 0.0:
				var spare := maxf(0.0, par - t)
				lines.append(["Boss time", "%.1f s" % t, roundi(spare * float(w.get("boss_time_bonus_per_second", 0)))])
		else:
			lines.append(["Boss escaped", "", 0])

	if stats.has("pickup_credits"):
		lines.append(["Pickups collected", "", roundi(float(stats["pickup_credits"]) * float(w.get("pickup_credit_mult", 1.0)))])
	if int(stats.get("secrets", 0)) > 0:
		lines.append(["Secrets found", "%d" % int(stats["secrets"]), int(stats["secrets"]) * int(w.get("secret_bonus", 0))])

	var subtotal := 0
	for l: Array in lines:
		subtotal += int(l[2])
	var mult := float(difficulty.get("credit_mult", 1.0))
	var total := roundi(subtotal * mult)
	if not is_equal_approx(mult, 1.0):
		lines.append(["%s difficulty" % difficulty.get("name", ""), "x%.2f" % mult, total - subtotal])
	return {"lines": lines, "total": total, "accuracy": acc, "kill_percent": pct}
