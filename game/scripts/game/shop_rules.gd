class_name ShopRules
extends RefCounted
## The shop's rules, independent of any screen: buying needs credits, prerequisites and no
## conflicting branch; selling refunds fully in the same visit, partly afterwards; one item
## per slot is equipped but any number can be owned. `items` maps ids to item definitions.

const CATEGORY_SLOTS := {
	"reactor": ["reactor"], "shield": ["shield"], "armor": ["armor"],
	"weapon": ["weapon1", "weapon2"], "special": ["special"],
}
# Slots the ship cannot fly without.
const REQUIRED_SLOTS := ["reactor", "armor"]

const OWNED := "owned"
const EQUIPPED := "equipped"
const AVAILABLE := "available"       # can be bought now
const TOO_EXPENSIVE := "expensive"   # everything but the credits is in place
const LOCKED := "locked"             # a prerequisite is missing
const EXCLUDED := "excluded"         # a conflicting branch is owned


static func slots_for(item: Dictionary) -> Array:
	return CATEGORY_SLOTS.get(item.get("category", ""), [])


static func state(run: RunState, items: Dictionary, id: String) -> String:
	if run.owned.has(id):
		return EQUIPPED if run.is_equipped(id) else OWNED
	var item: Dictionary = items.get(id, {})
	for other: String in exclusions(items, id):
		if run.owned.has(other):
			return EXCLUDED
	for req: String in item.get("requires", []):
		if not run.owned.has(req):
			return LOCKED
	if run.credits < int(item.get("cost", 0)):
		return TOO_EXPENSIVE
	return AVAILABLE


## Ids that conflict with `id`, in either direction (A excludes B also means B excludes A).
static func exclusions(items: Dictionary, id: String) -> Array:
	var out: Array = (items.get(id, {}) as Dictionary).get("excludes", []).duplicate()
	for other: String in items:
		if id in (items[other] as Dictionary).get("excludes", []) and not other in out:
			out.append(other)
	return out


## [ok, reason]. The reason is shown to the player when ok is false.
static func can_buy(run: RunState, items: Dictionary, id: String) -> Array:
	var item: Dictionary = items.get(id, {})
	if item.is_empty():
		return [false, "Unknown item."]
	match state(run, items, id):
		OWNED, EQUIPPED:
			return [false, "Already owned."]
		EXCLUDED:
			for other: String in exclusions(items, id):
				if run.owned.has(other):
					return [false, "Cannot be combined with %s. Sell it first." % items[other].get("name", other)]
		LOCKED:
			var missing: Array = []
			for req: String in item.get("requires", []):
				if not run.owned.has(req):
					missing.append(items.get(req, {}).get("name", req))
			return [false, "Requires %s." % ", ".join(missing)]
		TOO_EXPENSIVE:
			return [false, "Not enough credits."]
	return [true, ""]


static func buy(run: RunState, items: Dictionary, id: String) -> bool:
	if not can_buy(run, items, id)[0]:
		return false
	var item: Dictionary = items[id]
	run.credits -= int(item.get("cost", 0))
	run.owned[id] = run.shop_visit
	if item.get("category", "") == "special":
		run.ammo[id] = int(item.get("ammo", 0))
	# Fill an empty slot straight away; upgrading within a branch replaces the lower tier.
	var slots := slots_for(item)
	for s: String in slots:
		if run.equipped[s] == "":
			run.equipped[s] = id
			return true
	for s: String in slots:
		var cur: String = run.equipped[s]
		var cur_item: Dictionary = items.get(cur, {})
		var same_branch_lower: bool = cur_item.get("branch", "") == item.get("branch", "") \
				and int(cur_item.get("tier", 0)) < int(item.get("tier", 0))
		if cur != "" and (cur in item.get("requires", []) or same_branch_lower):
			run.equipped[s] = id
			return true
	return true


static func sell_value(run: RunState, items: Dictionary, economy: Dictionary, id: String) -> int:
	var cost := int((items.get(id, {}) as Dictionary).get("cost", 0))
	if int(run.owned.get(id, -1)) == run.shop_visit:
		return cost
	return floori(cost * float(economy.get("sell_refund", 0.75)))


static func can_sell(run: RunState, items: Dictionary, id: String) -> Array:
	if not run.owned.has(id):
		return [false, "Not owned."]
	for other: String in run.owned:
		if id in (items.get(other, {}) as Dictionary).get("requires", []):
			return [false, "Sell %s first; it is built on this." % items[other].get("name", other)]
	for s: String in REQUIRED_SLOTS:
		if run.equipped[s] == id:
			return [false, "The ship needs a %s. Equip another one first." % s]
	return [true, ""]


static func sell(run: RunState, items: Dictionary, economy: Dictionary, id: String) -> bool:
	if not can_sell(run, items, id)[0]:
		return false
	run.credits += sell_value(run, items, economy, id)
	run.owned.erase(id)
	run.ammo.erase(id)
	for s: String in RunState.SLOTS:
		if run.equipped[s] == id:
			run.equipped[s] = ""
	return true


## Equips an owned item into `slot` (any valid slot when slot is ""). A weapon already in the
## other weapon slot swaps places with whatever was in this one.
static func equip(run: RunState, items: Dictionary, id: String, slot: String = "") -> bool:
	if not run.owned.has(id):
		return false
	var slots := slots_for(items.get(id, {}))
	if slots.is_empty():
		return false
	if slot == "":
		slot = slots[0]
	if not slot in slots:
		return false
	var previous: String = run.equipped[slot]
	for s: String in slots:
		if s != slot and run.equipped[s] == id:
			run.equipped[s] = previous
	run.equipped[slot] = id
	return true


static func can_unequip(slot: String) -> bool:
	return not slot in REQUIRED_SLOTS


static func unequip(run: RunState, slot: String) -> bool:
	if not can_unequip(slot):
		return false
	run.equipped[slot] = ""
	return true


# ---------------------------------------------------------------- repair and ammo

static func armor_max(run: RunState, items: Dictionary) -> float:
	return float((items.get(run.equipped["armor"], {}) as Dictionary).get("hp", 100.0))


## Armor the ship will start the next stage with (never below 1).
static func armor_now(run: RunState, items: Dictionary) -> float:
	var m := armor_max(run, items)
	return clampf(m - run.hull_damage, 1.0, m)


static func repair_cost(run: RunState, items: Dictionary, economy: Dictionary) -> int:
	var missing := armor_max(run, items) - armor_now(run, items)
	return ceili(missing * float(economy.get("repair_cost_per_hp", 3)))


## Repairs as much as the credits allow. Returns the credits spent.
static func repair(run: RunState, items: Dictionary, economy: Dictionary) -> int:
	var per := float(economy.get("repair_cost_per_hp", 3))
	var missing := armor_max(run, items) - armor_now(run, items)
	if missing <= 0.0:
		run.hull_damage = 0.0
		return 0
	var points := missing if per <= 0.0 else minf(missing, floorf(run.credits / per))
	var spent := ceili(points * per)
	run.credits -= spent
	run.hull_damage = maxf(0.0, run.hull_damage - points)
	if armor_now(run, items) >= armor_max(run, items):
		run.hull_damage = 0.0
	return spent


static func restock_cost(run: RunState, items: Dictionary, id: String) -> int:
	var item: Dictionary = items.get(id, {})
	var missing := int(item.get("ammo", 0)) - int(run.ammo.get(id, 0))
	return maxi(missing, 0) * int(item.get("restock_cost", 0))


## Buys as much ammo as the credits allow. Returns the credits spent.
static func restock(run: RunState, items: Dictionary, id: String) -> int:
	var item: Dictionary = items.get(id, {})
	var per := int(item.get("restock_cost", 0))
	var missing := maxi(int(item.get("ammo", 0)) - int(run.ammo.get(id, 0)), 0)
	var n := missing if per <= 0 else mini(missing, run.credits / per)
	run.credits -= n * per
	run.ammo[id] = int(run.ammo.get(id, 0)) + n
	return n * per
