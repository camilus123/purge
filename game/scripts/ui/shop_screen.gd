class_name ShopScreen
extends Control
## The shop between stages: the tech tree by category, the loadout, repairs and ammo,
## and a details panel that compares the selected item with what is fitted now.

signal launch_requested
signal menu_requested

const CATEGORIES := [["weapon", "Weapons"], ["shield", "Shields"], ["special", "Specials"], ["reactor", "Reactor"], ["armor", "Armor"]]
const SLOT_TITLES := {"weapon1": "Weapon 1 (LMB)", "weapon2": "Weapon 2 (RMB)", "special": "Special (MMB)",
	"shield": "Shield", "reactor": "Reactor", "armor": "Armor"}

var run: RunState
var items: Dictionary = {}
var economy: Dictionary = {}

var _category: String = "weapon"
var _selected: String = ""
var _tree: TechTreeView
var _credits: Label
var _header: Label
var _cat_buttons: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _hull_label: Label
var _repair: Button
var _ammo_label: Label
var _restock: Button
var _d_name: Label
var _d_meta: Label
var _d_desc: Label
var _d_stats: GridContainer
var _d_reason: Label
var _d_actions: HBoxContainer
var _d_actions2: HBoxContainer
var _launch: Button
var _message: Label
var _message_time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	# Header: where we are going and the credits.
	var top := HBoxContainer.new()
	outer.add_child(top)
	_header = UiTheme.label("", 26, UiTheme.ACCENT)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	_message = UiTheme.label("", 18, UiTheme.WARN)
	top.add_child(_message)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	top.add_child(spacer)
	top.add_child(UiTheme.label("CREDITS", 18, UiTheme.DIM))
	_credits = UiTheme.label("0", 32, UiTheme.TEXT)
	top.add_child(_credits)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)
	body.add_child(_build_left())

	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var scroll := ScrollContainer.new()
	center.add_child(scroll)
	_tree = TechTreeView.new()
	_tree.item_selected.connect(_select)
	scroll.add_child(_tree)

	body.add_child(_build_details())


func _build_left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiTheme.label("TECH TREE", 16, UiTheme.DIM))
	for c: Array in CATEGORIES:
		var cat: String = c[0]
		var b := UiTheme.button(c[1], func() -> void: _show_category(cat), 40)
		b.toggle_mode = true
		box.add_child(b)
		_cat_buttons[cat] = b
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("LOADOUT", 16, UiTheme.DIM))
	for s: String in ["weapon1", "weapon2", "special", "shield", "reactor", "armor"]:
		var slot_name := s
		box.add_child(UiTheme.label(SLOT_TITLES[s], 13, UiTheme.DIM))
		var b := UiTheme.button("", func() -> void: _select_slot(slot_name), 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		box.add_child(b)
		_slot_buttons[s] = b
	box.add_child(HSeparator.new())
	_hull_label = UiTheme.label("", 15)
	box.add_child(_hull_label)
	_repair = UiTheme.button("Repair", _on_repair, 36)
	box.add_child(_repair)
	_ammo_label = UiTheme.label("", 15)
	box.add_child(_ammo_label)
	_restock = UiTheme.button("Restock", _on_restock, 36)
	box.add_child(_restock)
	return panel


func _build_details() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_d_name = UiTheme.label("", 26, UiTheme.ACCENT)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_d_name)
	_d_meta = UiTheme.label("", 14, UiTheme.DIM)
	box.add_child(_d_meta)
	_d_desc = UiTheme.label("", 16)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.custom_minimum_size = Vector2(400, 0)
	box.add_child(_d_desc)
	box.add_child(HSeparator.new())
	_d_stats = GridContainer.new()
	_d_stats.columns = 2
	_d_stats.add_theme_constant_override("h_separation", 18)
	_d_stats.add_theme_constant_override("v_separation", 4)
	box.add_child(_d_stats)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	_d_reason = UiTheme.label("", 15, UiTheme.WARN)
	_d_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_d_reason)
	_d_actions = HBoxContainer.new()
	_d_actions.add_theme_constant_override("separation", 8)
	box.add_child(_d_actions)
	_d_actions2 = HBoxContainer.new()
	_d_actions2.add_theme_constant_override("separation", 8)
	box.add_child(_d_actions2)
	box.add_child(HSeparator.new())
	_launch = UiTheme.button("LAUNCH", func() -> void: launch_requested.emit(), 60)
	_launch.add_theme_font_size_override("font_size", 24)
	box.add_child(_launch)
	box.add_child(UiTheme.button("Save and quit to main menu", func() -> void: menu_requested.emit(), 38))
	return panel


# ---------------------------------------------------------------- opening and refreshing

## Shows the shop for `p_run`. `next_title` names the stage the Launch button starts.
func open(p_run: RunState, p_items: Dictionary, p_economy: Dictionary, next_title: String) -> void:
	run = p_run
	items = p_items
	economy = p_economy
	_header.text = "SHOP   -   next: " + next_title
	_launch.text = "LAUNCH   " + next_title
	if _selected == "" or not items.has(_selected):
		_selected = run.equipped["weapon1"]
	_show_category(String(items.get(_selected, {}).get("category", "weapon")) if _selected != "" else "weapon")
	_launch.grab_focus.call_deferred()


func _show_category(cat: String) -> void:
	_category = cat
	for c: String in _cat_buttons:
		(_cat_buttons[c] as Button).button_pressed = c == cat
	_tree.show_category(cat, items, run)
	if _selected == "" or items.get(_selected, {}).get("category", "") != cat:
		_selected = ""
		for s: String in RunState.SLOTS:
			var id: String = run.equipped[s]
			if id != "" and items.get(id, {}).get("category", "") == cat:
				_selected = id
				break
	_refresh()


func _select(id: String) -> void:
	_selected = id
	_refresh()


func _select_slot(slot: String) -> void:
	var id: String = run.equipped[slot]
	var cat := "weapon" if slot.begins_with("weapon") else slot
	_selected = id
	_show_category(cat)
	if id == "":
		_selected = ""
		_refresh()


func _flash(text: String) -> void:
	_message.text = text
	_message_time = 3.0


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


func _refresh() -> void:
	_credits.text = UiTheme.format_int(run.credits)
	_tree.select(_selected)
	for s: String in _slot_buttons:
		var id: String = run.equipped[s]
		(_slot_buttons[s] as Button).text = items.get(id, {}).get("name", "(empty)") if id != "" else "(empty)"

	var amax := ShopRules.armor_max(run, items)
	var anow := ShopRules.armor_now(run, items)
	_hull_label.text = "Hull: %d / %d" % [roundi(anow), roundi(amax)]
	var rc := ShopRules.repair_cost(run, items, economy)
	_repair.text = "Repair hull  (%s cr)" % UiTheme.format_int(rc) if rc > 0 else "Hull is fully repaired"
	_repair.disabled = rc <= 0 or run.credits <= 0
	var sp: String = run.equipped["special"]
	if sp != "":
		_ammo_label.text = "%s ammo: %d / %d" % [items[sp].get("name", sp), int(run.ammo.get(sp, 0)), int(items[sp].get("ammo", 0))]
		var cost := ShopRules.restock_cost(run, items, sp)
		_restock.text = "Restock ammo  (%s cr)" % UiTheme.format_int(cost) if cost > 0 else "Ammo is full"
		_restock.disabled = cost <= 0 or run.credits < int(items[sp].get("restock_cost", 0))
		_restock.visible = true
	else:
		_ammo_label.text = "No special weapon fitted"
		_restock.visible = false
	_refresh_details()


func _refresh_details() -> void:
	for c in _d_stats.get_children():
		c.queue_free()
	for c in _d_actions.get_children():
		c.queue_free()
	for c in _d_actions2.get_children():
		c.queue_free()
	_d_reason.text = ""
	if _selected == "" or not items.has(_selected):
		_d_name.text = "Select an item"
		_d_meta.text = ""
		_d_desc.text = "Click a node in the tree. Owned items can be equipped freely; selling refunds the full price in the same visit and %d%% later." % roundi(float(economy.get("sell_refund", 0.75)) * 100.0)
		return
	var it: Dictionary = items[_selected]
	var st := ShopRules.state(run, items, _selected)
	_d_name.text = it.get("name", _selected)
	_d_meta.text = "%s  -  %s branch  -  tier %d  -  %s cr" % [String(it.get("category", "")).capitalize(),
			String(it.get("branch", "")).capitalize(), int(it.get("tier", 1)), UiTheme.format_int(int(it.get("cost", 0)))]
	_d_desc.text = it.get("description", "")

	# Compare with what this item would replace.
	var slots := ShopRules.slots_for(it)
	var current: Dictionary = {}
	if not slots.is_empty():
		var cur_id: String = run.equipped[slots[0]]
		if cur_id != "" and cur_id != _selected:
			current = items.get(cur_id, {})
	for r: Array in ItemStats.compare(it, current):
		_d_stats.add_child(UiTheme.label(r[0], 15, UiTheme.DIM))
		_d_stats.add_child(UiTheme.label(r[1], 15, r[2]))
	if not current.is_empty():
		_d_stats.add_child(UiTheme.label("", 12))
		_d_stats.add_child(UiTheme.label("compared with %s" % current.get("name", ""), 12, UiTheme.DIM))

	if st in [ShopRules.OWNED, ShopRules.EQUIPPED]:
		for s: String in slots:
			if run.equipped[s] == _selected:
				if ShopRules.can_unequip(s):
					_d_actions.add_child(_action("Unequip " + _short(s), func() -> void: _do(ShopRules.unequip(run, s), "")))
			else:
				_d_actions.add_child(_action("Equip " + _short(s), func() -> void: _do(ShopRules.equip(run, items, _selected, s), "")))
		var can_sell := ShopRules.can_sell(run, items, _selected)
		var value := ShopRules.sell_value(run, items, economy, _selected)
		var sell := _action("Sell  (+%s cr)" % UiTheme.format_int(value), _on_sell)
		sell.disabled = not can_sell[0]
		_d_actions2.add_child(sell)
		if not can_sell[0]:
			_d_reason.text = can_sell[1]
	else:
		var can := ShopRules.can_buy(run, items, _selected)
		var buy := _action("Buy  (%s cr)" % UiTheme.format_int(int(it.get("cost", 0))), _on_buy)
		buy.disabled = not can[0]
		_d_actions.add_child(buy)
		_d_reason.text = can[1]


func _short(slot: String) -> String:
	return {"weapon1": "on LMB", "weapon2": "on RMB"}.get(slot, "")


func _action(text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, cb, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _do(ok: bool, message: String) -> void:
	if ok:
		if message != "":
			_flash(message)
	else:
		Sfx.play_asset("sfx.ui.deny")
	_tree.refresh()
	_refresh()


func _on_buy() -> void:
	if ShopRules.buy(run, items, _selected):
		Sfx.play_asset("sfx.ui.buy")
		_do(true, "Bought %s" % items[_selected].get("name", ""))
	else:
		_do(false, "")


func _on_sell() -> void:
	var name: String = items[_selected].get("name", "")
	_do(ShopRules.sell(run, items, economy, _selected), "Sold %s" % name)


func _on_repair() -> void:
	var spent := ShopRules.repair(run, items, economy)
	_do(spent > 0, "Repaired for %s cr" % UiTheme.format_int(spent))


func _on_restock() -> void:
	var spent := ShopRules.restock(run, items, run.equipped["special"])
	_do(spent > 0, "Ammo restocked for %s cr" % UiTheme.format_int(spent))


## Debug builds: F7 adds credits for testing.
func _unhandled_input(event: InputEvent) -> void:
	if visible and OS.is_debug_build() and event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_F7:
		run.credits += 10000
		_flash("Debug: +10,000 credits")
		_tree.refresh()
		_refresh()
