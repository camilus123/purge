class_name ItemStats
extends RefCounted
## Turns an item definition into rows of readable stats for the shop, so two items
## can be compared line by line. Each row: [label, number, text, higher_is_better].
## Numbers that depend on the power split are shown at the 50/50 default.


static func rows(item: Dictionary) -> Array:
	var out: Array = []
	match String(item.get("category", "")):
		"weapon":
			_weapon(item, out)
		"shield":
			out.append(["Capacity", float(item.get("capacity", 0)), "%d" % int(item.get("capacity", 0)), true])
			out.append(["Recharge", float(item.get("recharge", 0)), "%.0f / s" % float(item.get("recharge", 0)), true])
			out.append(["Recharge delay", float(item.get("delay", 0)), "%.2f s" % float(item.get("delay", 0)), false])
			if float(item.get("reflect", 0)) > 0.0 or float(item.get("bleed", 0)) > 0.0:
				out.append(["Reflected", float(item.get("reflect", 0)), _pct(item.get("reflect", 0)), true])
				out.append(["Bleeds to hull", float(item.get("bleed", 0)), _pct(item.get("bleed", 0)), false])
		"reactor":
			out.append(["Output", float(item.get("output", 0)), "%d MW" % int(item.get("output", 0)), true])
			out.append(["Capacitor", float(item.get("capacitor", 0)), "%d" % int(item.get("capacitor", 0)), true])
		"armor":
			out.append(["Hit points", float(item.get("hp", 0)), "%d" % int(item.get("hp", 0)), true])
			var res: Dictionary = item.get("resist", {})
			for t: String in ["kinetic", "explosive", "energy"]:
				out.append(["%s resist" % t.capitalize(), float(res.get(t, 0)), _pct(res.get(t, 0)), true])
			out.append(["Ship speed", float(item.get("speed_mult", 1)), _pct(item.get("speed_mult", 1)), true])
		"special":
			_special(item, out)
	return out


static func _pct(v: Variant) -> String:
	return "%d%%" % roundi(float(v) * 100.0)


static func _scale(item: Dictionary, key: String) -> float:
	var ps: Dictionary = item.get("power_scaling", {})
	if ps.has(key):
		return lerpf(float(ps[key][0]), float(ps[key][1]), 0.5)
	return 1.0


static func _weapon(item: Dictionary, out: Array) -> void:
	var behaviour := String(item.get("behaviour", "projectile"))
	var dmg := float(item.get("damage", 0)) * _scale(item, "damage")
	var rate := float(item.get("fire_rate", 1)) * _scale(item, "fire_rate")
	var n := int(item.get("projectiles", 1))
	out.append(["Type", 0.0, "%s, %s damage" % [String(item.get("class", "")).capitalize(), String(item.get("damage_type", "")).capitalize()], true])
	match behaviour:
		"beam":
			out.append(["Damage per second", dmg, "%d" % roundi(dmg), true])
			out.append(["Energy per second", float(item.get("energy_per_shot", 0)), "%d" % roundi(float(item.get("energy_per_shot", 0))), false])
			if float(item.get("sweep_deg", 0)) > 0.0:
				out.append(["Sweep", float(item.get("sweep_deg", 0)), "%d deg" % int(item.get("sweep_deg", 0)), true])
			out.append(["Range", float(item.get("range", 0)), "%d" % int(item.get("range", 0)), true])
		"rail":
			out.append(["Damage", dmg, "%d" % roundi(dmg), true])
			out.append(["Shots per second", rate, "%.2f" % rate, true])
			out.append(["Charge time", float(item.get("charge_time", 0)), "%.2f s" % float(item.get("charge_time", 0)), false])
			out.append(["Energy per shot", float(item.get("energy_per_shot", 0)), "%d" % roundi(float(item.get("energy_per_shot", 0))), false])
			out.append(["Damage per second", dmg * rate, "%d" % roundi(dmg * rate), true])
		_:
			out.append(["Damage", dmg, "%.1f x %d" % [dmg, n] if n > 1 else "%.1f" % dmg, true])
			out.append(["Shots per second", rate, "%.1f" % rate, true])
			out.append(["Damage per second", dmg * rate * n, "%d" % roundi(dmg * rate * n), true])
			out.append(["Energy per second", float(item.get("energy_per_shot", 0)) * rate, "%d" % roundi(float(item.get("energy_per_shot", 0)) * rate), false])
			if float(item.get("spread_deg", 0)) > 0.0:
				out.append(["Spread", float(item.get("spread_deg", 0)), "%d deg" % int(item.get("spread_deg", 0)), true])
			if float(item.get("splash", 0)) > 0.0:
				out.append(["Blast radius", float(item.get("splash", 0)), "%.1f" % float(item.get("splash", 0)), true])
			if float(item.get("heat_capacity", 0)) > 0.0:
				var hps := float(item.get("heat_per_shot", 0)) * float(item.get("fire_rate", 1)) - float(item.get("heat_dissipation", 0))
				var secs := float(item.get("heat_capacity", 0)) / maxf(hps, 0.01)
				out.append(["Fire before overheating", secs, "%.1f s" % secs, true])
			if float(item.get("spin_up", 0)) > 0.0:
				out.append(["Spin-up", float(item.get("spin_up", 0)), "%.2f s" % float(item.get("spin_up", 0)), false])
	if int(item.get("pierce", 0)) > 0:
		out.append(["Pierces", float(item.get("pierce", 0)), "%d enemies" % int(item.get("pierce", 0)), true])


static func _special(item: Dictionary, out: Array) -> void:
	out.append(["Ammo", float(item.get("ammo", 0)), "%d" % int(item.get("ammo", 0)), true])
	out.append(["Restock per use", float(item.get("restock_cost", 0)), "%d cr" % int(item.get("restock_cost", 0)), false])
	if String(item.get("effect", "")) == "shockwave":
		out.append(["Damage to all", float(item.get("shockwave_damage", 0)), "%d" % int(item.get("shockwave_damage", 0)), true])
		out.append(["Clears bullets", 1.0, "Yes", true])
		return
	var p: Dictionary = item.get("projectile", {})
	var volley := int(item.get("volley", 1))
	if p.has("burst"):
		var b: Dictionary = p["burst"]
		out.append(["Bomblets", float(b.get("count", 0)), "%d" % int(b.get("count", 0)), true])
		out.append(["Bomblet damage", float(b.get("damage", 0)), "%d" % int(b.get("damage", 0)), true])
	else:
		out.append(["Per volley", float(volley), "%d" % volley, true])
		out.append(["Damage", float(p.get("damage", 0)), "%d" % int(p.get("damage", 0)), true])
	if float(p.get("splash", 0)) > 0.0:
		out.append(["Blast radius", float(p.get("splash", 0)), "%.1f" % float(p.get("splash", 0)), true])
	if float(p.get("homing", 0)) > 0.0:
		out.append(["Homing", float(p.get("homing", 0)), "Yes", true])


## [label, text, colour] rows comparing `item` with `current` (may be empty).
static func compare(item: Dictionary, current: Dictionary) -> Array:
	var mine := rows(item)
	var theirs: Dictionary = {}
	for r: Array in rows(current):
		theirs[r[0]] = r
	var out: Array = []
	for r: Array in mine:
		var color := UiTheme.TEXT
		var text: String = r[2]
		if theirs.has(r[0]) and r[0] != "Type":
			var o: Array = theirs[r[0]]
			if not is_equal_approx(float(o[1]), float(r[1])):
				var better: bool = (float(r[1]) > float(o[1])) == bool(r[3])
				color = UiTheme.GOOD if better else UiTheme.BAD
				text = "%s  (now %s)" % [r[2], o[2]]
		out.append([r[0], text, color])
	return out
